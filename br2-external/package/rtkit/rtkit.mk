################################################################################
#
# rtkit
#
################################################################################

# UNTESTED (staged on wip/tooling, never built yet). See NOTES.md.

# RealtimeKit: the D-Bus service that grants SCHED_FIFO/RT scheduling to
# user processes (pipewire's module-rt asks it over the SYSTEM bus). The
# daemon itself holds CAP_SYS_NICE, which user services cannot get - the
# reason module-rt stays SCHED_OTHER without it (roadmap audio item).
RTKIT_VERSION = 0.13
RTKIT_SITE = $(call github,heftig,rtkit,v$(RTKIT_VERSION))
RTKIT_LICENSE = GPL-3.0-or-later
RTKIT_LICENSE_FILES = COPYING
# polkit-gobject-1 is optional upstream; the tree ships no polkit, the
# D-Bus policy (org.freedesktop.RealtimeKit1.conf) is the access control.
RTKIT_DEPENDENCIES = dbus libcap host-pkgconf host-meson host-xxd

RTKIT_CONF_OPTS = \
	-Dinstalled_tests=false \
	-Dlibsystemd=enabled \
	-Ddbus_rulesdir=/usr/share/dbus-1/system.d \
	-Ddbus_systemservicedir=/usr/share/dbus-1/system-services \
	-Ddbus_interfacedir=/usr/share/dbus-1/interfaces \
	-Dsystemd_systemunitdir=/usr/lib/systemd/system

# rtkit-daemon drops privileges to a dedicated system user
define RTKIT_USERS
	rtkit -1 rtkit -1 * - - -
endef

define RTKIT_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/lib/systemd/system-preset
	$(INSTALL) -D -m 0644 $(RTKIT_PKGDIR)/files/usr/lib/systemd/system-preset/52-rgos-rtkit.preset \
		$(TARGET_DIR)/usr/lib/systemd/system-preset/52-rgos-rtkit.preset
endef

$(eval $(meson-package))
