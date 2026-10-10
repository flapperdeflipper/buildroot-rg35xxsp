################################################################################
#
# rgos-padd
#
################################################################################

RGOS_PADD_VERSION = 1.0
RGOS_PADD_SITE = $(BR2_EXTERNAL_RGOS_PATH)/../src/padd
RGOS_PADD_SITE_METHOD = local
RGOS_PADD_LICENSE = AGPL-3.0-only
RGOS_PADD_DEPENDENCIES = host-pkgconf libevdev

define RGOS_PADD_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) $(TARGET_CONFIGURE_OPTS) \
		PKG_CONFIG="$(PKG_CONFIG_HOST_BINARY)"
endef

define RGOS_PADD_INSTALL_TARGET_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) DESTDIR=$(TARGET_DIR) install
	$(INSTALL) -D -m 0644 $(@D)/padd.conf $(TARGET_DIR)/etc/rgos/padd.conf
endef

$(eval $(generic-package))
