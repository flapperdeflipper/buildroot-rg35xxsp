################################################################################
#
# libretro-mgba
#
################################################################################

LIBRETRO_MGBA_VERSION = 517e518c48e351def04042dc159064dd098830a9
LIBRETRO_MGBA_SITE = $(call github,libretro,mGBA,$(LIBRETRO_MGBA_VERSION))
LIBRETRO_MGBA_LICENSE = MPL-2.0
LIBRETRO_MGBA_LICENSE_FILES = LICENSE

# UNTESTED (staged on wip/tooling)
define LIBRETRO_MGBA_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) -f Makefile.libretro platform=unix
endef
define LIBRETRO_MGBA_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0644 $(@D)/mgba_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/mgba_libretro.so
endef

$(eval $(generic-package))
