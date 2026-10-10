# Pinned ROCKNIX commit: H700 kernel patches (below) and panel firmware
# (package/rgos-panel-firmware). Bump both together.
RGOS_ROCKNIX_COMMIT = 03204074ef308f8e195fe35bc7192ac06b1f1050
RGOS_ROCKNIX_URL = https://raw.githubusercontent.com/ROCKNIX/distribution/$(RGOS_ROCKNIX_COMMIT)

include $(sort $(wildcard $(BR2_EXTERNAL_RGOS_PATH)/package/*/*.mk))

# ROCKNIX H700 kernel patches. Downloaded (and hash-checked via
# patches/linux/linux.hash) like any kernel patch, but applied here instead of
# through BR2_LINUX_KERNEL_PATCH: Buildroot applies patches with zero fuzz,
# while ROCKNIX's patches against vanilla 7.2 need patch's default fuzz.
# 0140/0150 (ROCKNIX joypad driver) are left out: we keep mainline gpio-keys.
# 0144 is left out too: it edits the RG35XX H's joypad node from 0140.
RGOS_ROCKNIX_H700_PATCHES = \
	0002-rg35xx-enable-HDMI-LCD.patch \
	0003-Update-sun8i_tcon_top.c.patch \
	0007-rg35xx-add-GPU-opp.patch \
	0008-v8_20260804_james_hilliard1_introduce_allwinner_h616_pwm_controller.patch \
	0010-rg35xx-enable-pwm-backlight.patch \
	0040-Revert-usb-musb-Fix-hardware-lockup-on-first-Rx-endp.patch \
	0110-v2_20250226_kikuchan98_drm_panel_add_generic_mipi_panel_driver.patch \
	0111-rg35xx-2024-use-panel-mipi-dpi-spi-driver.patch \
	0124-battery-name.patch \
	0126-20241018_macroalpha82_rg35xx_add_additional_hardware_support.patch \
	0127-enable-mmc1-for-RG35XX-2024.patch \
	0151-phy-fix-OTG-host-mode.patch \
	0152-rg35xx-2024-enable-usb-otg.patch \
	0153-enable-rgb-leds.patch \
	0154-rocknix-dt-id.patch \
	0155-sun4i-set-rgb-connector-as-DSI.patch \
	0156-rg35xx-plus-add-pcf8563-rtc.patch \
	0157-input-axp20x-pek-do-not-report-the-key-press-that-woke-the-system.patch \
	0158-mmc-sunxi-mmc-mask-data0-when-updating-the-clock-on-h616-emmc.patch \
	0159-arm64-dts-rg35xx-2024-keep-the-second-sd-card-powered.patch \
	0160-phy-sun4i-usb-disable-the-clock-that-was-enabled.patch \
	0161-drm-sun4i-gate-the-display-pipeline-across-system-suspend.patch \
	0162-pinctrl-sunxi-release-the-lcd0-pads-while-the-panel-is-off.patch \
	0163-asoc-sun4i-codec-suspend-the-codec-and-switch-the-amplifier-supply.patch \
	0200-h700-update-opps.patch \
	0204-dts-Enable-hdmi-sound.patch \
	0210-h616-cpu-opp-mark-480MHz-as-suspend-opp.patch \
	0901-dts-rg35xx-2024-fix-led-1-color.patch

ifeq ($(BR2_RGOS_LINUX_ROCKNIX_H700),y)
LINUX_EXTRA_DOWNLOADS += \
	$(addprefix $(RGOS_ROCKNIX_URL)/projects/ROCKNIX/devices/H700/patches/linux/,$(RGOS_ROCKNIX_H700_PATCHES))
define RGOS_LINUX_APPLY_ROCKNIX
	$(foreach p,$(RGOS_ROCKNIX_H700_PATCHES),
		echo "Applying ROCKNIX $(p)"
		patch -d $(@D) -p1 -N -F2 --no-backup-if-mismatch -s < $(LINUX_DL_DIR)/$(p)
	)
endef
LINUX_POST_PATCH_HOOKS += RGOS_LINUX_APPLY_ROCKNIX
endif

# Fail the build when kernel fragment options didn't make it into .config
define RGOS_LINUX_CHECK_FRAGMENTS
	$(BR2_EXTERNAL_RGOS_PATH)/boards/scripts/check-kconfig.sh $(@D)/.config \
		$(call qstrip,$(BR2_LINUX_KERNEL_CONFIG_FRAGMENT_FILES))
endef
LINUX_POST_CONFIGURE_HOOKS += RGOS_LINUX_CHECK_FRAGMENTS

# libfm/PCManFM 1.3.2 are old C: K&R-style "()" prototypes mean "(void)" in
# GCC 15's default C23, and GCC 14+ makes incompatible pointer types an
# error. Build them as gnu17 with that one diagnostic as a warning.
RGOS_OLD_C_CFLAGS = $(TARGET_CFLAGS) -std=gnu17 -Wno-error=incompatible-pointer-types
LIBFM_CONF_ENV += CFLAGS="$(RGOS_OLD_C_CFLAGS)"
PCMANFM_CONF_ENV += CFLAGS="$(RGOS_OLD_C_CFLAGS)"
MENU_CACHE_CONF_ENV += CFLAGS="$(RGOS_OLD_C_CFLAGS)"
