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

Open: Rockbox's SDL app runs at a fixed resolution (320x240 in the muOS port);
check 640x480 support before committing to it.
