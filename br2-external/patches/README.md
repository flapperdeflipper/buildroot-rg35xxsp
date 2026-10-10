# Patch and hash locations

This directory is `BR2_GLOBAL_PATCH_DIR`. Buildroot looks here for
`<pkg>/<pkg>.hash` — which is all it holds today: hashes for the extra
downloads that external.mk fetches at build time (H700 kernel patches,
TF-A suspend patch, suspend-stub tarball). `<pkg>/*.patch` files placed
here would also be applied to Buildroot's packages.

The other patch locations:

- `buildroot-patches/` — patches **Buildroot itself** (package bumps/fixes
  that an external tree cannot do: in-tree packages cannot be overridden
  from BR2_EXTERNAL). Applied and stamped by `bin/build-image.sh`.
- `boards/<board>/linux-patches/` — local kernel patches, applied by
  Buildroot via `BR2_LINUX_KERNEL_PATCH` (zero fuzz). The downloaded H700
  patch set bypasses this on purpose: it needs fuzz, so external.mk applies
  it after download.
- `package/<pkg>/*.patch` — patches for packages defined in this tree
  (standard Buildroot per-package mechanism).
