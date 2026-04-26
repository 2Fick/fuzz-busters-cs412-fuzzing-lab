
# 1. LIBRARY SPECIFIC CONFIGURATION
LIB_NAME = png
LIB_VERSION = 1.6.37
LIB_DIR = libpng-$(LIB_VERSION)

DOWNLOAD_CMD = wget https://download.sourceforge.net/libpng/$(LIB_DIR).tar.gz && tar xf $(LIB_DIR).tar.gz

# 2. PATHS AND TARGETS
HARNESS_SRC = src/harness.c
SEEDS = seeds/
DICT = dictionaries/png.dict
AFL_CC = afl-clang-fast
STD_CC = gcc

.PHONY: all build fuzz fuzz-qemu plot clean build-docker

all: build

# 3. WHITE-BOX BUILD (Instrumented + ASan)
build:
	@echo "[*] Building libpng $(LIB_VERSION) with AFL++..."

	test -d $(LIB_DIR) || ($(DOWNLOAD_CMD))

	cd $(LIB_DIR) && \
	CC=$(AFL_CC) \
	CFLAGS="-fsanitize=address -g -O1" \
	LDFLAGS="-fsanitize=address" \
	./configure --disable-shared && \
	make -j$$(nproc)

	$(AFL_CC) -fsanitize=address -g -O1 $(HARNESS_SRC) \
		-I$(LIB_DIR) \
		$(LIB_DIR)/.libs/libpng16.a \
		-lz -lm \
		-o harness_whitebox

# 4. BLACK-BOX BUILD (Standard GCC)
build-qemu:
	@echo "[*] Building libpng (QEMU mode)..."

	test -d $(LIB_DIR) || ($(DOWNLOAD_CMD))

	cd $(LIB_DIR) && \
	CC=$(STD_CC) \
	CFLAGS="-g -O1" \
	./configure --disable-shared && \
	make -j$$(nproc)

	$(STD_CC) -g -O1 $(HARNESS_SRC) \
		-I$(LIB_DIR) \
		$(LIB_DIR)/.libs/libpng16.a \
		-lz -lm \
		-o harness_blackbox

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