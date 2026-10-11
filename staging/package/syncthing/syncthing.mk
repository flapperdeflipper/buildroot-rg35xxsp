################################################################################
#
# syncthing
#
################################################################################

SYNCTHING_VERSION = 2.1.6
SYNCTHING_SITE = $(call github,syncthing,syncthing,v$(SYNCTHING_VERSION))
SYNCTHING_LICENSE = MPL-2.0
SYNCTHING_LICENSE_FILES = LICENSE

SYNCTHING_GOMOD = github.com/syncthing/syncthing/v2
SYNCTHING_BUILD_TARGETS = ./cmd/syncthing

# UNTESTED (staged on wip/tooling, never built yet):
# - If the binary starts without its web GUI assets, add a pre-build step
#   that runs `go run build.go assets` (packs gui/ into the binary).
# - Ship a systemd user unit (systemd/user/syncthing.service in the
#   syncthing source) rather than a system service; the design keeps user
#   things in the session.
# - Consider `--no-default-folder` and a config under /data/config/syncthing
#   when the storage middle layer lands.

$(eval $(golang-package))
