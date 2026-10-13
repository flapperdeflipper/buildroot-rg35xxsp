################################################################################
#
# zig (host toolchain)
#
################################################################################

# Official prebuilt zig for the build host. The build VM (lima on
# Apple Silicon) is aarch64 - hence the aarch64 host tarball; it still
# cross-builds for -Dtarget=aarch64-linux-gnu with bundled glibc stubs:
# no full compiler bootstrap. 0.14.1 = what mepo 1.3.4 builds against.
HOST_ZIG_VERSION = 0.14.1
HOST_ZIG_SITE = https://ziglang.org/download/$(HOST_ZIG_VERSION)
HOST_ZIG_SOURCE = zig-aarch64-linux-$(HOST_ZIG_VERSION).tar.xz
HOST_ZIG_LICENSE = MIT
HOST_ZIG_LICENSE_FILES = LICENSE

# The tarball keeps the binary at the top level (no bin/); install it as
# $(HOST_DIR)/bin/zig and drop lib/ next to it.
define HOST_ZIG_INSTALL_CMDS
	$(INSTALL) -D -m 0755 $(@D)/zig $(HOST_DIR)/bin/zig
	cp -a $(@D)/lib/. $(HOST_DIR)/lib/
endef

$(eval $(host-generic-package))
