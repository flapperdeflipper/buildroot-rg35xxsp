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
- [ ] **First boot on hardware**: verify panel (v1/v2), backlight, buttons,
      WiFi, BT, audio controls, battery readout, USB OTG host
- [x] Tune `osk_step` to the wvkbd key grid (49x45, verified in QEMU)
- [ ] Font sizes / readability on the real 3.5" panel

## Phase 2: daily usability

- [ ] Suspend/resume (lid + power key). ROCKNIX carries suspend fixes; needs testing
- [ ] Audio: PipeWire + WirePlumber (BT headsets, per-app volume)
- [ ] Battery: low-battery warning + auto power-off; charge LED
- [ ] Second SD card (TF2) automount as /media/sd2
- [ ] Notifications (fnott or mako) for volume/brightness/wifi feedback
- [ ] A d-pad-native on-screen keyboard (highlight grid, no pointer) if the
      wvkbd + pointer-stepping approach turns out clumsy
- [ ] USB gadget mode (NCM ethernet + serial over the USB-C port)
- [ ] Image updates without reflashing (rsync rootfs, or RAUC when merging
      into offline-lab)

## Phase 3: apps

- [ ] Ghostty (requested): needs GTK4 + libadwaita + a Zig 0.15 cross build,
      and OpenGL 4.3, which Panfrost on the Mali-G31 doesn't provide (GL 3.1),
      so on the device it can only run with llvmpipe. Try in QEMU first.
- [ ] Browser: WPE WebKit + cog (Buildroot has both; heavy build), or
      netsurf as a light fallback
- [ ] Video player: mpv on Panfrost; hardware decode via cedrus (V4L2
      stateless) needs FFmpeg v4l2-request support
- [ ] File manager (TUI: nnn / mc)
- [ ] SDR: librtlsdr, rtl_433, SoapySDR, gqrx or a TUI frontend. The kernel
      fragment already keeps the DVB driver off RTL2832U dongles
- [ ] Emulators / RetroArch in game mode (passthrough is ready for it)

## Housekeeping

- [ ] Panfrost pulls in target LLVM (~100 MB) through Buildroot's
      MESA3D_LLVM; patch Buildroot to only need host LLVM for the precompiler
- [ ] Hash files for every download (kernel patches are pinned by commit)
- [ ] Grow bin/test-qemu into pytest-testinfra (like offline-lab) once it outgrows bash
- [x] BR2_PER_PACKAGE_DIRECTORIES for parallel top-level builds
- [ ] More H700 boards (RG35XX Plus/H/2024, RG40XX, RG CubeXX): DTB + meta only
