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

- [x] syncthing 2.1.6 (package/syncthing; UNTESTED notes in the .mk)
- [x] retroarch 1.22.2 + first cores: gambatte (GB/GBC), mGBA (GBA),
      nestopia (NES), snes9x (SNES), Genesis Plus GX (MD/SMS/GG) — all
      commit/tag pinned + hashed, never built
- [x] game-mode system pieces (system/): games.slice, background.slice,
      system.slice memory floor, rgos-game launcher with the Mali-G31
      copy-image Mesa override — see system/NOTES.md
- [x] USB gadget mode (gadget/): NCM + ACM configfs script and unit —
      see gadget/NOTES.md for the kernel lines still needed
- [x] mepo 1.3.4 + host-zig 0.14.1 (package/mepo, package/host-zig):
      OSM map viewer, Zig+SDL2, online tiles + offline region download,
      rgos-mepo nav launcher — UNTESTED notes in mepo/NOTES.md
- [ ] candidates, not started: SDR TUI frontend, batteryplus (only if
      the AXP717 percentage drifts), charge-only-boot U-Boot patch port
      (ROCKNIX 0002-sunxi-axp717-charge-only-boot onto our 2026.07 base)
