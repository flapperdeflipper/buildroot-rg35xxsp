################################################################################
#
# mepo
#
################################################################################

# UNTESTED (staged on wip/tooling, never built yet). See NOTES.md.

# mepo 1.3.4 builds against zig 0.14.x (Alpine moved to 0.15 and carries
# 11 patches for it; we stay on 0.14.1 = no source patches needed).
MEPO_VERSION = 1.3.4
# git.sr.ht is the canonical source but is DNS-blocked from some networks
# (ours, at draft time). Alpine's distfiles mirror carries the identical
# tarball (same bytes as the sr.ht archive; sha512 from Alpine's APKBUILD).
MEPO_SITE = https://distfiles.alpinelinux.org/distfiles/v3.22
MEPO_SOURCE = mepo-$(MEPO_VERSION).tar.gz
MEPO_LICENSE = GPL-3.0-or-later
MEPO_LICENSE_FILES = LICENSE
# Alpine's APKBUILD (sha512, verified against their mirror of the sr.ht
# archive); compute a sha256 at first build if preferred.
# sha512 ef45de275e46c25ba4aedf6a27298c6b0ce5c751bd0680d37dca81baf86f059be05574d0655013ba405d45d958b1fef3d795050efa2db4fad6ca7f47aa577cb7 mepo-1.3.4.tar.gz

MEPO_DEPENDENCIES = sdl2 sdl2_ttf sdl2_gfx sdl2_image libcurl host-zig

# Zig cross-builds via its bundled glibc stubs; the target triple's glibc
# version must be <= the toolchain's (Buildroot glibc). Set at promotion
# time to the actual BR2_TOOLCHAIN_BUILDROOT_GLIBC_VERSION_STRING.
MEPO_ZIG_TARGET = aarch64-linux-gnu

define MEPO_BUILD_CMDS
	cd $(@D) && \
	PKG_CONFIG_PATH="$(STAGING_DIR)/usr/lib/pkgconfig:$(STAGING_DIR)/usr/share/pkgconfig" \
	PKG_CONFIG_SYSROOT_DIR="$(STAGING_DIR)" \
	$(HOST_DIR)/bin/zig build -Doptimize=ReleaseSafe \
		-Dtarget=$(MEPO_ZIG_TARGET) -Dcpu=baseline
endef

define MEPO_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/zig-out/bin/mepo \
		$(TARGET_DIR)/usr/bin/mepo
	$(INSTALL) -D -m 0755 $(MEPO_PKGDIR)/rgos-mepo \
		$(TARGET_DIR)/usr/bin/rgos-mepo
	$(INSTALL) -D -m 0644 $(MEPO_PKGDIR)/mepo.desktop \
		$(TARGET_DIR)/usr/share/applications/mepo.desktop
endef

$(eval $(generic-package))
