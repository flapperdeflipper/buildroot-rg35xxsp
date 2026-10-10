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

# Mount point for the RGOS-BOOT vfat partition (kernel, DTBs, extlinux.conf)
mkdir -p "${TARGET_DIR}/boot"

# Boot into the graphical session (rgos-session.service owns tty1; the
# serial console on ttyS0 keeps its getty for debugging)
ln -sf /usr/lib/systemd/system/graphical.target "${TARGET_DIR}/etc/systemd/system/default.target"
ln -sf /dev/null "${TARGET_DIR}/etc/systemd/system/getty@tty1.service"

# Menu clutter. Files installed by other packages must be removed here, not
# in a package: with per-package directories they'd come back at the merge.
rm -f "${TARGET_DIR}/usr/share/applications/footclient.desktop" \
      "${TARGET_DIR}/usr/share/applications/foot-server.desktop"

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
