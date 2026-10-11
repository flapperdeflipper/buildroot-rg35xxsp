# Game-mode system pieces: promotion notes

Untested drafts (wip/tooling). Where things go when promoted:

- `games.slice`, `background.slice`, `system-slice-memory.conf`
  -> rgos-power (it owns the system tuning) or a small rgos-game package;
     slices install to /usr/lib/systemd/system, the drop-in to
     /etc/systemd/system/system.slice.d/.
  ManagedOOMMemoryPressure needs systemd >= 256 (we ship 258).
- `rgos-game` -> /usr/bin; menu entries launch through it:
  `<action name="Execute" command="rgos-game retroarch -L /usr/lib/libretro/gambatte_libretro.so /path/rom.gb" />`
- RetroArch config to ship as /etc/rgos/retroarch.cfg.defaults (user
  overrides in ~/.config/retroarch):
  - video_driver gl, video_scale_integer true, fullscreen on the 640x480 panel
  - audio_driver alsa
  - input via evdev (udev), the gpio-keys gamepad maps to RetroArch IDs
    automatically (BTN_SOUTH=A, TL/TR = L1/R1, ...)
  - libretro_directory /usr/lib/libretro
  - menu_driver rgui or xmb (try both on the 3.5" panel)
- Input: rgos-padd passthrough mode is ready (roadmap); the game launcher
  should switch the pad to passthrough while a core runs and back after
  (pattern: rgos-rockbox does the same).
- The existing "Game mode" power-menu entry is the natural hook: it can
  start RetroArch directly or toggle passthrough.
