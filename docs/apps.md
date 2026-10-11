# Apps

Everything on the device works from the pad. A USB or Bluetooth keyboard
and mouse work too.

## Desktop

Open things with Start, then Applications.

- **Terminal** (foot). The on-screen keyboard opens by itself when no
  hardware keyboard is attached. SELECT toggles it.
- **Files** (PCManFM). The SD card appears as "SD card".
- **Notes** (Mousepad) and **Geany** for editing code.
- **Web Browser (NetSurf)**: fast, own engine, limited JavaScript. Good
  for reading sites and documentation.
- **Web Browser (WebKit)**: WebKitGTK with MiniBrowser, so full HTTPS and
  JavaScript. It is heavy. For now it is built for the QEMU test image
  only, while RAM use is measured on the device.
- **Srain** (IRC, GTK) and **WeeChat** (IRC, terminal).

## YouTube

Search with the keyboard, pick a result with the d-pad and A. The video
plays full screen in mpv at up to 480p.

- A: pause
- L1/R1: seek
- B: back to the list, again for a new search

Formats are picked in the order H.264, VP9, AV1. Override the search URL
in `~/.config/rgos/youtube.conf`. yt-dlp is pinned in the image; since
YouTube breaks old versions, use "Update yt-dlp" in the main menu to
refresh it.

## Rockbox

Music player. It renders at 320x240 and is shown doubled.

- d-pad: browse
- A: OK, B: back
- X: menu, Y: play/pause
- L1/R1: previous/next track
- While playing: left/right skips (hold to seek), up/down changes volume

Quit through its menu. The pad returns to pointer mode afterwards. Music
lives in `~/Music` or on the SD card under `SD/Music`.

## Video and media

mpv plays local files (H.264 and VP9 in software, AV1 through dav1d).

## Command line

The usual modern set: `rg`, `fd`, `bat`, `zoxide` (`z`), `fzf` (Ctrl-R
works), `tldr`, `tree`, `ncdu`, `jq`, `yq`, `7za`, `git`, `sqlite3`,
`gpg` and `python3`, plus `mosh`.

Network tools: `tcpdump`, `nmap`, `mtr`, `iperf3`, `ngrep`, `nc`.

Radio: `rtl_sdr`, `rtl_fm`, `rtl_tcp`, `rtl_433`, `dump1090` and
`SoapySDR`. With a USB SDR dongle and an OTG adapter the handheld is a
portable receiver.

Terminal apps that work well from the pad: Midnight Commander, btop,
htop.

## Second SD card

Cards in the second slot (TF2) are checked, repaired if needed, and
mounted at `/media/sdcard` and `~/SD`. exFAT, FAT32 and ext4 are
supported.

The panel SD icon and the SD card menu offer Eject and Format. Format
converts the card to exFAT and asks twice. Cards the system cannot read,
such as Mac OS Extended, produce a warning with an offer to format.
