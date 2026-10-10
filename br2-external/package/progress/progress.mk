################################################################################
#
# progress
#
################################################################################

PROGRESS_VERSION = 0.17
PROGRESS_SITE = $(call github,Xfennec,progress,v$(PROGRESS_VERSION))
PROGRESS_LICENSE = GPL-3.0+
PROGRESS_LICENSE_FILES = LICENSE
PROGRESS_DEPENDENCIES = host-pkgconf ncurses

define PROGRESS_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) $(TARGET_CONFIGURE_OPTS) \
		PKG_CONFIG=$(PKG_CONFIG_HOST_BINARY)
endef

define PROGRESS_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/progress $(TARGET_DIR)/usr/bin/progress
endef

$(eval $(generic-package))
