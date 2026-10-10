################################################################################
#
# rgos-padsim
#
################################################################################

RGOS_PADSIM_VERSION = 1.0
RGOS_PADSIM_SITE = $(BR2_EXTERNAL_RGOS_PATH)/../src/padsim
RGOS_PADSIM_SITE_METHOD = local
RGOS_PADSIM_LICENSE = AGPL-3.0-only
RGOS_PADSIM_DEPENDENCIES = host-pkgconf libevdev

define RGOS_PADSIM_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) $(TARGET_CONFIGURE_OPTS) \
		PKG_CONFIG="$(PKG_CONFIG_HOST_BINARY)"
endef

define RGOS_PADSIM_INSTALL_TARGET_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) DESTDIR=$(TARGET_DIR) install
	$(INSTALL) -D -m 0644 $(@D)/rgos-padsim.service \
		$(TARGET_DIR)/usr/lib/systemd/system/rgos-padsim.service
	$(INSTALL) -D -m 0644 $(@D)/71-rgos-padsim.rules \
		$(TARGET_DIR)/usr/lib/udev/rules.d/71-rgos-padsim.rules
endef

$(eval $(generic-package))
