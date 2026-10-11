################################################################################
#
# libretro-genesis-plus-gx
#
################################################################################

LIBRETRO_GENESIS_PLUS_GX_VERSION = 393f70cd64c7334564c19a424c383f53986c13f4
LIBRETRO_GENESIS_PLUS_GX_SITE = $(call github,libretro,Genesis-Plus-GX,$(LIBRETRO_GENESIS_PLUS_GX_VERSION))
LIBRETRO_GENESIS_PLUS_GX_LICENSE = Genesis Plus GX license (non-commercial)
LIBRETRO_GENESIS_PLUS_GX_LICENSE_FILES = LICENSE.txt

# UNTESTED (staged on wip/tooling)
define LIBRETRO_GENESIS_PLUS_GX_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) -f Makefile.libretro platform=unix
endef
define LIBRETRO_GENESIS_PLUS_GX_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0644 $(@D)/genesis_plus_gx_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/genesis_plus_gx_libretro.so
endef

$(eval $(generic-package))
