# How the OS works

What happens between the power button and the desktop, where your files
live, and how power management is set up.

## Boot

1. The H700 boot ROM loads the SPL from offset 8 KiB of the SD card in
   slot TF1. The offset is fixed, so the card uses an MBR partition
   table. A GPT entry array would overlap the SPL.
2. The SPL sets up DRAM (LPDDR4 or LPDDR3, depending on the image) and
   loads TF-A and U-Boot.
3. U-Boot reads `extlinux/extlinux.conf` from the boot partition and
   starts the kernel with its initramfs.
4. The initramfs mounts the root, overlay and data partitions, puts an
   overlayfs over the root, and starts systemd.
5. systemd logs you in and starts the desktop: labwc with the sfwbar
   panel.

## Storage

| Partition | Label | Filesystem | Content |
|---|---|---|---|
| raw | | | SPL and U-Boot at 8 KiB |
| p1 | RGOS-BOOT | FAT | kernel, initramfs, DTBs, extlinux config, provisioning files |
| p2 | rgos-root | erofs, read-only | the OS |
| p3 | rgos-overlay | ext4, 2 GiB | overlayfs upper and work directory |
| p4 | rgos-data | ext4, grows to fill the card on first boot | `/data`, home directories |

The running system is an overlayfs. The erofs image below never changes;
every runtime change to `/etc`, `/var`, the journal and installed files
lands on p3. Changes survive reboots, and flashing a new OS image does
not touch them.

`/home` is a bind mount from `/data/home`. On first boot it is seeded
from the image. Because home lives on its own partition, an OS update
never touches your files.

The underlying partitions stay reachable for inspection: `/mnt/root-ro`
is the erofs image, `/mnt/overlay` is the writable layer.

The layout is fully exercised by the automated QEMU tests; hardware
validation is in progress.

Notes on the design:

- MBR instead of GPT, because the boot ROM expects the SPL at 8 KiB.
- The overlay upper is persistent instead of being wiped each boot. The
  journal and configuration edits are worth keeping.
- The overlay is mounted with `index=off`. Image updates replace the
  erofs side wholesale, and a stale inode index would fail the mount.
- `/home` and `/data` are real mounts, not symlinks.

## Desktop and input

The desktop is labwc (a Wayland compositor) with an sfwbar panel showing
the clock, battery, network, SD card and a power menu. It ships with the
foot terminal, PCManFM files, Mousepad notes and Xwayland for X11 apps.

rgos-padd drives it all from the handheld buttons:

- Pointer mode (the default): the d-pad moves the pointer, A clicks,
  B right-clicks, L1/R1 scroll.
- Navigation mode for menus and lists.
- Keys mode for typing.
- SELECT toggles the on-screen keyboard. It opens by itself when a text
  field needs input and no hardware keyboard is attached.

Button mapping lives in `/etc/rgos/padd.conf`.

Notifications appear through mako: volume and brightness popups, SD card
events, radio toggles, low-battery warnings. Any script can send one:

```
rgos-notify "Summary" "Body" icon
```

## Power management

Settings live in `/etc/rgos/power.conf`, with per-user overrides in
`~/.config/rgos/power.conf`. Run `rgos-power reload` after editing.

Profiles: `battery`, `balanced` and `performance` cap the CPU and GPU
frequencies. Switch them from the panel power menu. With `profile_ac`
set, the profile changes automatically when you plug in the charger.

Idle: the screen dims after 60 seconds, turns off after 3 minutes, and
the device suspends after 10 minutes on battery. The timeouts are
`dim_after`, `off_after` and `suspend_after`. Closing the lid or pressing
the power key briefly also suspends (`lid_action`, `power_key_action`).

Suspend uses deep sleep when the firmware provides it, s2idle otherwise
(`suspend_mode`). Around suspend the audio codec is muted, so headphones
do not pop, and the power LED turns off. Setting `suspend_poweroff_min`
powers the device off cleanly after that many minutes asleep.

Battery: one low-battery notification per discharge at 10 percent
(`warn_percent`), a clean shutdown at 3 percent (`poweroff_percent`), and
the red status LED lights up while charging (`charge_led`).

Radios: Wi-Fi and Bluetooth start blocked. Once you toggle them, the
choice is remembered across reboots (`wifi_default`, `bluetooth_default`).
Wi-Fi power saving stays off on purpose. The SDIO chip in this device
has large latency spikes with it on, so the setting is reapplied whenever
the interface comes up.

`rgos-power status` prints battery, power draw, time left, radio states
and the current profile. `rgos-power log 10` records samples once a
second for measurements.

Setting `cpu_turbo=1` unlocks the 1.512 GHz turbo OPP above the stock
1.416 GHz ceiling. It is off by default.

## Tuning decisions

In use: zram swap with lzo-rle and idle zstd recompression, MGLRU,
journald sync every 15 minutes, `noatime,commit=60` data mounts, a small
sysctl pack (panic reboot, inotify limits, NMI watchdog off), and GPU
frequency caps per profile.

Rejected, and why:

- KSM: dedups single-digit megabytes on this workload while waking a
  kernel thread every 500 ms.
- Fake suspend (screen off, system awake): a workaround for devices with
  broken suspend. Ours works.
- Core parking before suspend: PSCI already powers the secondary cores
  down, and parking them first can panic.
- Aggressive memory sysctls: most restate kernel defaults or never engage
  with our writeback intervals.
- Firefox or Chromium as the full browser: both are far beyond 1 GB of
  RAM. NetSurf covers light browsing, WebKitGTK is the evaluated option
  for the rest (see apps.md).
