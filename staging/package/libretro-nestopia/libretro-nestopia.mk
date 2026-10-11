################################################################################
#
# libretro-nestopia
#
################################################################################

LIBRETRO_NESTOPIA_VERSION = b9fdc9c4e6d374abacd1a678ae46ec7f963ef59a
LIBRETRO_NESTOPIA_SITE = $(call github,libretro,nestopia,$(LIBRETRO_NESTOPIA_VERSION))
LIBRETRO_NESTOPIA_LICENSE = GPL-2.0
LIBRETRO_NESTOPIA_LICENSE_FILES = COPYING

# UNTESTED (staged on wip/tooling): root Makefile builds the libretro core
define LIBRETRO_NESTOPIA_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) platform=unix
endef
define LIBRETRO_NESTOPIA_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0644 $(@D)/nestopia_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/nestopia_libretro.so
endef

$(eval $(generic-package))
