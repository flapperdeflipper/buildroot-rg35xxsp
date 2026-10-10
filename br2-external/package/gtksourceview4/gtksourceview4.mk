################################################################################
#
# gtksourceview4
#
################################################################################

GTKSOURCEVIEW4_VERSION_MAJOR = 4.8
GTKSOURCEVIEW4_VERSION = $(GTKSOURCEVIEW4_VERSION_MAJOR).4
GTKSOURCEVIEW4_SOURCE = gtksourceview-$(GTKSOURCEVIEW4_VERSION).tar.xz
GTKSOURCEVIEW4_SITE = https://download.gnome.org/sources/gtksourceview/$(GTKSOURCEVIEW4_VERSION_MAJOR)
GTKSOURCEVIEW4_LICENSE = LGPL-2.1+
GTKSOURCEVIEW4_LICENSE_FILES = COPYING
GTKSOURCEVIEW4_INSTALL_STAGING = YES
GTKSOURCEVIEW4_DEPENDENCIES = host-pkgconf host-libglib2 libgtk3 libxml2 libglib2 \
	$(TARGET_NLS_DEPENDENCIES)
GTKSOURCEVIEW4_CONF_OPTS = \
	-Dglade_catalog=false \
	-Dinstall_tests=false \
	-Dgir=false \
	-Dvapi=false \
	-Dgtk_doc=false

$(eval $(meson-package))
