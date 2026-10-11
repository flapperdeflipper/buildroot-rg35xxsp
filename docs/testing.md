# Testing and debugging

## Flash a card

```bash
bin/flash.sh                                    # list SD cards
bin/flash.sh --key ~/.ssh/id_ed25519.pub --wifi "<ssid>" --country NL disk4
```

Images contain no keys or passwords. The boot partition carries your key
and Wi-Fi settings, the device imports them on first boot and deletes
them. SSH is key-only.

Put the card in slot TF1. The first boot takes longer: the data partition
grows to fill the card and `/home` gets seeded.

Check that SSH answers:

```bash
ssh user@rgos.local
findmnt -t overlay,erofs,ext4
```

`/` should be overlay, `/mnt/root-ro` erofs, `/data` ext4.

## What to check on the device

### Pointer and keyboard

A short d-pad tap moves the pointer one small step. Holding it glides
and speeds up. A clicks, B right-clicks, L1/R1 scroll.

SELECT opens the on-screen keyboard. The pointer starts on "g" and the
first press types it. Stepping stays on key centres within rows, between
rows, and in the symbols layer (the key bottom left). One press types
one character. B closes it. Opening a terminal brings the keyboard up on
its own.

### Power

A short press of the power key suspends. The screen goes dark and the
green LED turns off. Any key wakes it. Over SSH, check that it used deep
sleep:

```bash
journalctl -b | grep "PM: suspend entry"
```

Closing the lid suspends, opening it wakes. Left alone, the screen dims
after a minute, turns off after three, and on battery the device
suspends after ten. Menu plus d-pad up/down changes brightness. The
volume keys show a volume popup.

The power menu (panel icon, or Menu plus Start) offers Suspend, Screen
off, Game mode, Restart desktop, Reboot and Power off.

### Radios and battery

Toggle Wi-Fi from the main menu. A popup confirms each change and Wi-Fi
reconnects. The state survives a reboot. Check that power saving stays
off, including right after a resume:

```bash
iw dev wlan0 get power_save
```

The panel shows battery percentage, watts and time left, with a plus
sign while charging. The red LED is on while charging. A "Battery low"
notification appears once per discharge at 10 percent. At 3 percent the
device shuts down cleanly.

### Apps

Try YouTube (search, pick, play, smooth at 480p), Rockbox (browse
`~/Music`, controls in apps.md), NetSurf on a real site, mpv with a local
file, Geany with a source file, and a few terminal tools.

### Second SD card

Insert an exFAT card with some files: a notification appears, the files
show in Files and in `~/SD`. Eject, remove, reinsert. Removing without
ejecting gives a warning and remounts the card. Format produces a
Mac-readable exFAT card with standard folders.

### Keyboard, mouse, sound

A USB keyboard through an OTG adapter types and keeps the on-screen
keyboard closed. Bluetooth devices pair from the menu. Headphones take
over the output when plugged in.

## Measurements over SSH

```bash
rgos-power status                            # battery, watts, profile
journalctl -b | grep -iE 'mesa|gl'           # should show Panfrost, not llvmpipe
systemd-analyze critical-chain               # boot time
```

For idle-drain numbers, run `rgos-power log 10` for a while on battery
with the screen off, then read the log file it prints.

## QEMU, without hardware

```bash
bin/run-qemu --key ~/.ssh/id_ed25519.pub     # boot the test image in a window
bin/qemu-pad                                 # handheld buttons
bin/test-qemu                                # automated checks, ~190 of them
```

`bin/test-qemu` boots the image headless, drives it through simulated
buttons, takes screenshots into `tmp/qemu-N/` and cleans up. Each run
claims its own instance directory and SSH port. Use `--keep` to leave
the VM running, or `bin/run-qemu --sdcard` to attach a second card.

Two quirks are normal in QEMU: the display stays blank after an s2idle
suspend, and rarely the VM panics during initramfs load. The panic
is a QEMU artifact; run it again.

### Test the device image itself

`bin/test-qemu` runs the QEMU board build, which has its own kernel and
image. `bin/test-qemu-device` instead boots the real RG35XX SP
artifacts: the kernel Image and the complete SD card image exactly as
they ship. It loads no external initramfs, so the kernel-embedded one
runs, like on the device. The test passes when the boot report appears
on the boot partition and no systemd units failed.

```bash
bin/test-qemu-device            # PASS or FAIL, ~4 min
```

Run it before flashing a new device image. It would have caught the
initramfs panic that black-screened the device: the early init script
ran before the SD partitions existed and gave up. The QEMU board suite
missed it because that board wins the timing race by accident.

The disk is attached as virtio-mmio on purpose. The device kernel has
no virtio PCI support, so the default `-drive if=virtio` would look
like a broken disk.

## Reading logs from the device

The journal is persistent. Over SSH, `journalctl -b` is enough. Without
network, put the card in the Mac and read the boot log from
`/Volumes/RGOS-BOOT/rgos-boot.log`. For the full journal, dump it from
the data partition:

```bash
sudo /opt/homebrew/opt/e2fsprogs/sbin/debugfs -R "rdump /var/log/journal $HOME/rgos-journal" /dev/rdisk4s3
journalctl -D ~/rgos-journal -b -1    # from the build VM
```

The journal lives on the overlay partition, which is the third one on
the card.

SSH once stopped answering after about an hour with
"kex_exchange_identification: Connection reset by peer". If that happens
again, the answer is in the journal from that time: look at the sshd
messages around it.
