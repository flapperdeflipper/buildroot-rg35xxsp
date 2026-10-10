#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash
#
# Build a board image. Runs on the buildbox VM (invoked by buildbox.sh).
#
# Usage:
#   build-image.sh <board>                  # configure + full build + copy artifacts
#   build-image.sh --check <board>          # configure + verify the defconfig only
#   build-image.sh --prune <board>          # delete object files of finished packages
#   build-image.sh --make <board> <target>  # run a buildroot make target (e.g. linux-rebuild)
#
# Layout on the VM:
#   ~/buildroot            buildroot source tree
#   ~/work                 synced br2-external/, bin/, src/, .config
#   ~/output-<board>       buildroot O= dir (kept between builds for incremental work)
#   ~/artifacts/<board>    final images
#
set -e -u -o pipefail

# shellcheck source=lib/common.sh
source "$(dirname "${0}")/lib/common.sh"
# shellcheck source=lib/versions.sh
source "$(dirname "${0}")/lib/versions.sh"

MAKE_ONLY=0
CHECK_ONLY=0
PRUNE_ONLY=0
case "${1:-}" in
    --make)  MAKE_ONLY=1; shift ;;
    --check) CHECK_ONLY=1; shift ;;
    --prune) PRUNE_ONLY=1; shift ;;
esac

BOARD="${1:-}"
[[ -n "${BOARD}" ]] || { log_err "Usage: build-image.sh [--make] <board> [targets]"; exit 1; }
shift

NPROC="$(nproc)"
BUILDROOT="${HOME}/buildroot"
WORK="${HOME}/work"
OUT="${HOME}/output-${BOARD}"
ARTIFACTS="${HOME}/artifacts/${BOARD}"

export BR2_DL_DIR="${HOME}/downloads"

BR_MAKE=(make -C "${BUILDROOT}" O="${OUT}" BR2_EXTERNAL="${WORK}/br2-external")

# A full build may be running (detached, see buildbox.sh). Checks, make
# targets and pruning must not reset the Buildroot tree or rewrite .config
# underneath it.
STATUS_FILE="${HOME}/build-${BOARD}.status"
if [[ "${MAKE_ONLY}${CHECK_ONLY}${PRUNE_ONLY}" != 000 ]] \
   && [[ "$(cat "${STATUS_FILE}" 2>/dev/null)" == running ]] \
   && pgrep -f "[b]uild-image.sh ${BOARD}\$" >/dev/null; then
    log_err "A ${BOARD} build is running; wait for it (bin/buildbox.sh follow ${BOARD})"
    exit 1
fi


# Pristine pinned Buildroot + our patches (buildroot-patches/*.patch), e.g.
# package bumps that can't be done from a BR2_EXTERNAL tree. Re-applied on
# every run, so the tree always matches the repo.
function prepare_buildroot() {
    local patch
    git -C "${BUILDROOT}" fetch -q --tags origin "refs/tags/${BUILDROOT_VERSION}" 2>/dev/null || true
    git -C "${BUILDROOT}" checkout -q -f "${BUILDROOT_VERSION}"
    git -C "${BUILDROOT}" clean -q -fd
    for patch in "${WORK}"/buildroot-patches/*.patch; do
        [[ -f "${patch}" ]] || continue
        git -C "${BUILDROOT}" apply "${patch}" || { log_err "Cannot apply ${patch##*/}"; exit 1; }
    done
}
prepare_buildroot

# Reclaim disk. Packages that are fully installed don't need their build
# tree again: the results live in per-package/. Two boards with LLVM, Clang,
# Mesa and the kernel otherwise fill a 100 GB disk. For installed packages
# over 200 MB only Buildroot's bookkeeping (stamps, file lists: the dot
# files) is kept, so they are not rebuilt; to rebuild one, use
# <pkg>-dirclean (<pkg>-rebuild won't work on a pruned tree). The kernel is
# kept whole: out-of-tree module packages build against it.
function prune_objects() {
    local dir before after
    before="$(du -sm "${OUT}/build" | cut -f1)"
    for dir in "${OUT}"/build/*/; do
        case "$(basename "${dir}")" in linux-*|uboot-*|rgos-uboot-*) continue ;; esac
        ls "${dir}".stamp_*installed >/dev/null 2>&1 || continue
        [[ "$(du -sm "${dir}" | cut -f1)" -gt 200 ]] || continue
        find "${dir}" -mindepth 1 -maxdepth 1 ! -name '.*' -exec rm -rf {} + 2>/dev/null || true
    done
    after="$(du -sm "${OUT}/build" | cut -f1)"
    log "Pruned finished build trees: build/ ${before} MB -> ${after} MB"
}

if [[ "${PRUNE_ONLY}" -eq 1 ]]; then
    prune_objects
    exit 0
fi

if [[ "${MAKE_ONLY}" -eq 1 ]]; then
    exec "${BR_MAKE[@]}" "${@}"
fi


COMMON_DEFCONFIG="${WORK}/br2-external/configs/rgos_common_defconfig"
BOARD_DEFCONFIG="${WORK}/br2-external/configs/rgos_${BOARD//-/_}_defconfig"
[[ -f "${BOARD_DEFCONFIG}" ]] || { log_err "No defconfig for board '${BOARD}': ${BOARD_DEFCONFIG}"; exit 1; }

mkdir -p "${OUT}" "${ARTIFACTS}" "${BR2_DL_DIR}"

# Common base + board fragment + optional local overrides (.config, not committed)
FRAGMENTS=("${COMMON_DEFCONFIG}" "${BOARD_DEFCONFIG}")
[[ -f "${WORK}/.config" ]] && FRAGMENTS+=("${WORK}/.config")

log "Merging config: ${FRAGMENTS[*]##*/}"
cat "${FRAGMENTS[@]}" >"${OUT}/rgos_merged_defconfig"
"${BR_MAKE[@]}" BR2_DEFCONFIG="${OUT}/rgos_merged_defconfig" defconfig

# Kconfig silently drops symbols that don't exist or whose dependencies are
# unmet. Fail loudly instead, so a typo never ships as a missing feature.
check_config() {
    local line sym val actual bad=0
    while IFS= read -r line; do
        if [[ "${line}" =~ ^(BR2_[A-Za-z0-9_]+)=(.*)$ ]]; then
            sym="${BASH_REMATCH[1]}" val="${BASH_REMATCH[2]}"
        elif [[ "${line}" =~ ^#\ (BR2_[A-Za-z0-9_]+)\ is\ not\ set$ ]]; then
            sym="${BASH_REMATCH[1]}" val=""
        else
            continue
        fi
        # Last assignment in the merged file wins; only check that one
        [[ "$(grep -E "^(# )?${sym}[= ]" "${OUT}/rgos_merged_defconfig" | tail -n1)" == "${line}" ]] || continue
        actual="$(grep -E "^${sym}=" "${OUT}/.config" | cut -d= -f2- || true)"
        [[ -z "${val}" && -z "${actual}" ]] && continue
        [[ -n "${val}" && "${actual}" == "${val}" ]] && continue
        log_err "config: ${sym} wanted '${val}', got '${actual:-<unset>}'"
        bad=1
    done <"${OUT}/rgos_merged_defconfig"
    # Legacy (renamed/removed) options only fail later, at build time
    if grep -q '^BR2_LEGACY=y' "${OUT}/.config"; then
        log_err "config: legacy options selected; see Config.in.legacy for:"
        grep -E '^BR2_.*=y' "${OUT}/.config" | cut -d= -f1 | while read -r sym; do
            grep -q "^config ${sym}\$" "${BUILDROOT}/Config.in.legacy" && log_err "  ${sym}"
        done
        bad=1
    fi
    return "${bad}"
}
check_config || { log_err "Config check failed (see above)"; exit 1; }
log "Config OK"
[[ "${CHECK_ONLY}" -eq 1 ]] && exit 0

# Full build from here on: log + status for buildbox.sh follow
LOG_FILE="${HOME}/build-${BOARD}.log"
STATUS_FILE="${HOME}/build-${BOARD}.status"
exec > >(tee "${LOG_FILE}") 2>&1
# buildbox.sh follows the log and reads the exit code from the status file,
# so a dropped SSH connection never kills or loses a build.
echo running >"${STATUS_FILE}"
trap 'echo $? >"${STATUS_FILE}"' EXIT

# Per-package directories: build several packages at once (top-level -j),
# each with half the cores, so big single packages still go fast
TOP_JOBS=$(( NPROC / 2 > 1 ? NPROC / 2 : 1 ))
log "Building ${BOARD}: ${TOP_JOBS} packages in parallel, ${NPROC} jobs each"
"${BR_MAKE[@]}" -j"${TOP_JOBS}" BR2_JLEVEL="${NPROC}"

prune_objects

log "Copying artifacts to ${ARTIFACTS}"
rm -rf "${ARTIFACTS:?}"/*
for img in "${OUT}"/images/rgos-*.img; do
    [[ -f "${img}" ]] || continue
    log_dim "compressing $(basename "${img}")"
    pigz -9 --force --keep --stdout "${img}" >"${ARTIFACTS}/$(basename "${img}").gz"
done
cp -v "${OUT}/images/Image" "${OUT}/images/cmdline.txt" "${OUT}"/images/*.dtb "${ARTIFACTS}/" 2>/dev/null || true

log "${BOARD} build complete"
