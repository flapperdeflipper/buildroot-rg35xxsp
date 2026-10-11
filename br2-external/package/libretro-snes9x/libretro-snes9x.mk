################################################################################
#
# libretro-snes9x
#
################################################################################

LIBRETRO_SNES9X_VERSION = fae2fea08f74180759ef540ee94259213f503480
LIBRETRO_SNES9X_SITE = $(call github,libretro,snes9x,$(LIBRETRO_SNES9X_VERSION))
LIBRETRO_SNES9X_LICENSE = Snes9x license (permissive, non-commercial)
LIBRETRO_SNES9X_LICENSE_FILES = LICENSE

# UNTESTED (staged on wip/tooling)
define LIBRETRO_SNES9X_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/libretro -f Makefile platform=unix
endef
define LIBRETRO_SNES9X_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0644 $(@D)/libretro/snes9x_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/snes9x_libretro.so
endef

$(eval $(generic-package))
