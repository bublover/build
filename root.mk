################################################################
# Root Makefile of the whole project
################################################################

# Basic Definitions
################################################################
BOARD	?= 96b_ivy5661
BOOT	:= mcuboot
KERNEL	:= zephyr

# Directories and Files
################################################################
SHELL		:= /bin/bash
PWD		:= $(shell pwd)
PRJDIR		:= $(PWD)

app_DIR		:= $(PRJDIR)/apps
boot_DIR	:= $(PRJDIR)/$(BOOT)
kernel_DIR	:= $(PRJDIR)/$(KERNEL)

BUILD_DIR		:= $(PRJDIR)/output
boot_BUILD_DIR		:= $(BUILD_DIR)/$(BOOT)
kernel_BUILD_DIR	:= $(BUILD_DIR)/$(KERNEL)

BOOT_BIN	:= $(boot_BUILD_DIR)/$(KERNEL)/$(KERNEL).bin
KERNEL_BIN	:= $(kernel_BUILD_DIR)/$(KERNEL)/$(KERNEL).bin

DIST_DIR	:= $(PRJDIR)/output/images
BOOT_DIST_BIN	:= $(DIST_DIR)/$(BOOT)-pubkey.bin
KERNEL_DIST_BIN	:= $(DIST_DIR)/$(KERNEL)-signed-ota.bin

IMGTOOL = $(boot_DIR)/scripts/imgtool.py

# Macros
################################################################
# MESSAGE Macro -- display a message in bold type
MESSAGE = echo "\n$(TERM_BOLD)>>> $(1)$(TERM_RESET)"
TERM_BOLD := $(shell tput smso 2>/dev/null)
TERM_RESET := ${shell tput rmso 2>/dev/null}

# Macro of Building Targets
# $(1): Target
# $(2): Dir of main
define MAKE_TARGET
.PHONY: $(1)
$(1): 
	@ $(call MESSAGE,"Building $(1)")
	@ if [ ! -d $($(1)_BUILD_DIR) ]; then mkdir -p $($(1)_BUILD_DIR); fi
	(source $(kernel_DIR)/zephyr-env.sh && cd $($(1)_BUILD_DIR) && \
	if [ ! -f Makefile ] ; then cmake -DBOARD=$(BOARD) -DCONF_FILE=prj$(findstring _debug,$(1)).conf $(2); fi && \
	make \
	)
endef

# Macro of Cleaning Targets
# $(1): Target
# $(2): Target suffix
# $(3): .config
define CLEAN_TARGET
.PHONY: $(if $(2),$(1)-$(2),$(1))
$(if $(2),$(1)-$(2),$(1)):
	@ $(call MESSAGE,"Cleaning $(1)")
	@ if [ -d $($(1)_BUILD_DIR) ]; then make -C $($(1)_BUILD_DIR) $(2); fi
endef

SIGNING_KEY	?= $(boot_DIR)/root-rsa-2048.pem
BOOT_HEADER_LEN	:= 0x1000
FLASH_ALIGNMENT	:= 8

# Macro of Signing KERNEL Image
# $(1): input file
# $(2): output file
define SIGN_KERNEL_IMAGE
	@ $(IMGTOOL) sign \
		--key $(SIGNING_KEY) \
		--header-size $(BOOT_HEADER_LEN) \
		--align $(FLASH_ALIGNMENT) \
		--version 1.2 \
		--slot-size 0x60000 \
		$(1) $(2)
endef

# Targets
################################################################
DEFAULT_TARGETS		:= boot kernel
DIST_TARGETS		:= $(DEFAULT_TARGETS) 
ALL_TARGETS		:= $(DEFAULT_TARGETS)
CLEAN_TARGETS		:= $(addsuffix -clean,$(ALL_TARGETS))

.PHONY: dist
dist: $(DIST_TARGETS)
	@ if [ ! -d $(DIST_DIR) ]; then install -d $(DIST_DIR); fi
	@ install $(BOOT_BIN) $(BOOT_DIST_BIN)
	$(call SIGN_KERNEL_IMAGE,$(KERNEL_BIN),$(KERNEL_DIST_BIN))

.PHONY: clean
clean: $(CLEAN_TARGETS)

.PHONY: distclean
distclean:
	@ if [ -d $(BUILD_DIR) ]; then rm -rf $(BUILD_DIR); fi

# Respective Targets
################################################################

# Build Targets
$(eval $(call MAKE_TARGET,boot,$(boot_DIR)/boot/zephyr))

$(eval $(call MAKE_TARGET,kernel,$(app_DIR)/repeater))

# Clean Targets
$(foreach target,$(ALL_TARGETS),$(eval $(call CLEAN_TARGET,$(target),clean)))
