# mepo staging notes (draft, never built)

OSM map app for the device: online tiles + first-class offline download
(bbox or radius, zoom range) into the same tile cache. Chosen over Pure
Maps/modRana (Qt), GNOME Maps (gjs), foxtrotgps (GTK2/abandoned).

## Promotion checklist (in addition to staging/README.md)

1. Wire `source ".../package/mepo/Config.in"` and host-zig's into
   br2-external/Config.in (Games/apps section).
2. Enable BR2_PACKAGE_MEPO + BR2_PACKAGE_HOST_ZIG in the qemu defconfig;
   also enable SDL2_TTF/GFX/IMAGE if not already selected by Config.in
   selects (Config.in selects them; check `buildbox.sh check qemu-arm64`).
3. Pin MEPO_ZIG_TARGET: append the toolchain's glibc version, e.g.
   `aarch64-linux-gnu.2.39`, read from BR2_TOOLCHAIN_BUILDROOT_
   GLIBC_VERSION_STRING. Zig's bundled stubs must be >= that.
4. Build; expect the source download to come from the Alpine mirror
   (sr.ht is DNS-blocked on this network; bytes identical, sha512
   verified against Alpine's APKBUILD).
5. bin/test-qemu: launch rgos-mepo over the GUI path, screenshot, check
   the tile cache dir is created, Menu-tap exits (labwc Close path).

## Open questions / TODO

- **mepolang binds for the face buttons**: mepo's defaults already bind
  arrows = pan and keys for zoom. rgos-mepo seeds only the tile cache
  line. Map A/B/X/Y once the exact mepolang command names are verified
  on a live build (bind_key + zoom_relative / bind_menu for mepo's
  built-in menu; see `mepo -docmd` output for the command list).
- **UI glyphs**: mepo draws its on-screen buttons with Nerd Font glyphs;
  the image ships no nerd font. Either add a small nerd font (a few MB,
  size-trim conflict) or ignore the on-screen buttons (keyboard-first
  anyway). Decide on the device.
- **Offline download UX for the user**: the CLI flag (non-interactive
  prefetch of a bbox/radius) should get a launcher-friendly wrapper
  (foot one-liner or a menu entry: "download current view, zoom 0-14").
  Exact CLI syntax: `mepo -h` at promotion time.
- **Tile usage policy**: default tiles come from tile.openstreetmap.org;
  fine for personal use, bulk downloads should use a custom tileserver
  (mepolang: tileserver_url). Note it in the user docs.
- **GPLv3**: first GPLv3 app in the image? Check docs/release notes.
- **jq/curl scripts**: mepo's companion scripts (search etc.) need
  jq + curl + zenity - deliberately NOT shipped for now; core viewer +
  offline prefetch only. curl IS selected (libcurl for tile fetching);
  jq is NOT in the image.

## Sizing (rough)

- Binary: expect ~2-4 MB (Zig, ReleaseSafe).
- Runtime deps added to the image: sdl2_ttf + sdl2_gfx + sdl2_image
  (small), host-zig is build-time only (~49 MB download, ~300 MB in the
  build dir; prune after).
- RAM: designed for 1-2 GB PinePhone class; expect well under 100 MB
  with a 640x480 window.
