# Pinned ROCKNIX commit: H700 kernel patches (below) and panel firmware
# (package/rgos-panel-firmware). Bump both together.
RGOS_ROCKNIX_COMMIT = 03204074ef308f8e195fe35bc7192ac06b1f1050
RGOS_ROCKNIX_URL = https://raw.githubusercontent.com/ROCKNIX/distribution/$(RGOS_ROCKNIX_COMMIT)

# Deep sleep (PSCI SYSTEM_SUSPEND) on the H700: TF-A patch + the SRAM
# suspend stubs from rgos-suspend-stub. Used by both the atf package
# (below) and rgos-suspend-stub (header extraction from the same patch).
RGOS_ROCKNIX_ATF_PATCH = 001-allwinner-h616-psci-system-suspend.patch
RGOS_ROCKNIX_ATF_PATCH_URL = $(RGOS_ROCKNIX_URL)/projects/ROCKNIX/packages/tools/atf/patches/H700/$(RGOS_ROCKNIX_ATF_PATCH)

include $(sort $(wildcard $(BR2_EXTERNAL_RGOS_PATH)/package/*/*.mk))

# Apply the ROCKNIX TF-A patch (kailashrs' SRAM-stub system suspend) and
# embed both stubs; hash-checked via patches/arm-trusted-firmware/. Applied
# here like the kernel patches above: downloaded, not committed.
# boot/common.mk (the atf package) is included before this file, so
# ARM_TRUSTED_FIRMWARE_DEPENDENCIES can no longer be extended; hang the
# ordering on the patch stamp instead (order-only: a plain prerequisite
# would be phony and re-run the patch step - applying the patch twice -
# on every build): stubs install to $(BINARIES_DIR) before TF-A
# configures and builds.
ifeq ($(BR2_PACKAGE_RGOS_SUSPEND_STUB),y)
ARM_TRUSTED_FIRMWARE_EXTRA_DOWNLOADS += $(RGOS_ROCKNIX_ATF_PATCH_URL)
define ARM_TRUSTED_FIRMWARE_APPLY_ROCKNIX
	patch -d $(@D) -p1 -N -F2 --no-backup-if-mismatch -s \
		< $(ARM_TRUSTED_FIRMWARE_DL_DIR)/$(RGOS_ROCKNIX_ATF_PATCH)
endef
ARM_TRUSTED_FIRMWARE_POST_PATCH_HOOKS += ARM_TRUSTED_FIRMWARE_APPLY_ROCKNIX
$(ARM_TRUSTED_FIRMWARE_DIR)/.stamp_patched: | rgos-suspend-stub-install
ARM_TRUSTED_FIRMWARE_MAKE_OPTS += \
	SUNXI_SYSTEM_SUSPEND=1 \
	SUNXI_SUSPEND_STUB=$(BINARIES_DIR)/suspend_stub_lpddr4.bin \
	SUNXI_SUSPEND_STUB2=$(BINARIES_DIR)/suspend_stub_lpddr3.bin
endif

# ROCKNIX H700 kernel patches. Downloaded (and hash-checked via
# patches/linux/linux.hash) like any kernel patch, but applied here instead of
# through BR2_LINUX_KERNEL_PATCH: Buildroot applies patches with zero fuzz,
# while these are generated against vanilla 7.2 and need patch's default
# fuzz. 0140/0150 (the joypad driver) are left out: we keep mainline
# gpio-keys. 0144 is left out too: it edits the RG35XX H's joypad node
# from 0140.
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

ifeq ($(BR2_RGOS_LINUX_H700_PATCHES),y)
LINUX_EXTRA_DOWNLOADS += \
	$(addprefix $(RGOS_ROCKNIX_URL)/projects/ROCKNIX/devices/H700/patches/linux/,$(RGOS_ROCKNIX_H700_PATCHES))
define RGOS_LINUX_APPLY_ROCKNIX
	$(foreach p,$(RGOS_ROCKNIX_H700_PATCHES),
		echo "Applying H700 patch $(p)"
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
