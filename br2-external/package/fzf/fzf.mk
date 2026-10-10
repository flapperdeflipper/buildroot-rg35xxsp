################################################################################
#
# fzf
#
################################################################################

FZF_VERSION = 0.74.4
FZF_SITE = $(call github,junegunn,fzf,v$(FZF_VERSION))
FZF_LICENSE = MIT
FZF_LICENSE_FILES = LICENSE
FZF_GOMOD = github.com/junegunn/fzf
FZF_LDFLAGS = -X main.version=$(FZF_VERSION) -X main.revision=rgos

$(eval $(golang-package))
