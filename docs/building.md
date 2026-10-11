# Building RGOS

Builds never run on the Mac directly — the toolchain lives in a Linux VM
(`rgbox`, managed by [lima](https://lima-vm.io/)). The `bin/buildbox.sh`
wrapper handles syncing the tree, running the build and fetching results,
so day-to-day it's one command:

```bash
bin/buildbox.sh create            # create the VM (once)
bin/buildbox.sh build             # RG35XX SP image -> artifacts/rg35xxsp/
bin/buildbox.sh build qemu-arm64  # QEMU test image -> artifacts/qemu-arm64/
```

Requirements on the Mac: Apple Silicon (or arm64 Linux), `lima`, `jq`,
`qemu`. First build downloads and compiles everything (an hour or two);
later builds are incremental.

## What gets built

- **Pinned Buildroot** (version in `bin/lib/versions.sh`), patched from
  `buildroot-patches/` on every run — the tree is only re-patched when
  the version or the patches change.
- **Linux** with the Allwinner H700 patch set, fetched at build time from
  a pinned ROCKNIX commit (`RGOS_ROCKNIX_COMMIT` in
  `br2-external/external.mk`); hashes in `br2-external/patches/linux/`.
- **U-Boot** plus a second SPL build with LPDDR3 timings
  (`rgos-uboot-ddr3`), **TF-A** with the SRAM suspend stub, and the
  desktop/app stack from `br2-external/package/`.

Each build produces `rgos-<board>.img.gz`, a CycloneDX SBOM
(`*.sbom.cdx.json`) and keeps the last three images in
`artifacts/<board>/history/`.

## Useful commands

| Command | What it does |
|---|---|
| `bin/buildbox.sh build` | full build of the RG35XX SP image |
| `bin/buildbox.sh make <board> <pkg>-dirclean` | wipe one package's build dir (required after changing its dependencies) |
| `bin/buildbox.sh check <board>` | defconfig/kernel-fragment sanity check; run it after changing defconfigs |
| `bin/buildbox.sh ssh '<cmd>'` | run a command in the build VM |
| `bin/buildbox.sh cache pull` / `push` | sync the download cache with `~/.cache/rgos/dl` on the Mac |
| `bin/check-versions` | audit pinned package versions against upstream (`--update` bumps tag-pinned ones) |

Local-source packages (`rgos-padd`, `rgos-oskd`, `rgos-power`, ...) are
rebuilt automatically when their sources change.

## Concurrent use

The VM safely serves several builds and terminals at once:

- one build per board at a time (`flock` refuses a second),
- a per-board work copy under `~/work/<board>`,
- QEMU test runs claim their own instance directory and SSH port
  (`tmp/qemu-N`, port 2222+N; `RGOS_QEMU_INSTANCE=N` selects one).

## Troubleshooting

- `Lima VM 'rgbox' not found or not running` — `bin/buildbox.sh start`.
- Disk full — `bin/buildbox.sh ssh 'du -sh ~/output-*'`, delete an output
  dir you don't need, or prune one with
  `bin/buildbox.sh ssh 'bash ~/work/<board>/bin/build-image.sh --prune <board>'`.
- Out of memory during big compiles (WebKit's JavaScriptCore kills
  `cc1plus`) — the VM ships a 12 GB swapfile (`/swapfile-build`, in
  `/etc/fstab`). After recreating the VM, restore it with
  `sudo fallocate -l 12G /swapfile-build && sudo chmod 600 /swapfile-build && sudo mkswap /swapfile-build && sudo swapon /swapfile-build`.
- Big first builds: WebKitGTK needs ~15 GB of disk and 2–4 h (ICU,
  libsoup3, WebKit itself). Everything else stays well under that.
