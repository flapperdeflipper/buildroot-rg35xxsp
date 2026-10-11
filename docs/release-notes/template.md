# RGOS @VERSION@

@DATE@ · [installation](../README.md#install) · [what this is](../README.md)

One paragraph: what this release is and who it is for. Name the device
(Anbernic RG35XX SP family), say that it is an independent Linux OS
(Buildroot, systemd, a labwc desktop driven from the buttons), and state
the maturity honestly.

## Highlights

- Feature bullets. Keep them user-visible: what works, not how it works.

## Devices and image variants

| Image | Units |
|---|---|
| `rgos-rg35xxsp.img.gz` | RG35XX SP with LPDDR4 RAM (most units) |
| `rgos-rg35xxsp-lpddr3.img.gz` | RG35XX SP with LPDDR3 RAM |

Boot menu entries for the RG35XX 2024, Plus and H are included but
untested on that hardware. If the screen stays black on an SP, switch to
the `rgos-v1` boot entry (original panel revision).

## Install

1. Flash the `.img.gz` to a 16 GB or larger SD card with balenaEtcher,
   Raspberry Pi Imager, or
   `zcat rgos-rg35xxsp.img.gz | sudo dd of=/dev/rdiskN bs=1m`.
2. Optional, for SSH access: put your Wi-Fi credentials and an SSH key on
   the RGOS-BOOT partition (`wifi.txt`, `authorized_keys/`). See the
   provisioning section of the README. Without them the device boots with
   radios off and no remote access.
3. The first boot grows the data partition to fill the card. Expect it to
   take a little longer.

## Known issues

- An honest list, or point to the issue tracker.

## Checksums

@CHECKSUMS@

---

RGOS is AGPL-3.0. The image contains free software components under
their own licenses; the SBOM asset in this release has the full
inventory. Kernel patches and device trees originate from the ROCKNIX
project and its contributors, and the deep-sleep support from kailashrs'
H700 suspend stub. See the credits in the README.
