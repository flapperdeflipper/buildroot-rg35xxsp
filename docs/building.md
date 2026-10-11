# Building RGOS

Builds run in a Linux VM, not on the Mac. The `bin/buildbox.sh` wrapper
syncs the tree, runs the build and copies the results back, so a build
is one command:

```bash
bin/buildbox.sh create            # create the VM (once)
bin/buildbox.sh build             # RG35XX SP image -> artifacts/rg35xxsp/
bin/buildbox.sh build qemu-arm64  # QEMU test image -> artifacts/qemu-arm64/
```

You need macOS on Apple Silicon (or arm64 Linux) with `lima`, `jq` and
`qemu` installed. The first build downloads and compiles everything and
takes an hour or two. Later builds are incremental.

## What gets built

- A pinned Buildroot (version in `bin/lib/versions.sh`), patched from
  `buildroot-patches/`. It is only re-patched when the version or the
  patches change.
- Linux with the Allwinner H700 patch set, fetched at build time from a
  pinned ROCKNIX commit (`RGOS_ROCKNIX_COMMIT` in
  `br2-external/external.mk`).
- U-Boot, a second SPL with LPDDR3 timings, TF-A with the suspend stub,
  and the desktop and app packages from `br2-external/package/`.

Every build produces a gzipped image, a CycloneDX SBOM next to it, and
keeps the last three images in `artifacts/<board>/history/`.

## Commands

- `bin/buildbox.sh make <board> <pkg>-dirclean` wipes one package's build
  directory. Do this after changing a package's dependencies.
- `bin/buildbox.sh check <board>` verifies defconfigs and kernel
  fragments. Run it after changing them.
- `bin/buildbox.sh ssh '<cmd>'` runs a command in the VM.
- `bin/buildbox.sh cache pull` and `push` sync the download cache with
  `~/.cache/rgos/dl` on the Mac.
- `bin/check-versions` compares pinned versions against upstream.
  `--update` bumps packages pinned to tags.

Packages with local sources (rgos-padd, rgos-power and friends) rebuild
automatically when their sources change.

## Several builds at once

The VM serves parallel work safely. Only one build per board runs at a
time; a second one is refused. Each board has its own work directory.
QEMU test runs get their own instance directory and SSH port under
`tmp/qemu-N`.

## Troubleshooting

- `Lima VM 'rgbox' not found or not running`: run `bin/buildbox.sh start`.
- Disk full: check with `bin/buildbox.sh ssh 'du -sh ~/output-*'`, remove
  an output directory, or prune one with
  `bin/buildbox.sh ssh 'bash ~/work/<board>/bin/build-image.sh --prune <board>'`.
- Out of memory during big compiles: a heavy source file can kill the
  compiler. The VM ships a 12 GB swapfile for this (`/swapfile-build`,
  registered in `/etc/fstab`). After recreating the VM:

  ```bash
  sudo fallocate -l 12G /swapfile-build && sudo chmod 600 /swapfile-build
  sudo mkswap /swapfile-build && sudo swapon /swapfile-build
  ```

  For the heaviest packages, cap the parallelism: `RGOS_JOBS=4`.
