# Roadmap

## Phase 1: bootable desktop (current)

- [x] Buildroot external tree, build VM, image assembly (MBR, SPL at 8K)
- [x] Linux 7.2 + ROCKNIX H700 patches, kernel fragment
- [x] U-Boot LPDDR4 + LPDDR3 images, extlinux with v1/v2 panel entries
- [x] Desktop session (autologin, logind/PAM): labwc + sfwbar panel + wallpaper,
      foot terminal, Mousepad notes, PCManFM files, Xwayland
- [x] rgos-padd: nav / mouse / osk / passthrough modes, Menu layer, config file
- [x] WiFi picker (iwd), Bluetooth (bluetoothctl), SSH, zram, first-boot grow
- [x] QEMU test board + simulated pad + `bin/test-qemu` smoke test (38 checks)
- [x] **First boot on hardware**: screen, backlight, desktop work (v2 panel, LPDDR4)
- [ ] Verify on hardware: buttons/padd, Wi-Fi, BT, audio, battery readout, USB OTG host
- [x] Tune `osk_step` to the wvkbd key grid (49x45, verified in QEMU)
- [ ] Font sizes / readability on the real 3.5" panel

## Phase 2: daily usability

- [ ] Suspend/resume (lid + power key) — see docs/power.md S1–S3
- [ ] Audio: PipeWire + WirePlumber (BT headsets, per-app volume)
- [ ] Battery: low-battery warning + auto power-off (docs/power.md B1); charge LED
- [ ] Brightness control in the panel (slider) + keys
- [ ] Second SD card (TF2) automount as /media/sd2
- [ ] Notifications (fnott or mako) for volume/brightness/wifi feedback
- [ ] On-screen keyboard rework (oskd) — in progress (OSK agent)
- [ ] Power saving + performance tuning — candidates in docs/power.md, in progress
- [ ] USB gadget mode (NCM ethernet + serial over the USB-C port)
- [ ] Image updates without reflashing (rsync rootfs, or RAUC when merging
      into offline-lab — their pattern: RAUC A/B slots + udev usb-update +
      bin/test-qemu-ota A→B→A cycle; RGOS could deliver updates via TF2)

## Phase 3: apps

- [ ] Ghostty (requested): needs GTK4 + libadwaita + a Zig 0.15 cross build,
      and OpenGL 4.3, which Panfrost on the Mali-G31 doesn't provide (GL 3.1),
      so on the device it can only run with llvmpipe. Try in QEMU first.
- [ ] Browser: WPE WebKit + cog (Buildroot has both; heavy build), or
      netsurf as a light fallback
- [ ] Video player: mpv on Panfrost; hardware decode via cedrus (V4L2
      stateless) needs FFmpeg v4l2-request support
- [ ] Music player, IRC client, web browser, editor, power-user CLI tools
      (choices to be made, see the planning questions)
- [ ] File manager (TUI: nnn / mc)
- [ ] SDR: librtlsdr, rtl_433, SoapySDR, gqrx or a TUI frontend. The kernel
      fragment already keeps the DVB driver off RTL2832U dongles
- [ ] Emulators / RetroArch in game mode (passthrough is ready for it)

## Housekeeping

- [x] No target LLVM for Panfrost (buildroot-patches/0002)
- [x] Hash files for every download
- [x] Auto-dirclean local-source packages (rgos-padd/oskd/padsim/desktop) when
      their sources change — build-image.sh hashes them at sync time
- [ ] Port offline-lab's pytest-testinfra harness (`tests/`): same suite against
      QEMU (--board) and the real device over SSH (--host). Started: conftest +
      test_base; grow it out of bin/test-qemu as checks migrate
- [ ] SBOM per image: `make show-info | generate-cyclonedx` in build-image.sh
      (offline-lab pattern)
- [ ] bin/check-versions.sh: audit pinned versions (Buildroot, ROCKNIX, wvkbd,
      ...) against upstream latest; `--update` rewrites them (offline-lab pattern)
- [ ] Keep the last 2–3 timestamped images in artifacts/ instead of rm -rf
      (rollback + diffing)
- [ ] Try BR2_REPRODUCIBLE=y (may fight the ROCKNIX kernel patches; drop if noisy)
- [ ] Trim the kernel config to the H700 (docs/power.md P1)
- [x] BR2_PER_PACKAGE_DIRECTORIES for parallel top-level builds
- [ ] More H700 boards (RG35XX Plus/H/2024, RG40XX, RG CubeXX): DTB + meta only
