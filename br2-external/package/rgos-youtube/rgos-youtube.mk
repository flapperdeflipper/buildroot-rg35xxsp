################################################################################
#
# rgos-youtube
#
################################################################################

RGOS_YOUTUBE_VERSION = 1.0
RGOS_YOUTUBE_SITE = $(RGOS_YOUTUBE_PKGDIR)/files
RGOS_YOUTUBE_SITE_METHOD = local
RGOS_YOUTUBE_LICENSE = AGPL-3.0-only
RGOS_YOUTUBE_DEPENDENCIES = yt-dlp mpv libgtk3

define RGOS_YOUTUBE_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(TARGET_CC) $(TARGET_CFLAGS) -std=gnu17 \
		$(RGOS_YOUTUBE_PKGDIR)/rgos-yt-app.c -o $(@D)/rgos-yt-app \
		$$($(PKG_CONFIG_HOST_BINARY) --cflags --libs gtk+-3.0)
endef

define RGOS_YOUTUBE_INSTALL_TARGET_CMDS
	cp -a --remove-destination $(@D)/usr $(TARGET_DIR)/
	$(INSTALL) -D -m 0755 $(@D)/rgos-yt-app $(TARGET_DIR)/usr/bin/rgos-yt-app
endef

$(eval $(generic-package))
