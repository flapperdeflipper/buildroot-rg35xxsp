# Handover — state as of 2026-10-10 ~16:45

Read CLAUDE.md first (rules, gotchas). This file is the live status.

## Goal

RG35XX SP boots RGOS with a **working screen** (hard requirement) and a
Raspberry-Pi-OS-like desktop (labwc + sfwbar, foot, Mousepad, PCManFM),
pad = mouse pointer by default. Then: first public GitHub commit.

## Where things are

- **Device image built and verified (16:50)**: `artifacts/rg35xxsp/rgos-rg35xxsp.img.gz`
  (608 MB image, 122 MB gz; rootfs 376 MiB, no LLVM; panel_mipi in
  modules-load.d; PPU=y; v2 panel default). **Not yet flashed/booted.**
  It includes, untested on hardware:
  1. panel fix: `boards/h700/rootfs_overlay/etc/modules-load.d/rgos-panel.conf`
     loads `panel_mipi` (SPI modalias mismatch meant it never autoloaded →
     LCD controller deferred forever → no display, no backlight).
  2. `CONFIG_SUN50I_H6_PRCM_PPU=y` (GPU power domain; panfrost timed out).
  3. v2 panel is the default extlinux entry (device has the v2 panel: stock
     firmware DTB says `fog_fj035fhd05_v1`, timings match ROCKNIX sp-v2).
  4. no target LLVM/clang (buildroot-patches/0002) → much smaller image.
  5. provisioning: `/usr/libexec/rgos/bootconfig` + `rgos-bootconfig.service`
     import `/boot/authorized_keys` and `/boot/wifi.txt` (deleted after import).
     User has no password, sudo NOPASSWD, sshd key-only. No keys at build time.
  6. `/boot/rgos-boot.log` written ~30 s after boot (`rgos-bootlog.service`).
- **QEMU image is stale** (built before items 4–6). Rebuild:
  `bin/buildbox.sh ssh 'rm -rf ~/output-qemu-arm64/target'`,
  `bin/buildbox.sh make qemu-arm64 rgos-desktop-dirclean mesa3d-dirclean`,
  `bin/buildbox.sh build qemu-arm64`, then `bin/test-qemu` (now also checks
  provisioning + key-only SSH + bootlog). Not yet run — expect to fix bugs.
- **Repo not committed yet.** User reviewed: safe to push (no secrets/PII).
  User will reset the git author email. LICENSE = AGPL-3.0 (matches offline-lab).

## Next steps (in order)

1. (Done) Image verified. Unverified: service enablement (preset-all runs on
   the rootfs copy, not target/) — confirm on device via rgos-boot.log.
2. Give the user this command (their terminal; macOS blocks raw disk access
   from the agent). Card is usually `disk4` — re-check with `diskutil list`:
   `bin/flash.sh --key ~/.ssh/<key>.pub --wifi "<ssid>" --country NL disk4`
3. After a boot on the device: card back in the Mac, read
   `/Volumes/RGOS-BOOT/rgos-boot.log`. If there's still no screen, check the
   deferred-probe and DRM/panel sections. Full journal: user runs
   `sudo /opt/homebrew/opt/e2fsprogs/sbin/debugfs -R "rdump /var/log/journal $HOME/rgos-journal" /dev/rdisk4s2`,
   then copy to the VM and `journalctl -D … -b -1`.
4. Rebuild + test QEMU (above), fix failures, then the user commits.

## Facts worth not re-deriving

- First hardware boot (old image): kernel + userspace OK (rootfs grew to
  31.8 GB); `6511000.lcd-controller: deferred probe pending`, panfrost -110.
- Stock Anbernic card (16 GB) dumps are in `~/stock-head.img`,
  `~/stock-boot.img`, DTBs in `~/stock-dtb/` (not in the repo; proprietary).
- Card reader runs at USB 2.0 (480 Mb/s → ~34 MB/s); not a script problem.
- Build VM disk was full once; `build-image.sh` now prunes finished build
  trees. ~64 GB free after the clean device build started.
- Buildroot quirks fixed in-tree: libfm/pcmanfm built as gnu17
  (external.mk), ROCKNIX kernel patches applied with fuzz via hook
  (external.mk), wlroots 0.20.1 + mesa patches in buildroot-patches/.

## Open items / roadmap

docs/roadmap.md. Notable: Ghostty (needs GL 4.3; Mali-G31 has 3.1 → only
llvmpipe; GTK4/libadwaita/Zig not in Buildroot) — user hasn't decided.
Kernel modules (~41 MB, arm64 defconfig leftovers) could be trimmed properly.
