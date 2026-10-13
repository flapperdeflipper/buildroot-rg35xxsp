# USB gadget mode: promotion notes

Untested draft (wip/tooling). What "up" means when this is promoted:

- Kernel: CONFIG_USB_LIBCOMPOSITE=y is already in the config (the trim
  round kept it deliberately). Still needed in the h700 fragment:
  CONFIG_USB_CONFIGFS_F_NCM=y, CONFIG_USB_CONFIGFS_F_ACM=y,
  CONFIG_USB_GADGET=y (verify each with `buildbox.sh check` first).
- usb-gadget -> /usr/libexec/rgos/, the unit to /usr/lib/systemd/system,
  enable via the rgos-power preset (or its own).
- Network: the NCM function creates usb0; a systemd-networkd drop-in
  (20-usb.network, DHCP server or a fixed link-local pair) makes
  ssh user@<usb-ip> work without Wi-Fi.
- Serial: /dev/ttyGS0 appears on the host as a serial port; a
  serial-getty@ttyGS0 unit gives a console.
- The musb-sunxi driver is the UDC; the survey note about re-binding the
  UDC after a dead gadget session across suspend is handled by the
  rgos-power sleep hook area.
- Toggle: a main-menu entry "USB networking" calling usb-gadget up/down
  fits the radio toggles pattern in rgos-power.
