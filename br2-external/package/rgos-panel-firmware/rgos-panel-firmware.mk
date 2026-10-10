################################################################################
#
# rgos-panel-firmware
#
################################################################################

# Same pinned ROCKNIX commit as the kernel patches (RGOS_ROCKNIX_COMMIT,
# external.mk)
RGOS_PANEL_FIRMWARE_VERSION = $(RGOS_ROCKNIX_COMMIT)
RGOS_PANEL_FIRMWARE_SITE = https://raw.githubusercontent.com/ROCKNIX/distribution/$(RGOS_PANEL_FIRMWARE_VERSION)/projects/ROCKNIX/packages/linux-firmware/kernel-firmware/extra-firmware/panels
RGOS_PANEL_FIRMWARE_LICENSE = GPL-2.0
RGOS_PANEL_FIRMWARE_SOURCE =

# Panel names contain a comma, which make treats as an argument separator,
# so they are fetched URL-encoded (%2C) and renamed on install.
RGOS_PANEL_FIRMWARE_PANELS = \
	anbernic%2Crg35xx-plus-panel.panel \
	anbernic%2Crg35xx-plus-rev6-panel.panel \
	anbernic%2Crg35xx-sp-v2-panel.panel \
	anbernic%2Crg34xx-panel.panel \
	anbernic%2Crg34xx-sp-panel.panel \
	anbernic%2Crg34xx-sp-v2-panel.panel \
	anbernic%2Crg28xx-panel.panel \
	anbernic%2Crg40xx-panel.panel \
	anbernic%2Crg40xx-v2-panel.panel \
	anbernic%2Crgcubexx-panel.panel

RGOS_PANEL_FIRMWARE_EXTRA_DOWNLOADS = \
	$(addprefix $(RGOS_PANEL_FIRMWARE_SITE)/,$(RGOS_PANEL_FIRMWARE_PANELS))

define RGOS_PANEL_FIRMWARE_INSTALL_TARGET_CMDS
	$(foreach p,$(RGOS_PANEL_FIRMWARE_PANELS),
		$(INSTALL) -D -m 0644 $(RGOS_PANEL_FIRMWARE_DL_DIR)/$(p) \
			"$(TARGET_DIR)/usr/lib/firmware/panels/$(subst %2C,$(comma),$(p))"
	)
endef

$(eval $(generic-package))
