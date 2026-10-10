# Buildbox: the build VM

All builds run in a Debian 13 arm64 VM (lima, Apple Virtualization
Framework) called `rgbox`, never on the Mac. `bin/buildbox.sh` drives it:
it rsyncs the tree in, starts the build there and fetches the images out.

## Requirements (Mac)

- Apple Silicon, `brew install lima jq rsync`
- ~100 GB free disk (the VM disk grows up to that)

## Create the VM (once)

```sh
bin/buildbox.sh create
```

This:

- generates `.ssh/builder` (ed25519, gitignored) if it doesn't exist; the
  VM's `builder` account accepts only this key. The QEMU tests use the same
  key to log in to the test image.
- creates the VM: CPUs = Mac cores − 2, RAM = 2/3 of the Mac's memory, 100 GiB
  disk (override with `BUILDBOX_VM_CPUS`, `BUILDBOX_VM_MEMORY`, e.g. `16GiB`,
  `BUILDBOX_VM_DISK`; VM name with `BUILDBOX_VM_NAME`)
- installs the Buildroot host packages and clones Buildroot at the version
  pinned in `bin/lib/versions.sh`

`bin/buildbox.sh start|stop` starts and stops it; `destroy` deletes it,
including all build output and downloads.

## Build

```sh
bin/buildbox.sh build               # RG35XX SP  -> artifacts/rg35xxsp/
bin/buildbox.sh build qemu-arm64    # QEMU image -> artifacts/qemu-arm64/
```

`build` syncs the tree, starts the build detached on the VM and follows its
log; at the end it fetches the images. If the connection drops, the build
keeps running: re-attach with `bin/buildbox.sh follow <board>`.

The first build takes several hours (toolchain, LLVM for Mesa, kernel,
desktop); after that builds are incremental and take minutes, with
ccache (20 GB) and the download cache on the VM.

Other commands:

| Command | What it does |
|---|---|
| `bin/buildbox.sh check <board>` | sync + configure + verify the defconfig (run after every defconfig change; catches dropped and legacy symbols) |
| `bin/buildbox.sh make <board> <target>…` | sync + run Buildroot make targets, e.g. `linux-rebuild`, `foo-dirclean` |
| `bin/buildbox.sh fetch <board>` | copy the images to `artifacts/<board>/` again |
| `bin/buildbox.sh sync` | only rsync the tree |
| `bin/buildbox.sh ssh [cmd]` | shell or command on the VM |

Incremental rebuild of one package: `make <board> <pkg>-dirclean`, then
`build <board>`. Use `-dirclean`, not `-rebuild`: finished packages over
200 MB are pruned to save disk (object files deleted, stamps kept), so they
can't be rebuilt in place. The local-source packages (rgos-padd, rgos-oskd,
rgos-padsim, rgos-desktop) are dircleaned automatically when their sources
change.

Local overrides (root password, timezone, extra packages): copy
`.config.example` to `.config` (gitignored); it's appended to the defconfig.

## What's on the VM

| Path | Contents |
|---|---|
| `~/buildroot` | Buildroot, reset to the pinned tag and patched from `buildroot-patches/` on every build |
| `~/work` | synced copy of `br2-external/`, `bin/`, `src/`, `buildroot-patches/`, `.config` |
| `~/output-<board>` | Buildroot output dir, kept for incremental builds |
| `~/artifacts/<board>` | finished images (what `fetch` copies) |
| `~/downloads` | source tarballs (shared by all boards) |
| `~/build-<board>.log`, `.status` | log of the last full build; status `running` or its exit code |

## Sharing the VM (several agents or terminals)

- One build per board at a time: `build` refuses a second one, and
  `check`/`make` refuse while a full build of that board runs. Different
  boards (rg35xxsp, qemu-arm64) may build at the same time.
- Before building, look: `bin/buildbox.sh ssh 'cat ~/build-*.status'`.
- Every `build`/`make`/`check` syncs the whole working tree, including other
  people's uncommitted changes; keep the tree buildable.
- Disk: two full outputs fit in 100 GB; a third doesn't. Check with
  `bin/buildbox.sh ssh 'df -h /'`.

## Test and flash

- QEMU: `bin/test-qemu` (boots the QEMU image, runs the checks, screenshots
  in `tmp/qemu/test-*.png`); `bin/run-qemu` for a manual session.
- Device: `bin/flash.sh --key <your.pub> --wifi "<network>" <disk>`; see
  README.md.

## Troubleshooting

- `Lima VM 'rgbox' not found or not running`: `bin/buildbox.sh start`.
- Disk full: `bin/buildbox.sh ssh 'du -sh ~/output-*'`; delete an output dir
  you don't need (`rm -rf ~/output-<board>`, the next build starts from
  scratch), or prune it with `bin/buildbox.sh ssh 'bash ~/work/bin/build-image.sh --prune <board>'`.
- A stale `running` status after the VM was stopped mid-build: check that
  nothing runs (`pgrep -af build-image`), then
  `bin/buildbox.sh ssh 'echo 1 > ~/build-<board>.status'`.
