################################################################################
#
# syncthing
#
################################################################################

SYNCTHING_VERSION = 2.1.6
SYNCTHING_SITE = $(call github,syncthing,syncthing,v$(SYNCTHING_VERSION))
SYNCTHING_LICENSE = MPL-2.0
SYNCTHING_LICENSE_FILES = LICENSE

SYNCTHING_GOMOD = github.com/syncthing/syncthing
SYNCTHING_BUILD_TARGETS = ./cmd/syncthing

# The web GUI is not shipped pre-generated: a plain "go build" fails
# because lib/api/auto/gui.files.go must be produced first (noassets.go
# only compiles behind the "noassets" tag). The generator is pure Go
# (script/genassets.go, run via go generate), so run it host-side; only
# the generated source feeds the target build. Fixed SOURCE_DATE_EPOCH
# keeps the generated file reproducible.
define SYNCTHING_GENERATE_GUI
	cd "$(@D)" && \
	SOURCE_DATE_EPOCH=1760000000 \
	$(HOST_GO_HOST_ENV) \
		$(GO_BIN) run script/genassets.go -o lib/api/auto/gui.files.go gui
endef
SYNCTHING_POST_EXTRACT_HOOKS += SYNCTHING_GENERATE_GUI

# GUI assets note: this step packs the web GUI into the binary. A headless
# build (without it) would need the "noassets" build tag instead.
# Config under /data/config/syncthing once the storage middle layer lands.

# Disabled by default: the user unit is installed but not preset-enabled.
# Enable on request with: systemctl --user enable --now syncthing
define SYNCTHING_INSTALL_INIT_SYSTEMD
	$(INSTALL) -D -m 0644 $(SYNCTHING_PKGDIR)/syncthing.service \
		$(TARGET_DIR)/usr/lib/systemd/user/syncthing.service
endef

$(eval $(golang-package))
