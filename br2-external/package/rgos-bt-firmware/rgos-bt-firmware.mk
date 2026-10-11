################################################################################
#
# rgos-bt-firmware
#
################################################################################

# Only rtl_bt/rtl8821cs_config.bin is taken from this release: current
# linux-firmware no longer ships it, while the btrtl driver still calls
# it mandatory for the RTL8821CS (H700 Bluetooth). 20230804 is the
# newest release known to carry the file.
RGOS_BT_FIRMWARE_VERSION = 20230804
RGOS_BT_FIRMWARE_SOURCE = linux-firmware-$(RGOS_BT_FIRMWARE_VERSION).tar.xz
RGOS_BT_FIRMWARE_SITE = https://cdn.kernel.org/pub/linux/kernel/firmware
RGOS_BT_FIRMWARE_LICENSE = PROPRIETARY
RGOS_BT_FIRMWARE_LICENSE_FILES = LICENCE.rtlwifi_firmware.txt

define RGOS_BT_FIRMWARE_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0644 $(@D)/rtl_bt/rtl8821cs_config.bin \
		$(TARGET_DIR)/lib/firmware/rtl_bt/rtl8821cs_config.bin
endef

$(eval $(generic-package))
