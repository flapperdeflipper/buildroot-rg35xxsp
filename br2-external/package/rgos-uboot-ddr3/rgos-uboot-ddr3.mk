################################################################################
#
# rgos-uboot-ddr3
#
################################################################################

# Same source tarball as the main U-Boot (shared download dir)
RGOS_UBOOT_DDR3_VERSION = $(UBOOT_VERSION)
RGOS_UBOOT_DDR3_SITE = $(UBOOT_SITE)
RGOS_UBOOT_DDR3_SOURCE = $(UBOOT_SOURCE)
RGOS_UBOOT_DDR3_DL_SUBDIR = uboot
RGOS_UBOOT_DDR3_LICENSE = GPL-2.0+
RGOS_UBOOT_DDR3_LICENSE_FILES = Licenses/gpl-2.0.txt
RGOS_UBOOT_DDR3_INSTALL_TARGET = NO
RGOS_UBOOT_DDR3_INSTALL_IMAGES = YES

# Depending on uboot pulls in BL31 and all host tools the build needs
RGOS_UBOOT_DDR3_DEPENDENCIES = uboot

RGOS_UBOOT_DDR3_FRAGMENTS = \
	$(call qstrip,$(BR2_TARGET_UBOOT_CONFIG_FRAGMENT_FILES)) \
	$(BR2_EXTERNAL_RGOS_PATH)/boards/h700/uboot-ddr3.fragment

RGOS_UBOOT_DDR3_MAKE_ENV = \
	$(TARGET_CONFIGURE_OPTS) \
	PKG_CONFIG="$(PKG_CONFIG_HOST_BINARY)" \
	PKG_CONFIG_SYSROOT_DIR="/" \
	PKG_CONFIG_ALLOW_SYSTEM_CFLAGS=1 \
	PKG_CONFIG_ALLOW_SYSTEM_LIBS=1 \
	PKG_CONFIG_LIBDIR="$(HOST_DIR)/lib/pkgconfig:$(HOST_DIR)/share/pkgconfig"

define RGOS_UBOOT_DDR3_CONFIGURE_CMDS
	$(RGOS_UBOOT_DDR3_MAKE_ENV) $(BR2_MAKE) -C $(@D) $(UBOOT_MAKE_OPTS) \
		$(call qstrip,$(BR2_TARGET_UBOOT_BOARD_DEFCONFIG))_defconfig
	cd $(@D) && ./scripts/kconfig/merge_config.sh -m .config $(RGOS_UBOOT_DDR3_FRAGMENTS)
	$(RGOS_UBOOT_DDR3_MAKE_ENV) $(BR2_MAKE) -C $(@D) $(UBOOT_MAKE_OPTS) olddefconfig
endef

define RGOS_UBOOT_DDR3_BUILD_CMDS
	cp $(BINARIES_DIR)/bl31.bin $(@D)/
	$(RGOS_UBOOT_DDR3_MAKE_ENV) $(BR2_MAKE) -C $(@D) $(UBOOT_MAKE_OPTS)
endef

define RGOS_UBOOT_DDR3_INSTALL_IMAGES_CMDS
	$(INSTALL) -D -m 0644 $(@D)/u-boot-sunxi-with-spl.bin \
		$(BINARIES_DIR)/u-boot-sunxi-with-spl-lpddr3.bin
endef

$(eval $(generic-package))
