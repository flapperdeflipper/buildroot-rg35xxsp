# RGOS integration tests (pytest + testinfra)

Same suite, two targets:

```bash
cd tests
uv run pytest --board qemu-arm64   # boot the QEMU image and test it
uv run pytest --host ssh://user@rgos.local   # test a provisioned device
```

- QEMU mode reuses `bin/run-qemu --fresh --headless` (fresh disk, SSH key
  provisioned from `.ssh/builder.pub`).
- `--host` mode needs a card flashed with `bin/flash.sh --key ...` and
  network access to the device.
- `bin/test-qemu` remains the place for pad-driven UI checks (screenshots,
  simulated buttons); migrate checks here when they are SSH-shaped.

See docs/roadmap.md (Housekeeping) for the migration plan.
