################################################################################
#
# retroarch
#
################################################################################

RETROARCH_VERSION = 1.22.2
RETROARCH_SITE = $(call github,libretro,RetroArch,v$(RETROARCH_VERSION))
RETROARCH_LICENSE = GPL-3.0
RETROARCH_LICENSE_FILES = COPYING

RETROARCH_DEPENDENCIES = libsdl2 alsa-lib freetype

# UNTESTED (staged on wip/tooling). Decisions to confirm at build time:
# - Video context: SDL2 (simple, works under Wayland/labwc like Rockbox).
#   If the SDL GL context underperforms, try -Dsdl2=disabled -Dwayland=enabled
#   with the native wayland video context (libwayland-client + EGL).
# - GLES via Panfrost: opengles2 (mesa gives GLES3, RA picks GLES2/GLES3).
# - Option names follow RetroArch's meson_options.txt as of 1.22; adjust
#   whatever meson rejects.
RETROARCH_CONF_OPTS = \
	-Dbuild=release \
	-Dsdl2=enabled \
	-Degl=enabled \
	-Dopengles2=enabled \
	-Dwayland=enabled \
	-Dalsa=enabled \
	-Dfreetype=enabled \
	-Dx11=disabled \
	-Dvulkan=disabled \
	-Ddrm=disabled \
	-Djack=disabled \
	-Dpulse=disabled \
	-Dcoreaudio=disabled \
	-Dshaderc=disabled

# Cores live in their own packages (libretro-*), installed into
# /usr/lib/libretro. retroarch.cfg needs libretro_directory=/usr/lib/libretro;
# see staging/system/NOTES.md for the intended device config.

$(eval $(meson-package))
