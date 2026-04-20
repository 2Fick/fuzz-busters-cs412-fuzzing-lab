# ==========================================
# 1. LIBRARY SPECIFIC CONFIGURATION
# ==========================================
# TODO : Once you choose a library, fill these in:
LIB_NAME = [my_library]
LIB_VERSION = [e.g., 1.2.56]
LIB_DIR = $(LIB_NAME)-$(LIB_VERSION)

# Example: wget https://... or git clone https://...
DOWNLOAD_CMD = @echo "Error: No download command defined in Makefile" && exit 1

# ==========================================
# 2. PATHS AND TARGETS
# ==========================================
HARNESS_SRC = src/harness.c
SEEDS = seeds/
DICT = dictionaries/[library].dict
AFL_CC = afl-clang-fast
STD_CC = gcc

.PHONY: all build fuzz fuzz-qemu plot clean build-docker

all: build

# 3. WHITE-BOX BUILD (Instrumented + ASan)
build:
	@echo "[*] Downloading and building $(LIB_NAME) with instrumentation..."
	# 1. Download library if not present
	test -d $(LIB_DIR) || ($(DOWNLOAD_CMD))
	# 2. Apply patches (e.g., CRC removal)
	# patch -p0 < patches/nocrc.patch
	# 3. Build library with AFL compiler and ASan
	cd $(LIB_DIR) && \
	CC=$(AFL_CC) CFLAGS="-fsanitize=address -g -O1" ./configure --disable-shared && \
	make -j$$(nproc)
	# 4. Build harness
	$(AFL_CC) -fsanitize=address -g -O1 $(HARNESS_SRC) \
		-I$(LIB_DIR) $(LIB_DIR)/.libs/lib$(LIB_NAME).a \
		-lz -lm -o harness_whitebox

# 4. BLACK-BOX BUILD (Standard GCC)
build-qemu:
	@echo "[*] Building $(LIB_NAME) for QEMU mode..."
	# Similar to above but:
	# CC=$(STD_CC) CFLAGS="-g -O1" ./configure ...
	# $(STD_CC) -g -O1 $(HARNESS_SRC) ... -o harness_blackbox

# 5. EXECUTION TARGETS
fuzz: build
	afl-fuzz -i $(SEEDS) -o findings -x $(DICT) -- ./harness_whitebox @@

fuzz-qemu: build-qemu
	afl-fuzz -Q -i $(SEEDS) -o findings-qemu -x $(DICT) -- ./harness_blackbox @@

plot:
	afl-plot findings/default/ plot_output/
	afl-plot findings-qemu/default/ plot_output_qemu/

clean:
	rm -rf findings/ findings-qemu/ plot_output/ plot_output_qemu/
	rm -f harness_whitebox harness_blackbox

build-docker:
	docker build -t cs412-fuzz-env .