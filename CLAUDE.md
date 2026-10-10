# RGOS: notes for Claude

Buildroot + systemd OS for the Anbernic RG35XX SP (Allwinner H700). Desktop:
labwc + sfwbar, foot, Mousepad, PCManFM; rgos-padd maps the buttons.
See README.md (usage) and docs/ (roadmap, hardware, boot flow).
**Current status and next steps: docs/HANDOVER.md** (keep it updated).
Planned work: docs/roadmap.md (power/perf candidates + verdicts: its ROCKNIX-survey section); the storage redesign (read-only
root, data partition, clone/backup apps): docs/storage-plan.md.
Design preference (user): systemd mechanisms over custom scripts; mounts and
configuration over symlinks; stay mergeable with ~/.projects/offline-lab.
**Several agents may work in this tree at once**: read and append to
`tmp/agents/channel.md` (protocol at its top) before builds, QEMU runs
(one VM at a time) and edits in shared files.

## Builds

- Builds run in the lima VM `rgbox` via `bin/buildbox.sh`, never on the Mac
  (`bin/build-image.sh` runs inside the VM). How to set up and use it:
  docs/buildbox.md.
- `bin/buildbox.sh check <board>` after any defconfig change (catches dropped
  and legacy symbols). Kernel fragments are checked after configure.
- Incremental: `bin/buildbox.sh make <board> <pkg>-dirclean`, then
  `bin/buildbox.sh build <board>`. Pruned (large, finished) packages can't
  `-rebuild`; use `-dirclean`.
- Buildroot is pinned (bin/lib/versions.sh) and patched from
  buildroot-patches/ on every run; ROCKNIX is pinned in external.mk.

## Testing

- QEMU first: `bin/buildbox.sh build qemu-arm64 && bin/test-qemu`. Read the
  screenshots in tmp/qemu-N/test-*.png (each run gets its own instance N;
  the path is printed). New services, scripts or bindings get a
  check in bin/test-qemu.
- Device: `/boot/rgos-boot.log` (FAT) after each boot; the full journal is
  persistent (copy /var/log/journal with debugfs, read with journalctl -D).

## Rules

- No secrets or keys in images or the repo. SSH keys and Wi-Fi are
  provisioned per card on RGOS-BOOT (bin/provision.sh); SSH is key-only.
- No third-party source committed: fetch at build time, pinned + hashed.
- macOS blocks raw disk access from Claude's process: give the user the exact,
  tested flash/dd command instead.
- Fix root causes; no deleting files after the fact to shrink the image.

## Gotchas

- Local-source packages (rgos-padd/oskd/padsim/desktop/power/youtube/sdcard) are auto-dircleaned by
  build-image.sh when their sources change (hash stamp per output dir); a
  manual `make <board> <pkg>-dirclean` is only needed after touching a build
  dir directly.
- Per-package directories: when a package's dependencies change, dependents
  keep stale copies; clean-build that output dir. Remove other packages'
  files in post-build.sh, never from a package.
- Never run check/make on an output dir while a full build runs there.
- SPI panel modules aren't autoloaded (spi:<compatible> mismatch); see
  boards/h700/rootfs_overlay/etc/modules-load.d/rgos-panel.conf.
- The test device has the v2 panel (stock fw: fog_fj035fhd05_v1), the
  default boot entry.
