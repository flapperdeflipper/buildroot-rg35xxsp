# Handover — status 2026-10-10 evening

Read CLAUDE.md first (rules, gotchas). This file is the live status. Build VM
setup and usage: docs/buildbox.md.

## Status

- **Works on the device** (RG35XX SP, v2 panel, LPDDR4): boots, screen and
  backlight on, labwc desktop + panel load, basic use works. Image:
  `artifacts/rg35xxsp/rgos-rg35xxsp.img.gz` (608 MB; rootfs 376 MiB, no LLVM).
  Flashed without SSH key/Wi-Fi, so there is no remote access yet
  (`bin/provision.sh --key … --wifi …` with the card in the Mac fixes that).
- Wi-Fi/BT fix by the OSK agent: `# CONFIG_RESET_GPIO is not set` (h700
  fragment; pwrseq-simple failed with the reset-gpio fallback).
- **QEMU 18:31 image = the whole tree (both agents) — `bin/test-qemu` 83/83
  green**, including oskd, the precise pointer, rgos-power (idle, profiles,
  SD-write tuning) and s2idle suspend + RTC wake. The test overrides lid and
  power key to `screen-off` in ~/.config/rgos/power.conf: QEMU only wakes
  from s2idle via the RTC alarm, so the defaults (suspend) would hang it. The
  earlier 64-check run also validated the `tests/` pytest-testinfra harness
  (14 passed, 1 skipped; `cd tests && uv run pytest --board qemu-arm64`, or
  `--host ssh://user@<ip>` against a provisioned device).
- Build hygiene: local-source packages (rgos-padd/oskd/padsim/desktop) are
  auto-dircleaned when their sources change (build-image.sh); no more manual
  `-dirclean` after source edits. README hardware caveat removed (it works).
- Two commits on `main`; everything since is uncommitted in the tree (both
  agents' work, intermixed — see `git diff`).

## Who works on what (session handoff, 2026-10-10 ~18:15)

Both prior agents (OSK + power) are wrapping up; a new agent picks up
everything. What each left behind:

| Area | State | Where |
|---|---|---|
| On-screen keyboard | **Done**, QEMU-verified | `src/oskd/`, `package/rgos-oskd/`; `rgos-padctl osk on\|off`; `/etc/rgos/oskd.conf` |
| Pointer precision | **Done** (tap = 2 px nudge, glide after 180 ms) | `src/padd/padd.c`, `mouse_tap`/`mouse_speed` in padd.conf |
| Power management | **Implemented, QEMU-verified; device measurements pending** | `docs/plan.md`, `rgos-power` package, `docs/power.md` ("Progress") |
| Build/test infra | **Done** this session | auto-dirclean in `build-image.sh`; `tests/` (pytest-testinfra) |

Still valid for any number of agents:
- One build per output dir at a time (`build-image.sh` refuses a second);
  check `bin/buildbox.sh ssh 'cat ~/build-<board>.status'` first. Builds sync
  the whole working tree, including others' uncommitted work.
- Build VM disk: ~41 GB free; two full outputs fit, a third does not.

## Device findings 2026-10-10 evening (image 18:35 on hardware)

- Works: Wi-Fi from wifi.txt (on despite the off default), mDNS
  (`ssh user@rgos.local`), s2idle suspend + resume with Wi-Fi back.
- Buttons don't bounce (evtest: presses >=126 ms, gaps >=55 ms); taps last
  130-640 ms.
- OSK pointer bug, fixed in image **19:13** (QEMU 86/86): the kernel drops
  repeated absolute values, so re-parking the pointer on "g" did nothing
  after the first time; and fixed pixel steps landed on key edges because
  wvkbd's rows are staggered. padd now has per-layout key grids
  (`osk_layout` in padd.conf, wvkbd reports layer switches via rgos-osk
  `-D` -> `rgos-padctl osk_layout`), warps to key centres and nudges 1 px
  before a repeated warp. Glide faster: `mouse_tap 2 150`, `mouse_speed 2 16 40`.
- To verify on hardware with 19:13: OSK typing, pointer speed feel.

## Next steps (for the next agent)

1. **Commit the tree** — both agents' work is uncommitted and QEMU-validated
   (83/83). The user does the commits themselves; leave staging to them.
2. **Flash + verify on hardware** — the **18:35** rg35xxsp image = the same
   tree as the 83/83 QEMU run. Includes rgos-power: lid/power key suspend,
   idle dim/off/suspend, Wi-Fi + BT off by default, **except** that a card
   provisioned with wifi.txt switches Wi-Fi on (bootconfig unblocks it; the
   state is then remembered). Device-only checks: Wi-Fi really comes up on
   first boot, plus docs/power.md "Still to do on the device". Also contains oskd, the WiFi fix
   and the precise pointer (tap = 2 px nudge, glide after 180 ms;
   `set mouse_tap`/`mouse_speed` in padd.conf). User flashes with
   `bin/flash.sh --key ~/.ssh/<key>.pub --wifi "<ssid>" --country NL disk4`,
   then verify: WiFi associates + `ssh user@<ip>`, oskd opens the keyboard
   in foot, pointer precision, brightness (Menu + d-pad up/down). Full suite:
   `cd tests && uv run pytest --host ssh://user@<ip>`.
3. **Power phase** per **docs/plan.md** (approved): measure → idle → radios →
   USB-C → sleep → …; `rgos-power` package owns it. Battery measurement
   needs the SSH from step 2.
4. Then Phase 2/3 of docs/roadmap.md (suspend field-testing, audio, TF2
   automount, apps; housekeeping: SBOM, check-versions, artifacts retention,
   BR2_REPRODUCIBLE).

## Device debugging

After a boot, card in the Mac: `/Volumes/RGOS-BOOT/rgos-boot.log`. Full
journal (persistent): user runs
`sudo /opt/homebrew/opt/e2fsprogs/sbin/debugfs -R "rdump /var/log/journal $HOME/rgos-journal" /dev/rdisk4s2`,
then `journalctl -D <dir> -b -1` in the build VM.

## Facts worth not re-deriving

- First boot failure was the panel module not autoloading (SPI modalias) →
  LCD controller deferred → no display/backlight; fixed via modules-load.d.
- Device has the v2 panel (stock fw `fog_fj035fhd05_v1`; ROCKNIX sp-v2 timings).
- Stock Anbernic dumps: `~/stock-head.img`, `~/stock-boot.img`, DTBs in
  `~/stock-dtb/` (not in the repo; proprietary).
- Card reader is USB 2.0 (~34 MB/s); flashing 608 MB takes ~18 s.
- In-tree Buildroot fixes: libfm/pcmanfm gnu17, ROCKNIX patches with fuzz
  (external.mk); wlroots 0.20.1 + mesa (no target LLVM, host RTTI) in
  buildroot-patches/.
- Wayland clients here: libwayland **aborts** on NULL listener entries
  (wl_closure_invoke) — stub every event you ignore; and wlr-foreign-toplevel
  must be the wlroots 0.20 XML variant (output_enter/output_leave, no
  `output` event), same one sfwbar bundles. labwc reports X11 apps' WM_CLASS
  as app_id (e.g. "Mousepad", "pcmanfm").
