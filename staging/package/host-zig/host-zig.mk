################################################################################
#
# host-zig
#
################################################################################

# Official prebuilt zig toolchain for the build host (x86_64 Linux).
# Used to cross-build zig-based packages (mepo) without a full zig
# bootstrap. 0.14.1: what mepo 1.3.4 builds against.
HOST_ZIG_VERSION = 0.14.1
HOST_ZIG_SITE = https://ziglang.org/download/$(HOST_ZIG_VERSION)
HOST_ZIG_SOURCE = zig-x86_64-linux-$(HOST_ZIG_VERSION).tar.xz
HOST_ZIG_LICENSE = MIT
HOST_ZIG_LICENSE_FILES = LICENSE

# The tarball layout (bin/zig, lib/...) maps straight onto HOST_DIR
define HOST_ZIG_INSTALL_CMDS
	cp -a $(@D)/bin $(HOST_DIR)/
	cp -a $(@D)/lib $(HOST_DIR)/
endef

$(eval $(host-generic-package))
