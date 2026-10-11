# rtkit staging notes (draft, never built)

Roadmap audio follow-up: pipewire's module-rt falls back to SCHED_OTHER
(journal: RTKit D-Bus warnings) because no RTKit daemon runs and user
services cannot get CAP_SYS_NICE. rtkit-daemon holds CAP_SYS_NICE and
grants RT over the system bus.

## Promotion checklist

1. Copy to br2-external/package/rtkit, source its Config.in, enable
   BR2_PACKAGE_RTKIT in rgos_common_defconfig.
2. rootfs_overlay preset: enable rtkit-daemon.service (WantedBy=
   multi-user.target; also D-Bus-activatable). Check the preset dir used
   by the other services.
3. Build + test-qemu: assert `systemctl is-active rtkit-daemon` and,
   with pipewire running, that module-rt reports SCHED_FIFO for the
   audio threads (pw-top / /proc/<pid>/stat policy) - the existing
   "no rtkit fallback" audio check needs inverting then.
4. Device pass: the journal RTKit warnings disappear; audio under load
   (emulator + mpv) does not crackle.

## Open questions

- **dbus-broker compatibility**: the system bus here is dbus-broker
  (not dbus-daemon). dbus-broker-launch must be configured to read the
  classic XML policy in /usr/share/dbus-1/system.d for the RealtimeKit1
  rules to apply; verify on the first build (broker may need its own
  policy drop-in instead).
- **pipewire config**: module-rt auto-uses RTKit when the service is
  reachable; there is also `rtkit = true/false` in pipewire.conf.d.
  Confirm the shipped config prefers RTKit (default) and that the
  RLIMIT_RTPRIO drop-ins (50-rgos-rt.conf) do not fight it.
- polkit is not shipped; upstream treats it optional, the D-Bus policy
  is then the only gate (default allow for the local session user).
