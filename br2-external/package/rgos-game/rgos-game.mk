################################################################################
#
# rgos-game
#
################################################################################

RGOS_GAME_VERSION = 1.0
RGOS_GAME_SITE = $(RGOS_GAME_PKGDIR)/files
RGOS_GAME_SITE_METHOD = local
RGOS_GAME_LICENSE = AGPL-3.0-only

define RGOS_GAME_INSTALL_TARGET_CMDS
	cp -a --remove-destination $(@D)/etc $(@D)/usr $(TARGET_DIR)/
endef

# The menu entry only makes sense with the frontend installed
ifeq ($(BR2_PACKAGE_RETROARCH),y)
define RGOS_GAME_INSTALL_RETROARCH_MENU
	$(INSTALL) -D -m 0644 $(RGOS_GAME_PKGDIR)/retroarch.desktop \
		$(TARGET_DIR)/usr/share/applications/retroarch.desktop
endef
RGOS_GAME_POST_INSTALL_TARGET_HOOKS += RGOS_GAME_INSTALL_RETROARCH_MENU
endif

$(eval $(generic-package))
