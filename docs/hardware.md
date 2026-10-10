# Anbernic RG35XX SP: hardware notes

| Part | What | Linux driver | Status in RGOS |
|---|---|---|---|
| SoC | Allwinner H700 (H616 family), 4x Cortex-A53 @1.5GHz | sun50i | mainline |
| GPU | Mali-G31 MP2 | panfrost (Mesa) | mainline, open |
| RAM | 1 GB LPDDR4 (some units LPDDR3) | U-Boot SPL `dram_sun50i_h616` | two SPL builds |
| Display engine | DE33 + TCON | sun4i-drm | mainline mixer + ROCKNIX DT/TCON patches |
| Panel | 3.5" 640x480 RGB, NV3052-class, SPI init (v1 and v2 revisions) | panel-mipi (`panel-mipi-dpi-spi`) | ROCKNIX patch + `/lib/firmware/panels/*.panel` |
| Backlight | PWM | pwm-sun8i + pwm-backlight | ROCKNIX patch (H616 PWM, v8 series) |
| PMIC | AXP717 (battery, charger, regulators, power key) | axp20x | mainline |
| WiFi | RTL8821CS (SDIO) | rtw88_8821cs | mainline + linux-firmware `rtw88/rtw8821c_fw.bin` |
| Bluetooth | RTL8821CS (UART, H5) | hci_uart + btrtl | mainline + `rtl_bt/rtl8821cs_*.bin` |
| Buttons | GPIO: d-pad, ABXY, L1/L2/R1/R2, Start/Select/Menu, Vol± | gpio-keys | mainline DTS (BTN_* gamepad codes) |
| Lid | Hall sensor, SW_LID | gpio-keys | mainline DTS |
| Audio | H616 internal codec + speaker amp; HDMI audio | sun4i-codec | mainline (+ ROCKNIX suspend patch) |
| RTC | PCF8563 on r_i2c | rtc-pcf8563 | mainline |
| USB | 1x USB-C (OTG via musb + charging) | musb-sunxi | ROCKNIX OTG host fixes |
| Video out | mini-HDMI | sun8i-dw-hdmi | ROCKNIX patch (untested) |
| Storage | 2x microSD (TF1 boot, TF2 data) | sunxi-mmc | mainline |

## Button codes (mainline `sun50i-h700-anbernic-rg35xx-2024.dts`)

A=`BTN_EAST`, B=`BTN_SOUTH`, X=`BTN_NORTH`, Y=`BTN_WEST`, L1=`BTN_TL`,
L2=`BTN_TL2`, R1=`BTN_TR`, R2=`BTN_TR2`, Menu=`BTN_MODE`,
Select=`BTN_SELECT`, Start=`BTN_START`, d-pad=`BTN_DPAD_*`;
volume keys are a separate device (`KEY_VOLUMEUP/DOWN`), the power key comes
from the AXP717 (`KEY_POWER`).

## Boot flow

1. BROM loads the SPL from byte offset 8K of the SD card in TF1 (so the card
   uses MBR; a GPT entry array would overlap).
2. SPL initialises DRAM (LPDDR4 or LPDDR3 parameters, per image), loads
   TF-A BL31 + U-Boot.
3. U-Boot finds `extlinux/extlinux.conf` on partition 1 (`RGOS-BOOT`, vfat)
   and boots `Image` with the chosen DTB.
4. Kernel mounts `root=PARTUUID=52473335-02` (fixed MBR signature, so it
   doesn't matter which SD slot enumerates first).

## Sources

- ROCKNIX H700 device support: `projects/ROCKNIX/devices/H700` in
  https://github.com/ROCKNIX/distribution (pinned commit in the board defconfig)
- linux-sunxi wiki: https://linux-sunxi.org/Anbernic_RG35XX_Plus
- DE33 upstreaming: https://lwn.net/Articles/1021624/
