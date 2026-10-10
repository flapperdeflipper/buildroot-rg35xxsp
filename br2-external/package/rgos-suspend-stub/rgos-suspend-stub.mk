################################################################################
#
# rgos-suspend-stub
#
################################################################################

# The stub sources are downloaded as an extra download; the package's main
# source is the U-Boot tarball (same pin as the uboot package: the stub is
# compiled from U-Boot's DRAM driver, and reusing the download keeps the two
# in lockstep for free).
RGOS_SUSPEND_STUB_VERSION = 712653d11230b2450061ddb8e25f31e072da7a48
RGOS_SUSPEND_STUB_SITE = $(UBOOT_SITE)
RGOS_SUSPEND_STUB_SOURCE = $(UBOOT_SOURCE)
RGOS_SUSPEND_STUB_DL_SUBDIR = uboot
RGOS_SUSPEND_STUB_LICENSE = GPL-2.0-or-later
RGOS_SUSPEND_STUB_LICENSE_FILES = stub-src/COPYING
RGOS_SUSPEND_STUB_INSTALL_TARGET = NO
RGOS_SUSPEND_STUB_INSTALL_IMAGES = YES

RGOS_SUSPEND_STUB_EXTRA_DOWNLOADS = \
	https://github.com/Jacob-Matthew-Cook/h700-suspend-stub/archive/$(RGOS_SUSPEND_STUB_VERSION).tar.gz \
	$(RGOS_ROCKNIX_ATF_PATCH_URL)

# TF-A (patched by the same allwinner suspend patch) provides the only
# header the stub needs from an ATF tree; extract it from that patch so both
# sides share one source of truth.
define RGOS_SUSPEND_STUB_EXTRACT_HEADER
	mkdir -p $(@D)/atf-include/plat/allwinner/sun50i_h616/include
	awk '/^diff .*sunxi_suspend_params\.h/ {f=1; next} \
	     /^diff / {f=0} \
	     f && /^\+/ && !/^\+\+\+/ {print substr($$0,2)}' \
	    $(RGOS_SUSPEND_STUB_DL_DIR)/001-allwinner-h616-psci-system-suspend.patch \
	    >$(@D)/atf-include/plat/allwinner/sun50i_h616/include/sunxi_suspend_params.h
endef

# Merge boards/h700/uboot-ddr3.fragment into the upstream defconfig, last
# value wins. LPDDR4=y from the base is dropped so the stub's type
# detection (first SUNXI_DRAM_H616_ match) sees LPDDR3.
define RGOS_SUSPEND_STUB_MERGE_DDR3_CONFIG
	$(TARGET_MAKE_ENV) awk \
	    'NR==FNR { if ($$0 ~ /^CONFIG_[A-Z0-9_]+=/) { k=$$0; sub(/=.*/, "", k); m[k]=$$0 } next } \
	     { if ($$0 ~ /^CONFIG_[A-Z0-9_]+=/) { k=$$0; sub(/=.*/, "", k); if (k in m) next } print } \
	     END { for (k in m) print m[k] }' \
	    $(BR2_EXTERNAL_RGOS_PATH)/boards/h700/uboot-ddr3.fragment \
	    $(@D)/configs/anbernic_rg35xx_h700_defconfig \
	    | sed -e '\|^CONFIG_SUNXI_DRAM_H616_LPDDR4=y|d' >$(@D)/stub-lpddr3.defconfig
endef

# The stub was written against U-Boot 2026.01;
# dram-size-test-revert.patch (applied by Buildroot at the patch step)
# reverts the one 2026.07 change its freestanding environment cannot build.
# This tree is the stub's private copy; the bootloaders build their own.
define RGOS_SUSPEND_STUB_BUILD_CMDS
	mkdir -p $(@D)/stub-src
	$(TAR) --strip-components=1 -C $(@D)/stub-src \
	    -xf $(RGOS_SUSPEND_STUB_DL_DIR)/$(RGOS_SUSPEND_STUB_VERSION).tar.gz
	cp $(@D)/configs/anbernic_rg35xx_h700_defconfig $(@D)/stub-lpddr4.defconfig
	$(RGOS_SUSPEND_STUB_MERGE_DDR3_CONFIG)
	$(RGOS_SUSPEND_STUB_EXTRACT_HEADER)
	$(foreach v,lpddr4 lpddr3,\
		mkdir -p $(@D)/stub-$(v) && \
		$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/stub-$(v) -f $(@D)/stub-src/Makefile \
			SRC_DIR=$(@D)/stub-src UBOOT_DIR=$(@D) ATF_DIR=$(@D)/atf-include \
			DEFCONFIG=$(@D)/stub-$(v).defconfig OUT=suspend_stub_$(v).bin \
			CROSS_COMPILE=$(TARGET_CROSS)$(sep))
endef

define RGOS_SUSPEND_STUB_INSTALL_IMAGES_CMDS
	cp $(@D)/stub-src/suspend_stub_lpddr4.bin $(BINARIES_DIR)/suspend_stub_lpddr4.bin
	cp $(@D)/stub-src/suspend_stub_lpddr3.bin $(BINARIES_DIR)/suspend_stub_lpddr3.bin
endef

$(eval $(generic-package))
