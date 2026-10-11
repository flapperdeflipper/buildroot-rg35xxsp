"""Power/perf checks, ported from bin/test-qemu's Power and System sections:
sysctl tuning, zram (lzo-rle + zstd idle recompression), MGLRU, the sleep
hook, battery guard, rgos-power itself. Environment-agnostic; suspend/resume
execution (RTC wake) stays in bin/test-qemu — it needs orchestration."""

import re


def test_sysctl_pack(host):
    assert host.run("sysctl -n kernel.panic").stdout.strip() == "20"
    assert host.run("sysctl -n vm.dirty_writeback_centisecs").stdout.strip() == "1500"
    assert host.run("sysctl -n fs.inotify.max_user_instances").stdout.strip() == "1024"
    assert host.run("sysctl -n fs.inotify.max_user_watches").stdout.strip() == "524288"


def test_mglru_enabled_at_runtime(host):
    out = host.run("cat /sys/kernel/mm/lru_gen/enabled").stdout.strip()
    assert out and out != "0x0000", out


def test_zram_lzo_rle_with_zstd_recompression(host):
    assert host.run("swapon --show=NAME --noheadings | grep -q zram0").rc == 0
    assert "[lzo-rle]" in host.run("cat /sys/block/zram0/comp_algorithm").stdout
    assert "zstd" in host.run("cat /sys/block/zram0/recomp_algorithm").stdout
    assert host.run("systemctl is-enabled rgos-zram-recompress.timer").rc == 0


def test_sleep_hook_installed(host):
    assert host.run("test -x /usr/lib/systemd/system-sleep/rgos-power.sh").rc == 0


def test_ac_profile_noop_without_config(host):
    # profile_ac is unset by default: the udev entry point must exit cleanly
    assert host.run("/usr/libexec/rgos/ac-profile").rc == 0


def test_battery_guard_running(host):
    assert host.run("systemctl is-active rgos-battery-guard.service").rc == 0


def test_rgos_power_status_and_panel(host):
    out = host.run("rgos-power status").stdout
    assert re.search(r"^profile\s+\w+$", out, re.M), out
    assert host.run("rgos-power panel").rc == 0


def test_power_conf_documents_system_keys(host):
    # keys the root-side sleep hook reads must ship in the default config
    conf = host.file("/etc/rgos/power.conf").content_string
    for key in ("suspend_mode", "suspend_mute_dac", "suspend_led_off",
                "suspend_poweroff_min", "cpu_turbo", "gpu_max_mhz", "profile_ac"):
        assert re.search(rf"^{key}=", conf, re.M), key
