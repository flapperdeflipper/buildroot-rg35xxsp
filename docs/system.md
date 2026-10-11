# How RGOS works

The system in one page: what happens between pressing the power button
and seeing the desktop, where your files live, and how the power and
input plumbing fits together.

## Boot chain

1. The H700 boot ROM loads the SPL from offset 8 KiB of the SD card in
   slot TF1. That fixed offset is why the card uses an **MBR** partition
   table — a GPT entry array would overlap it.
2. The SPL initialises DRAM (LPDDR4 or LPDDR3 timings, per image) and
   loads TF-A BL31 and U-Boot.
3. U-Boot reads `extlinux/extlinux.conf` from the boot partition and
   boots the kernel with its initramfs.
4. The initramfs (`boards/common/initramfs/init`, busybox) mounts the
   read-only root, the overlay and the data partition, puts an overlayfs
   over the whole root, binds `/home` from `/data/home`, then switches
   to systemd.
5. systemd brings up the machine and starts the desktop session (labwc +
   sfwbar panel) via automatic login.

## Storage layout

| # | Label | Filesystem | Content |
|---|---|---|---|
| raw | — | — | SPL + U-Boot at 8 KiB |
| p1 | RGOS-BOOT | FAT | kernel, DTBs, initramfs, extlinux config, provisioning files |
| p2 | rgos-root | erofs (lz4hc), read-only | the whole OS |
| p3 | rgos-overlay | ext4, 2 GiB | overlayfs upper + work dir for the whole root |
| p4 | rgos-data | ext4, grown to fill the card on first boot | `/data`: home directories, user data |

- The running root is an **overlayfs**: the immutable erofs image below,
  and every change to `/etc`, `/var`, installed files and the journal on
  p3 above. Nothing you change at runtime is lost on reboot; a reflash
  of the OS partition leaves it untouched.
- `/home` is a bind mount from `/data/home`, seeded from the image on
  first boot. Data lives on its own partition, so an OS update never
  touches it.
- The raw layers stay reachable for debugging: `/mnt/root-ro` (the
  erofs lower) and `/mnt/overlay` (the ext4 upper).
- The overlay is mounted with `index=off` — image updates replace the
  erofs lower wholesale, and a stale inode index would fail the mount.

**Why this shape:** the OS proper is immutable and reproducible (erofs,
no fsck, dm-verity-ready); everything mutable is confined to p3/p4. The
overlay upper is deliberately *persistent* — the journal, configuration
edits and installed files survive reboots — unlike stateless /etc
designs that reset every boot. `/home` and `/data` are real mounts, not
symlink farms.

## Desktop and input

- **labwc** (wlroots compositor) with an **sfwbar** panel: clock,
  battery, network, SD card, power menu. **foot** terminal, **PCManFM**
  files, **Mousepad** notes; Xwayland for X11 apps.
- **rgos-padd** turns the handheld buttons into a pointer and keyboard
  driver: pointer mode (d-pad moves, A clicks, B right-click/Esc,
  L1/R1 scroll), navigation mode for menus and lists, keys mode for
  typing. `SELECT` toggles the on-screen keyboard (**oskd**), which
  opens automatically when a text field needs input and no hardware
  keyboard is attached. Remapping: `/etc/rgos/padd.conf`.
- **Notifications** (mako): volume and brightness popups, SD card
  events, radio toggles, low-battery warnings. Anything can send one
  with `rgos-notify "Summary" "Body" icon`.

## Power management (rgos-power)

Configured in `/etc/rgos/power.conf` (system defaults) and
`~/.config/rgos/power.conf` (per user); `rgos-power reload` applies
changes.

- **Profiles** — `battery` / `balanced` / `performance` scale the CPU and
  GPU frequency ceilings; the panel power menu switches them, and
  `profile_ac` can switch automatically on charger connect.
- **Idle steps** — dim after `dim_after` (60 s), screen off after
  `off_after` (180 s), suspend after `suspend_after` (600 s, on battery).
  Lid close and a short power-key press suspend (`lid_action`,
  `power_key_action`).
- **Suspend** — `suspend_mode=auto` uses deep sleep (the TF-A SRAM
  suspend stub) when the firmware provides it, s2idle otherwise. Around
  suspend the codec DAC is muted (no pop), the power LED goes off, and
  an optional RTC watchdog (`suspend_poweroff_min`) powers the device
  off cleanly after N minutes asleep.
- **Battery** — one low-battery notification per discharge at
  `warn_percent` (10), a clean shutdown at `poweroff_percent` (3), and
  the red status LED on while charging (`charge_led`).
- **Radios** — Wi-Fi and Bluetooth start blocked and are remembered once
  toggled (`wifi_default`, `bluetooth_default`). Wi-Fi power saving is
  deliberately off on this SDIO chip (latency spikes; `iw dev wlan0 set
  power_save off` is reapplied at interface-up, radio-on and resume).
- **Turbo** — `cpu_turbo=1` unlocks the 1.512 GHz OPP above the stock
  1.416 GHz ceiling; off by default.

`rgos-power status` shows battery, draw, time left, radios and profile;
`rgos-power log <seconds>` records a power log for measurements.

## Tuning decisions (and what was rejected)

Adopted: zram swap with lzo-rle + idle zstd recompression, MGLRU, journald
15-minute sync + `noatime,commit=60` data mounts, a small sysctl pack
(panic-reboot, inotify limits, no NMI watchdog), per-session GPU
frequency caps in the profiles.

Rejected, with reasons:

- **KSM** — dedups single-digit MB on this workload while waking a
  kernel thread every 500 ms; the wakeup class we remove for battery.
- **Fake suspend** (display off + freeze, system awake) — a workaround
  for hardware with broken suspend; real suspend works here.
- **Core parking before suspend** — PSCI already powers secondary cores
  down in real suspend; parking them first only panics some platforms.
- **Aggressive memory-manager sysctls** — most restate kernel defaults or
  never engage at these dirty-writeback intervals; the useful part
  (zram, recompression) is in.
- **Firefox/Chromium as the full browser** — far beyond 1 GB RAM;
  NetSurf covers light browsing and WebKitGTK is the evaluated "real
  web" option (see apps.md).

## Image services, next steps of the layout

The storage layout was built for growth: A/B root partitions with RAUC
updates, a `/data/config` layer for system-wide overrides, and sysext /
confext image stores under `/data/extensions` all fit on top of the
current partition scheme without changing it.
