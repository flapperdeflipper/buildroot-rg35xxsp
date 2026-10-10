################################################################################
#
# btop
#
################################################################################

BTOP_VERSION = 1.4.7
BTOP_SITE = $(call github,aristocratos,btop,v$(BTOP_VERSION))
BTOP_LICENSE = Apache-2.0
BTOP_LICENSE_FILES = LICENSE
# No GPU module for Panfrost; LTO only slows the build
BTOP_CONF_OPTS = -DBTOP_GPU=OFF -DBTOP_LTO=OFF
# btop refuses in-source builds
BTOP_SUPPORTS_IN_SOURCE_BUILD = NO

$(eval $(cmake-package))
