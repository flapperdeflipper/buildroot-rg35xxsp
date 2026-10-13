################################################################################
#
# rgos-services
#
################################################################################

RGOS_SERVICES_VERSION = 1.0
RGOS_SERVICES_SITE = $(RGOS_SERVICES_PKGDIR)/files
RGOS_SERVICES_SITE_METHOD = local
RGOS_SERVICES_LICENSE = AGPL-3.0-only

define RGOS_SERVICES_INSTALL_TARGET_CMDS
	cp -a --remove-destination $(@D)/usr $(TARGET_DIR)/
endef

$(eval $(generic-package))
