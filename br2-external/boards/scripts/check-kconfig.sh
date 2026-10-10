#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash
#
# Verify that every option from kernel config fragments made it into the
# final .config. Kconfig silently drops options whose dependencies are unmet
# or that no longer exist (e.g. zram compressors became separate
# CONFIG_ZRAM_BACKEND_* options), so a fragment typo otherwise ships as a
# missing feature.
#
# Usage: check-kconfig.sh <.config> <fragment>...
#
# "=m" is satisfied by "=y" (something selected it built-in); an
# "is not set" line is satisfied by the option being absent.
#
set -u -o pipefail

config="${1}"
shift

declare -A want
for frag in "${@}"; do
    while IFS= read -r line; do
        if [[ "${line}" =~ ^(CONFIG_[A-Za-z0-9_]+)=(.*)$ ]]; then
            want["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
        elif [[ "${line}" =~ ^#\ (CONFIG_[A-Za-z0-9_]+)\ is\ not\ set$ ]]; then
            want["${BASH_REMATCH[1]}"]="n"
        fi
    done <"${frag}"
done

bad=0
for sym in "${!want[@]}"; do
    val="${want[${sym}]}"
    got="$(grep -E "^${sym}=" "${config}" | cut -d= -f2-)"
    case "${val}" in
        n) [[ -z "${got}" ]] && continue ;;
        m) [[ "${got}" == m || "${got}" == y ]] && continue ;;
        *) [[ "${got}" == "${val}" ]] && continue ;;
    esac
    printf 'check-kconfig: %s wanted %s, got %s\n' "${sym}" "${val}" "${got:-<unset>}" >&2
    bad=1
done

if [[ "${bad}" -ne 0 ]]; then
    printf 'check-kconfig: kernel config fragments not applied (see above)\n' >&2
    exit 1
fi
