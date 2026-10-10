################################################################################
#
# sfwbar
#
################################################################################

SFWBAR_VERSION = 1.0_beta17
SFWBAR_SITE = $(call github,LBCrion,sfwbar,v$(SFWBAR_VERSION))
SFWBAR_LICENSE = GPL-3.0
SFWBAR_LICENSE_FILES = LICENSE
SFWBAR_DEPENDENCIES = host-pkgconf host-wayland libgtk3 gtk-layer-shell json-c \
	wayland wayland-protocols libglib2

# Modules we use: app menu, iwd (WiFi), bluez, ALSA volume, network, dbus.
SFWBAR_CONF_OPTS = \
	-Dappmenu=enabled \
	-Diwd=enabled \
	-Dbluez=enabled \
	-Ddbus=enabled \
	-Dnetwork=enabled \
	-Dalsa=enabled \
	-Dnm=disabled \
	-Dpulse=disabled \
	-Dpipewire=disabled \
	-Dmpd=disabled \
	-Dxkb=enabled \
	-Dbuild-docs=disabled
SFWBAR_DEPENDENCIES += alsa-lib libxkbcommon

$(eval $(meson-package))
