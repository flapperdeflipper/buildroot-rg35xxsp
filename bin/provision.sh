#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash
#
# Provision SSH keys and Wi-Fi on an RGOS card (or disk image). Writes
# authorized_keys and wifi.txt to the RGOS-BOOT partition; the device
# imports them at the next boot (see README.txt on that partition).
#
# Usage:
#   bin/provision.sh [--key <pubkey file>]... [--wifi <ssid> [--country CC]] [target]
#
#   --key FILE    add an SSH public key (repeatable), e.g. ~/.ssh/id_ed25519.pub
#   --wifi SSID   add a Wi-Fi network; the password is prompted (hidden).
#                 Empty password = open network. Scripts: RGOS_WIFI_PASSWORD.
#   --country CC  Wi-Fi country code, e.g. NL
#   target        mounted RGOS-BOOT directory, or a disk image file
#                 (default: the RGOS-BOOT volume that is mounted)
#
set -e -u -o pipefail

BASEDIR="$(cd "$(dirname "${0}")/.." && pwd)"
# shellcheck source=lib/common.sh
source "${BASEDIR}/bin/lib/common.sh"

KEYS=() SSID="" COUNTRY="" TARGET=""
while [[ "${#}" -gt 0 ]]; do
    case "${1}" in
        --key)     KEYS+=("${2:?--key needs a file}"); shift 2 ;;
        --wifi)    SSID="${2:?--wifi needs an SSID}"; shift 2 ;;
        --country) COUNTRY="${2:?--country needs a code}"; shift 2 ;;
        -h|--help) sed -n '5,19p' "${0}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)         TARGET="${1}"; shift ;;
    esac
done
[[ "${#KEYS[@]}" -gt 0 || -n "${SSID}" ]] || { sed -n '5,19p' "${0}" | sed 's/^# \{0,1\}//'; exit 2; }

if [[ -z "${TARGET}" ]]; then
    if [[ -d /Volumes/RGOS-BOOT ]]; then
        TARGET=/Volumes/RGOS-BOOT
    else
        TARGET="$(lsblk -nro LABEL,MOUNTPOINT 2>/dev/null | awk '$1 == "RGOS-BOOT" && $2 { print $2; exit }')"
    fi
    [[ -n "${TARGET}" ]] || { log_err "No mounted RGOS-BOOT partition found; insert the card or pass a target"; exit 1; }
fi

# Collect the files in a private temp dir first
work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

for key in "${KEYS[@]}"; do
    [[ -f "${key}" ]] || { log_err "No such key file: ${key}"; exit 1; }
    grep -Eq '^(ssh-|ecdsa-|sk-)' "${key}" || { log_err "${key} doesn't look like an SSH public key"; exit 1; }
    [[ "${key}" == *.pub ]] || { log_err "${key}: use the PUBLIC key (.pub)"; exit 1; }
    # one key per line, even if the file lacks a trailing newline
    grep -E '^(ssh-|ecdsa-|sk-)' "${key}" >>"${work}/authorized_keys"
done

if [[ -n "${SSID}" ]]; then
    if [[ -n "${RGOS_WIFI_PASSWORD+set}" ]]; then
        password="${RGOS_WIFI_PASSWORD}"
    else
        read -r -s -p "Wi-Fi password for '${SSID}' (empty = open network): " password
        echo
    fi
    {
        [[ -n "${COUNTRY}" ]] && echo "country=${COUNTRY}"
        echo "ssid=${SSID}"
        [[ -n "${password}" ]] && echo "password=${password}"
    } >"${work}/wifi.txt"
fi

if [[ -d "${TARGET}" ]]; then
    # Mounted partition: append keys/networks to what's already there
    if [[ -f "${work}/authorized_keys" ]]; then
        # don't glue onto an existing last line without a newline
        if [[ -s "${TARGET}/authorized_keys" && -n "$(tail -c1 "${TARGET}/authorized_keys")" ]]; then
            echo >>"${TARGET}/authorized_keys"
        fi
        cat "${work}/authorized_keys" >>"${TARGET}/authorized_keys"
        log "SSH key(s) added to ${TARGET}/authorized_keys"
    fi
    if [[ -f "${work}/wifi.txt" ]]; then
        if [[ -f "${TARGET}/wifi.txt" ]]; then
            { echo; cat "${work}/wifi.txt"; } >>"${TARGET}/wifi.txt"
        else
            cp "${work}/wifi.txt" "${TARGET}/wifi.txt"
        fi
        log "Wi-Fi network '${SSID}' added to ${TARGET}/wifi.txt"
    fi
    sync
elif [[ -f "${TARGET}" ]]; then
    # Disk image: boot partition = first MBR entry; write with mtools
    require_tools mcopy od
    start="$(od -An -tu4 -j 454 -N 4 "${TARGET}" | tr -d ' ')"
    for f in authorized_keys wifi.txt; do
        [[ -f "${work}/${f}" ]] || continue
        MTOOLS_SKIP_CHECK=1 mcopy -o -i "${TARGET}@@$(( start * 512 ))" "${work}/${f}" "::${f}"
        log "${f} written to the boot partition of ${TARGET}"
    done
else
    log_err "Target not found: ${TARGET}"
    exit 1
fi
log "Done. The device imports this at its next boot (wifi.txt is then removed)."
