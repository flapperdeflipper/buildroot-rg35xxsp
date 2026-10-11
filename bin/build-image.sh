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
#   ~/buildroot            buildroot source tree (shared by all boards)
#   ~/work/<board>         synced br2-external/, bin/, src/, .config (per board,
#                          so syncing one board never changes another's build)
#   ~/output-<board>       buildroot O= dir (kept between builds for incremental work)
#   ~/artifacts/<board>    final images
#   ~/.locks/              board-<board>: one job per board (build/make/check/
#                          prune); buildroot: shared while building, exclusive
#                          while re-patching
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
WORK="$(cd "$(dirname "${0}")/.." && pwd)"
OUT="${HOME}/output-${BOARD}"
ARTIFACTS="${HOME}/artifacts/${BOARD}"

export BR2_DL_DIR="${HOME}/downloads"

BR_MAKE=(make -C "${BUILDROOT}" O="${OUT}" BR2_EXTERNAL="${WORK}/br2-external")

# One job per board at a time: a build, make, check or prune shares the
# output dir. The lock lives as long as this process (no stale state).
mkdir -p "${HOME}/.locks"
exec 8>"${HOME}/.locks/board-${BOARD}"
if ! flock -n 8; then
    log_err "${BOARD} is busy (build/make/check/prune running); follow it: bin/buildbox.sh follow ${BOARD}"
    exit 1
fi

# Full builds: log + status for buildbox.sh follow from the very start, so
# an early failure is reported instead of leaving "running" behind
FULL_BUILD=0
[[ "${MAKE_ONLY}${CHECK_ONLY}${PRUNE_ONLY}" == 000 ]] && FULL_BUILD=1
if [[ "${FULL_BUILD}" -eq 1 ]]; then
    LOG_FILE="${HOME}/build-${BOARD}.log"
    STATUS_FILE="${HOME}/build-${BOARD}.status"
    exec > >(tee "${LOG_FILE}") 2>&1
    echo running >"${STATUS_FILE}"
    trap 'echo $? >"${STATUS_FILE}"' EXIT
fi

# Local-source packages keep their .stamp_* across source changes, so a plain
# rebuild silently ships the old binary (bit us twice in one day). Hash each
# package's sources at sync time; when the hash changes, dirclean the package
# so the next build re-copies them (cheap: ccache keeps the compile cache).
function dirclean_changed_locals() {
    local pkg src stamp new build_dir
    mkdir -p "${OUT}"   # a clean build has no output dir yet
    for pkg in rgos-desktop rgos-power rgos-youtube rgos-sdcard rgos-web rgos-oskd rgos-padd rgos-padsim rgos-game; do
        if [[ -d "${WORK}/br2-external/package/${pkg}/files" ]]; then
            src="${WORK}/br2-external/package/${pkg}/files"
        else
            src="${WORK}/src/${pkg#rgos-}"
        fi
        [[ -d "${src}" ]] || continue
        stamp="${OUT}/.${pkg}.srchash"
        new="$(find "${src}" -type f -print0 | sort -z | xargs -0 md5sum | md5sum | cut -d' ' -f1)"
        [[ -f "${stamp}" && "$(cat "${stamp}")" == "${new}" ]] && continue
        printf '%s\n' "${new}" >"${stamp}"
        # Only dirclean what was actually built before (a pristine tree has
        # no build dirs, and <pkg>-dirclean needs a configured tree)
        for build_dir in "${OUT}"/build/${pkg}-*/; do
            [[ -d "${build_dir}" ]] || continue
            log "Sources of ${pkg} changed since the last build: ${pkg}-dirclean"
            "${BR_MAKE[@]}" "${pkg}-dirclean" >/dev/null
            break
        done
    done
}


# Pristine pinned Buildroot + our patches (buildroot-patches/*.patch), e.g.
# package bumps that can't be done from a BR2_EXTERNAL tree. The tree is
# shared by all boards: it is only reset and re-patched when the version or
# the patches changed (stamp), and only when no other board is building
# (exclusive lock); every job then holds a shared lock until it ends.
function prepare_buildroot() {
    local patch want stamp="${BUILDROOT}/.rgos-prepared"
    want="$( { echo "${BUILDROOT_VERSION}"; cat "${WORK}"/buildroot-patches/*.patch 2>/dev/null; } | md5sum | cut -d' ' -f1)"
    exec 9>"${HOME}/.locks/buildroot"
    if [[ "$(cat "${stamp}" 2>/dev/null)" != "${want}" ]]; then
        if ! flock -n -x 9; then
            log_err "Buildroot needs re-patching (version/patches changed), but another"
            log_err "board's job is using it; retry when that is done"
            exit 1
        fi
        log "Preparing Buildroot ${BUILDROOT_VERSION} + buildroot-patches/"
        git -C "${BUILDROOT}" fetch -q --tags origin "refs/tags/${BUILDROOT_VERSION}" 2>/dev/null || true
        git -C "${BUILDROOT}" checkout -q -f "${BUILDROOT_VERSION}"
        git -C "${BUILDROOT}" clean -q -fd
        for patch in "${WORK}"/buildroot-patches/*.patch; do
            [[ -f "${patch}" ]] || continue
            git -C "${BUILDROOT}" apply "${patch}" || { log_err "Cannot apply ${patch##*/}"; exit 1; }
        done
        echo "${want}" >"${stamp}"
    fi
    flock -s 9   # converts the exclusive lock, or waits for a re-patch to end
}
prepare_buildroot
dirclean_changed_locals

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

# Full build from here on (log + status were set up at the start;
# buildbox.sh follows the log and reads the exit code from the status file,
# so a dropped SSH connection never kills or loses a build)
# Per-package directories: build several packages at once (top-level -j),
# each with half the cores, so big single packages still go fast.
# RGOS_JOBS caps per-package parallelism when RAM is the limit, not cores
# (WebKit's unified TUs take 2-4 GB each; 8 in parallel OOMs a 16 GB VM).
JOBS="${RGOS_JOBS:-$NPROC}"
TOP_JOBS=$(( NPROC / JOBS > 1 ? NPROC / JOBS : 1 ))
log "Building ${BOARD}: ${TOP_JOBS} packages in parallel, ${JOBS} jobs each"
"${BR_MAKE[@]}" -j"${TOP_JOBS}" BR2_JLEVEL="${JOBS}"

# The H700 device kernel is dead without its out-of-tree panel driver
# (black screen). A partially-patched kernel once shipped silently, so
# assert the module is actually there. The module is panel-mipi.ko
# (CONFIG_DRM_PANEL_MIPI; "panel-mipi-dpi-spi" is its DT compatible).
if grep -q "^BR2_RGOS_LINUX_H700_PATCHES=y" "${OUT}/.config"; then
    if ! ls "${OUT}"/target/lib/modules/*/kernel/drivers/gpu/drm/panel/panel-mipi.ko >/dev/null 2>&1; then
        log_err "H700 patches enabled but panel-mipi.ko is missing from the kernel!"
        log_err "The ROCKNIX kernel patches did not apply (see 'Applying H700 patch' in the log above)."
        exit 1
    fi
    log "H700 panel driver present in the kernel (panel-mipi.ko)"
fi

prune_objects

log "Copying artifacts to ${ARTIFACTS}"
rm -rf "${ARTIFACTS:?}"/*
for img in "${OUT}"/images/rgos-*.img; do
    [[ -f "${img}" ]] || continue
    log_dim "compressing $(basename "${img}")"
    pigz -9 --force --keep --stdout "${img}" >"${ARTIFACTS}/$(basename "${img}").gz"
done
cp -v "${OUT}/images/Image" "${OUT}/images/cmdline.txt" "${OUT}/images/initramfs.cpio.gz" "${OUT}"/images/*.dtb "${ARTIFACTS}/" 2>/dev/null || true

# Software bill of materials (CycloneDX): every package, version, license
log "Writing the SBOM (CycloneDX)"
"${BR_MAKE[@]}" -s show-info \
    | python3 "${BUILDROOT}/utils/generate-cyclonedx" \
        --project-name "rgos-${BOARD}" --project-version "$(date +%Y%m%d-%H%M)" \
        -o "${ARTIFACTS}/rgos-${BOARD}.sbom.cdx.json" \
    || log_err "SBOM generation failed (image is fine)"

log "${BOARD} build complete"
