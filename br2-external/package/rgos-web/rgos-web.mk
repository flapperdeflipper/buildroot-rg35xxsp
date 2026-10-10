################################################################################
#
# rgos-web
#
################################################################################

RGOS_WEB_VERSION = 1.0
RGOS_WEB_SITE = $(RGOS_WEB_PKGDIR)/files
RGOS_WEB_SITE_METHOD = local
RGOS_WEB_LICENSE = AGPL-3.0-only
RGOS_WEB_DEPENDENCIES = webkitgtk

define RGOS_WEB_INSTALL_TARGET_CMDS
	cp -a --remove-destination $(@D)/usr $(TARGET_DIR)/
endef

$(eval $(generic-package))
