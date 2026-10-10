################################################################################
#
# geany
#
################################################################################

GEANY_VERSION = 2.1
GEANY_SOURCE = geany-$(GEANY_VERSION).tar.bz2
GEANY_SITE = https://github.com/geany/geany/releases/download/$(GEANY_VERSION).0
GEANY_LICENSE = GPL-2.0+
GEANY_LICENSE_FILES = COPYING
GEANY_DEPENDENCIES = host-pkgconf libgtk3 $(TARGET_NLS_DEPENDENCIES)
GEANY_CONF_OPTS = \
	--disable-vte \
	--disable-html-docs \
	--disable-pdf-docs \
	--disable-api-docs \
	--disable-gtkdoc-header

$(eval $(autotools-package))
