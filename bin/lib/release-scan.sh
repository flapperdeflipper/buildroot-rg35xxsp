#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash
#
# Release secret/content scan. Runs ON THE BUILD VM against a finished
# output directory: the target/ root (as it goes into the rootfs image)
# and the generated boot.vfat. Invoked by bin/release.sh; standalone:
#   release-scan.sh ~/output-rg35xxsp
#
# Fails (exit 1) when anything release-blocking is found: provisioning
# files, machine identity, state from a booted system, SSH/Wi-Fi
# credentials or private key material. INFO lines are for the release
# notes, not blockers.
set -u -o pipefail

OUT="${1:?usage: release-scan.sh <output-dir>}"
TARGET="${OUT}/target"
VFAT="${OUT}/images/boot.vfat"
MDIR="${OUT}/host/bin/mdir"

fail=0

ok()   { printf '  \033[32mPASS\033[0m %s\n' "$*"; }
bad()  { printf '  \033[31mFAIL\033[0m %s\n' "$*"; fail=1; }
info() { printf '  \033[2mINFO\033[0m %s\n' "$*"; }

[[ -d "${TARGET}" ]] || { echo "no target/ under ${OUT}" >&2; exit 2; }

# --- machine identity + state from a booted system -------------------------
[[ ! -s "${TARGET}/etc/machine-id" ]] \
    && ok "machine-id absent or empty" \
    || bad "/etc/machine-id has content (machine identity baked in)"
[[ ! -d "${TARGET}/var/log/journal" ]] \
    && ok "no persistent journal" \
    || bad "/var/log/journal present (journal from a booted system)"
for d in "${TARGET}"/var/lib/rgos; do
    [[ ! -d "${d}" || -z "$(ls -A "${d}" 2>/dev/null)" ]] \
        && ok "no first-boot state in ${d}" \
        || bad "${d} not empty (image was booted or stamped: $(ls -A "${d}" | tr '\n' ' '))"
done

# --- credentials -------------------------------------------------------------
for d in "${TARGET}/root/.ssh" "${TARGET}"/home/*/.ssh; do
    [[ -e "${d}" ]] && bad "${d} present" || true
done
[[ -z "$(ls -d "${TARGET}"/home/*/.ssh 2>/dev/null)" ]] && ok "no .ssh in any home"
if ls "${TARGET}"/etc/ssh/ssh_host_* >/dev/null 2>&1; then
    bad "/etc/ssh contains host keys (must be generated at first boot)"
else
    ok "no SSH host keys baked in"
fi
if [[ -d "${TARGET}/var/lib/iwd" ]] && ls "${TARGET}"/var/lib/iwd/* >/dev/null 2>&1; then
    bad "/var/lib/iwd has network profiles: $(ls "${TARGET}"/var/lib/iwd | tr '\n' ' ')"
else
    ok "no Wi-Fi networks (iwd) configured"
fi
if [[ -d "${TARGET}/var/lib/systemd/rfkill" ]] && ls "${TARGET}"/var/lib/systemd/rfkill/* >/dev/null 2>&1; then
    bad "/var/lib/systemd/rfkill has remembered radio state"
else
    ok "no remembered rfkill state"
fi

# --- passwords ---------------------------------------------------------------
while IFS=: read -r name _ pwfield _; do
    case "${name}" in
        ""|+) continue ;;
    esac
    if [[ "${pwfield}" == '!' || "${pwfield}" == '*' || -z "${pwfield}" ]]; then
        :
    else
        bad "account ${name} has a password hash set"
    fi
done <"${TARGET}/etc/shadow"
awk -F: '$1 == "root" && ($2 == "!" || $2 == "*") { found = 1 } END { exit !found }' \
    "${TARGET}/etc/shadow" \
    && ok "root is locked" || bad "root password is not locked"
awk -F: '$1 == "user" && $2 == "" { found = 1 } END { exit !found }' \
    "${TARGET}/etc/shadow" \
    && info "user has no password (by design: local login; sshd is key-only)"

# --- private key material anywhere in the root -------------------------------
hits="$(grep -r -l -E 'BEGIN (RSA |DSA |EC |OPENSSH )?PRIVATE KEY|BEGIN ENCRYPTED PRIVATE KEY' \
    "${TARGET}/etc" "${TARGET}/root" "${TARGET}/home" "${TARGET}/usr/local" \
    "${TARGET}/var" "${TARGET}/opt" 2>/dev/null || true)"
[[ -z "${hits}" ]] && ok "no private key material in the root" \
    || { bad "private key blocks in: ${hits}"; }

# --- boot partition ----------------------------------------------------------
if [[ -f "${VFAT}" && -x "${MDIR}" ]]; then
    # Drop mdir headers/summary (Volume label, Directory for, "N files"):
    # the volume label is RGOS-BOOT itself.
    listing="$("${MDIR}" -/ -i "${VFAT}" :: 2>/dev/null \
        | sed -e 's/^[[:space:]]*//' \
        | awk '/^(Volume in drive|Directory for)/ { next }
               /^[0-9]+ files?[[:space:]].*bytes/ { next }
               { print }')"
    # mdir prints name and extension as separate columns ("wifi     txt"),
    # so match forbidden base names as whole words, case-insensitive.
    boot_ok=1
    for forbidden in wifi wifi-imported authorized_keys rgos-boot; do
        if grep -iqw "${forbidden}" <<<"${listing}"; then
            bad "boot partition contains ${forbidden}*"; boot_ok=0
        fi
    done
    (( boot_ok )) && ok "boot partition has no provisioning or boot-log files"
    info "boot files: $(awk 'NF >= 4 && $1 !~ /^(Volume|Directory|[0-9]+)$/ { printf "%s ", $1 }' \
        <<<"${listing}")"
else
    bad "cannot read ${VFAT} with ${MDIR} (boot partition unscanned)"
fi

# --- release-notes facts -------------------------------------------------------
. "${TARGET}/etc/os-release" 2>/dev/null || true
info "image: ${PRETTY_NAME:-RGOS} ${VERSION_ID:-unknown} (rootfs $(du -sh "${TARGET}" 2>/dev/null | cut -f1))"

exit "${fail}"
