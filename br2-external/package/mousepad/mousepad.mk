################################################################################
#
# mousepad
#
################################################################################

MOUSEPAD_VERSION_MAJOR = 0.7
MOUSEPAD_VERSION = $(MOUSEPAD_VERSION_MAJOR).0
MOUSEPAD_SOURCE = mousepad-$(MOUSEPAD_VERSION).tar.xz
MOUSEPAD_SITE = https://archive.xfce.org/src/apps/mousepad/$(MOUSEPAD_VERSION_MAJOR)
MOUSEPAD_LICENSE = GPL-2.0+
MOUSEPAD_LICENSE_FILES = COPYING
# Buildroot compiles GSettings schemas from staging (target-finalize);
# without this Mousepad's settings schema is missing at runtime
MOUSEPAD_INSTALL_STAGING = YES
MOUSEPAD_DEPENDENCIES = host-pkgconf host-libglib2 libgtk3 gtksourceview4 libglib2 \
	$(TARGET_NLS_DEPENDENCIES)
MOUSEPAD_CONF_OPTS = \
	-Dgtksourceview4=enabled \
	-Dpolkit=disabled \
	-Dgspell-plugin=disabled \
	-Dshortcuts-plugin=disabled \
	-Dtest-plugin=disabled \
	-Dkeyfile-settings=false

$(eval $(meson-package))
