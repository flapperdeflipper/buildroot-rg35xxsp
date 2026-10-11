# Releases

Shipping images to GitHub Releases. Builds always run locally (build VM);
there is intentionally **no CI build**, to save runner credits.
`bin/release.sh` is the pipeline.

## Policy: what must never be in a release image

The scanner (`bin/lib/release-scan.sh`, run against the built target on
the VM) enforces this list. Anything here is a release blocker:

- **Credentials**: `wifi.txt`, `wifi-imported.txt`, `authorized_keys/` on
  the boot partition; iwd network profiles; SSH host keys; private key
  material anywhere in the root; remembered rfkill state.
- **Machine identity / state from a booted system**: non-empty
  `/etc/machine-id`, a persistent journal, first-boot stamps in
  `/var/lib/rgos`, `rgos-boot.log` on the boot partition.
- **Passwords**: any password hash; `root` must stay locked. (`user` has
  no password by design, for local console login on a personal device.
  sshd is key-only.)

End users provision their own card after flashing: SSH key + Wi-Fi via
files on the boot partition (`bin/provision.sh`, see README). The
released image itself boots with radios off and no keys.

## Process

```sh
bin/buildbox.sh build rg35xxsp     # green build (the scan requires status 0)
bin/release.sh scan rg35xxsp       # scan + SHA256SUMS -> tmp/release/
bin/release.sh notes 0.1.0         # draft docs/release-notes/v0.1.0.md
$EDITOR docs/release-notes/v0.1.0.md
git add/commit                     # publish refuses a dirty tree
bin/release.sh publish 0.1.0 --dry-run
bin/release.sh publish 0.1.0       # confirms, then gh release create
```

Notes on the mechanics:

- `gh` creates the tag on the remote at `--target HEAD`; this script never
  pushes refs itself. `gh auth login` first (a stale `GITHUB_TOKEN` env
  var interferes, so unset it).
- Assets per release: `rgos-rg35xxsp.img.gz` (LPDDR4 units),
  `rgos-rg35xxsp-lpddr3.img.gz` (LPDDR3 units), the CycloneDX SBOM, and
  `rg35xxsp-SHA256SUMS.txt`.
- Versioning: semver-ish `vMAJOR.MINOR.PATCH`; use `--prerelease` for
  anything not device-tested yet.
- Rollback = delete the release on GitHub (assets remain in
  `artifacts/<board>/history/` locally regardless).
- The QEMU image is a development artifact; it is not released.

## Before the first public release

The image being shipped should have passed a full round of device
verification (docs/testing.md). Beyond that, make sure the README covers
flashing without `bin/flash.sh` (balenaEtcher or Raspberry Pi Imager,
then provisioning through the boot partition, and the panel v1/v2 and
LPDDR3 variants), the LICENSE credits are current, and
`bin/check-versions` reports no stale pins.
