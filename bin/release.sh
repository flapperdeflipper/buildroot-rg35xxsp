#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash
#
# RGOS release tooling: verify a locally built image is clean, draft the
# release notes, and publish the artifacts to a GitHub release. Builds run
# locally (build VM) — never on GitHub Actions; the repo deliberately has
# no build workflow (runner credits).
#
# Usage:
#   bin/release.sh scan rg35xxsp             # secret/content scan + checksums
#   bin/release.sh notes 0.1.0               # draft docs/release-notes/v0.1.0.md
#   bin/release.sh publish 0.1.0 [--prerelease] [--yes] [--dry-run]
#
# publish gates on: green scan, existing notes, committed tree, gh auth.
# The git tag is created on the remote by gh (--target HEAD); nothing is
# pushed from the local repo by this script.
set -u -o pipefail

BASEDIR="$(cd "$(dirname "${0}")/.." && pwd)"
# shellcheck source=lib/common.sh
source "${BASEDIR}/bin/lib/common.sh"

BOARD="rg35xxsp"
NOTES_DIR="${BASEDIR}/docs/release-notes"
STATE_DIR="${BASEDIR}/tmp/release"

die() { log_err "$*"; exit 1; }
buildbox() { "${BASEDIR}/bin/buildbox.sh" "$@"; }

usage() { sed -n '6,15p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }

# ---------------------------------------------------------------- scan ----
do_scan() {
    log "Release scan: ${BOARD}"

    local status
    status="$(buildbox ssh "cat ~/build-${BOARD}.status 2>/dev/null" 2>/dev/null || true)"
    [[ "${status}" == "0" ]] \
        || die "last ${BOARD} build is not green (status '${status:-none}') — rebuild first"

    log "Syncing the tree (the scanner runs from the work copy)"
    buildbox sync "${BOARD}" >/dev/null || die "sync failed"

    log "Secret/content scan (on the build VM, against the built target)"
    buildbox ssh "~/work/${BOARD}/bin/lib/release-scan.sh ~/output-${BOARD}" \
        || die "scan FAILED — see the FAIL lines above"

    log "Artifacts"
    mkdir -p "${STATE_DIR}"
    local sums="${STATE_DIR}/${BOARD}-SHA256SUMS.txt" f
    : >"${sums}"
    for f in "${BASEDIR}/artifacts/${BOARD}"/rgos-"${BOARD}"*; do
        [[ -f "${f}" ]] || continue
        case "${f}" in
            *.img.gz|*.sbom.cdx.json) ;;
            *) continue ;;
        esac
        printf '%s  %s\n' "$(shasum -a 256 "${f}" | cut -d' ' -f1)" "$(basename "${f}")" | tee -a "${sums}"
        log_dim "$(basename "${f}"): $(du -h "${f}" | cut -f1)"
    done
    [[ -s "${sums}" ]] || die "no artifacts found for ${BOARD}"
    log "checksums in ${sums}"
    log "scan OK"
}

# ---------------------------------------------------------------- notes ----
do_notes() {
    local version="${1:?usage: bin/release.sh notes <version>}"
    local out="${NOTES_DIR}/v${version}.md"
    [[ -e "${out}" ]] && die "${out} already exists (won't clobber a draft)"
    mkdir -p "${NOTES_DIR}" "${STATE_DIR}"

    [[ -f "${STATE_DIR}/${BOARD}-SHA256SUMS.txt" ]] \
        || die "no scan for ${BOARD} yet — run: bin/release.sh scan ${BOARD}"

    local sums="" date
    date="$(date +%Y-%m-%d)"
    while IFS= read -r line; do sums+="    ${line}"$'\n'; done \
        <"${STATE_DIR}/${BOARD}-SHA256SUMS.txt"

    awk -v version="v${version}" -v date="${date}" -v repl="${sums}" '
        { gsub(/@VERSION@/, version); gsub(/@DATE@/, date) }
        /@CHECKSUMS@/ { printf "%s", repl; next }
        { print }
    ' "${NOTES_DIR}/template.md" >"${out}"

    log "drafted ${out} — edit the prose, then: bin/release.sh publish ${version}"
}

# ---------------------------------------------------------------- publish ----
do_publish() {
    local version="${1:?usage: bin/release.sh publish <version> [flags]}"
    shift
    local prerelease=0 yes=0 dry=0 a
    for a in "$@"; do
        case "${a}" in
            --prerelease) prerelease=1 ;;
            --yes) yes=1 ;;
            --dry-run) dry=1 ;;
            *) die "unknown flag ${a}" ;;
        esac
    done
    local tag="v${version}"
    local notes="${NOTES_DIR}/v${version}.md"
    [[ -f "${notes}" ]] || die "no notes: ${notes} (run: bin/release.sh notes ${version})"

    local dirty
    dirty="$(git -C "${BASEDIR}" status --porcelain --untracked-files=no)"
    [[ -z "${dirty}" ]] || die "tree has uncommitted changes — commit first (a release is a git state)"

    do_scan

    require_tools gh || die
    gh auth status >/dev/null 2>&1 \
        || die "gh is not authenticated (gh auth login; a stale GITHUB_TOKEN env can also interfere)"

    local assets=() f target
    for f in "${BASEDIR}/artifacts/${BOARD}"/rgos-"${BOARD}"*.img.gz \
             "${BASEDIR}/artifacts/${BOARD}"/rgos-"${BOARD}".sbom.cdx.json \
             "${STATE_DIR}/${BOARD}-SHA256SUMS.txt"; do
        [[ -f "${f}" ]] && assets+=("${f}")
    done

    local flags=(--title "RGOS ${tag}" --notes-file "${notes}")
    (( prerelease )) && flags+=(--prerelease)
    target="$(git -C "${BASEDIR}" rev-parse HEAD)"

    log "Release ${tag} at ${target:0:12}"
    for f in "${assets[@]}"; do log_dim "  asset: $(basename "${f}")"; done
    if (( dry )); then
        log "dry run — would run: gh release create ${tag} <assets> --target ${target} ${flags[*]}"
        exit 0
    fi
    if (( ! yes )); then
        printf 'publish? [y/N] ' >&2
        local reply
        read -r reply
        [[ "${reply}" == y ]] || die "aborted"
    fi
    gh release create "${tag}" "${assets[@]}" "${flags[@]}" --target "${target}" \
        || die "gh release create failed"
    log "published: $(gh release view "${tag}" --json url --jq .url 2>/dev/null || echo "see the repo's releases page")"
}

cmd="${1:-}"
case "${cmd}" in
    scan)    [[ -n "${2:-}" ]] && BOARD="$2"; do_scan ;;
    notes)   shift; do_notes "$@" ;;
    publish) shift; do_publish "$@" ;;
    *)       usage ;;
esac
