################################################################################
#
# rgos-oskd
#
################################################################################

RGOS_OSKD_VERSION = 1.0
RGOS_OSKD_SITE = $(BR2_EXTERNAL_RGOS_PATH)/../src/oskd
RGOS_OSKD_SITE_METHOD = local
RGOS_OSKD_LICENSE = AGPL-3.0-only
RGOS_OSKD_DEPENDENCIES = host-pkgconf host-wayland wayland

define RGOS_OSKD_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) $(TARGET_CONFIGURE_OPTS) \
		PKG_CONFIG="$(PKG_CONFIG_HOST_BINARY)" \
		SCANNER=$(HOST_DIR)/bin/wayland-scanner
endef

define RGOS_OSKD_INSTALL_TARGET_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) DESTDIR=$(TARGET_DIR) PREFIX=/usr install
endef

$(eval $(generic-package))
