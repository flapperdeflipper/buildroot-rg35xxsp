################################################################################
#
# rgos-desktop
#
################################################################################

RGOS_DESKTOP_VERSION = 1.0
RGOS_DESKTOP_SITE = $(RGOS_DESKTOP_PKGDIR)/files
RGOS_DESKTOP_SITE_METHOD = local
RGOS_DESKTOP_LICENSE = AGPL-3.0-only
RGOS_DESKTOP_DEPENDENCIES = host-python3 labwc sfwbar swaybg wlopm foot fuzzel \
	wvkbd rgos-padd

define RGOS_DESKTOP_BUILD_CMDS
	$(HOST_DIR)/bin/python3 $(RGOS_DESKTOP_PKGDIR)/gen-wallpaper.py \
		$(@D)/wallpaper.png 1280 960
endef

# --remove-destination: replace files a previous install left read-only
define RGOS_DESKTOP_INSTALL_TARGET_CMDS
	cp -a --remove-destination $(@D)/etc $(@D)/usr $(TARGET_DIR)/
	$(INSTALL) -D -m 0644 $(@D)/wallpaper.png $(TARGET_DIR)/usr/share/rgos/wallpaper.png
	# Panel: our layout + the stock sfwbar CSS
	{ cat $(@D)/etc/rgos/sfwbar.config.in; \
	  awk '/^#CSS/ { css = 1 } css' $(TARGET_DIR)/usr/share/sfwbar/sfwbar.config; } \
		> $(TARGET_DIR)/etc/rgos/sfwbar.config
	rm -f $(TARGET_DIR)/etc/rgos/sfwbar.config.in
	grep -q '^#CSS' $(TARGET_DIR)/etc/rgos/sfwbar.config
endef

$(eval $(generic-package))
