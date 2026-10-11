################################################################################
#
# libretro-gambatte
#
################################################################################

LIBRETRO_GAMBATTE_VERSION = d9d6cd06382d1ced30de34d56d3609452323dab1
LIBRETRO_GAMBATTE_SITE = $(call github,libretro,gambatte-libretro,$(LIBRETRO_GAMBATTE_VERSION))
LIBRETRO_GAMBATTE_LICENSE = GPL-2.0
LIBRETRO_GAMBATTE_LICENSE_FILES = COPYING

# UNTESTED (staged on wip/tooling): build via the core Makefile, install
# the single .so into /usr/lib/libretro.
define LIBRETRO_GAMBATTE_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) -f Makefile.libretro platform=unix
endef
define LIBRETRO_GAMBATTE_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0644 $(@D)/gambatte_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/gambatte_libretro.so
endef

$(eval $(generic-package))
