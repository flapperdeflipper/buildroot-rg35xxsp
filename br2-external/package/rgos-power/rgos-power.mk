################################################################################
#
# rgos-power
#
################################################################################

RGOS_POWER_VERSION = 1.0
RGOS_POWER_SITE = $(RGOS_POWER_PKGDIR)/files
RGOS_POWER_SITE_METHOD = local
RGOS_POWER_LICENSE = AGPL-3.0-only
RGOS_POWER_DEPENDENCIES = swayidle

define RGOS_POWER_INSTALL_TARGET_CMDS
	cp -a --remove-destination $(@D)/etc $(@D)/usr $(TARGET_DIR)/
endef

$(eval $(generic-package))
