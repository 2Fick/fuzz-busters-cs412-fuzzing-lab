
# 1. LIBRARY SPECIFIC CONFIGURATION
LIB_NAME = png
LIB_VERSION = 1.2.56
LIB_DIR = libpng-$(LIB_VERSION)
# vanilla directory for black-box comparison
LIB_DIR_QEMU = $(LIB_DIR)_qemu

# 2. PATHS AND TARGETS
HARNESS_SRC = src/harness.c
HARNESS_PERSISTENT_SRC = src/harness_persistent.c
SEEDS = seeds/
DICT = dictionaries/png.dict
AFL_CC = afl-clang-fast
STD_CC = gcc

# Path to the AFL++ utility patches
AFL_PATCH = /AFLplusplus/utils/libpng_no_checksum/libpng-nocrc.patch

.PHONY: all build build-qemu build-persistent fuzz fuzz-qemu plot clean build-docker

all: build build-qemu build-persistent

# 3. WHITE-BOX BUILD (Instrumented + ASan + Patch)
build:
	@echo "[*] Setting up instrumented build..."
	# Apply the CRC patch (Educational requirement)
	cd $(LIB_DIR) && (patch -p0 -N < $(AFL_PATCH) || true)
	# Configure and compile with AFL compiler
	cd $(LIB_DIR) && \
	CC=$(AFL_CC) CFLAGS="-fsanitize=address -g -O1" ./configure --disable-shared && \
	make -j$$(nproc)
	# Build the white-box harness
	$(AFL_CC) -fsanitize=address -g -O1 $(HARNESS_SRC) \
		-I$(LIB_DIR) $(LIB_DIR)/.libs/libpng12.a \
		-lz -lm -o harness_whitebox

# 4. BLACK-BOX BUILD (Standard GCC, no instrumentation, no sanitizers)
build-qemu:
	@echo "[*] Setting up uninstrumented build for QEMU..."
	# Apply CRC patch even for vanilla (to allow mutations to reach code)
	cd $(LIB_DIR_QEMU) && (patch -p0 -N < $(AFL_PATCH) || true)
	cd $(LIB_DIR_QEMU) && \
	CC=$(STD_CC) CFLAGS="-g -O1" ./configure --disable-shared && \
	make -j$$(nproc)
	# Build the black-box harness
	$(STD_CC) -g -O1 $(HARNESS_SRC) \
		-I$(LIB_DIR_QEMU) $(LIB_DIR_QEMU)/.libs/libpng12.a \
		-lz -lm -o harness_blackbox

# 5. PERSISTENT MODE BUILD (for Q8)
build-persistent:
	@echo "[*] Building persistent mode harness..."
	$(AFL_CC) -fsanitize=address -g -O1 $(HARNESS_PERSISTENT_SRC) \
		-I$(LIB_DIR) $(LIB_DIR)/.libs/libpng12.a \
		-lz -lm -o harness_persistent

# 6. EXECUTION TARGETS
fuzz: build
	afl-fuzz -i $(SEEDS) -o findings -x $(DICT) -- ./harness_whitebox @@

fuzz-qemu: build-qemu
	afl-fuzz -Q -i $(SEEDS) -o findings-qemu -x $(DICT) -- ./harness_blackbox @@

plot:
	afl-plot findings/default/ plot_output/
	afl-plot findings-qemu/default/ plot_output_qemu/

clean:
	rm -rf findings/ findings-qemu/ plot_output/ plot_output_qemu/
	rm -f harness_whitebox harness_blackbox harness_persistent
	rm -rf $(LIB_DIR) $(LIB_DIR_QEMU) *.tar.gz

build-docker:
	docker build -t cs412-fuzz-env .