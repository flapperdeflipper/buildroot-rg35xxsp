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

## Build finding (2026-10-13, promotion attempt)

rtkit's meson.build uses `xxd -i` to embed the D-Bus introspection
XML into a C header, and Buildroot ships no xxd (and no host-xxd).
Options: (a) a tiny host-xxd shim package implementing `-i`
faithfully (symbol name = input path with non-alnum -> _, plus the
_len symbol rtkit.c references), or (b) patch meson.build to use a
pre-generated xml-introspection.h vendored in the package. (b) is
the more reproducible; both were unbuilt at the time.

## RESOLVED (2026-10-13)

- host tool: real **host xxd** (br2-external/package/xxd,
  host-generic-package) built from vim's src/xxd/xxd.c (pinned
  v9.1.0000, sha256 in xxd.hash). `xxd -i` from stdin emits the bare C
  byte list rtkit-daemon.c's `{ #include "..." ,0x00}` needs - verified
  against vim's xxd and macOS xxd; Buildroot's own xxd package was
  removed upstream and its somos-1.10 site is dead.
- RTKIT_USERS: rtkit-daemon drops privileges to a dedicated `rtkit`
  system user; without it the unit exits ("Failed to find user
  'rtkit'").
- Verified in QEMU: user created (uid 106), D-Bus activation starts
  the daemon, org.freedesktop.RealtimeKit1 served. No preset needed
  (D-Bus activated on demand).
- Cosmetic: polkit is not shipped, rtkit logs "PolicyKit call
  failed: The name is not activatable" and continues.
- TODO for the audio owner: bin/test-qemu's "no rtkit fallback"
  check assumed no rtkit; its semantics flip now.
