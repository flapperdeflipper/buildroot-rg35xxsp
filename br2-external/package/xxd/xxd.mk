################################################################################
#
# xxd (host)
#
################################################################################

# Host-only xxd. Buildroot had one (added 2014, package/xxd) but dropped it
# upstream, and rtkit's meson embeds its D-Bus introspection XML with
# `xxd -i` from stdin (bare C byte list). xxd is maintained in the vim tree
# now; build just that file with the host compiler.
HOST_XXD_VERSION = 9.1.0000
HOST_XXD_SITE = $(call github,vim,vim,v$(HOST_XXD_VERSION))
HOST_XXD_SOURCE = vim-$(HOST_XXD_VERSION).tar.gz
HOST_XXD_LICENSE = Public domain
HOST_XXD_LICENSE_FILES = src/xxd/xxd.c

define HOST_XXD_BUILD_CMDS
	$(HOSTCC) $(HOST_CFLAGS) -o $(@D)/xxd $(@D)/src/xxd/xxd.c
endef

define HOST_XXD_INSTALL_CMDS
	$(INSTALL) -D -m 0755 $(@D)/xxd $(HOST_DIR)/bin/xxd
endef

$(eval $(host-generic-package))
