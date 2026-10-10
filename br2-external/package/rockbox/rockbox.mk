################################################################################
#
# rockbox
#
################################################################################

# No releases since 3.15 (2020); development happens on master
ROCKBOX_VERSION = 5a0fc3c6e9ecc2c876033a8088479e3886f3cc2a
ROCKBOX_SITE = $(call github,Rockbox,rockbox,$(ROCKBOX_VERSION))
ROCKBOX_LICENSE = GPL-2.0+
ROCKBOX_LICENSE_FILES = docs/COPYING
ROCKBOX_DEPENDENCIES = sdl2

# Rockbox has its own configure (not autoconf). The SDL "application"
# target builds a native program; 320x240 is the largest size the stock
# themes (cabbiev2) support below 800x480, and rgos-rockbox shows it 2x.
define ROCKBOX_CONFIGURE_CMDS
	mkdir -p $(@D)/build
	cd $(@D)/build && $(TARGET_MAKE_ENV) CROSS_COMPILE=$(TARGET_CROSS) \
		../tools/configure --target=sdlapp --type=N \
		--lcdwidth=320 --lcdheight=240 --prefix=/usr
endef

define ROCKBOX_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/build
endef

# fullinstall copies into PREFIX; the paths compiled in stay /usr/...
define ROCKBOX_INSTALL_TARGET_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/build fullinstall PREFIX=$(TARGET_DIR)/usr
	$(INSTALL) -D -m 0755 $(ROCKBOX_PKGDIR)/rgos-rockbox $(TARGET_DIR)/usr/bin/rgos-rockbox
	$(INSTALL) -D -m 0644 $(ROCKBOX_PKGDIR)/rockbox.desktop \
		$(TARGET_DIR)/usr/share/applications/rockbox.desktop
endef

$(eval $(generic-package))
