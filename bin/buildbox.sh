#!/usr/bin/env bash
# vi: ft=bash
# shellcheck shell=bash
#
# Buildbox: native arm64 Debian VM (lima, Apple Virtualization Framework)
# that runs the Buildroot build. Code is rsynced in, images are fetched out.
#
# Usage:
#   bin/buildbox.sh create             # create + provision the VM
#   bin/buildbox.sh start|stop         # start / stop the VM
#   bin/buildbox.sh sync               # rsync br2-external + bin/ to the VM
#   bin/buildbox.sh check [board]      # sync + configure + verify the defconfig
#   bin/buildbox.sh build [board]      # sync + full image build (default: rg35xxsp)
#   bin/buildbox.sh follow [board]     # re-attach to a running build's log
#   bin/buildbox.sh make [board] <tgt> # sync + run a buildroot make target, e.g. linux-rebuild
#   bin/buildbox.sh fetch [board]      # copy images to artifacts/<board>/
#   bin/buildbox.sh ssh [cmd]          # shell (or command) on the VM
#   bin/buildbox.sh destroy            # delete the VM
#
set -e -u -o pipefail

BASEDIR="$(cd "$(dirname "${0}")/.." && pwd)"

# shellcheck source=lib/common.sh
source "${BASEDIR}/bin/lib/common.sh"

VM_NAME="${BUILDBOX_VM_NAME:-rgbox}"
SSH_KEY="${BASEDIR}/.ssh/builder"
DEFAULT_BOARD="rg35xxsp"

# shellcheck source=lib/versions.sh
source "${BASEDIR}/bin/lib/versions.sh"

_host_cpus="$(sysctl -n hw.logicalcpu 2>/dev/null || echo 4)"
_host_mem_gib=$(( $(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1073741824 ))
_default_cpus=$(( _host_cpus - 2 ))
(( _default_cpus < 2 )) && _default_cpus=2
_default_mem_gib=$(( _host_mem_gib * 2 / 3 ))
(( _default_mem_gib < 4 )) && _default_mem_gib=4

VM_CPUS="${BUILDBOX_VM_CPUS:-${_default_cpus}}"
VM_MEMORY="${BUILDBOX_VM_MEMORY:-${_default_mem_gib}GiB}"
VM_DISK="${BUILDBOX_VM_DISK:-100GiB}"
unset _host_cpus _host_mem_gib _default_cpus _default_mem_gib

REMOTE_USER="builder"
REMOTE_HOME="/home/${REMOTE_USER}"
REMOTE_WORK="${REMOTE_HOME}/work"

SSH_OPTS=(-F /dev/null -i "${SSH_KEY}" -o IdentityAgent=none -o IdentitiesOnly=yes
          -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile="${BASEDIR}/.ssh/known_hosts"
          -o ConnectTimeout=10 -o BatchMode=yes -o ServerAliveInterval=30)
REMOTE_HOST="127.0.0.1"
SSH_PORT=""

################################################################################
# Helpers
################################################################################

function resolve_host() {
    SSH_PORT="$(limactl list --json 2>/dev/null | jq -r "select(.name == \"${VM_NAME}\") | .sshLocalPort")"
    if [[ -z "${SSH_PORT}" ]] || [[ "${SSH_PORT}" == "null" ]] || [[ "${SSH_PORT}" == "0" ]]; then
        log_err "Lima VM '${VM_NAME}' not found or not running. Run: ${0} create (or start)"
        return 1
    fi
}

# shellcheck disable=SC2029
function bb_ssh() {
    SSH_AUTH_SOCK=/dev/null ssh "${SSH_OPTS[@]}" -p "${SSH_PORT}" "${REMOTE_USER}@${REMOTE_HOST}" "${@}"
}

function bb_rsync() {
    local ssh_cmd
    ssh_cmd="ssh $(printf '%q ' "${SSH_OPTS[@]}") -p ${SSH_PORT}"
    SSH_AUTH_SOCK=/dev/null rsync -a -e "${ssh_cmd}" "${@}"
}

function wait_for_ssh() {
    local attempt
    log "Waiting for SSH on ${REMOTE_HOST}:${SSH_PORT}..."
    for attempt in $(seq 1 60); do
        bb_ssh true 2>/dev/null && return 0
        log_dim "attempt ${attempt}/60"
        sleep 5
    done
    log_err "SSH not available"
    return 1
}

################################################################################
# Commands
################################################################################

function cmd_create() {
    require_tools limactl jq rsync

    if limactl list --json 2>/dev/null | jq -e "select(.name == \"${VM_NAME}\")" >/dev/null; then
        log_err "Lima VM '${VM_NAME}' already exists. Run '${0} destroy' first."
        exit 1
    fi

    local pub_key tmpconfig
    pub_key="$(cat "${SSH_KEY}.pub")"
    tmpconfig="$(mktemp /tmp/rgbox-lima-XXXX).yaml"
    # shellcheck disable=SC2064
    trap "rm -f '${tmpconfig}'" RETURN

    cat >"${tmpconfig}" <<YAML
vmType: vz
arch: aarch64
images:
  - location: "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-arm64.qcow2"
    arch: aarch64
cpus: ${VM_CPUS}
memory: "${VM_MEMORY}"
disk: "${VM_DISK}"
mounts: []
ssh:
  loadDotSSHPubKeys: false
provision:
  - mode: system
    script: |
      #!/bin/bash
      set -eux
      id ${REMOTE_USER} &>/dev/null && exit 0
      useradd -m -s /bin/bash -c "Buildroot Builder" ${REMOTE_USER}
      echo "${REMOTE_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${REMOTE_USER}
      chmod 440 /etc/sudoers.d/${REMOTE_USER}
      install -d -m 700 -o ${REMOTE_USER} -g ${REMOTE_USER} ${REMOTE_HOME}/.ssh
      echo "${pub_key}" > ${REMOTE_HOME}/.ssh/authorized_keys
      chown ${REMOTE_USER}:${REMOTE_USER} ${REMOTE_HOME}/.ssh/authorized_keys
      chmod 600 ${REMOTE_HOME}/.ssh/authorized_keys
  - mode: system
    script: |
      #!/bin/bash
      set -eux
      export DEBIAN_FRONTEND=noninteractive
      apt-get update -qq
      apt-get install -y --no-install-recommends \
        bc bison build-essential bzip2 ca-certificates ccache cmake \
        coreutils cpio curl device-tree-compiler dosfstools e2fsprogs \
        fakeroot fdisk file flex g++ gawk gcc git grep gzip jq kmod less \
        libncurses-dev libssl-dev make mtools patch perl pigz pkg-config \
        procps python3 python3-setuptools python3-dev python3-pyelftools \
        rsync swig sudo unzip util-linux wget xz-utils zip zstd
YAML

    log "Creating lima VM '${VM_NAME}' (${VM_CPUS} CPUs, ${VM_MEMORY}, ${VM_DISK} disk)"
    limactl start --name="${VM_NAME}" --tty=false "${tmpconfig}"

    resolve_host
    wait_for_ssh

    log "Cloning buildroot ${BUILDROOT_VERSION}"
    bb_ssh "test -f ~/buildroot/Makefile || git clone --branch ${BUILDROOT_VERSION} ${BUILDROOT_GIT} ~/buildroot"
    bb_ssh "mkdir -p ~/work ~/downloads ~/artifacts ~/.ccache && ccache --max-size=20G >/dev/null"

    log "Buildbox ready. Connect with: ${0} ssh"
}

function cmd_start() {
    limactl start "${VM_NAME}"
}

function cmd_stop() {
    limactl stop "${VM_NAME}"
}

function cmd_destroy() {
    limactl delete --force "${VM_NAME}"
}

function cmd_sync() {
    resolve_host
    log "Syncing to ${VM_NAME}:${REMOTE_WORK}"
    bb_ssh "mkdir -p ${REMOTE_WORK}"
    bb_rsync --delete --exclude '.git' "${BASEDIR}/br2-external/" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_WORK}/br2-external/"
    bb_rsync --delete "${BASEDIR}/bin/" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_WORK}/bin/"
    bb_rsync --delete "${BASEDIR}/buildroot-patches/" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_WORK}/buildroot-patches/"
    bb_rsync --delete --exclude '.git' --exclude 'target' --exclude 'build' \
        "${BASEDIR}/src/" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_WORK}/src/"
    bb_ssh "rm -f ${REMOTE_WORK}/authorized_keys"
    if [[ -f "${BASEDIR}/.config" ]]; then
        bb_rsync "${BASEDIR}/.config" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_WORK}/.config"
    else
        bb_ssh "rm -f ${REMOTE_WORK}/.config"
    fi
}

# The build runs detached on the VM; we only follow its log. If the SSH
# session drops, re-attach with: bin/buildbox.sh follow [board]
function cmd_build() {
    local board="${1:-${DEFAULT_BOARD}}"
    cmd_sync
    if [[ "$(bb_ssh "cat ~/build-${board}.status 2>/dev/null")" == "running" ]]; then
        log_err "A ${board} build is already running; attach with: ${0} follow ${board}"
        exit 1
    fi
    bb_ssh "echo running > ~/build-${board}.status; : > ~/build-${board}.log; nohup setsid bash ${REMOTE_WORK}/bin/build-image.sh ${board} >/dev/null 2>&1 </dev/null &"
    log "Building ${board} on ${VM_NAME} (log: ~/build-${board}.log on the VM)"
    cmd_follow "${board}"
}

function cmd_follow() {
    local board="${1:-${DEFAULT_BOARD}}" status start
    resolve_host
    start="$(date +%s)"
    bb_ssh "tail -n +1 -F ~/build-${board}.log 2>/dev/null & t=\$!; while [ \"\$(cat ~/build-${board}.status)\" = running ]; do sleep 5; done; sleep 1; kill \$t"
    status="$(bb_ssh "cat ~/build-${board}.status")"
    if [[ "${status}" != "0" ]]; then
        log_err "${board} build failed (exit ${status})"
        exit 1
    fi
    log "Build finished (followed for $(( ($(date +%s) - start) / 60 )) min)"
    cmd_fetch "${board}"
}

function cmd_check() {
    local board="${1:-${DEFAULT_BOARD}}"
    cmd_sync
    bb_ssh "bash ${REMOTE_WORK}/bin/build-image.sh --check ${board}"
}

function cmd_make() {
    local board="${DEFAULT_BOARD}"
    if [[ "${#}" -gt 1 ]]; then
        board="${1}"
        shift
    fi
    cmd_sync
    bb_ssh "bash ${REMOTE_WORK}/bin/build-image.sh --make ${board} ${*}"
}

function cmd_fetch() {
    local board="${1:-${DEFAULT_BOARD}}"
    resolve_host
    mkdir -p "${BASEDIR}/artifacts/${board}"
    log "Fetching artifacts to artifacts/${board}/"
    bb_rsync --delete "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_HOME}/artifacts/${board}/" "${BASEDIR}/artifacts/${board}/"
    ls -lh "${BASEDIR}/artifacts/${board}/"
}

function cmd_ssh() {
    resolve_host
    if [[ "${#}" -gt 0 ]]; then
        bb_ssh "${@}"
    else
        SSH_AUTH_SOCK=/dev/null ssh "${SSH_OPTS[@]/BatchMode=yes/BatchMode=no}" -t -p "${SSH_PORT}" "${REMOTE_USER}@${REMOTE_HOST}"
    fi
}

################################################################################
# Main
################################################################################

cmd="${1:-build}"
[[ "${#}" -gt 0 ]] && shift

case "${cmd}" in
    create|start|stop|destroy|sync|check|build|follow|make|fetch|ssh) "cmd_${cmd}" "${@}" ;;
    *) sed -n '3,19p' "${0}"; exit 1 ;;
esac
