# shellcheck shell=bash
# QEMU instances, so several people/agents can run VMs at once.
# RGOS_QEMU_INSTANCE=N (default 0): state in tmp/qemu (N=0) or tmp/qemu-N,
# SSH on 127.0.0.1 port 2222+N. bin/qemu-pad, qemu-screenshot and
# qemu-sdcard read the same variable. bin/test-qemu picks a free N >= 1.
QEMU_INSTANCE="${RGOS_QEMU_INSTANCE:-0}"
[[ "${QEMU_INSTANCE}" =~ ^[0-9]+$ ]] || { echo "RGOS_QEMU_INSTANCE must be a number" >&2; exit 2; }
if [[ "${QEMU_INSTANCE}" -eq 0 ]]; then
    QEMU_STATE="${BASEDIR}/tmp/qemu"
else
    QEMU_STATE="${BASEDIR}/tmp/qemu-${QEMU_INSTANCE}"
fi
QEMU_SSH_PORT=$(( 2222 + QEMU_INSTANCE ))

# PID of this instance's running VM, if any
qemu_running_pid() {
    local pid
    pid="$(cat "${QEMU_STATE}/qemu.pid" 2>/dev/null)" || return 1
    [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null && ps -p "${pid}" -o command= | grep -q qemu-system \
        && echo "${pid}"
}

# Atomic claim of an instance (mkdir), released by qemu_release
qemu_claim() {
    mkdir -p "$(dirname "${QEMU_STATE}")"
    if mkdir "${QEMU_STATE}.lock" 2>/dev/null; then
        echo "$$" >"${QEMU_STATE}.lock/pid"
        return 0
    fi
    # Stale lock: its owner is gone
    local owner
    owner="$(cat "${QEMU_STATE}.lock/pid" 2>/dev/null)"
    if [[ -n "${owner}" ]] && ! kill -0 "${owner}" 2>/dev/null && [[ -z "$(qemu_running_pid)" ]]; then
        rm -rf "${QEMU_STATE}.lock"
        mkdir "${QEMU_STATE}.lock" 2>/dev/null && { echo "$$" >"${QEMU_STATE}.lock/pid"; return 0; }
    fi
    return 1
}

qemu_release() { rm -rf "${QEMU_STATE}.lock"; }
