################################################################################
#
# glow
#
################################################################################

GLOW_VERSION = 3.0.0
GLOW_SITE = $(call github,charmbracelet,glow,v$(GLOW_VERSION))
GLOW_LICENSE = MIT
GLOW_LICENSE_FILES = LICENSE
GLOW_GOMOD = charm.land/glow/v3
GLOW_LDFLAGS = -X main.Version=$(GLOW_VERSION)

$(eval $(golang-package))
