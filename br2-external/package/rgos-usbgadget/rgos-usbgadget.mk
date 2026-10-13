################################################################################
#
# rgos-usbgadget
#
################################################################################

RGOS_USBGADGET_VERSION = 1.0
RGOS_USBGADGET_SITE = $(RGOS_USBGADGET_PKGDIR)/files
RGOS_USBGADGET_SITE_METHOD = local
RGOS_USBGADGET_LICENSE = AGPL-3.0-only

# Ships disabled; the Services menu (rgos-services) enables it via
# systemctl enable --now rgos-usbgadget.service.
define RGOS_USBGADGET_INSTALL_TARGET_CMDS
	cp -a --remove-destination $(@D)/usr $(TARGET_DIR)/
endef

$(eval $(generic-package))
