// SPDX-License-Identifier: AGPL-3.0-only
/*
 * rgos-padsim — simulated RG35XX SP controls for the QEMU test image.
 *
 * Reads "<CODE> <value>" lines (e.g. "BTN_START 1", "SW_LID 0") from a
 * character device — by default the virtio-serial port that bin/run-qemu
 * creates — and replays them on uinput devices that look like the
 * handheld's:
 *
 *   "rgos-padsim gamepad"  BTN_* face/shoulder/d-pad/menu buttons (what
 *                          rgos-padd grabs, like gpio-keys-gamepad)
 *   "rgos-padsim keys"     KEY_VOLUMEUP/DOWN, KEY_POWER (seen by sway)
 *   "rgos-padsim lid"      SW_LID
 *
 * Host side: bin/qemu-pad.
 */

#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <libevdev/libevdev.h>
#include <libevdev/libevdev-uinput.h>

static const int pad_buttons[] = {
	BTN_SOUTH, BTN_EAST, BTN_NORTH, BTN_WEST,
	BTN_TL, BTN_TR, BTN_TL2, BTN_TR2,
	BTN_SELECT, BTN_START, BTN_MODE,
	BTN_DPAD_UP, BTN_DPAD_DOWN, BTN_DPAD_LEFT, BTN_DPAD_RIGHT,
};
static const int keys[] = { KEY_VOLUMEUP, KEY_VOLUMEDOWN, KEY_POWER };

static struct libevdev_uinput *make(const char *name, int type, const int *codes, size_t n)
{
	struct libevdev *dev = libevdev_new();
	struct libevdev_uinput *ui = NULL;
	int err;

	libevdev_set_name(dev, name);
	libevdev_set_id_bustype(dev, BUS_HOST);
	libevdev_set_id_vendor(dev, 0x0001);
	libevdev_set_id_product(dev, 0x0001);
	libevdev_enable_event_type(dev, type);
	for (size_t i = 0; i < n; i++)
		libevdev_enable_event_code(dev, type, codes[i], NULL);

	err = libevdev_uinput_create_from_device(dev, LIBEVDEV_UINPUT_OPEN_MANAGED, &ui);
	libevdev_free(dev);
	if (err < 0) {
		fprintf(stderr, "rgos-padsim: cannot create %s: %s\n", name, strerror(-err));
		exit(1);
	}
	return ui;
}

static int in_list(int code, const int *list, size_t n)
{
	for (size_t i = 0; i < n; i++)
		if (list[i] == code)
			return 1;
	return 0;
}

int main(int argc, char **argv)
{
	const char *path = argc > 1 ? argv[1] : "/dev/virtio-ports/rgos.pad";
	static const int lid[] = { SW_LID };
	struct libevdev_uinput *pad, *kbd, *sw;
	char line[128];
	FILE *in;

	pad = make("rgos-padsim gamepad", EV_KEY, pad_buttons, sizeof(pad_buttons) / sizeof(*pad_buttons));
	kbd = make("rgos-padsim keys", EV_KEY, keys, sizeof(keys) / sizeof(*keys));
	sw = make("rgos-padsim lid", EV_SW, lid, 1);

	if (!(in = fopen(path, "r"))) {
		fprintf(stderr, "rgos-padsim: %s: %s\n", path, strerror(errno));
		return 1;
	}
	fprintf(stderr, "rgos-padsim: reading %s\n", path);

	for (;;) {
		char name[64];
		int value, type, code;
		struct libevdev_uinput *ui;

		if (!fgets(line, sizeof(line), in)) {
			/* Host side disconnected: wait for the next client */
			clearerr(in);
			usleep(50000);
			continue;
		}
		if (sscanf(line, "%63s %d", name, &value) != 2)
			continue;

		type = strncmp(name, "SW_", 3) ? EV_KEY : EV_SW;
		code = libevdev_event_code_from_name(type, name);
		if (code < 0) {
			fprintf(stderr, "rgos-padsim: unknown code %s\n", name);
			continue;
		}
		if (type == EV_SW)
			ui = sw;
		else if (in_list(code, pad_buttons, sizeof(pad_buttons) / sizeof(*pad_buttons)))
			ui = pad;
		else if (in_list(code, keys, sizeof(keys) / sizeof(*keys)))
			ui = kbd;
		else {
			fprintf(stderr, "rgos-padsim: %s is not a handheld control\n", name);
			continue;
		}
		libevdev_uinput_write_event(ui, type, code, value);
		libevdev_uinput_write_event(ui, EV_SYN, SYN_REPORT, 0);
	}
}
