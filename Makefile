C1541   = c1541
AS = acme

TAG := $(shell git describe --tags --abbrev=0 || svnversion --no-newline)
TAG_DEPLOY_DOT := $(shell git describe --tags --long --dirty=_m | sed 's/-g[0-9a-f]\+//' | tr _- -.)
TAG_DEPLOY := $(shell git describe --tags --abbrev=0 --dirty=_M | tr _. -_)
GIT_HASH := $(shell git rev-parse --short HEAD)

X64 = x64
X64_OPTS = -warp
ifdef VICE_X64SC
    X64 = x64sc
    X64_OPTS += +confirmonexit
else
    X64_OPTS += +confirmexit
endif
DEBUGCART = 1
ifeq ($(DEBUGCART),1)
    X64_OPTS += -debugcart
endif

SRC_DIR = forth_src
BUILD_DIR = build
CONST_DIR = $(BUILD_DIR)/const
GEN_FINAL_DIR = $(BUILD_DIR)/gen-final
GEN_DEPLOY_DIR = $(BUILD_DIR)/gen-deploy
SRC_NAMES_CONST = base debug v asm gfx gfxdemo rnd sin ls turtle fractals \
    sprite doloop sys labels mml mmldemo sid spritedemo test testcore \
    testcoreplus tester format require compat timer float viceutil \
    wordlist io open dos
SRC_NAMES_GEN = turnkey
# (deploy suffix must match 'base*' filename in durexforth.asm)
SRCS_CONST = $(addprefix $(CONST_DIR)/,$(addsuffix .fs,$(SRC_NAMES_CONST)))
SRCS_GEN = $(addprefix $(GEN_FINAL_DIR)/,$(addsuffix .fs,$(SRC_NAMES_GEN)))
SRCS_GEN_DEPLOY = $(addprefix $(GEN_DEPLOY_DIR)/,$(addsuffix .fs,$(SRC_NAMES_GEN)))
PETS_CONST = $(SRCS_CONST:.fs=.pet)
PETS_GEN = $(SRCS_GEN:.fs=.pet)
PETS_GEN_DEPLOY = $(SRCS_GEN_DEPLOY:.fs=.pet)
ifeq ($(DEBUGCART),1)
    SRC_NAMES_GEN_FINAL =
    SRC_NAMES_GEN_TMP = $(SRC_NAMES_GEN)
else
    SRC_NAMES_GEN_FINAL = $(SRC_NAMES_GEN)
    SRC_NAMES_GEN_TMP =
endif

M4_OPTS =
M4_OPTS_DEPLOY = -DDEPLOY

EMPTY_FILE = _empty.txt
SEPARATOR_NAME1 = '=-=-=-=-=-=-=-=,s'
SEPARATOR_NAME2 = '=-------------=,s'
SEPARATOR_NAME3 = '=-=---=-=---=-=,s'

DF = durexforth
# deploy 1571 (d71) or 1581 (d81); e.g. make IMAGE_SUF=d81 deploy
IMAGE_SUF = d64
DF_DEPLOY = $(DF)-$(TAG_DEPLOY)
IMAGE = $(DF).$(IMAGE_SUF)

all:	$(IMAGE)

%.pet: %.fs $(BUILD_DIR)/header
	cat $(BUILD_DIR)/header $< | ext/petcom - > $@

deploy: $(IMAGE) cart.asm
	rm -rf deploy
	mkdir deploy
	$(MAKE) -C docs
	cp docs/durexforth.pdf deploy/$(DF_DEPLOY).pdf
	cp $(IMAGE) deploy/$(DF_DEPLOY).$(IMAGE_SUF)
	$(X64) $(X64_OPTS) deploy/$(DF_DEPLOY).$(IMAGE_SUF)
	for forth in $(SRC_NAMES_GEN_TMP); do \
        $(C1541) -attach deploy/$(DF_DEPLOY).$(IMAGE_SUF) -delete $$forth; \
        $(C1541) -attach deploy/$(DF_DEPLOY).$(IMAGE_SUF) -write $(GEN_FINAL_DIR)/$$forth.pet $$forth; \
    done;
	# make cartridge
	c1541 -attach deploy/$(DF_DEPLOY).$(IMAGE_SUF) -read durexforth
	mv durexforth $(BUILD_DIR)/durexforth
	@$(AS) cart.asm
	cartconv -t simon -i $(BUILD_DIR)/cart.bin -o deploy/$(DF_DEPLOY).crt -n "DUREXFORTH $(TAG_DEPLOY_DOT)"

durexforth.prg: *.asm
	$(AS) durexforth.asm

$(BUILD_DIR) $(CONST_DIR) $(GEN_FINAL_DIR) $(GEN_DEPLOY_DIR):
	mkdir -p $@

$(SRCS_CONST): | $(CONST_DIR)

$(SRCS_GEN): | $(GEN_FINAL_DIR)

$(SRCS_GEN_DEPLOY): | $(GEN_DEPLOY_DIR)

$(BUILD_DIR)/header: | $(BUILD_DIR)

$(BUILD_DIR)/header:
	echo -n "aa" > $@

$(CONST_DIR)/%.fs: $(SRC_DIR)/%.fs
	cp $< $@

$(GEN_FINAL_DIR)/%.fs: $(SRC_DIR)/%.m4
	m4 $(M4_OPTS) < $< > $@

$(GEN_DEPLOY_DIR)/%.fs: $(SRC_DIR)/%.m4
	m4 $(M4_OPTS_DEPLOY) < $< > $@

$(IMAGE): durexforth.prg Makefile ext/petcom $(SRCS_CONST) $(SRCS_GEN) $(SRCS_GEN_DEPLOY) \
        $(PETS_CONST) $(PETS_GEN) $(PETS_GEN_DEPLOY)
	touch $(EMPTY_FILE)
	$(C1541) -format "durexforth,DF"  $(IMAGE_SUF) $@ # > /dev/null
	$(C1541) -attach $@ -write durexforth.prg durexforth # > /dev/null
	$(C1541) -attach $@ -write $(EMPTY_FILE) $(SEPARATOR_NAME1) # > /dev/null
	$(C1541) -attach $@ -write $(EMPTY_FILE) $(TAG_DEPLOY_DOT),s # > /dev/null
	$(C1541) -attach $@ -write $(EMPTY_FILE) '  '$(GIT_HASH),s # > /dev/null
	$(C1541) -attach $@ -write $(EMPTY_FILE) $(SEPARATOR_NAME2) # > /dev/null
# $(C1541) -attach $@ -write debug.bak
	for forth in $(SRC_NAMES_CONST); do \
        $(C1541) -attach $@ -write $(CONST_DIR)/$$forth.pet $$forth; \
    done;
	for forth in $(SRC_NAMES_GEN_FINAL); do \
        $(C1541) -attach $@ -write $(GEN_FINAL_DIR)/$$forth.pet $$forth; \
    done;
	for forth in $(SRC_NAMES_GEN_TMP); do \
        $(C1541) -attach $@ -write $(GEN_DEPLOY_DIR)/$$forth.pet $$forth; \
    done;
	$(C1541) -attach $@ -write $(EMPTY_FILE) $(SEPARATOR_NAME3) # > /dev/null
	rm -f $(EMPTY_FILE)

clean:
	$(MAKE) -C docs clean
	rm -f *.lbl *.prg *.$(IMAGE_SUF)
	rm -rf $(BUILD_DIR) deploy
