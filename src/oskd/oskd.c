// SPDX-License-Identifier: AGPL-3.0-only
/*
 * rgos-oskd — phone-style on-screen keyboard trigger for RGOS.
 *
 * Watches the compositor's toplevels (wlr-foreign-toplevel-management,
 * implemented by labwc) and opens wvkbd through rgos-padd when a
 * text-oriented app is *activated* and no hardware keyboard is attached —
 * the way a phone opens its keyboard when a text field gets the focus.
 * Attaching a USB/Bluetooth keyboard hides it again; detaching re-opens
 * it for the active app.
 *
 * Config: ~/.config/rgos/oskd.conf, falling back to /etc/rgos/oskd.conf
 *   set apps <app_id ...>    substrings, case-insensitive; any match shows
 *                            the keyboard (default: foot mousepad pcmanfm)
 *   set match_title 0|1      also match window titles (default 0)
 *   set on_show <command>    default: rgos-padctl osk on
 *   set on_hide <command>    default: rgos-padctl osk off
 *   set keyboard_watch 0|1   1: never show while a hardware keyboard is
 *                            attached (default 1)
 *
 * The pad commands are idempotent, so this daemon can fire them on every
 * activation change without toggling anything unexpectedly. Manual toggles
 * (SELECT on the pad) keep working; the next window switch is evaluated
 * afresh.
 *
 * Started from the labwc autostart; stderr goes to the journal.
 */

#define _GNU_SOURCE
#include <ctype.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <poll.h>
#include <signal.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/inotify.h>
#include <sys/ioctl.h>
#include <time.h>
#include <unistd.h>

#include <linux/input.h>
#include <linux/input-event-codes.h>

#include "wayland-client.h"
#include "wlr-foreign-toplevel-management-unstable-v1.h"

#define MAX_APPS     16
#define MAX_TOPLEVELS 32
#define RESCAN_MS    300

struct toplevel {
	struct zwlr_foreign_toplevel_handle_v1 *handle;
	char app_id[128];
	char title[256];
	bool active;
};

static struct {
	char apps[MAX_APPS][48];
	int napps;
	bool match_title;
	bool keyboard_watch;
	char on_show[128];
	char on_hide[128];
} cfg = {
	.apps = { "foot", "mousepad", "pcmanfm" },
	.napps = 3,
	.match_title = false,
	.keyboard_watch = true,
	.on_show = "rgos-padctl osk on",
	.on_hide = "rgos-padctl osk off",
};

static struct toplevel toplevels[MAX_TOPLEVELS];
static struct wl_display *display;
static int have_manager;
static int nkeyboards = -1;    /* -1: not scanned yet */
static long rescan_at;

static void logmsg(const char *fmt, ...)
{
	va_list ap;
	va_start(ap, fmt);
	fprintf(stderr, "rgos-oskd: ");
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

static void lowercase(char *s)
{
	for (; *s; s++)
		*s = tolower((unsigned char)*s);
}

/* Case-insensitive substring search (ASCII), so "Mousepad" matches
 * "mousepad" without depending on the libc having strcasestr(). */
static const char *ascii_casestrstr(const char *hay, const char *needle)
{
	size_t n = strlen(needle);
	if (!n)
		return hay;
	for (; *hay; hay++) {
		size_t i;
		for (i = 0; i < n; i++) {
			int a = tolower((unsigned char)hay[i]);
			int b = (unsigned char)needle[i];
			if (!hay[i] || a != b)
				break;
		}
		if (i == n)
			return hay;
	}
	return NULL;
}

/* ------------------------------------------------------------------------ */
/* Config                                                                    */
/* ------------------------------------------------------------------------ */

static void config_load(void)
{
	const char *home = getenv("HOME");
	char line[512], path[512];
	const char *file = NULL;
	FILE *f;
	int lineno = 0;

	if (home) {
		snprintf(path, sizeof(path), "%s/.config/rgos/oskd.conf", home);
		if ((f = fopen(path, "r")))
			file = path;
	}
	if (!f) {
		snprintf(path, sizeof(path), "/etc/rgos/oskd.conf");
		if ((f = fopen(path, "r")))
			file = path;
	}
	if (!f) {
		logmsg("no config file, using defaults");
		return;
	}

	while (fgets(line, sizeof(line), f)) {
		char *p = line, *opt, *rest;

		lineno++;
		p[strcspn(p, "\r\n")] = 0;
		p += strspn(p, " \t");
		if (!*p || *p == '#' || strncmp(p, "set ", 4))
			continue;
		p += 4;
		p += strspn(p, " \t");
		opt = strsep(&p, " \t");
		while (p && (*p == ' ' || *p == '\t'))
			p++;
		rest = p ? p : "";
		if (!opt || !*opt)
			continue;

		if (!strcmp(opt, "apps")) {
			cfg.napps = 0;
			char *tok;
			for (tok = strtok(rest, " \t"); tok && cfg.napps < MAX_APPS;
			     tok = strtok(NULL, " \t")) {
				snprintf(cfg.apps[cfg.napps], sizeof(cfg.apps[0]), "%s", tok);
				lowercase(cfg.apps[cfg.napps++]);
			}
		} else if (!strcmp(opt, "match_title")) {
			cfg.match_title = atoi(rest);
		} else if (!strcmp(opt, "keyboard_watch")) {
			cfg.keyboard_watch = atoi(rest);
		} else if (!strcmp(opt, "on_show") || !strcmp(opt, "on_hide")) {
			snprintf(opt[3] == 'h' ? cfg.on_hide : cfg.on_show,
				 sizeof(cfg.on_show), "%s", rest);
		} else {
			logmsg("%s:%d: unknown option '%s'", file, lineno, opt);
		}
	}
	fclose(f);
	logmsg("config: %d apps, keyboard_watch=%d", cfg.napps, cfg.keyboard_watch);
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

static struct toplevel *active_toplevel(void)
{
	for (int i = 0; i < MAX_TOPLEVELS; i++)
		if (toplevels[i].handle && toplevels[i].active)
			return &toplevels[i];
	return NULL;
}

static bool wants_osk(const struct toplevel *t)
{
	if (!t)
		return false;
	for (int i = 0; i < cfg.napps; i++) {
		if (ascii_casestrstr(t->app_id, cfg.apps[i]) ||
		    (cfg.match_title && ascii_casestrstr(t->title, cfg.apps[i])))
			return true;
	}
	return false;
}

/* Called on every activation change and on keyboard (at|de)tach. Idempotent
 * on the padd side, so firing more often than needed is harmless. */
static void evaluate(const char *why)
{
	const struct toplevel *t = active_toplevel();
	bool want = wants_osk(t);

	if (cfg.keyboard_watch && nkeyboards > 0)
		want = false;

	run_command(want ? cfg.on_show : cfg.on_hide);
	if (t && t->app_id[0])
		logmsg("%s: %s (%s)", why, want ? "show" : "hide", t->app_id);
	else
		logmsg("%s: %s", why, want ? "show" : "hide");
}

/* ------------------------------------------------------------------------ */
/* Hardware keyboard detection (/dev/input)                                 */
/* ------------------------------------------------------------------------ */

#define BIT(bits, bit) ((bits)[(bit) / 8] & (1 << ((bit) % 8)))

/* A real keyboard reports KEY_Q. The built-in pad reports BTN_* gamepad
 * codes, the volume keys only KEY_VOLUME*, the power key only KEY_POWER,
 * and rgos-padd's own virtual devices are filtered by vendor id. */
static bool device_is_keyboard(const char *path, char *name, size_t namesz)
{
	struct input_id id;
	unsigned char bits[KEY_MAX / 8 + 1];
	int fd = open(path, O_RDONLY | O_NONBLOCK | O_CLOEXEC);

	if (fd < 0)
		return false;
	if (ioctl(fd, EVIOCGID, &id) == 0 &&
	    id.bustype == BUS_VIRTUAL && id.vendor == 0x5247) {  /* ours */
		close(fd);
		return false;
	}
	if (name && namesz) {
		if (ioctl(fd, EVIOCGNAME(namesz), name) < 0)
			name[0] = 0;
	}
	bool kbd = ioctl(fd, EVIOCGBIT(EV_KEY, sizeof(bits)), bits) >= 0 &&
	           BIT(bits, KEY_Q) && BIT(bits, KEY_ENTER);
	close(fd);
	return kbd;
}

static int scan_keyboards(void)
{
	DIR *dir = opendir("/dev/input");
	struct dirent *de;
	int n = 0;

	if (!dir)
		return 0;
	while ((de = readdir(dir))) {
		char path[PATH_MAX], name[128];

		if (strncmp(de->d_name, "event", 5))
			continue;
		snprintf(path, sizeof(path), "/dev/input/%s", de->d_name);
		if (device_is_keyboard(path, name, sizeof(name))) {
			n++;
			if (n == 1)
				logmsg("hardware keyboard: %s (%s)", path, name);
		}
	}
	closedir(dir);
	return n;
}

static void keyboards_check(void)
{
	int n = scan_keyboards();

	if (n == nkeyboards)
		return;
	nkeyboards = n;
	if (cfg.keyboard_watch)
		evaluate(n > 0 ? "keyboard attached" : "keyboard detached");
}

/* ------------------------------------------------------------------------ */
/* Wayland: foreign toplevels                                                */
/* ------------------------------------------------------------------------ */

static void handle_title(void *data, struct zwlr_foreign_toplevel_handle_v1 *h,
			 const char *title)
{
	struct toplevel *t = data;
	snprintf(t->title, sizeof(t->title), "%s", title);
}

static void handle_app_id(void *data, struct zwlr_foreign_toplevel_handle_v1 *h,
			  const char *app_id)
{
	struct toplevel *t = data;
	snprintf(t->app_id, sizeof(t->app_id), "%s", app_id);
}

static void handle_state(void *data, struct zwlr_foreign_toplevel_handle_v1 *h,
			 struct wl_array *state)
{
	struct toplevel *t = data;
	uint32_t *s;

	t->active = false;
	wl_array_for_each(s, state)
		if (*s == ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_ACTIVATED)
			t->active = true;
}

/* libwayland aborts on NULL listener entries (wl_closure_invoke), so the
 * events we ignore still need a stub. */
static void handle_output(void *data, struct zwlr_foreign_toplevel_handle_v1 *h,
			  struct wl_output *output)
{
}

static void handle_parent(void *data, struct zwlr_foreign_toplevel_handle_v1 *h,
			  struct zwlr_foreign_toplevel_handle_v1 *parent)
{
}

static void handle_closed(void *data, struct zwlr_foreign_toplevel_handle_v1 *h);

static void handle_done(void *data, struct zwlr_foreign_toplevel_handle_v1 *h)
{
	struct toplevel *t = data;

	if (t->active)
		evaluate("window activated");
	/* Deactivations are covered by whichever toplevel activates instead;
	 * if none does (desktop clicked), close the keyboard anyway. */
}

static const struct zwlr_foreign_toplevel_handle_v1_listener handle_listener = {
	.title = handle_title,
	.app_id = handle_app_id,
	.output_enter = handle_output,
	.output_leave = handle_output,
	.state = handle_state,
	.done = handle_done,
	.closed = handle_closed,
	.parent = handle_parent,
};

static void handle_closed(void *data, struct zwlr_foreign_toplevel_handle_v1 *h)
{
	struct toplevel *t = data;

	zwlr_foreign_toplevel_handle_v1_destroy(h);
	memset(t, 0, sizeof(*t));
	if (!active_toplevel())
		run_command(cfg.on_hide);
}

static void manager_toplevel(void *data, struct zwlr_foreign_toplevel_manager_v1 *m,
			     struct zwlr_foreign_toplevel_handle_v1 *h)
{
	struct toplevel *t = toplevels;

	for (int i = 0; i < MAX_TOPLEVELS; i++, t++)
		if (!t->handle)
			break;
	if (t == toplevels + MAX_TOPLEVELS) {
		logmsg("too many toplevels, ignoring one");
		zwlr_foreign_toplevel_handle_v1_destroy(h);
		return;
	}
	memset(t, 0, sizeof(*t));
	t->handle = h;
	zwlr_foreign_toplevel_handle_v1_add_listener(h, &handle_listener, t);
}

static const struct zwlr_foreign_toplevel_manager_v1_listener manager_listener = {
	.toplevel = manager_toplevel,
};

static void registry_global(void *data, struct wl_registry *r, uint32_t name,
			    const char *iface, uint32_t version)
{
	if (strcmp(iface, zwlr_foreign_toplevel_manager_v1_interface.name))
		return;
	have_manager = 1;
	if (version > 3)
		version = 3;
	void *m = wl_registry_bind(r, name, &zwlr_foreign_toplevel_manager_v1_interface, version);
	if (m)
		zwlr_foreign_toplevel_manager_v1_add_listener(m, &manager_listener, NULL);
}

static const struct wl_registry_listener registry_listener = {
	.global = registry_global,
};

/* ------------------------------------------------------------------------ */
/* Main loop                                                                 */
/* ------------------------------------------------------------------------ */

int main(void)
{
	struct wl_registry *registry;
	int ifd;
	char buf[4096];

	signal(SIGCHLD, SIG_IGN);  /* reap exec'd children */
	config_load();

	display = wl_display_connect(NULL);
	if (!display) {
		logmsg("cannot connect to a Wayland compositor");
		return 1;
	}
	registry = wl_display_get_registry(display);
	wl_registry_add_listener(registry, &registry_listener, NULL);
	wl_display_roundtrip(display);
	if (!have_manager) {
		logmsg("compositor has no wlr-foreign-toplevel-management; exiting");
		return 1;
	}

	ifd = inotify_init1(IN_NONBLOCK | IN_CLOEXEC);
	if (ifd >= 0)
		inotify_add_watch(ifd, "/dev/input", IN_CREATE | IN_ATTRIB | IN_DELETE);
	keyboards_check();

	for (;;) {
		struct pollfd pfds[2];
		int timeout = -1, n = 0;

		while (wl_display_prepare_read(display) != 0)
			wl_display_dispatch_pending(display);
		if (wl_display_flush(display) < 0 && errno != EAGAIN) {
			logmsg("compositor gone: %s", strerror(errno));
			return 1;
		}

		pfds[n].fd = wl_display_get_fd(display);
		pfds[n++].events = POLLIN;
		if (ifd >= 0) {
			pfds[n].fd = ifd;
			pfds[n++].events = POLLIN;
		}
		if (rescan_at) {
			long left = rescan_at - now_ms();
			if (left < 0)
				left = 0;
			timeout = (int)left;
		}

		if (poll(pfds, n, timeout) < 0 && errno != EINTR) {
			logmsg("poll: %s", strerror(errno));
			return 1;
		}

		if (pfds[0].revents & POLLIN) {
			wl_display_read_events(display);
			wl_display_dispatch_pending(display);
		} else {
			wl_display_cancel_read(display);
		}

		if (n > 1 && (pfds[1].revents & POLLIN)) {
			while (read(ifd, buf, sizeof(buf)) > 0)
				;
			/* udev sets permissions shortly after the node appears */
			if (!rescan_at)
				rescan_at = now_ms() + RESCAN_MS;
		}
		if (rescan_at && now_ms() >= rescan_at) {
			rescan_at = 0;
			keyboards_check();
		}
	}
}
