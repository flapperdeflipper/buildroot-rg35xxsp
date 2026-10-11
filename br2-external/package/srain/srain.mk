################################################################################
#
# srain
#
################################################################################

SRAIN_VERSION = 1.8.1
SRAIN_SITE = https://github.com/SrainApp/srain/archive/refs/tags/$(SRAIN_VERSION)
SRAIN_LICENSE = GPL-3.0
SRAIN_LICENSE_FILES = LICENSE
SRAIN_DEPENDENCIES = host-pkgconf host-gettext libconfig libgtk3 libsecret \
	libsoup3 openssl

# Optional ayatana appindicator (system tray) is not built
SRAIN_CONF_OPTS = -Dapp_indicator=false

$(eval $(meson-package))
