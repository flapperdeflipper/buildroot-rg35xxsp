################################################################################
#
# rgos-youtube
#
################################################################################

RGOS_YOUTUBE_VERSION = 1.0
RGOS_YOUTUBE_SITE = $(RGOS_YOUTUBE_PKGDIR)/files
RGOS_YOUTUBE_SITE_METHOD = local
RGOS_YOUTUBE_LICENSE = AGPL-3.0-only
RGOS_YOUTUBE_DEPENDENCIES = yt-dlp mpv

define RGOS_YOUTUBE_INSTALL_TARGET_CMDS
	cp -a --remove-destination $(@D)/usr $(TARGET_DIR)/
endef

$(eval $(generic-package))
