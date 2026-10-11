"""Core system checks, ported from bin/test-qemu: identity, provisioning,
session processes, key-only SSH, oskd. Environment-agnostic (QEMU + device)."""

import time

import pytest


def test_os_release(host):
    content = host.file("/etc/os-release").content_string
    assert 'NAME="RGOS"' in content
    assert "ID=rgos" in content


def test_no_failed_units(host):
    out = host.run("systemctl --failed --plain --no-legend").stdout.strip()
    assert out == "", f"failed units:\n{out}"


def test_desktop_session_active(host):
    assert host.run("systemctl is-active rgos-session.service").rc == 0


def test_session_processes(host):
    for proc in ("labwc", "sfwbar", "swaybg", "wvkbd-mobintl", "rgos-padd", "rgos-oskd"):
        assert host.run(f"pgrep -x {proc}").rc == 0, f"{proc} not running"


def test_padd_starts_in_mouse_mode(host):
    mode = host.file("/run/user/1000/rgos-padd.mode")
    assert mode.exists
    assert mode.content_string == "mouse"  # no trailing newline (panel label)


def test_padd_control_fifo(host):
    assert host.run("test -p /run/user/1000/rgos-padd.ctl").rc == 0


def test_osk_fifo_commands(host):
    assert host.run(
        "export XDG_RUNTIME_DIR=/run/user/1000;"
        "export WAYLAND_DISPLAY=$(basename $(ls /run/user/1000/wayland-[0-9] | head -1));"
        "rgos-padctl osk on && test \"$(cat /run/user/1000/rgos-padd.mode)\" = osk"
    ).rc == 0
    assert host.run(
        "export XDG_RUNTIME_DIR=/run/user/1000;"
        "rgos-padctl osk off && test \"$(cat /run/user/1000/rgos-padd.mode)\" = mouse"
    ).rc == 0


def test_sshd_key_only(host):
    conf = host.run("sudo sshd -T").stdout.lower()
    for line in (
        "passwordauthentication no",
        "kbdinteractiveauthentication no",
        "permitemptypasswords no",
        "authenticationmethods publickey",
    ):
        assert line in conf, f"sshd -T missing: {line}"


def test_user_has_no_password(host):
    shadow = host.run("sudo awk -F: '$1==\"user\" {print $2}' /etc/shadow").stdout
    assert shadow.strip() == ""


def test_sudo_without_password(host):
    assert host.run("sudo -n true").rc == 0


def test_ssh_key_imported(host):
    keys = host.file("/etc/ssh/authorized_keys/user")
    assert keys.exists
    # one line per provisioned key (flash.sh accepts several --key)
    assert len(keys.content_string.strip().splitlines()) >= 1


def test_boot_partition_readme(host):
    assert host.file("/boot/README.txt").exists


def test_boot_log_written(host):
    """rgos-bootlog.service writes ~30 s after boot; allow for slow boots."""
    deadline = time.monotonic() + 120
    while time.monotonic() < deadline:
        r = host.run("test -s /boot/rgos-boot.log")
        if r.rc == 0:
            return
        time.sleep(5)
    pytest.fail("/boot/rgos-boot.log missing or empty")


def test_zram_swap_active(host):
    out = host.run("swapon --show --noheadings").stdout.strip()
    assert out != ""


def test_backlight_present(host):
    """Real device only (QEMU has no backlight device)."""
    out = host.run("ls /sys/class/backlight").stdout.strip()
    if not out:
        pytest.skip("no backlight device (QEMU)")
    assert host.run("test -r /sys/class/backlight/$(ls /sys/class/backlight | head -1)/brightness").rc == 0
