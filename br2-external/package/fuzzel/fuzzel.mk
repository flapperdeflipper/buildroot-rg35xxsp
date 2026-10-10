################################################################################
#
# fuzzel
#
################################################################################

FUZZEL_VERSION = 1.15.0
FUZZEL_SITE = https://codeberg.org/dnkl/fuzzel/archive
FUZZEL_SOURCE = $(FUZZEL_VERSION).tar.gz
FUZZEL_LICENSE = MIT
FUZZEL_LICENSE_FILES = LICENSE
FUZZEL_DEPENDENCIES = \
	host-pkgconf \
	host-wayland \
	fcft \
	fontconfig \
	libpng \
	libxkbcommon \
	pixman \
	tllist \
	wayland \
	wayland-protocols

FUZZEL_CONF_OPTS = \
	-Denable-cairo=disabled \
	-Dpng-backend=libpng \
	-Dsvg-backend=nanosvg

# Man pages need host scdoc (and aren't installed on the device anyway);
# fuzzel has no option to turn them off, so drop the doc/ subdir.
define FUZZEL_DROP_DOCS
	$(SED) "/^subdir('doc')/d" $(@D)/meson.build
endef
FUZZEL_POST_PATCH_HOOKS += FUZZEL_DROP_DOCS

$(eval $(meson-package))
