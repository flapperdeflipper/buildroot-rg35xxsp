################################################################################
#
# weechat
#
################################################################################

WEECHAT_VERSION = 4.10.1
WEECHAT_SOURCE = weechat-$(WEECHAT_VERSION).tar.xz
WEECHAT_SITE = https://weechat.org/files/src
WEECHAT_LICENSE = GPL-3.0+
WEECHAT_LICENSE_FILES = COPYING
WEECHAT_DEPENDENCIES = host-pkgconf ncurses libcurl gnutls libgcrypt zlib zstd cjson \
	$(TARGET_NLS_DEPENDENCIES)
WEECHAT_CONF_OPTS = \
	-DENABLE_HEADLESS=OFF \
	-DENABLE_SPELL=OFF \
	-DENABLE_PERL=OFF \
	-DENABLE_RUBY=OFF \
	-DENABLE_LUA=OFF \
	-DENABLE_TCL=OFF \
	-DENABLE_GUILE=OFF \
	-DENABLE_JAVASCRIPT=OFF \
	-DENABLE_PHP=OFF \
	-DENABLE_MAN=OFF \
	-DENABLE_DOC=OFF \
	-DENABLE_TESTS=OFF

ifeq ($(BR2_SYSTEM_ENABLE_NLS),y)
WEECHAT_CONF_OPTS += -DENABLE_NLS=ON
else
WEECHAT_CONF_OPTS += -DENABLE_NLS=OFF
endif

ifeq ($(BR2_PACKAGE_PYTHON3),y)
WEECHAT_DEPENDENCIES += python3
WEECHAT_CONF_OPTS += -DENABLE_PYTHON=ON
else
WEECHAT_CONF_OPTS += -DENABLE_PYTHON=OFF
endif

$(eval $(cmake-package))
