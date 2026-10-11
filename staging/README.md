# WIP tooling branch

Staging area for new packages and features that are written but not yet
build-tested. Nothing here is wired into the build; the main branch stays
clean until an item survives a real build and the QEMU test suite.

A testing pipeline will merge these one by one later.

## Promoting an item to the tree

1. Take a free build-VM slot (check the channel first).
2. For packages: copy `staging/package/<name>/` to
   `br2-external/package/<name>/`, add the Config.in source line to
   `br2-external/Config.in`, enable in `configs/rgos_qemu_arm64_defconfig`.
   For system files: see the NOTES.md next to them for target paths.
3. `bin/buildbox.sh check qemu-arm64`, build, `bin/test-qemu`, add a
   check for the new item.
4. If it belongs on the device too: enable in `rgos_common_defconfig`,
   build rg35xxsp, note it in the device checklist.
5. Merge this branch (or move the files onto the main tree; the branch
   history is disposable).

## Queue

- [x] syncthing 2.1.6 — **promoted + QEMU-validated 2026-10-11** (stamped,
      go2 hashed, GUI assets generated; disabled by default; lives in the
      main tree now, this copy is stale)
- [x] retroarch 1.22.2 + first cores (gambatte, mGBA @ 517e518 pre-CMake,
      nestopia, snes9x, Genesis-Plus-GX) — **promoted + QEMU-validated
      2026-10-11**; main tree has the build fixes (qb configure, underscore
      options, PKG_CONF_PATH, GL1 off, hash file naming, subdir Makefiles)
- [x] game-mode system pieces — promoted as package rgos-game (launcher
      with systemd-run --wait + pad passthrough, user slices, system.slice
      memory floor, RA defaults config); QEMU-validated
- [ ] USB gadget mode (gadget/): NCM + ACM configfs script and unit —
      see gadget/NOTES.md for the kernel lines still needed
- [ ] candidates, not started: SDR TUI frontend, batteryplus (only if
      the AXP717 percentage drifts), charge-only-boot U-Boot patch port
      (ROCKNIX 0002-sunxi-axp717-charge-only-boot onto our 2026.07 base)
