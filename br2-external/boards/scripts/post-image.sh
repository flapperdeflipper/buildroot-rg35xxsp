#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash disable=SC1090
#
# Assemble SD card / disk images. Called by buildroot as:
#   post-image.sh <BINARIES_DIR> <board-dir> <board-name>
#
# The board dir provides genimage.cfg.in, an optional extlinux.conf.in and
# <board-name>.meta. BOARD_SPL_VARIANTS in the meta lists "<spl>:<suffix>"
# pairs; one image is built per SPL that exists, e.g. for the H700:
#   rgos-rg35xxsp.img         LPDDR4 SPL
#   rgos-rg35xxsp-lpddr3.img  LPDDR3 SPL
# Boards without an SPL (QEMU) get a single image.
#
set -e -u -o pipefail

BINARIES_DIR="${1}"
BOARD_DIR="${2}"
BOARD_NAME="${3}"

BOARD_SPL_VARIANTS=""
source "${BOARD_DIR}/${BOARD_NAME}.meta"

GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"

printf '%s\n' "${BOARD_CMDLINE}" >"${BINARIES_DIR}/cmdline.txt"

if [[ -f "${BOARD_DIR}/extlinux.conf.in" ]]; then
    sed -e "s|#CMDLINE#|${BOARD_CMDLINE}|" \
        "${BOARD_DIR}/extlinux.conf.in" >"${BINARIES_DIR}/extlinux.conf"
fi

# Instructions for provisioning SSH keys and Wi-Fi from any computer
cp "${BR2_EXTERNAL_RGOS_PATH}/boards/common/boot/README.txt" "${BINARIES_DIR}/README.txt"

# shellcheck disable=SC2086
BOOT_FILES="$(printf '\t\t\t"%s",\n' Image ${BOARD_DTBS} README.txt)"
export BOOT_FILES="${BOOT_FILES%,}"

function make_image() {
    local image_name="${1}" spl_image="${2}" cfg
    cfg="${BINARIES_DIR}/genimage-${image_name%.img}.cfg"

    awk '/#BOOT_FILES#/ { print ENVIRON["BOOT_FILES"]; next } { print }' \
        "${BOARD_DIR}/genimage.cfg.in" \
        | sed -e "s|#IMAGE_NAME#|${image_name}|" \
              -e "s|#SPL_IMAGE#|${spl_image}|" \
              -e "s|#DISK_SIGNATURE#|${BOARD_DISK_SIGNATURE}|" \
        >"${cfg}"

    rm -rf "${GENIMAGE_TMP}"
    genimage \
        --rootpath "${TARGET_DIR}" \
        --tmppath "${GENIMAGE_TMP}" \
        --inputpath "${BINARIES_DIR}" \
        --outputpath "${BINARIES_DIR}" \
        --config "${cfg}"
}

if [[ -z "${BOARD_SPL_VARIANTS}" ]]; then
    make_image "${BOARD_IMAGE_BASENAME}.img" ""
    exit 0
fi

for variant in ${BOARD_SPL_VARIANTS}; do
    spl="${variant%%:*}"
    suffix="${variant#*:}"
    if [[ -f "${BINARIES_DIR}/${spl}" ]]; then
        make_image "${BOARD_IMAGE_BASENAME}${suffix}.img" "${spl}"
    fi
done
