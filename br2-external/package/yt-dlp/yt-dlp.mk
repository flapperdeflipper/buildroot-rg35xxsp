################################################################################
#
# yt-dlp
#
################################################################################

YT_DLP_VERSION = 2026.08.19
YT_DLP_SOURCE = yt-dlp
YT_DLP_SITE = https://github.com/yt-dlp/yt-dlp/releases/download/$(YT_DLP_VERSION)
YT_DLP_LICENSE = Unlicense
YT_DLP_DEPENDENCIES = python3 quickjs

# The zipapp is a single file: nothing to extract
define YT_DLP_EXTRACT_CMDS
	cp $(YT_DLP_DL_DIR)/$(YT_DLP_SOURCE) $(@D)/
endef

define YT_DLP_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/yt-dlp $(TARGET_DIR)/usr/bin/yt-dlp
	$(INSTALL) -D -m 0644 $(YT_DLP_PKGDIR)/yt-dlp.conf $(TARGET_DIR)/etc/yt-dlp.conf
endef

$(eval $(generic-package))
