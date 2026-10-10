# Work plan: power saving, performance, apps

Approved by the user 2026-10-10. Owner: power agent. Details/background:
docs/power.md (power candidates), docs/apps.md (app research).

## Ground rules

- **Measure before and after** every power change on the device; record the
  numbers in docs/power.md. No "should save power" without a measurement.
- **Everything configurable**: defaults in `/etc/rgos/power.conf`, user
  overrides in `~/.config/rgos/power.conf`. Nothing hardcoded in scripts.
- **Separate package** `rgos-power` owns the power work (scripts, configs,
  services, panel widgets). Shared files (sfwbar config, labwc autostart,
  defconfigs, kernel fragments) only get small hook lines — they belong to
  the OSK agent / both agents (docs/HANDOVER.md).
- Each step: build → QEMU smoke test where it applies (`bin/test-qemu`) →
  device test → docs updated → commit-ready.

## Phase 1 — Power (one long task, in this order)

1. **Measure** — `rgos-powerstat`: battery voltage × current (AXP717,
   /sys/class/power_supply) → watts and time left, logged to a CSV; panel
   widget (W, time left). Add `powertop`. Baseline: idle desktop, screen on;
   screen off; Wi-Fi on/off.
2. **mDNS** — systemd-resolved MulticastDNS so `ssh user@rgos.local` works.
3. **Idle** — `swayidle` (new package; labwc speaks ext-idle-notify): dim to
   `dim_brightness` after `dim_after` (60 s), screen off after `off_after`
   (180 s), any input wakes. Values in power.conf.
4. **Radios** — Wi-Fi and Bluetooth **off by default** (rfkill at boot,
   state remembered); toggles in the main menu and the panel.
5. **USB-C 5 V** — the device tree is already right (AXP717 `boost` is not
   always-on; `usb0-vbus` is GPIO-switched with `vin-supply = boost`; the
   PHY has `usb0_id_det-gpios` for role detection). Check at runtime on the
   device (`/sys/kernel/debug/regulator/regulator_summary`, musb role) whether
   the boost really stays off with nothing plugged in — USB-C has no classic
   ID pin. Fix only if measured on; USB devices must keep working.
6a. **Bug (user report)**: pressing the power button makes the screen flash.
    Likely labwc repeating the keybind while the key is held (each repeat
    toggles the screen). Fix: bind on release, single-instance action (flock),
    power key → `rgos-power event power-key`. Verify on the device.
6. **Sleep** — s2idle (`mem_sleep=s2idle`): lid close and power-key press →
   suspend; auto-suspend after `suspend_after` (600 s) on battery only.
   Verify resume: panel, backlight, Wi-Fi, pad, audio. Conservative defaults
   if the lid switch misbehaves.
7. **Background wake-ups** — panel mode label to an event (padd signals
   sfwbar) instead of a 1 s poll; review other panel intervals with powertop.
8. **SD writes** — `noatime`, ext4 `commit=60`, longer journald sync.
9. **Battery safety** — warning at `warn_percent` (10 %), clean poweroff at
   `poweroff_percent` (3 %).
10. **Power profiles** — performance / balanced / battery (cpufreq max +
    governor, GPU devfreq); switch in the panel; default balanced.
11. **Check only** — GPU idles (devfreq, power domain off) and the desktop
    renders on the GPU (Panfrost GLES, not software).

Follow-up projects (separate decisions later): real deep sleep (ROCKNIX SRAM
suspend stub + patched TF-A), trimming the kernel config to the H700.

## Phase 2 — Apps (after phase 1, smallest first)

1. **CLI tools** (small and clean): from Buildroot — ripgrep, fd, bat,
   zoxide, tealdeer, ncdu, mc, lsof, strace, tcpdump, iperf3, mtr, nmap,
   ngrep, git, sqlite, p7zip, gnupg2, minicom, tree, jq, yq, netcat, python3;
   new packages — btop, fzf, glow, progress, prettyping.
2. **Geany** (GUI code editor, new package; Mousepad stays for notes).
3. **IRC** — WeeChat + HexChat (new packages).
4. **NetSurf** — bump 3.10 → 3.11; default browser.
5. **RGOS YouTube** — search → pad-friendly list → mpv via yt-dlp, max 480p.
6. **Rockbox** (SDL app build) — first check 640x480 support.
7. **WebKit browser** — WebKitGTK (Safari's engine, not Chromium) in a
   minimal GTK3 shell; judge RAM/speed on the device. Firefox: not viable
   (1 GB RAM, Rust/Clang cross-build); Ladybird: pre-alpha, revisit later.

Each app: .desktop entry (shows up in the menu), pad-usable, size noted.
