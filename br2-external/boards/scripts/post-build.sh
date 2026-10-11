#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash
#
# Final touches on the target rootfs. Called by buildroot as:
#   post-build.sh <TARGET_DIR> <board-dir> <board-name>
#
set -e -u -o pipefail

TARGET_DIR="${1}"
BOARD_NAME="${3}"

BUILD_ID="$(git -C "${BR2_EXTERNAL_RGOS_PATH}" describe --tags --always --dirty 2>/dev/null || date -u +%Y%m%d)"

cat >"${TARGET_DIR}/usr/lib/os-release" <<EOF
NAME="RGOS"
ID=rgos
PRETTY_NAME="RGOS (${BOARD_NAME})"
VERSION_ID=${BUILD_ID}
BUILD_ID=${BUILD_ID}
VARIANT_ID=${BOARD_NAME}
EOF
ln -sf ../usr/lib/os-release "${TARGET_DIR}/etc/os-release"

# Lock root: an empty root password on a public image is a hole. `user`
# (passwordless console login by design) with passwordless sudo is the
# access path; sshd is key-only anyway. bin/lib/release-scan.sh enforces
# this.
sed -i -E 's/^(root:)[^:]*:/\1!:/' "${TARGET_DIR}/etc/shadow"

# Mount point for the RGOS-BOOT vfat partition (kernel, DTBs, extlinux.conf)
mkdir -p "${TARGET_DIR}/boot"

# Boot into the graphical session (rgos-session.service owns tty1; the
# serial console on ttyS0 keeps its getty for debugging)
ln -sf /usr/lib/systemd/system/graphical.target "${TARGET_DIR}/etc/systemd/system/default.target"
ln -sf /dev/null "${TARGET_DIR}/etc/systemd/system/getty@tty1.service"

# Menu clutter. Files installed by other packages must be removed here, not
# in a package: with per-package directories they'd come back at the merge.
rm -f "${TARGET_DIR}/usr/share/applications/footclient.desktop" \
      "${TARGET_DIR}"/usr/share/applications/foot-server.desktop

# --- Size: files nothing on the device ever reads (curated, keep it that
# way; measurements + verdicts in tmp/agents/size-trim.md) ---
# Boot files: U-Boot loads kernel/DTBs from the RGOS-BOOT vfat that mounts
# over /boot, so the copies the kernel package drops into the rootfs stay
# shadowed forever. post-image.sh builds the vfat from BINARIES_DIR, never
# from here; /boot itself stays as the mount point.
rm -f "${TARGET_DIR}"/boot/Image "${TARGET_DIR}"/boot/*.dtb
# udev reads only the compiled hwdb.bin; the hwdb.d text sources exist to
# rebuild it (systemd-hwdb update), which nothing on the device runs.
rm -rf "${TARGET_DIR}/usr/lib/udev/hwdb.d"
# font-awesome is a web-frontend package (svg/js/css/woff2); nothing on the
# desktop references it and fontconfig cannot load woff2. The rm also guards
# output dirs built before the package was dropped from the defconfig.
rm -rf "${TARGET_DIR}/usr/share/font-awesome" \
      "${TARGET_DIR}/usr/share/fonts/font-awesome"
# Adwaita: the panel is 640x480, so icon sizes above 64 are never requested
# (gtk-icon-theme-name=Adwaita). There is no SVG loader in the image (no
# librsvg), so scalable/ never rendered anything. Cursors stay
# (XCURSOR_THEME=Adwaita). icon-theme.cache is removed with the pruned dirs:
# its stale entries would point at deleted files (GTK then scans the dirs).
rm -rf "${TARGET_DIR}"/usr/share/icons/Adwaita/{8x8,96x96,256x256,512x512,scalable,scalable-up-to-32}
rm -f "${TARGET_DIR}"/usr/share/icons/*/icon-theme.cache
# Rockbox fonts: user call 2026-10-11 (Latin + Unifont). Drop the CJK
# families (18M; "WenQangYi" is upstream's own spelling) but keep
# 16-GNU-Unifont so CJK metadata still renders; all Latin fonts stay.
# No shipped theme references the dropped families (verified).
rm -f "${TARGET_DIR}"/usr/share/rockbox/fonts/*WenQangYi-* \
      "${TARGET_DIR}"/usr/share/rockbox/fonts/*Sazanami-* \
      "${TARGET_DIR}"/usr/share/rockbox/fonts/*Namil*
# GTK ships per-language emoji-picker translations (23 files). The image
# sets LANG=en_US.UTF-8 and the en/C emoji data is compiled into GTK
# itself (there is no en.gresource), so every one of these is unused.
# If more locales are ever generated (BR2_GENERATE_LOCALE), keep the
# matching .gresource.
rm -rf "${TARGET_DIR}"/usr/share/gtk-3.0/emoji

# --- Size: files nothing on the device ever reads (curated, keep it that
# way; details + measurements in tmp/agents/size-trim.md) ---
# Boot files: U-Boot loads kernel/DTBs from the RGOS-BOOT vfat that mounts
# over /boot, so the copies the kernel package drops into the rootfs stay
# shadowed forever. post-image.sh builds the vfat from BINARIES_DIR, never
# from here; /boot itself stays as the mount point.
rm -f "${TARGET_DIR}"/boot/Image "${TARGET_DIR}"/boot/*.dtb
# udev reads only the compiled hwdb.bin; the hwdb.d text sources exist to
# rebuild it (systemd-hwdb update), which nothing on the device runs.
rm -rf "${TARGET_DIR}/usr/lib/udev/hwdb.d"
# font-awesome is a web-frontend package (svg/js/css/woff2); nothing on the
# desktop references it and fontconfig cannot load woff2. The rm also guards
# output dirs built before the package was dropped from the defconfig.
rm -rf "${TARGET_DIR}/usr/share/font-awesome" \
      "${TARGET_DIR}/usr/share/fonts/font-awesome"
# Adwaita: the panel is 640x480, so icon sizes above 64 are never requested
# (gtk-icon-theme-name=Adwaita). There is no SVG loader in the image (no
# librsvg), so scalable/ never rendered anything. Cursors stay
# (XCURSOR_THEME=Adwaita). icon-theme.cache is removed with the pruned dirs:
# its stale entries would point at deleted files (GTK then scans the dirs).
rm -rf "${TARGET_DIR}"/usr/share/icons/Adwaita/{8x8,96x96,256x256,512x512,scalable,scalable-up-to-32}
rm -f "${TARGET_DIR}"/usr/share/icons/*/icon-theme.cache

# Upstream sshd_config has no Include; prepend it so sshd_config.d drop-ins
# apply (sshd uses the first value it sees for each option)
sshd_config="${TARGET_DIR}/etc/ssh/sshd_config"
if [[ -f "${sshd_config}" ]] && ! grep -q '^Include /etc/ssh/sshd_config.d/' "${sshd_config}"; then
    sed -i '1i Include /etc/ssh/sshd_config.d/*.conf' "${sshd_config}"
fi

# sudoers drop-ins must not be group/world writable
chmod 0440 "${TARGET_DIR}"/etc/sudoers.d/* 2>/dev/null || true

# Package installs sometimes replace the /var/run symlink with a directory
if [[ -d "${TARGET_DIR}/var/run" && ! -L "${TARGET_DIR}/var/run" ]]; then
    rm -rf "${TARGET_DIR}/var/run"
    ln -s ../run "${TARGET_DIR}/var/run"
fi
