################################################################################
#
# wvkbd
#
################################################################################

WVKBD_VERSION = 0.20
WVKBD_SITE = $(call github,jjsullivan5196,wvkbd,v$(WVKBD_VERSION))
WVKBD_LICENSE = GPL-3.0
WVKBD_LICENSE_FILES = LICENSE
WVKBD_DEPENDENCIES = host-pkgconf host-wayland cairo libxkbcommon pango wayland

WVKBD_LAYOUT = mobintl

# Only build the binary; the man page needs scdoc and is not useful on-device
define WVKBD_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) \
		CC="$(TARGET_CC)" \
		PKG_CONFIG="$(PKG_CONFIG_HOST_BINARY)" \
		LAYOUT=$(WVKBD_LAYOUT) \
		wvkbd-$(WVKBD_LAYOUT)
endef

define WVKBD_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/wvkbd-$(WVKBD_LAYOUT) $(TARGET_DIR)/usr/bin/wvkbd-$(WVKBD_LAYOUT)
endef

$(eval $(generic-package))
