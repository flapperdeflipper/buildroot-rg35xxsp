################################################################################
#
# rgos-roms
#
################################################################################

RGOS_ROMS_VERSION = 1.0
RGOS_ROMS_SITE = $(RGOS_ROMS_PKGDIR)/files
RGOS_ROMS_SITE_METHOD = local
RGOS_ROMS_LICENSE = AGPL-3.0-only
RGOS_ROMS_DEPENDENCIES = host-python3 retroarch

define RGOS_ROMS_BUILD_CMDS
	$(HOST_DIR)/bin/python3 $(RGOS_ROMS_PKGDIR)/rgos-roms.py $(@D)
endef

define RGOS_ROMS_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/share/rgos/roms
	$(INSTALL) -m 0644 $(@D)/rgos-test.* $(TARGET_DIR)/usr/share/rgos/roms/
	for d in $(RGOS_ROMS_PKGDIR)/files/usr/share/applications/*.desktop; do \
		$(INSTALL) -D -m 0644 "$$d" "$(TARGET_DIR)/usr/share/applications/"; \
	done
endef

$(eval $(generic-package))
