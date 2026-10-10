################################################################################
#
# wlopm
#
################################################################################

WLOPM_VERSION = 1.0.0
WLOPM_SITE = https://git.sr.ht/~leon_plickat/wlopm/archive
WLOPM_SOURCE = v$(WLOPM_VERSION).tar.gz
WLOPM_LICENSE = GPL-3.0
WLOPM_LICENSE_FILES = LICENSE
WLOPM_DEPENDENCIES = host-wayland wayland

# Passing CFLAGS replaces upstream's -Werror set (new GCC warnings break it)
define WLOPM_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) \
		CC="$(TARGET_CC)" CFLAGS="$(TARGET_CFLAGS)" LDFLAGS="$(TARGET_LDFLAGS)" \
		SCANNER=$(HOST_DIR)/bin/wayland-scanner wlopm
endef

define WLOPM_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/wlopm $(TARGET_DIR)/usr/bin/wlopm
endef

$(eval $(generic-package))
