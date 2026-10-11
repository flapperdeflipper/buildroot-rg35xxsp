# Testing and debugging

## Flash and provision

```bash
bin/flash.sh                                   # list SD cards
bin/flash.sh --key ~/.ssh/id_ed25519.pub --wifi "<ssid>" --country NL disk4
```

The image carries no keys or credentials; the provisioning files on the
boot partition are imported (and removed) at first boot. SSH is
key-only. Put the card in **TF1**. First boot takes longer: it grows the
data partition to fill the card and seeds `/home`.

A good first check from the Mac: `ssh user@rgos.local`, then
`findmnt -t overlay,erofs,ext4` — `/` should be overlay, `/mnt/root-ro`
erofs, `/data` ext4.

## Verifying a build on the handheld

Work through the areas in whatever order suits you; the details below
are the things that have broken before, so they are worth a look after
big changes.

**Desktop and pointer.** D-pad tap = small precise step, hold = glide.
A = click, B = right-click/Esc, L1/R1 = scroll. Start = main menu.

**On-screen keyboard** (SELECT). The pointer starts on "g" and the first
press types it; stepping lands on key centres within and between rows,
including the symbols layer (the ⌨ key, bottom left). One press = one
character. B closes it. Opening a terminal should bring the keyboard up
by itself.

**Power.** Short power-key press suspends (deep sleep: screen dark, green
LED off, no audio pop with headphones on), any key wakes; check
`journalctl -b | grep "PM: suspend entry"` says `(deep)` over SSH. Lid
close/open suspend/wake. Idle: dim after 1 min, screen off after 3,
suspend after 10 on battery; any button wakes. Menu + d-pad up/down =
brightness; volume keys pop up the volume. Power menu (panel icon or
Menu+Start): Suspend, Screen off, Game mode, Restart desktop, Reboot,
Power off.

**Radios and battery.** Wi-Fi on/off from the menu with a popup and
automatic reconnect; survives a reboot. `iw dev wlan0 get power_save`
should say `off`, also right after resume. Battery percentage, watts and
time left in the panel ("+" while charging); red LED on while charging;
one "Battery low" notification at 10 % per discharge; clean shutdown at
3 %.

**Apps.** YouTube (search -> list -> full screen playback, smooth at
480p), Rockbox (browse `~/Music`, the controls above), NetSurf opens a
real site, mpv plays a local file, Geany shows syntax colours, terminal
tools work (`rg`, `fzf`, `tldr`...).

**SD card (TF2).** exFAT card with files mounts with a notification and
shows in Files and `~/SD`; Eject -> remove -> re-insert works; removing
without ejecting gives the warning and remounts; Format (asks twice)
produces a Mac-readable exFAT card with standard folders.

**Keyboard, mouse, sound.** USB keyboard via an OTG adapter types and
suppresses the on-screen keyboard; Bluetooth peripherals pair; headphones
switch the output when plugged in.

**Measurements over SSH** (a few minutes):

```bash
rgos-power status                       # battery, watts, profile; GPU line = Panfrost
journalctl -b | grep -iE 'mesa|gl'      # no llvmpipe fallback
systemd-analyze; systemd-analyze critical-chain   # boot time
iw dev wlan0 get power_save             # off
```

`rgos-power log 10` records time-stamped power samples — running it for
a while on battery-idle gives the idle-drain numbers.

## QEMU (no hardware needed)

```bash
bin/run-qemu --key ~/.ssh/id_ed25519.pub    # boot the test image in a window
bin/qemu-pad                                # simulated handheld buttons
bin/test-qemu                               # automated smoke test (~190 checks)
```

`bin/test-qemu` boots the image headless, drives it through the pad
simulation, screenshots into `tmp/qemu-N/`, and cleans up after itself.
Each run claims its own instance directory and SSH port; `--keep` leaves
the VM running for manual poking, `bin/run-qemu --sdcard` attaches a
second SD card image.

Two QEMU quirks to know: the display stays blank after an s2idle suspend
(the suspend checks therefore run last), and very rarely the VM panics
within the first tenth of a second during initramfs load — a QEMU/HVF
artifact; run it again before investigating.

## Reading logs from the device

- After a boot, with the card in the Mac: `/Volumes/RGOS-BOOT/rgos-boot.log`.
- The journal is persistent. Over SSH: `journalctl -b`. Without network,
  with the card in the Mac:
  `sudo /opt/homebrew/opt/e2fsprogs/sbin/debugfs -R "rdump /var/log/journal $HOME/rgos-journal" /dev/rdisk4s2`,
  then `journalctl -D ~/rgos-journal -b -1` (from the build VM).
- SSH once stopped answering after about an hour ("kex_exchange_identification:
  Connection reset by peer"); if that recurs, the journal around that
  time is where the answer lives (sshd messages, PerSourcePenalties).
