################################################################################
#
# labwc
#
################################################################################

LABWC_VERSION = 0.20.2
LABWC_SITE = $(call github,labwc,labwc,$(LABWC_VERSION))
LABWC_LICENSE = GPL-2.0
LABWC_LICENSE_FILES = LICENSE
LABWC_DEPENDENCIES = host-pkgconf host-wayland wlroots wayland wayland-protocols \
	libxkbcommon libxml2 libglib2 cairo pango pixman libpng libdrm libinput

# Window icons need libsfdo and SVG buttons need librsvg (Rust); labwc falls
# back to its built-in button images.
LABWC_CONF_OPTS = \
	-Dicon=disabled \
	-Dsvg=disabled \
	-Dman-pages=disabled \
	-Dnls=disabled \
	-Dlabnag=disabled \
	-Dsystemd-session=disabled \
	-Dtest=disabled

ifeq ($(BR2_PACKAGE_WLROOTS_XWAYLAND),y)
LABWC_CONF_OPTS += -Dxwayland=enabled
LABWC_DEPENDENCIES += libxcb xcb-util-wm xwayland
else
LABWC_CONF_OPTS += -Dxwayland=disabled
endif

$(eval $(meson-package))
