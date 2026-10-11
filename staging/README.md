# WIP tooling branch

Staging area for new packages that are written but not yet build-tested.
Nothing here is wired into the build; the main branch stays clean until a
package survives a real build and the QEMU test suite.

## Promoting a package to the tree

1. Take a free build-VM slot (check the channel first).
2. Copy `staging/package/<name>/` to `br2-external/package/<name>/`.
3. Add `source "$BR2_EXTERNAL_RGOS_PATH/package/<name>/Config.in"` to
   `br2-external/Config.in` in the right menu block.
4. Enable it in `configs/rgos_qemu_arm64_defconfig`, then
   `bin/buildbox.sh check qemu-arm64`.
5. Build, run `bin/test-qemu`, add a check for the new package.
6. If it belongs on the device too: enable in `rgos_common_defconfig`,
   build rg35xxsp, note it in the device checklist.
7. Merge this branch (or just move the files onto the main tree; the
   branch history is disposable).

## Queue

- [x] syncthing 2.1.6 (see staging/package/syncthing; untested)
- [ ] next candidates, roughly in value order:
      a small TUI for the SDR tools, a battery-percentage daemon
      (batteryplus) if the AXP717 readout drifts, RetroArch (large,
      emulators phase)
