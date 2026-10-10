################################################################################
#
# rgos-sdcard
#
################################################################################

RGOS_SDCARD_VERSION = 1.0
RGOS_SDCARD_SITE = $(RGOS_SDCARD_PKGDIR)/files
RGOS_SDCARD_SITE_METHOD = local
RGOS_SDCARD_LICENSE = AGPL-3.0-only

define RGOS_SDCARD_INSTALL_TARGET_CMDS
	cp -a --remove-destination $(@D)/usr $(TARGET_DIR)/
endef

$(eval $(generic-package))
