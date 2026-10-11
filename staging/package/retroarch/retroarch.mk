################################################################################
#
# retroarch
#
################################################################################

RETROARCH_VERSION = 1.22.2
RETROARCH_SITE = $(call github,libretro,RetroArch,v$(RETROARCH_VERSION))
RETROARCH_LICENSE = GPL-3.0
RETROARCH_LICENSE_FILES = COPYING

RETROARCH_DEPENDENCIES = sdl2 alsa-lib freetype mesa3d

# RetroArch 1.22 has no meson build; the qb system (./configure + Makefile)
# takes --enable-X/--disable-X for every HAVE_X option. Video context is
# SDL2 (runs under labwc/Wayland like Rockbox does); GL context comes from
# SDL. Audio: alsa driver enabled, config default is the sdl2 driver (SDL
# routes to pipewire-pulse like mpv does).
RETROARCH_CONF_OPTS = \
	--prefix=/usr \
	--enable-sdl2 \
	--disable-sdl \
	--enable-egl \
	--enable-opengles \
	--enable-opengl \
	--enable-alsa \
	--enable-freetype \
	--enable-udev \
	--enable-zlib \
	--enable-threads \
	--enable-dynamic \
	--enable-dylib \
	--enable-configfile \
	--enable-rgui \
	--enable-ozone \
	--enable-xmb \
	--enable-gfx_widgets \
	--enable-libretrodb \
	--enable-networking \
	--enable-ssl \
	--enable-cheats \
	--enable-rewind \
	--enable-runahead \
	--disable-x11 \
	--disable-wayland \
	--disable-vulkan \
	--disable-kms \
	--disable-drm \
	--disable-gbm \
	--disable-pulse \
	--disable-pipewire \
	--disable-jack \
	--disable-oss \
	--disable-mpv \
	--disable-ffmpeg \
	--disable-lua \
	--disable-bluetooth \
	--disable-hid \
	--disable-libusb \
	--disable-caca \
	--disable-sixel \
	--disable-osmesa \
	--disable-discord \
	--disable-online_updater \
	--disable-update_assets \
	--disable-update_cores \
	--disable-shaderpipeline \
	--disable-slang \
	--disable-angle

define RETROARCH_CONFIGURE_CMDS
	cd "$(@D)" && $(TARGET_CONFIGURE_OPTS) $(TARGET_MAKE_ENV) \
		./configure $(RETROARCH_CONF_OPTS)
endef

define RETROARCH_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C "$(@D)"
endef

define RETROARCH_INSTALL_TARGET_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C "$(@D)" DESTDIR="$(TARGET_DIR)" install
endef

# Cores live in their own packages (libretro-*), installed into
# /usr/lib/libretro. retroarch.cfg needs libretro_directory=/usr/lib/libretro;
# see staging/system/NOTES.md for the intended device config.

$(eval $(generic-package))
