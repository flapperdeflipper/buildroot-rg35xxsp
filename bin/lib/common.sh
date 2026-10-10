#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash
#
# Shared functions for build scripts. Source this file, do not execute it.
#

if [[ -z "${_COMMON_SH_LOADED:-}" ]]; then
    readonly _COMMON_SH_LOADED=1
else
    return 0
fi

function log() {
    printf '\e[1;32m>>>\e[0m %s\n' "${*}"
}

function log_err() {
    printf '\e[1;31m!!!\e[0m %s\n' "${*}" >&2
}

function log_dim() {
    printf '\e[0;90m    %s\e[0m\n' "${*}"
}

function require_tools() {
    local missing=0 tool

    for tool in "${@}"; do
        if ! command -v "${tool}" &>/dev/null; then
            log_err "Required tool not found: ${tool}"
            missing=$((missing + 1))
        fi
    done

    if [[ "${missing}" -gt 0 ]]; then
        log_err "Install the ${missing} missing tool(s) above, then re-run."
        return 1
    fi
}
