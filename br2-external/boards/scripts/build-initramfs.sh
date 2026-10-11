#!/bin/bash
# Build the RGOS initramfs cpio: busybox (+ its shared libs) and our init
# script (boards/common/initramfs/init) mount the erofs root, overlay and
# /data before systemd starts.
#
#   build-initramfs.sh <root-dir> <output.cpio.gz> <host-dir>
#
# <root-dir> must contain bin/busybox and its libs (a Buildroot target dir,
# either the global one or a per-package busybox dir). <host-dir> provides
# the cross readelf (omit to skip the shared-lib copy).
set -e -u -o pipefail

ROOT="${1:?root dir with bin/busybox}"
OUT="${2:?output file}"
HOST="${3:-}"

bb="${ROOT}/bin/busybox"
[[ -x "${bb}" ]] || { echo "build-initramfs: no ${bb}" >&2; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT
mkdir -p "${tmp}"/{bin,sbin,etc,proc,sys,dev,mnt,newroot,data,tmp,overlay}

cp "${bb}" "${tmp}/bin/busybox"
chmod 0755 "${tmp}/bin/busybox"
for cmd in sh mount umount mkdir rm cp chmod switch_root cat echo sleep; do
    ln -s busybox "${tmp}/bin/${cmd}"
done

script_dir="$(cd "$(dirname "${0}")" && pwd)"
cp "${script_dir}/../common/initramfs/init" "${tmp}/init"
chmod 0755 "${tmp}/init"

# Shared libraries busybox needs (glibc builds are dynamic)
readelf=""
if [[ -n "${HOST}" ]]; then
    for r in "${HOST}"/bin/*-readelf; do
        [[ -x "${r}" ]] && readelf="${r}" && break
    done
fi
if [[ -n "${readelf}" ]]; then
    mkdir -p "${tmp}/lib"
    for lib in $("${readelf}" -d "${bb}" |
                 sed -n 's/.*Shared library: \[\(.*\)\]/\1/p'); do
        # -L: SONAMEs are symlinks; copying the link alone leaves busybox
        # unloadable
        cp -L "${ROOT}/lib/${lib}" "${tmp}/lib/" 2>/dev/null || true
    done
    interp="$("${readelf}" -l "${bb}" |
              sed -n 's/.*Requesting program interpreter: \(.*\)\]/\1/p')"
    if [[ -n "${interp}" && -f "${ROOT}${interp}" ]]; then
        mkdir -p "${tmp}/$(dirname "${interp}")"
        cp -L "${ROOT}${interp}" "${tmp}${interp}"
    fi
    # This glibc searches /lib64 by default (the real root ships a
    # /lib64 -> /lib symlink; without it PID1 dies with exit 127)
    ln -sfn lib "${tmp}/lib64"
fi

# init needs stdio (the kernel opens /dev/console for PID1)
mknod -m 600 "${tmp}/dev/console" c 5 1 2>/dev/null || \
    echo "build-initramfs: warning: no /dev/console in the cpio" >&2

(cd "${tmp}" && find . | cpio -o -H newc 2>/dev/null | gzip -9 >"${OUT}")
echo "build-initramfs: $(basename "${OUT}") written ($(stat -c %s "${OUT}") bytes)"
