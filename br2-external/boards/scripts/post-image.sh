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

# Small initramfs (busybox + our init): mounts the erofs root, the overlay
# upper and /data before systemd starts (boards/common/initramfs/init).
function build_initramfs() {
    local tmpdir bb readelf lib interp
    tmpdir="$(mktemp -d)"
    mkdir -p "${tmpdir}"/{bin,sbin,etc,proc,sys,dev,mnt,newroot,data,tmp,overlay}

    bb="${TARGET_DIR}/bin/busybox"
    cp "${bb}" "${tmpdir}/bin/busybox"
    chmod 0755 "${tmpdir}/bin/busybox"
    local cmd
    for cmd in sh mount umount mkdir rm cp chmod switch_root cat echo sleep; do
        ln -s busybox "${tmpdir}/bin/${cmd}"
    done

    cp "${BR2_EXTERNAL_RGOS_PATH}/boards/common/initramfs/init" "${tmpdir}/init"
    chmod 0755 "${tmpdir}/init"

    # Shared libraries busybox needs (glibc builds are dynamic)
    readelf="$(echo "${HOST_DIR}"/bin/*-readelf 2>/dev/null | cut -d' ' -f1)"
    if [[ -x "${readelf}" ]]; then
        mkdir -p "${tmpdir}/lib"
        for lib in $("${readelf}" -d "${bb}" |
                     sed -n 's/.*Shared library: \[\(.*\)\]/\1/p'); do
            # -L: SONAMEs are symlinks (libpam.so.0 -> libpam.so.0.85.1);
            # copying the link alone leaves busybox unloadable
            cp -L "${TARGET_DIR}/lib/${lib}" "${tmpdir}/lib/" 2>/dev/null || true
        done
        interp="$("${readelf}" -l "${bb}" |
                  sed -n 's/.*Requesting program interpreter: \(.*\)\]/\1/p')"
        if [[ -n "${interp}" && -f "${TARGET_DIR}${interp}" ]]; then
            mkdir -p "${tmpdir}/$(dirname "${interp}")"
            cp -L "${TARGET_DIR}${interp}" "${tmpdir}${interp}"
        fi
        # This glibc searches /lib64 by default (the real root ships a
        # /lib64 -> /lib symlink; without it PID1 dies with exit 127)
        ln -sfn lib "${tmpdir}/lib64"
    fi

    # init needs stdio (the kernel opens /dev/console for PID1)
    mknod -m 600 "${tmpdir}/dev/console" c 5 1 2>/dev/null || \
        echo "post-image: warning: no /dev/console in the initramfs" >&2

    (cd "${tmpdir}" && find . | cpio -o -H newc 2>/dev/null |
        gzip -9 >"${BINARIES_DIR}/initramfs.cpio.gz")
    rm -rf "${tmpdir}"
}
build_initramfs

# shellcheck disable=SC2086
BOOT_FILES="$(printf '\t\t\t"%s",\n' Image initramfs.cpio.gz ${BOARD_DTBS} README.txt)"
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
    # genimage >= 20 copies --rootpath into every ext4/vfat image that has
    # no explicit contents; the overlay/data partitions must start EMPTY,
    # so rootpath is an empty staging dir, not the target root.
    GENIMAGE_ROOT="${BUILD_DIR}/genimage-root"
    rm -rf "${GENIMAGE_ROOT}"
    mkdir -p "${GENIMAGE_ROOT}"
    genimage \
        --rootpath "${GENIMAGE_ROOT}" \
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
