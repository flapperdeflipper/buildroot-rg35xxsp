# Apps: proposal

Status: **approved 2026-10-10** (incl. Geany). Work order: docs/plan.md.

| Need | Proposal | Why | Effort |
|---|---|---|---|
| Music (GUI) | **Rockbox** as an app (SDL build) | What the handheld world uses (muOS, ROCKNIX, Knulli): made for buttons and battery, plays FLAC/ALAC/MP3/trackers. Not in Buildroot: own package. | M |
| IRC | **WeeChat** (terminal) + **HexChat** (GTK3) | User wants both. Neither in Buildroot; irssi is. | S + S |
| Light browsing | **NetSurf** (fast, own engine, limited JS) as the default; **WebKitGTK** in a minimal shell as the "real web" option, judged on the device for RAM/speed | Firefox/Chromium are far too heavy for 1 GB RAM. Both engines are in Buildroot (NetSurf 3.10 is old; bump to 3.11). | S / L |
| YouTube | `rgos-youtube`: search → pick (pad-friendly list) → play in **mpv** via **yt-dlp**, capped at 480p | No video site in a browser; a dedicated player is lighter. Needs python3 (yt-dlp). HW decode (cedrus) later. | M |
| GUI code editor | **Mousepad already has syntax highlighting**; for more (symbols, projects): **Geany** (GTK3) | Geany isn't in Buildroot: own package. | S |
| CLI tools | From Buildroot: ripgrep, fd, bat, zoxide, tealdeer, ncdu, mc, lsof, strace, tcpdump, iperf3, mtr, nmap, ngrep, git, sqlite, p7zip, gnupg2, minicom, tree, jq, yq, netcat, htop, python3. Own packages: btop, fzf, glow, progress, prettyping | User's Brewfile + proposal. rclone left out (big Go binary). | S |

## Progress (2026-10-10)

In the build (QEMU checks in bin/test-qemu "Apps"):

- CLI from Buildroot: ripgrep, fd, bat, zoxide, tealdeer, tree, ncdu, mc, yq,
  p7zip, zip, sqlite, lsof, strace, tcpdump, iperf3, mtr, nmap, ngrep,
  netcat-openbsd, minicom, git, gnupg2, python3 (ssl, sqlite, curses, ...).
  ncurses is now the wide-character build (UTF-8; needed by mc and WeeChat).
- Own packages: btop 1.4.7, fzf 0.74.4, glow 3.0.0, progress 0.17,
  prettyping 1.1.0, WeeChat 4.10.1 (Python scripts on), Geany 2.1.
- Video: mpv + ffmpeg. NetSurf 3.10 (GTK3) as the light browser.
- YouTube: `rgos-youtube` (search with the on-screen keyboard -> fuzzel list
  -> mpv full screen, max 480p; `~/.config/rgos/youtube.conf`). yt-dlp
  2026.08.19 zipapp (pinned, hash = upstream SHA2-256SUMS) with QuickJS as
  the JavaScript runtime YouTube needs (`/etc/yt-dlp.conf`), instead of a
  ~100 MB Deno.
- HexChat: **not packaged** — archived upstream since 2024 and GTK2/X11
  only. Proposed replacement: **Srain** 1.8.1 (GTK3, maintained; libsoup3,
  libsecret, libconfig are in Buildroot). Waiting for the user's decision.

Next: NetSurf 3.11 bump, Rockbox, WebKitGTK shell.

Open: Rockbox's SDL app runs at a fixed resolution (320x240 in the muOS port);
check 640x480 support before committing to it.
