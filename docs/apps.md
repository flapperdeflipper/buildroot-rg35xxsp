# Apps

Everything on the device, with the controls that don't explain
themselves. All of them work with the pad; a USB or Bluetooth keyboard
and mouse work too.

## Desktop apps (Start -> Applications)

- **Terminal** (foot) — the on-screen keyboard opens by itself when no
  hardware keyboard is attached; SELECT toggles it.
- **Files** (PCManFM) — includes the SD card (TF2) under "SD card".
- **Notes** (Mousepad), **Geany** (code editor with syntax highlighting
  and symbol list).
- **Web Browser (NetSurf)** — fast, own engine, limited JavaScript. Good
  for reading sites and documentation.
- **Web Browser (WebKit)** — WebKitGTK/MiniBrowser, the "real web"
  option: HTTPS, full JavaScript, tabs. Heavy: it is currently built for
  the QEMU test image only while RAM use is evaluated on the device;
  whether it ships on the handheld is an open decision.
- **YouTube** (`rgos-youtube`) — search with the keyboard, pick a result
  (d-pad + A), plays full screen in mpv, capped at 480p. A = pause,
  L1/R1 = seek, B = back to the list, B again = new search. Format
  preference H.264 then VP9 then AV1. `~/.config/rgos/youtube.conf`
  overrides the search URL. yt-dlp is pinned in the image; "Update
  yt-dlp" in the main menu updates it (YouTube breaks old versions).
- **Rockbox** (music) — built at 320x240 and shown 2x. d-pad browse,
  A = OK, B = back, X = menu, Y = play/pause, L1/R1 = previous/next;
  on the now-playing screen left/right = skip (hold to seek), up/down =
  volume. Quit through its menu; the pad returns to pointer mode
  afterwards. Music lives in `~/Music` or on the SD card under
  `SD/Music`.
- **Srain** (IRC, GTK3) and **WeeChat** (IRC, terminal).
- **mpv** — plays local video (H.264/VP9 in software, AV1 via dav1d).
- **Midnight Commander**, **btop**, **htop** — terminal classics that
  work well from the pad.

## Command line

Modern CLI set installed system-wide: `rg`, `fd`, `bat`, `zoxide` (`z`),
`fzf` (Ctrl-R works), `tldr`, `tree`, `ncdu`, `jq`, `yq`, `7za`, `git`,
`sqlite3`, `gpg`, `python3` (with ssl/sqlite/curses), `mosh`, plus the
network toolbox: `tcpdump`, `nmap`, `mtr`, `iperf3`, `ngrep`, `nc`.

Radio/SDR tools: `rtl_sdr`/`rtl_fm`/`rtl_tcp` (librtlsdr), `rtl_433`,
`dump1090`, `SoapySDR` — with a USB SDR dongle and an OTG adapter the
handheld is a portable receiver.

## Second SD card (TF2)

Cards in TF2 are checked, fscked and mounted automatically at
`/media/sdcard` (also reachable as `~/SD`): exFAT, FAT32 and ext4. The
panel SD icon and the SD card menu offer Eject and Format (exFAT, asks
twice). Unformatted or Mac-formatted cards produce a warning
notification and a Format offer.
