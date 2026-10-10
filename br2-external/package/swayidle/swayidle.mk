################################################################################
#
# swayidle
#
################################################################################

SWAYIDLE_VERSION = 1.9.0
SWAYIDLE_SITE = https://github.com/swaywm/swayidle/releases/download/v$(SWAYIDLE_VERSION)
SWAYIDLE_LICENSE = MIT
SWAYIDLE_LICENSE_FILES = LICENSE
SWAYIDLE_DEPENDENCIES = host-pkgconf host-wayland wayland wayland-protocols systemd

# logind support provides the before-sleep / after-resume hooks
SWAYIDLE_CONF_OPTS = \
	-Dlogind=enabled \
	-Dlogind-provider=systemd \
	-Dman-pages=disabled \
	-Dzsh-completions=false \
	-Dbash-completions=false \
	-Dfish-completions=false

$(eval $(meson-package))
