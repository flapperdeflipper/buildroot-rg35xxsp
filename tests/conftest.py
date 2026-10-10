"""
Pytest fixtures for RGOS integration tests (pytest-testinfra).

Usage:

  # Auto-start QEMU from artifacts/qemu-arm64/:
  pytest --board qemu-arm64

  # Against a real device (needs SSH provisioning on the card):
  pytest --host ssh://user@rgos.local

The same tests run against both; keep them environment-agnostic (skip
hardware-only checks when the feature is absent, e.g. no backlight in QEMU).
"""

import os
import signal
import subprocess
import time
from pathlib import Path

import pytest
import testinfra

REPO = Path(__file__).resolve().parent.parent
STATE = REPO / "tmp" / "qemu"


def pytest_addoption(parser):
    parser.addoption(
        "--host",
        metavar="SSH_URL",
        help="ssh://user@host[:port] — connect to an existing device",
    )
    parser.addoption(
        "--board",
        metavar="NAME",
        help="boot this board in QEMU first (qemu-arm64)",
    )
    parser.addoption(
        "--ssh-key",
        metavar="PATH",
        default=str(REPO / ".ssh" / "builder"),
        help="SSH identity (default: <repo>/.ssh/builder)",
    )


# ---------------------------------------------------------------------------
# QEMU lifecycle (session-scoped, only with --board)
# ---------------------------------------------------------------------------

@pytest.fixture(scope="session")
def _qemu(request):
    board = request.config.getoption("--board")
    if not board:
        yield None
        return
    if board != "qemu-arm64":
        pytest.exit(f"unknown board '{board}' (only qemu-arm64)", returncode=1)

    key = request.config.getoption("--ssh-key")
    # bin/run-qemu prepares a fresh disk, provisions the SSH key, starts
    # QEMU daemonized and writes tmp/qemu/qemu.pid
    subprocess.run(
        [str(REPO / "bin" / "run-qemu"), "--fresh", "--headless", "--key", f"{key}.pub"],
        check=True,
    )
    try:
        yield
    finally:
        pidfile = STATE / "qemu.pid"
        if pidfile.exists():
            try:
                os.kill(int(pidfile.read_text().strip()), signal.SIGTERM)
            except (ValueError, ProcessLookupError):
                pass
            pidfile.unlink(missing_ok=True)


# ---------------------------------------------------------------------------
# SSH host (session-scoped — one connection for all tests)
# ---------------------------------------------------------------------------

@pytest.fixture(scope="session")
def host(request, _qemu):
    direct = request.config.getoption("--host")
    if not direct and not request.config.getoption("--board"):
        pytest.exit("Pass --host <ssh-url> or --board qemu-arm64", returncode=1)

    key = request.config.getoption("--ssh-key")
    url = direct if direct and direct.startswith("ssh://") else f"ssh://{direct}"
    if not direct:
        url = "ssh://user@localhost:2222"

    opts = (
        f"-i {key} "
        "-o StrictHostKeyChecking=no "
        "-o UserKnownHostsFile=/dev/null "
        "-o IdentitiesOnly=yes "
        "-o IdentityAgent=none "
        "-o BatchMode=yes "
        "-o ConnectTimeout=10"
    )
    h = testinfra.get_host(url, ssh_extra_args=opts)

    # The forwarded port opens before sshd is ready; wait for it to accept
    # commands (also covers the QEMU boot, ~1 min).
    deadline = time.monotonic() + 240
    while time.monotonic() < deadline:
        try:
            if h.run("true").rc == 0:
                return h
        except Exception:
            pass
        time.sleep(3)
    raise TimeoutError(f"{url} not answering over SSH after 240 s")
