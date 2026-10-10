#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash
#
# Write an RGOS image to an SD card (macOS or Linux).
#
# Usage:
#   bin/flash.sh                       # list candidate removable disks
#   bin/flash.sh <disk> [image]        # e.g. bin/flash.sh disk4
#   bin/flash.sh --verify <disk> [image]
#                                      # read the card back and compare
#   bin/flash.sh --key ~/.ssh/id_ed25519.pub --wifi "My net" --country NL disk4
#                                      # provision SSH key / Wi-Fi right after
#                                      # writing (see bin/provision.sh)
#   bin/flash.sh --confirm <disk> <disk> [image]
#                                      # no prompt (scripts); --confirm must
#                                      # name the same disk
#
# image defaults to the newest artifacts/rg35xxsp/rgos-rg35xxsp.img.gz
# (use rgos-rg35xxsp-lpddr3.img.gz for LPDDR3 units).
#
# Everything on <disk> is destroyed. Internal disks are refused, and you
# have to type the disk name (or pass --confirm <disk>) to confirm.
# Writing needs root: sudo, or on macOS without a terminal the standard
# administrator password dialog. The usual dd recipe: decompress into dd
# with a large block size and status=progress (raw /dev/rdiskN on macOS).
#
# Testing: RGOS_FLASH_TEST_TARGET=<file> writes to that file instead of a
# disk (no disk checks, no root).
#
set -e -u -o pipefail

BASEDIR="$(cd "$(dirname "${0}")/.." && pwd)"
# shellcheck source=lib/common.sh
source "${BASEDIR}/bin/lib/common.sh"

CONFIRM=""
VERIFY=0
PROVISION=()
while [[ "${1:-}" == --* ]]; do
    case "${1}" in
        --confirm) CONFIRM="${2:-}"; shift 2 ;;
        --verify)  VERIFY=1; shift ;;
        --key|--wifi|--country) PROVISION+=("${1}" "${2:?${1} needs a value}"); shift 2 ;;
        *) log_err "Unknown option: ${1}"; exit 2 ;;
    esac
done
DISK="${1:-}"
IMAGE="${2:-${BASEDIR}/artifacts/rg35xxsp/rgos-rg35xxsp.img.gz}"

TEST_TARGET="${RGOS_FLASH_TEST_TARGET:-}"

if [[ -n "${TEST_TARGET}" ]]; then
    DISK="${DISK:-test}"
    size="test file"
    target="${TEST_TARGET}"
elif [[ "$(uname)" == "Darwin" ]]; then
    if [[ -z "${DISK}" ]]; then
        diskutil list external physical
        exit 0
    fi
    DISK="${DISK#/dev/}"
    info="$(diskutil info "/dev/${DISK}")" || { log_err "No such disk: ${DISK}"; exit 1; }
    grep -Eq 'Device Location: +External|Removable Media: +Removable' <<<"${info}" \
        || { log_err "/dev/${DISK} is not an external/removable disk; refusing"; exit 1; }
    grep -Eq 'Whole: +Yes' <<<"${info}" || { log_err "Use the whole disk (e.g. disk4, not disk4s1)"; exit 1; }
    size="$(sed -n 's/^ *Disk Size: *//p' <<<"${info}")"
    target="/dev/r${DISK}"
else
    if [[ -z "${DISK}" ]]; then
        lsblk -d -o NAME,SIZE,MODEL,TRAN,RM
        exit 0
    fi
    DISK="${DISK#/dev/}"
    [[ "$(cat "/sys/block/${DISK}/removable" 2>/dev/null)" == 1 ]] \
        || [[ "$(lsblk -dn -o TRAN "/dev/${DISK}")" =~ ^(usb|mmc)$ ]] \
        || { log_err "/dev/${DISK} is not removable/USB/MMC; refusing"; exit 1; }
    size="$(lsblk -dn -o SIZE "/dev/${DISK}")"
    target="/dev/${DISK}"
fi

[[ -f "${IMAGE}" ]] || { log_err "Image not found: ${IMAGE} (run bin/buildbox.sh build first)"; exit 1; }

# Uncompressed size, needed to read back exactly the written bytes
case "${IMAGE}" in
    *.gz) bytes="$(gzip -l "${IMAGE}" | awk 'NR == 2 { print $2 }')"; cat_img="gzip -dc" ;;
    *)    bytes="$(wc -c <"${IMAGE}" | tr -d ' ')"; cat_img="cat" ;;
esac

log "Image:  ${IMAGE} ($(( bytes / 1048576 )) MiB)"
log "Target: ${target} (${size}) — ALL DATA ON IT WILL BE ERASED"
if [[ -n "${CONFIRM}" ]]; then
    answer="${CONFIRM}"
else
    read -r -p "Type '${DISK}' to continue: " answer
fi
[[ "${answer}" == "${DISK}" ]] || { log_err "Aborted"; exit 1; }

if [[ -z "${TEST_TARGET}" ]]; then
    if [[ "$(uname)" == "Darwin" ]]; then
        # Finder/loginwindow sometimes refuse a normal unmount; the card is
        # about to be overwritten, so force it
        diskutil unmountDisk "/dev/${DISK}" || diskutil unmountDisk force "/dev/${DISK}"
    else
        for part in $(lsblk -ln -o NAME "/dev/${DISK}" | tail -n +2); do
            sudo umount "/dev/${part}" 2>/dev/null || true
        done
    fi
fi

# The standard recipe: decompress straight into dd, large blocks, progress.
# macOS: raw device (/dev/rdiskN), /bin/dd (bytes, as BSD dd has no "M").
# Linux: GNU dd needs iflag=fullblock to get full blocks from a pipe.
img="${IMAGE//\'/\'\\\'\'}"
# Prefer GNU dd (coreutils; on macOS: brew install coreutils -> gdd). It's
# called by absolute path because sudo resets PATH to the system /bin/dd.
dd_bin=""
for c in gdd dd; do
    p="$(command -v "${c}" 2>/dev/null)" || continue
    if "${p}" --version 2>/dev/null | grep -q GNU; then dd_bin="${p}"; break; fi
done
if [[ -n "${dd_bin}" ]]; then
    dd_write="'${dd_bin}' of='${target}' bs=8M iflag=fullblock conv=fsync status=progress"
    dd_read="'${dd_bin}' if='${target}' bs=8M"
else
    # BSD dd (macOS /bin/dd): sizes in bytes, no iflag=fullblock
    dd_write="/bin/dd of='${target}' bs=8388608 status=progress"
    dd_read="/bin/dd if='${target}' bs=8388608"
fi
log "Using ${dd_bin:-/bin/dd (BSD; install GNU coreutils for gdd)}"
write_cmd="${cat_img} '${img}' | ${dd_write} && sync"
# Optional verify: SHA-256 of the card's first <image size> bytes against the
# image's (byte-wise cmp is ~35 MB/s on macOS; hashing runs at card speed)
if [[ "${VERIFY}" -eq 1 ]]; then
    if command -v sha256sum >/dev/null; then sha="sha256sum"; else sha="shasum -a 256"; fi
    write_cmd="${write_cmd} && echo '>>> Verifying (reading the card back):' >&2 && \
want=\$(${cat_img} '${img}' | ${sha} | cut -d' ' -f1) && \
got=\$(${dd_read} count=$(( (bytes + 8388607) / 8388608 )) status=progress | head -c ${bytes} | ${sha} | cut -d' ' -f1) && \
[ \"\${want}\" = \"\${got}\" ] && echo '>>> Verified: card matches the image' >&2"
fi

rc=0
if [[ -n "${TEST_TARGET}" ]]; then
    bash -c "${write_cmd}" || rc=$?
elif sudo -n true 2>/dev/null || [[ -t 0 || "$(uname)" != "Darwin" ]]; then
    sudo bash -c "${write_cmd}" || rc=$?
else
    # No terminal for a sudo prompt: use the macOS administrator dialog
    # (output only appears when it is done)
    osascript -e "do shell script \"/bin/bash -c \\\"${write_cmd//\"/\\\\\\\"}\\\"\" with administrator privileges" || rc=$?
fi

if [[ "${rc}" -ne 0 ]]; then
    log_err "Writing or verifying failed (exit ${rc}); the card is NOT usable."
    if [[ "$(uname)" == "Darwin" ]]; then
        log_err "If dd said 'Operation not permitted': macOS blocks raw disk access for"
        log_err "your terminal app. System Settings > Privacy & Security > Full Disk"
        log_err "Access > enable it, restart the terminal, and run this again."
    fi
    exit 1
fi

if [[ "${#PROVISION[@]}" -gt 0 ]]; then
    if [[ -n "${TEST_TARGET}" ]]; then
        "${BASEDIR}/bin/provision.sh" "${PROVISION[@]}" "${TEST_TARGET}"
    elif [[ "$(uname)" == "Darwin" ]]; then
        diskutil mountDisk "/dev/${DISK}" >/dev/null
        for _ in $(seq 1 20); do [[ -d /Volumes/RGOS-BOOT ]] && break; sleep 0.5; done
        "${BASEDIR}/bin/provision.sh" "${PROVISION[@]}" /Volumes/RGOS-BOOT
    else
        log_err "Mount the card's RGOS-BOOT partition and run: bin/provision.sh ${PROVISION[*]} <mountpoint>"
    fi
fi

if [[ -z "${TEST_TARGET}" && "$(uname)" == "Darwin" ]]; then
    diskutil eject "/dev/${DISK}" || true
fi
log "Done. Insert the card in the TF1 slot and power on."
