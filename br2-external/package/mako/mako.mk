################################################################################
#
# mako
#
################################################################################

MAKO_VERSION = 1.11.0
MAKO_SITE = $(call github,emersion,mako,v$(MAKO_VERSION))
MAKO_LICENSE = MIT
MAKO_LICENSE_FILES = LICENSE
MAKO_DEPENDENCIES = host-pkgconf host-wayland cairo pango libglib2 wayland \
	wayland-protocols systemd
MAKO_CONF_OPTS = \
	-Dsd-bus-provider=libsystemd \
	-Dman-pages=disabled \
	-Dbash-completions=false

ifeq ($(BR2_PACKAGE_GDK_PIXBUF),y)
MAKO_DEPENDENCIES += gdk-pixbuf
MAKO_CONF_OPTS += -Dicons=enabled
else
MAKO_CONF_OPTS += -Dicons=disabled
endif

$(eval $(meson-package))
