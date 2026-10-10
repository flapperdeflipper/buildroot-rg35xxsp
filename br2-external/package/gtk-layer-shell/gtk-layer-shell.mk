################################################################################
#
# gtk-layer-shell
#
################################################################################

GTK_LAYER_SHELL_VERSION = 0.10.1
GTK_LAYER_SHELL_SITE = $(call github,wmww,gtk-layer-shell,v$(GTK_LAYER_SHELL_VERSION))
GTK_LAYER_SHELL_LICENSE = MIT, LGPL-3.0+, GPL-3.0+
GTK_LAYER_SHELL_LICENSE_FILES = LICENSE_MIT.txt LICENSE_LGPL.txt LICENSE_GPL.txt
GTK_LAYER_SHELL_INSTALL_STAGING = YES
GTK_LAYER_SHELL_DEPENDENCIES = host-pkgconf host-wayland libgtk3 wayland wayland-protocols
GTK_LAYER_SHELL_CONF_OPTS = \
	-Dintrospection=false \
	-Dvapi=false \
	-Ddocs=false \
	-Dexamples=false \
	-Dtests=false

$(eval $(meson-package))
