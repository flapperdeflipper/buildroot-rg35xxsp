################################################################################
#
# prettyping
#
################################################################################

PRETTYPING_VERSION = 1.1.0
PRETTYPING_SITE = $(call github,denilsonsa,prettyping,v$(PRETTYPING_VERSION))
PRETTYPING_LICENSE = MIT
PRETTYPING_LICENSE_FILES = LICENSE

define PRETTYPING_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/prettyping $(TARGET_DIR)/usr/bin/prettyping
endef

$(eval $(generic-package))
