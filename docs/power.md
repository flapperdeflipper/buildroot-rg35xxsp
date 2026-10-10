# Power saving and performance: candidates

Status: **approved 2026-10-10** (all except the sshd/dropbear item; Wi-Fi
power save replaced by "Wi-Fi off by default + toggle"). Work order: docs/plan.md.
Impact is the expected effect on battery life; "?" = must be measured first.

## Progress (2026-10-10)

Implemented in the `rgos-power` package and QEMU-tested (`bin/test-qemu`),
**not yet measured on the device**:

- `rgos-power status|panel|log` (watts, time left, CPU/GPU MHz; CSV log),
  `powertop` installed.
- Settings: `/etc/rgos/power.conf`, overrides in `~/.config/rgos/power.conf`,
  `rgos-power reload` applies them.
- Idle: swayidle via `rgos-idle` — dim 60 s, screen off 180 s, suspend 600 s
  (battery only unless `suspend_on_ac=1`).
- Lid close / power key → suspend (`lid_action`, `power_key_action`:
  suspend|screen-off|nothing). Power key acts on release, with a lock and
  a 1 s debounce (fix for the screen flashing); with the screen off it wakes.
- s2idle via `systemctl suspend` (sleep.conf.d). QEMU: suspend + RTC wake +
  desktop/pad/screen alive afterwards.
- Wi-Fi and Bluetooth off by default (rfkill, then remembered by
  systemd-rfkill); menu toggles.
- Profiles performance / balanced / battery: CPU governor + max frequency,
  GPU devfreq min/max limits (no devfreq "performance" governor in the
  kernel); battery caps both at the OPP nearest ~2/3 of the top frequency.
- Battery guard: clean poweroff at 3 % while discharging; panel shows "LOW"
  at 10 %.
- mDNS: `ssh user@rgos.local`.
- Fewer SD writes: root `noatime,commit=60`, journald `MaxLevelStore=info`,
  `SyncIntervalSec=15m`, `SystemMaxUse=64M`, dirty writeback 15 s.
- Panel pad-mode label updates on a file event instead of a 1 s poll.

Still to do on the device: baseline measurements (below), USB-C boost check,
s2idle resume (panel, Wi-Fi, audio), lid behaviour, GPU idle/rendering check.

## Measurements

None yet. Protocol: `rgos-power log 10` for 10 min per state — idle desktop
screen on (50 %), screen off, Wi-Fi on/off, each profile under load.

## Measure first

| ID | Item | Impact | Effort | Notes |
|---|---|---|---|---|
| M1 | `rgos-power`: battery voltage × current from the AXP717 → watts, logged; panel shows power draw and time left | — | S | Without this every other item is guesswork. Needs SSH on the device. |
| M2 | `powertop` + a short test protocol (idle desktop, screen off, Wi-Fi on/off) | — | S | Finds wakeups and devices that never sleep. |

## Display (usually the biggest consumer)

| ID | Item | Impact | Effort | Notes |
|---|---|---|---|---|
| D1 | Idle: dim the backlight after ~1 min, screen off after ~3 min, any button wakes | High | S | `swayidle` (small new package; labwc supports the idle protocol). |
| D2 | Lower default brightness (e.g. 50 %); the last level is remembered already | Med | XS | Your preference. |
| D3 | Lid closed → suspend instead of screen off (after S1/S2 work) | High | XS | |

## Suspend

| ID | Item | Impact | Effort | Notes |
|---|---|---|---|---|
| S1 | s2idle ("freeze"): devices suspended, CPUs in idle; works with mainline | Med–High | S–M | Test resume of panel, Wi-Fi, pad. ROCKNIX patches 0157/0161–0163 help. |
| S2 | Deep sleep (PSCI SYSTEM_SUSPEND): ROCKNIX's SRAM suspend stub + patched TF-A, one stub per RAM type | Very high (days of standby) | L | Real project: TF-A + U-Boot DRAM sources + stub; high risk. |
| S3 | Power key short press → suspend; auto-suspend after N min idle on battery | High | XS | After S1/S2. |

## CPU / GPU

| ID | Item | Impact | Effort | Notes |
|---|---|---|---|---|
| C1 | Power profiles: performance / balanced / battery (cpufreq max, governor, GPU devfreq), switch in the panel | Med | S | Default `schedutil` is already sensible. |
| C2 | CPU idle states: the device tree has none, so cores only use WFI; add PSCI power-down states if TF-A supports them | ?–Med | M | Investigate first. |
| C3 | Verify GPU idle: Panfrost devfreq + GPU power domain actually turn off | ? | XS | Check only. |
| C4 | Verify the desktop really renders on the GPU (Panfrost GLES), not in software | ? (perf + power) | XS | Check only. |

## Radios

| ID | Item | Impact | Effort | Notes |
|---|---|---|---|---|
| R1 | Bluetooth off by default; on via the panel | Low–Med | XS | |
| R2 | Wi-Fi power save on | Med | XS | ROCKNIX turns it **off** on this chip (rtw88 SDIO instability). Test only; keep off if flaky. |
| R3 | Airplane mode / Wi-Fi off toggle in the panel | Med (when unused) | XS | |

## Wakeups and services

| ID | Item | Impact | Effort | Notes |
|---|---|---|---|---|
| W1 | Panel: the pad-mode label polls a file every second; switch to an event (signal) | Low | XS | Also review sfwbar widget intervals. |
| W2 | sshd → socket-activated (runs only during a connection), or dropbear | ~0 power, −4 MB RAM | XS | An idle sshd just sleeps in `accept()`; dropbear saves RAM, not power. |
| W3 | journald: longer sync interval (fewer SD card writes) | Low | XS | |
| W4 | Start Bluetooth/iwd/timesyncd only when used (follows R1/R3) | Low | S | |

## Storage

| ID | Item | Impact | Effort | Notes |
|---|---|---|---|---|
| T1 | ext4 `noatime` + `commit=60` | Low | XS | Fewer SD writes and wakeups. |
| T2 | Second SD slot: ROCKNIX patch 0159 keeps TF2 powered permanently | ?–Low | S | Measure; could power it only when a card is present. |

## USB

| ID | Item | Impact | Effort | Notes |
|---|---|---|---|---|
| U1 | Check whether the OTG 5 V boost stays on with nothing plugged in (patch 0152 enables host mode) | ?–High | S | A boost converter idling all the time is a classic hidden drain. Check first. |

## Battery safety

| ID | Item | Impact | Effort | Notes |
|---|---|---|---|---|
| B1 | Low-battery warning at 10 %, clean shutdown at 3 % | — (safety) | S | Avoids SD corruption from a dead battery. |

## Performance (not power)

| ID | Item | Impact | Effort | Notes |
|---|---|---|---|---|
| P1 | Trim the kernel to what the H700 needs (762 modules / 41 MB → a few dozen) | Boot, RAM, size | M | arm64 defconfig leftovers. |
| P2 | Boot time: `systemd-analyze` on the device, fix the slow units | Boot | S | |
| P3 | Desktop responsiveness: app start times, zram/swappiness tuning, preloading the panel/menu | UX | S–M | Measure first. |
