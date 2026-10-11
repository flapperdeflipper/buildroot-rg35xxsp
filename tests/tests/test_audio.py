"""Audio checks, ported from bin/test-qemu's Audio section: PipeWire user
services, pulse compatibility socket, hardware volume keys (wpctl with the
amixer fallback). Environment-agnostic: QEMU has no sound card, so PipeWire
serves its auto_null sink there."""

import re

XDG = "export XDG_RUNTIME_DIR=/run/user/1000; "


def test_pipewire_user_service_active(host):
    assert host.run(f"{XDG}systemctl --user is-active pipewire").rc == 0


def test_wireplumber_user_service_active(host):
    assert host.run(f"{XDG}systemctl --user is-active wireplumber").rc == 0


def test_pulse_compat_socket(host):
    assert host.run(f"{XDG}test -S $XDG_RUNTIME_DIR/pulse/native").rc == 0


def test_volume_keys_via_pipewire(host):
    # up + get must round-trip a number through the default sink
    up = host.run(f"{XDG}rgos-volume up")
    assert up.rc == 0
    level = host.run(f"{XDG}rgos-volume get").stdout.strip()
    assert re.fullmatch(r"\d+", level), f"volume get: {level!r}"


def test_volume_mute_toggle(host):
    assert host.run(f"{XDG}rgos-volume mute").rc == 0
    out = host.run(f"{XDG}wpctl get-volume @DEFAULT_AUDIO_SINK@").stdout
    assert "MUTED" in out, out
    assert host.run(f"{XDG}rgos-volume mute").rc == 0  # back
