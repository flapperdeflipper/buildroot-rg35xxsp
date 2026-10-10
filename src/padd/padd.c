// SPDX-License-Identifier: AGPL-3.0-only
/*
 * rgos-padd — gamepad-to-desktop input daemon for RGOS.
 *
 * Grabs gamepad devices (the built-in gpio-keys pad, USB/BT controllers) and
 * turns their buttons into keyboard and mouse events through two uinput
 * devices, so a Wayland compositor can be driven with only the built-in
 * controls. Runs inside the sway session (started from the sway config).
 *
 * Modes:
 *   nav          buttons send keys (arrows, enter, escape, ...)
 *   mouse        d-pad moves the pointer, face buttons click / scroll
 *   osk          on-screen keyboard: d-pad steps the pointer key by key
 *   passthrough  devices are released for games; only the exit chord is read
 *
 * While the hold button (default BTN_MODE, the "Menu" key) is held, the
 * "menu" layer applies in every mode. Tapping the hold button on its own
 * runs its binding from the current mode's layer.
 *
 * Config: ~/.config/rgos/padd.conf, falling back to /etc/rgos/padd.conf.
 *   set  <option> <value...>
 *   <layer> <button> <action> [args...]
 * See the default padd.conf for the full syntax.
 *
 * Signals: SIGHUP reloads the config, SIGUSR1 toggles mouse mode,
 * SIGUSR2 toggles passthrough. The current mode is written to
 * $XDG_RUNTIME_DIR/rgos-padd.mode for the panel.
 *
 * Control FIFO $XDG_RUNTIME_DIR/rgos-padd.ctl (see rgos-padctl), one
 * command per line:
 *   mode <nav|mouse|osk|passthrough|toggle-mouse|toggle-osk>
 *   warp <x> <y>     put the pointer at screen pixel x,y (absolute device)
 *
 * Lid switches are watched too (never grabbed): on_lid_close / on_lid_open.
 */

#define _GNU_SOURCE
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <poll.h>
#include <signal.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/inotify.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

#include <libevdev/libevdev.h>
#include <libevdev/libevdev-uinput.h>

#define MAX_DEVICES   8
#define MAX_BINDINGS  128
#define MAX_KEYS      4
#define MAX_PRESSED   KEY_CNT
#define TICK_MS       16

enum mode { MODE_NAV, MODE_MOUSE, MODE_OSK, MODE_PASSTHROUGH, MODE_COUNT };
enum layer { LAYER_NAV, LAYER_MOUSE, LAYER_OSK, LAYER_MENU, LAYER_COUNT };

static const char *mode_names[] = { "nav", "mouse", "osk", "passthrough" };
static const char *layer_names[] = { "nav", "mouse", "osk", "menu" };

enum action_type {
	ACT_NONE,
	ACT_KEY,     /* press keys while the button is held */
	ACT_CLICK,   /* mouse button while held */
	ACT_MOVE,    /* pointer motion while held */
	ACT_SCROLL,  /* wheel, repeating while held */
	ACT_STEP,    /* pointer jump of one on-screen-keyboard key */
	ACT_EXEC,    /* run a shell command on press */
	ACT_MODE,    /* switch mode on press */
};

enum dir { DIR_UP, DIR_DOWN, DIR_LEFT, DIR_RIGHT };

struct binding {
	enum layer layer;
	int button;
	enum action_type type;
	int keys[MAX_KEYS];
	int nkeys;
	int arg;          /* mouse button code, direction, or mode */
	char *cmd;
};

struct config {
	struct binding bindings[MAX_BINDINGS];
	int nbindings;
	int hold_button;
	int passthrough_exit[2];  /* chord that leaves passthrough mode */
	int speed_min, speed_max, accel_ticks;
	int scroll_repeat_ms;
	int step_x, step_y;
	int screen_w, screen_h;      /* range of the absolute "warp" device */
	int start_mode;
	char *on_enter[MODE_COUNT];  /* shell commands run on mode changes */
	char *on_leave[MODE_COUNT];
	char *on_lid_close, *on_lid_open;
};

struct device {
	int fd;
	struct libevdev *dev;
	char path[PATH_MAX];
	bool grabbed;
	bool lid;   /* lid switch: read, never grabbed */
};

/* What a held physical button is currently doing, so release undoes it */
struct active {
	const struct binding *b;
	bool used;
};

static struct config cfg;
static struct device devices[MAX_DEVICES];
static struct libevdev_uinput *ui_kbd, *ui_mouse, *ui_warp;
static int ctl_fd = -1;
static char ctl_buf[256];
static size_t ctl_len;
static enum mode mode = MODE_NAV;
static enum mode osk_return = MODE_NAV;  /* mode to go back to after osk */
static struct active active[MAX_PRESSED];
static bool hold_down, hold_used;
static int move_held[4];
static int move_ticks;
static long scroll_next_ms;
static const struct binding *scroll_binding;
static volatile sig_atomic_t sig_reload, sig_toggle_mouse, sig_toggle_pass;
static char config_path[PATH_MAX];

static void logmsg(const char *fmt, ...)
{
	va_list ap;
	va_start(ap, fmt);
	fprintf(stderr, "rgos-padd: ");
	vfprintf(stderr, fmt, ap);
	fputc('\n', stderr);
	va_end(ap);
}

static long now_ms(void)
{
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return ts.tv_sec * 1000L + ts.tv_nsec / 1000000L;
}

/* ------------------------------------------------------------------------ */
/* Config                                                                    */
/* ------------------------------------------------------------------------ */

static int code_from_name(const char *name)
{
	int code = libevdev_event_code_from_name(EV_KEY, name);
	if (code < 0)
		logmsg("%s: unknown key/button name '%s'", config_path, name);
	return code;
}

static void config_defaults(struct config *c)
{
	for (int i = 0; i < c->nbindings; i++)
		free(c->bindings[i].cmd);
	for (int m = 0; m < MODE_COUNT; m++) {
		free(c->on_enter[m]);
		free(c->on_leave[m]);
	}
	free(c->on_lid_close);
	free(c->on_lid_open);
	memset(c, 0, sizeof(*c));
	c->hold_button = BTN_MODE;
	c->passthrough_exit[0] = BTN_MODE;
	c->passthrough_exit[1] = BTN_START;
	c->speed_min = 2;
	c->speed_max = 14;
	c->accel_ticks = 40;
	c->scroll_repeat_ms = 120;
	c->step_x = 49;
	c->step_y = 45;
	c->screen_w = 640;
	c->screen_h = 480;
	c->start_mode = MODE_NAV;
}

static int parse_mode(const char *s)
{
	for (int m = 0; m < MODE_COUNT; m++)
		if (!strcmp(s, mode_names[m]))
			return m;
	if (!strcmp(s, "toggle-mouse"))
		return -1;
	if (!strcmp(s, "toggle-osk"))
		return -2;
	return -3;
}

static int parse_dir(const char *s)
{
	if (!strcmp(s, "up")) return DIR_UP;
	if (!strcmp(s, "down")) return DIR_DOWN;
	if (!strcmp(s, "left")) return DIR_LEFT;
	if (!strcmp(s, "right")) return DIR_RIGHT;
	return -1;
}

static bool parse_binding(struct config *c, char *layer, char *button, char *action, char *rest, int lineno)
{
	struct binding b = { 0 };
	int l;

	for (l = 0; l < LAYER_COUNT; l++)
		if (!strcmp(layer, layer_names[l]))
			break;
	if (l == LAYER_COUNT) {
		logmsg("%s:%d: unknown layer '%s'", config_path, lineno, layer);
		return false;
	}
	b.layer = l;
	if ((b.button = code_from_name(button)) < 0)
		return false;

	if (!strcmp(action, "key")) {
		b.type = ACT_KEY;
		for (char *tok = strtok(rest, "+ \t"); tok && b.nkeys < MAX_KEYS; tok = strtok(NULL, "+ \t"))
			if ((b.keys[b.nkeys++] = code_from_name(tok)) < 0)
				return false;
		if (!b.nkeys)
			return false;
	} else if (!strcmp(action, "click")) {
		b.type = ACT_CLICK;
		if (!strcmp(rest, "left")) b.arg = BTN_LEFT;
		else if (!strcmp(rest, "right")) b.arg = BTN_RIGHT;
		else if (!strcmp(rest, "middle")) b.arg = BTN_MIDDLE;
		else return false;
	} else if (!strcmp(action, "move") || !strcmp(action, "scroll") || !strcmp(action, "step")) {
		b.type = action[0] == 'm' ? ACT_MOVE : action[1] == 'c' ? ACT_SCROLL : ACT_STEP;
		if ((b.arg = parse_dir(rest)) < 0)
			return false;
	} else if (!strcmp(action, "exec")) {
		b.type = ACT_EXEC;
		if (!*rest)
			return false;
		b.cmd = strdup(rest);
	} else if (!strcmp(action, "mode")) {
		b.type = ACT_MODE;
		if ((b.arg = parse_mode(rest)) < -2)
			return false;
	} else {
		logmsg("%s:%d: unknown action '%s'", config_path, lineno, action);
		return false;
	}

	if (c->nbindings >= MAX_BINDINGS) {
		logmsg("%s:%d: too many bindings", config_path, lineno);
		free(b.cmd);
		return false;
	}
	c->bindings[c->nbindings++] = b;
	return true;
}

static bool parse_set(struct config *c, char *opt, char *rest, int lineno)
{
	if (!strcmp(opt, "hold_button")) {
		return (c->hold_button = code_from_name(rest)) >= 0;
	} else if (!strcmp(opt, "passthrough_exit")) {
		char *a = strtok(rest, "+ \t"), *b = strtok(NULL, "+ \t");
		if (!a || !b)
			return false;
		c->passthrough_exit[0] = code_from_name(a);
		c->passthrough_exit[1] = code_from_name(b);
		return c->passthrough_exit[0] >= 0 && c->passthrough_exit[1] >= 0;
	} else if (!strcmp(opt, "mouse_speed")) {
		return sscanf(rest, "%d %d %d", &c->speed_min, &c->speed_max, &c->accel_ticks) == 3;
	} else if (!strcmp(opt, "scroll_repeat_ms")) {
		return sscanf(rest, "%d", &c->scroll_repeat_ms) == 1;
	} else if (!strcmp(opt, "osk_step")) {
		return sscanf(rest, "%d %d", &c->step_x, &c->step_y) == 2;
	} else if (!strcmp(opt, "screen")) {
		return sscanf(rest, "%d %d", &c->screen_w, &c->screen_h) == 2 &&
		       c->screen_w > 1 && c->screen_h > 1;
	} else if (!strcmp(opt, "start_mode")) {
		return (c->start_mode = parse_mode(rest)) >= 0;
	} else if (!strcmp(opt, "on_lid_close") || !strcmp(opt, "on_lid_open")) {
		char **slot = opt[7] == 'c' ? &c->on_lid_close : &c->on_lid_open;
		if (!*rest)
			return false;
		free(*slot);
		*slot = strdup(rest);
		return true;
	} else if (!strcmp(opt, "on_enter") || !strcmp(opt, "on_leave")) {
		char *m = strsep(&rest, " \t");
		int mi = m ? parse_mode(m) : -3;
		if (mi < 0 || !rest || !*rest)
			return false;
		char **slot = opt[3] == 'e' ? &c->on_enter[mi] : &c->on_leave[mi];
		free(*slot);
		*slot = strdup(rest);
		return true;
	}
	logmsg("%s:%d: unknown option '%s'", config_path, lineno, opt);
	return false;
}

static bool config_load(struct config *c)
{
	const char *home = getenv("HOME");
	FILE *f = NULL;
	char line[512];
	int lineno = 0;

	if (home) {
		snprintf(config_path, sizeof(config_path), "%s/.config/rgos/padd.conf", home);
		f = fopen(config_path, "r");
	}
	if (!f) {
		snprintf(config_path, sizeof(config_path), "/etc/rgos/padd.conf");
		f = fopen(config_path, "r");
	}
	if (!f) {
		logmsg("cannot open config: %s", strerror(errno));
		return false;
	}

	config_defaults(c);
	while (fgets(line, sizeof(line), f)) {
		char *p = line, *w1, *w2, *w3, *rest;
		lineno++;
		p[strcspn(p, "\r\n")] = 0;
		p += strspn(p, " \t");
		if (!*p || *p == '#')
			continue;

		w1 = strsep(&p, " \t");
		while (p && (*p == ' ' || *p == '\t')) p++;
		w2 = p ? strsep(&p, " \t") : NULL;
		while (p && (*p == ' ' || *p == '\t')) p++;
		if (!w2) {
			logmsg("%s:%d: syntax error", config_path, lineno);
			continue;
		}

		bool ok;
		if (!strcmp(w1, "set")) {
			ok = parse_set(c, w2, p ? p : "", lineno);
		} else {
			w3 = p ? strsep(&p, " \t") : NULL;
			while (p && (*p == ' ' || *p == '\t')) p++;
			rest = p ? p : "";
			ok = w3 && parse_binding(c, w1, w2, w3, rest, lineno);
		}
		if (!ok)
			logmsg("%s:%d: ignoring invalid line", config_path, lineno);
	}
	fclose(f);
	logmsg("loaded %d bindings from %s", c->nbindings, config_path);
	return true;
}

static const struct binding *lookup(enum layer layer, int button)
{
	for (int i = 0; i < cfg.nbindings; i++)
		if (cfg.bindings[i].layer == layer && cfg.bindings[i].button == button)
			return &cfg.bindings[i];
	return NULL;
}

/* ------------------------------------------------------------------------ */
/* Output (uinput)                                                           */
/* ------------------------------------------------------------------------ */

static struct libevdev_uinput *make_uinput(const char *name, bool mouse, bool absolute)
{
	struct libevdev *dev = libevdev_new();
	struct libevdev_uinput *ui = NULL;
	int err;

	libevdev_set_name(dev, name);
	libevdev_set_id_bustype(dev, BUS_VIRTUAL);
	libevdev_set_id_vendor(dev, 0x5247);  /* "RG" */
	libevdev_set_id_product(dev, mouse ? 2 : 1);
	libevdev_enable_event_type(dev, EV_KEY);

	if (absolute) {
		/* An absolute pointer (like QEMU's tablet) used only to warp the
		 * cursor; BTN_LEFT makes udev/libinput treat it as a mouse. */
		struct input_absinfo x = { .maximum = cfg.screen_w - 1, .resolution = 1 };
		struct input_absinfo y = { .maximum = cfg.screen_h - 1, .resolution = 1 };
		libevdev_set_id_product(dev, 3);
		libevdev_enable_event_code(dev, EV_KEY, BTN_LEFT, NULL);
		libevdev_enable_event_type(dev, EV_ABS);
		libevdev_enable_event_code(dev, EV_ABS, ABS_X, &x);
		libevdev_enable_event_code(dev, EV_ABS, ABS_Y, &y);
	} else if (mouse) {
		libevdev_enable_event_code(dev, EV_KEY, BTN_LEFT, NULL);
		libevdev_enable_event_code(dev, EV_KEY, BTN_RIGHT, NULL);
		libevdev_enable_event_code(dev, EV_KEY, BTN_MIDDLE, NULL);
		libevdev_enable_event_type(dev, EV_REL);
		libevdev_enable_event_code(dev, EV_REL, REL_X, NULL);
		libevdev_enable_event_code(dev, EV_REL, REL_Y, NULL);
		libevdev_enable_event_code(dev, EV_REL, REL_WHEEL, NULL);
		libevdev_enable_event_code(dev, EV_REL, REL_HWHEEL, NULL);
	} else {
		for (int k = KEY_ESC; k < BTN_MISC; k++)
			libevdev_enable_event_code(dev, EV_KEY, k, NULL);
		for (int k = KEY_OK; k < BTN_DPAD_UP; k++)
			libevdev_enable_event_code(dev, EV_KEY, k, NULL);
	}

	err = libevdev_uinput_create_from_device(dev, LIBEVDEV_UINPUT_OPEN_MANAGED, &ui);
	libevdev_free(dev);
	if (err < 0) {
		logmsg("cannot create uinput device '%s': %s", name, strerror(-err));
		return NULL;
	}
	return ui;
}

static void emit(struct libevdev_uinput *ui, int type, int code, int value)
{
	libevdev_uinput_write_event(ui, type, code, value);
	libevdev_uinput_write_event(ui, EV_SYN, SYN_REPORT, 0);
}

/* ------------------------------------------------------------------------ */
/* Actions                                                                   */
/* ------------------------------------------------------------------------ */

static void run_command(const char *cmd)
{
	pid_t pid = fork();
	if (pid == 0) {
		setsid();
		execl("/bin/sh", "sh", "-c", cmd, (char *)NULL);
		_exit(127);
	} else if (pid < 0) {
		logmsg("fork: %s", strerror(errno));
	}
}

static void write_mode_file(void)
{
	const char *dir = getenv("XDG_RUNTIME_DIR");
	char path[PATH_MAX];
	FILE *f;

	if (!dir)
		return;
	snprintf(path, sizeof(path), "%s/rgos-padd.mode", dir);
	if ((f = fopen(path, "w"))) {
		fputs(mode_names[mode], f);  /* no newline: shown as-is by the panel */
		fclose(f);
	}
}

static void release_all(void);
static void set_grab(bool grab);

static void set_mode(enum mode m)
{
	if (m == mode)
		return;
	release_all();
	if (cfg.on_leave[mode])
		run_command(cfg.on_leave[mode]);
	if (m == MODE_OSK)
		osk_return = mode;
	mode = m;
	if (cfg.on_enter[mode])
		run_command(cfg.on_enter[mode]);
	set_grab(mode != MODE_PASSTHROUGH);
	write_mode_file();
	logmsg("mode: %s", mode_names[mode]);
}

static void action_press(const struct binding *b)
{
	switch (b->type) {
	case ACT_KEY:
		for (int i = 0; i < b->nkeys; i++)
			emit(ui_kbd, EV_KEY, b->keys[i], 1);
		break;
	case ACT_CLICK:
		emit(ui_mouse, EV_KEY, b->arg, 1);
		break;
	case ACT_MOVE:
		if (!move_held[0] && !move_held[1] && !move_held[2] && !move_held[3])
			move_ticks = 0;
		move_held[b->arg]++;
		break;
	case ACT_SCROLL:
		scroll_binding = b;
		scroll_next_ms = 0;  /* scroll immediately on the next tick */
		break;
	case ACT_STEP: {
		int dx = b->arg == DIR_LEFT ? -cfg.step_x : b->arg == DIR_RIGHT ? cfg.step_x : 0;
		int dy = b->arg == DIR_UP ? -cfg.step_y : b->arg == DIR_DOWN ? cfg.step_y : 0;
		if (dx)
			libevdev_uinput_write_event(ui_mouse, EV_REL, REL_X, dx);
		if (dy)
			libevdev_uinput_write_event(ui_mouse, EV_REL, REL_Y, dy);
		libevdev_uinput_write_event(ui_mouse, EV_SYN, SYN_REPORT, 0);
		break;
	}
	case ACT_EXEC:
		run_command(b->cmd);
		break;
	case ACT_MODE:
		if (b->arg == -1)
			set_mode(mode == MODE_MOUSE ? MODE_NAV : MODE_MOUSE);
		else if (b->arg == -2)
			set_mode(mode == MODE_OSK ? osk_return : MODE_OSK);
		else
			set_mode(b->arg);
		break;
	case ACT_NONE:
		break;
	}
}

static void action_release(const struct binding *b)
{
	switch (b->type) {
	case ACT_KEY:
		for (int i = b->nkeys - 1; i >= 0; i--)
			emit(ui_kbd, EV_KEY, b->keys[i], 0);
		break;
	case ACT_CLICK:
		emit(ui_mouse, EV_KEY, b->arg, 0);
		break;
	case ACT_MOVE:
		if (move_held[b->arg] > 0)
			move_held[b->arg]--;
		break;
	case ACT_SCROLL:
		if (scroll_binding == b)
			scroll_binding = NULL;
		break;
	default:
		break;
	}
}

static void release_all(void)
{
	for (int i = 0; i < MAX_PRESSED; i++) {
		if (active[i].b) {
			const struct binding *b = active[i].b;
			active[i].b = NULL;
			action_release(b);
		}
	}
	memset(move_held, 0, sizeof(move_held));
	scroll_binding = NULL;
	hold_down = hold_used = false;
}

static void tick(void)
{
	long now = now_ms();

	if (move_held[0] || move_held[1] || move_held[2] || move_held[3]) {
		int speed = cfg.speed_min + (cfg.speed_max - cfg.speed_min) * move_ticks / (cfg.accel_ticks ? cfg.accel_ticks : 1);
		if (speed > cfg.speed_max)
			speed = cfg.speed_max;
		int dx = (move_held[DIR_RIGHT] ? speed : 0) - (move_held[DIR_LEFT] ? speed : 0);
		int dy = (move_held[DIR_DOWN] ? speed : 0) - (move_held[DIR_UP] ? speed : 0);
		if (dx)
			libevdev_uinput_write_event(ui_mouse, EV_REL, REL_X, dx);
		if (dy)
			libevdev_uinput_write_event(ui_mouse, EV_REL, REL_Y, dy);
		libevdev_uinput_write_event(ui_mouse, EV_SYN, SYN_REPORT, 0);
		move_ticks++;
	}

	if (scroll_binding && now >= scroll_next_ms) {
		switch (scroll_binding->arg) {
		case DIR_UP:    emit(ui_mouse, EV_REL, REL_WHEEL, 1); break;
		case DIR_DOWN:  emit(ui_mouse, EV_REL, REL_WHEEL, -1); break;
		case DIR_LEFT:  emit(ui_mouse, EV_REL, REL_HWHEEL, -1); break;
		case DIR_RIGHT: emit(ui_mouse, EV_REL, REL_HWHEEL, 1); break;
		}
		scroll_next_ms = now + cfg.scroll_repeat_ms;
	}
}

static void warp(int x, int y)
{
	if (x < 0) x = 0;
	if (y < 0) y = 0;
	if (x >= cfg.screen_w) x = cfg.screen_w - 1;
	if (y >= cfg.screen_h) y = cfg.screen_h - 1;
	libevdev_uinput_write_event(ui_warp, EV_ABS, ABS_X, x);
	libevdev_uinput_write_event(ui_warp, EV_ABS, ABS_Y, y);
	libevdev_uinput_write_event(ui_warp, EV_SYN, SYN_REPORT, 0);
}

static bool ticking(void)
{
	return move_held[0] || move_held[1] || move_held[2] || move_held[3] || scroll_binding;
}

/* ------------------------------------------------------------------------ */
/* Input handling                                                            */
/* ------------------------------------------------------------------------ */

static bool pressed_on_any(int code)
{
	for (int i = 0; i < MAX_DEVICES; i++)
		if (devices[i].dev && libevdev_get_event_value(devices[i].dev, EV_KEY, code))
			return true;
	return false;
}

static void handle_button(int code, int value)
{
	enum layer base = mode == MODE_MOUSE ? LAYER_MOUSE : mode == MODE_OSK ? LAYER_OSK : LAYER_NAV;
	const struct binding *b;

	if (value == 2)  /* kernel autorepeat: clients repeat keys themselves */
		return;

	if (mode == MODE_PASSTHROUGH) {
		if (value == 1 &&
		    pressed_on_any(cfg.passthrough_exit[0]) && pressed_on_any(cfg.passthrough_exit[1]))
			set_mode(cfg.start_mode);
		return;
	}

	if (code == cfg.hold_button) {
		if (value == 1) {
			hold_down = true;
			hold_used = false;
		} else if (hold_down) {
			hold_down = false;
			/* A tap of the hold button runs its own binding from the base layer */
			if (!hold_used && (b = lookup(base, code))) {
				action_press(b);
				action_release(b);
			}
		}
		return;
	}

	if (code < 0 || code >= MAX_PRESSED)
		return;

	if (value == 1) {
		b = NULL;
		if (hold_down) {
			hold_used = true;
			b = lookup(LAYER_MENU, code);
		}
		if (!b)
			b = lookup(base, code);
		if (!b)
			return;
		active[code].b = b;
		action_press(b);
	} else if (active[code].b) {
		b = active[code].b;
		active[code].b = NULL;
		action_release(b);
	}
}

static bool is_gamepad(struct libevdev *dev)
{
	/* The built-in pad (gpio-keys) and any USB/BT controller */
	return libevdev_has_event_code(dev, EV_KEY, BTN_SOUTH) ||
	       libevdev_has_event_code(dev, EV_KEY, BTN_DPAD_UP);
}

static void set_grab(bool grab)
{
	for (int i = 0; i < MAX_DEVICES; i++) {
		struct device *d = &devices[i];
		if (!d->dev || d->lid || d->grabbed == grab)
			continue;
		if (libevdev_grab(d->dev, grab ? LIBEVDEV_GRAB : LIBEVDEV_UNGRAB) == 0)
			d->grabbed = grab;
		else
			logmsg("%s: cannot %sgrab", d->path, grab ? "" : "un");
	}
}

static bool device_known(const char *path)
{
	for (int i = 0; i < MAX_DEVICES; i++)
		if (devices[i].dev && !strcmp(devices[i].path, path))
			return true;
	return false;
}

static void device_close(struct device *d)
{
	logmsg("removed %s", d->path);
	libevdev_free(d->dev);
	close(d->fd);
	memset(d, 0, sizeof(*d));
	d->fd = -1;
	release_all();
}

static void scan_devices(void)
{
	DIR *dir = opendir("/dev/input");
	struct dirent *de;

	if (!dir)
		return;
	while ((de = readdir(dir))) {
		char path[PATH_MAX];
		struct libevdev *dev;
		int fd, slot = -1;

		if (strncmp(de->d_name, "event", 5))
			continue;
		snprintf(path, sizeof(path), "/dev/input/%s", de->d_name);
		if (device_known(path))
			continue;
		if ((fd = open(path, O_RDONLY | O_NONBLOCK | O_CLOEXEC)) < 0)
			continue;
		if (libevdev_new_from_fd(fd, &dev) < 0) {
			close(fd);
			continue;
		}
		/* Never pick up our own virtual devices */
		if (libevdev_get_id_bustype(dev) == BUS_VIRTUAL && libevdev_get_id_vendor(dev) == 0x5247) {
			libevdev_free(dev);
			close(fd);
			continue;
		}
		bool lid = libevdev_has_event_code(dev, EV_SW, SW_LID);
		if (!lid && !is_gamepad(dev)) {
			libevdev_free(dev);
			close(fd);
			continue;
		}
		for (int i = 0; i < MAX_DEVICES; i++)
			if (!devices[i].dev) { slot = i; break; }
		if (slot < 0) {
			libevdev_free(dev);
			close(fd);
			break;
		}

		struct device *d = &devices[slot];
		d->fd = fd;
		d->dev = dev;
		d->grabbed = false;
		d->lid = lid;
		snprintf(d->path, sizeof(d->path), "%s", path);
		logmsg("using %s (%s)%s", path, libevdev_get_name(dev), lid ? " as lid switch" : "");
		if (!lid && mode != MODE_PASSTHROUGH && libevdev_grab(dev, LIBEVDEV_GRAB) == 0)
			d->grabbed = true;
	}
	closedir(dir);
}

static void read_device(struct device *d)
{
	struct input_event ev;
	int rc;

	do {
		rc = libevdev_next_event(d->dev, LIBEVDEV_READ_FLAG_NORMAL, &ev);
		if (rc == LIBEVDEV_READ_STATUS_SYNC) {
			/* Dropped events: resync, then drop whatever we had pressed */
			while (rc == LIBEVDEV_READ_STATUS_SYNC)
				rc = libevdev_next_event(d->dev, LIBEVDEV_READ_FLAG_SYNC, &ev);
			release_all();
			continue;
		}
		if (rc == LIBEVDEV_READ_STATUS_SUCCESS && ev.type == EV_KEY && !d->lid)
			handle_button(ev.code, ev.value);
		else if (rc == LIBEVDEV_READ_STATUS_SUCCESS && ev.type == EV_SW && ev.code == SW_LID) {
			const char *cmd = ev.value ? cfg.on_lid_close : cfg.on_lid_open;
			if (cmd)
				run_command(cmd);
		}
	} while (rc == LIBEVDEV_READ_STATUS_SUCCESS || rc == LIBEVDEV_READ_STATUS_SYNC);

	if (rc == -ENODEV)
		device_close(d);
}

/* ------------------------------------------------------------------------ */
/* Main loop                                                                 */
/* ------------------------------------------------------------------------ */

/* ------------------------------------------------------------------------ */
/* Control FIFO                                                              */
/* ------------------------------------------------------------------------ */

static void ctl_open(void)
{
	const char *dir = getenv("XDG_RUNTIME_DIR");
	char path[PATH_MAX];
	struct stat st;

	if (!dir)
		return;
	snprintf(path, sizeof(path), "%s/rgos-padd.ctl", dir);
	if (lstat(path, &st) == 0 && !S_ISFIFO(st.st_mode))
		unlink(path);
	if (mkfifo(path, 0600) < 0 && errno != EEXIST) {
		logmsg("mkfifo %s: %s", path, strerror(errno));
		return;
	}
	/* O_RDWR keeps a writer around, so we never see EOF between clients */
	ctl_fd = open(path, O_RDWR | O_NONBLOCK | O_CLOEXEC);
	if (ctl_fd < 0)
		logmsg("open %s: %s", path, strerror(errno));
}

static void ctl_command(char *line)
{
	char *cmd = strtok(line, " \t");
	char *arg = strtok(NULL, " \t");
	int x, y, m;

	if (!cmd)
		return;
	if (!strcmp(cmd, "mode") && arg && (m = parse_mode(arg)) >= -2) {
		if (m == -1)
			set_mode(mode == MODE_MOUSE ? MODE_NAV : MODE_MOUSE);
		else if (m == -2)
			set_mode(mode == MODE_OSK ? osk_return : MODE_OSK);
		else
			set_mode(m);
	} else if (!strcmp(cmd, "warp") && arg && sscanf(arg, "%d", &x) == 1 &&
		   (arg = strtok(NULL, " \t")) && sscanf(arg, "%d", &y) == 1) {
		warp(x, y);
	} else {
		logmsg("control: unknown command '%s'", cmd);
	}
}

static void ctl_read(void)
{
	ssize_t n;
	char *nl;

	while ((n = read(ctl_fd, ctl_buf + ctl_len, sizeof(ctl_buf) - 1 - ctl_len)) > 0) {
		ctl_len += n;
		ctl_buf[ctl_len] = 0;
		while ((nl = strchr(ctl_buf, '\n'))) {
			*nl = 0;
			ctl_command(ctl_buf);
			ctl_len -= nl + 1 - ctl_buf;
			memmove(ctl_buf, nl + 1, ctl_len + 1);
		}
		if (ctl_len == sizeof(ctl_buf) - 1)  /* overlong line: drop it */
			ctl_len = 0;
	}
}

static void on_signal(int sig)
{
	if (sig == SIGHUP) sig_reload = 1;
	else if (sig == SIGUSR1) sig_toggle_mouse = 1;
	else if (sig == SIGUSR2) sig_toggle_pass = 1;
}

static void setup_signals(void)
{
	struct sigaction sa = { 0 };

	sa.sa_handler = on_signal;
	sigaction(SIGHUP, &sa, NULL);
	sigaction(SIGUSR1, &sa, NULL);
	sigaction(SIGUSR2, &sa, NULL);

	/* Reap exec'd children automatically */
	sa.sa_handler = SIG_IGN;
	sa.sa_flags = SA_NOCLDWAIT;
	sigaction(SIGCHLD, &sa, NULL);
}

int main(int argc, char **argv)
{
	struct pollfd pfds[MAX_DEVICES + 2];
	int ifd;
	long rescan_at = 0;

	if (argc > 1) {
		fprintf(stderr, "usage: %s\n(configure in ~/.config/rgos/padd.conf or /etc/rgos/padd.conf)\n", argv[0]);
		return 2;
	}

	for (int i = 0; i < MAX_DEVICES; i++)
		devices[i].fd = -1;

	if (!config_load(&cfg))
		return 1;
	if (!(ui_kbd = make_uinput("rgos-padd keyboard", false, false)) ||
	    !(ui_mouse = make_uinput("rgos-padd pointer", true, false)) ||
	    !(ui_warp = make_uinput("rgos-padd warp", false, true)))
		return 1;
	mode = cfg.start_mode;

	setup_signals();
	write_mode_file();
	ctl_open();

	ifd = inotify_init1(IN_NONBLOCK | IN_CLOEXEC);
	if (ifd >= 0)
		inotify_add_watch(ifd, "/dev/input", IN_CREATE | IN_ATTRIB);
	scan_devices();

	for (;;) {
		int n = 0, map[MAX_DEVICES], timeout = -1;

		if (sig_reload) {
			sig_reload = 0;
			release_all();
			config_load(&cfg);
		}
		if (sig_toggle_mouse) {
			sig_toggle_mouse = 0;
			set_mode(mode == MODE_MOUSE ? MODE_NAV : MODE_MOUSE);
		}
		if (sig_toggle_pass) {
			sig_toggle_pass = 0;
			set_mode(mode == MODE_PASSTHROUGH ? cfg.start_mode : MODE_PASSTHROUGH);
		}

		for (int i = 0; i < MAX_DEVICES; i++) {
			if (!devices[i].dev)
				continue;
			pfds[n].fd = devices[i].fd;
			pfds[n].events = POLLIN;
			map[n++] = i;
		}
		int ndev = n, ifd_idx = -1, ctl_idx = -1;
		if (ifd >= 0) {
			ifd_idx = n;
			pfds[n].fd = ifd;
			pfds[n++].events = POLLIN;
		}
		if (ctl_fd >= 0) {
			ctl_idx = n;
			pfds[n].fd = ctl_fd;
			pfds[n++].events = POLLIN;
		}

		if (ticking())
			timeout = TICK_MS;
		if (rescan_at) {
			long left = rescan_at - now_ms();
			if (left < 0) left = 0;
			if (timeout < 0 || left < timeout) timeout = (int)left;
		}

		int rc = poll(pfds, n, timeout);
		if (rc < 0 && errno != EINTR) {
			logmsg("poll: %s", strerror(errno));
			return 1;
		}

		for (int i = 0; rc > 0 && i < ndev; i++)
			if (pfds[i].revents & (POLLIN | POLLHUP | POLLERR))
				read_device(&devices[map[i]]);

		if (rc > 0 && ctl_idx >= 0 && (pfds[ctl_idx].revents & POLLIN))
			ctl_read();

		if (rc > 0 && ifd_idx >= 0 && (pfds[ifd_idx].revents & POLLIN)) {
			char buf[4096];
			while (read(ifd, buf, sizeof(buf)) > 0)
				;
			/* udev sets permissions shortly after the node appears */
			rescan_at = now_ms() + 300;
		}
		if (rescan_at && now_ms() >= rescan_at) {
			rescan_at = 0;
			scan_devices();
		}

		tick();
	}
}
