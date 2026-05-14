
# 1. LIBRARY SPECIFIC CONFIGURATION
LIB_NAME = png
LIB_VERSION = 1.2.56
LIB_DIR = libpng-$(LIB_VERSION)
# vanilla directory for black-box comparison
LIB_DIR_QEMU = $(LIB_DIR)_qemu
LIB_DIR_BUGGED = $(LIB_DIR)_bugged

# 2. PATHS AND TARGETS
HARNESS_SRC = src/harness.c
HARNESS_PERSISTENT_SRC = src/harness_persistent.c
SEEDS = seeds/
DICT = dictionaries/png.dict
AFL_CC = afl-clang-fast
STD_CC = gcc
PNG_TARBALL = libpng-$(LIB_VERSION).tar.gz
PNG_URL = https://download.sourceforge.net/libpng/$(PNG_TARBALL)

# Path to the AFL++ utility patches
AFL_PATCH = /AFLplusplus/utils/libpng_no_checksum/libpng-nocrc.patch

.PHONY: all build build-qemu build-bugged build-persistent build-nosanit fuzz fuzz-qemu fuzz-bugged fuzz-persistent fuzz-nosanit plot clean build-docker run-docker bootstrap-libpng help

all: build build-qemu build-persistent

# 3. WHITE-BOX BUILD (Instrumented + ASan + Patch)
bootstrap-libpng:
	@set -e; \
	if [ ! -d "libpng-$(LIB_VERSION)" ] || [ ! -d "libpng-$(LIB_VERSION)_qemu" ] || [ ! -d "libpng-$(LIB_VERSION)_bugged" ]; then \
		if [ ! -f "$(PNG_TARBALL)" ]; then \
			wget -q "$(PNG_URL)"; \
		fi; \
		rm -rf "libpng-$(LIB_VERSION)" "libpng-$(LIB_VERSION)_qemu" "libpng-$(LIB_VERSION)_bugged"; \
		tar xf "$(PNG_TARBALL)"; \
		mv "libpng-$(LIB_VERSION)" "libpng-$(LIB_VERSION)_qemu"; \
		tar xf "$(PNG_TARBALL)"; \
		cp -a "libpng-$(LIB_VERSION)" "libpng-$(LIB_VERSION)_bugged"; \
		python3 patches/insert_synthetic.py "libpng-$(LIB_VERSION)_bugged/pngread.c" || true; \
	fi

build:
	@echo "[*] Setting up instrumented build..."
	$(MAKE) bootstrap-libpng
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
	$(MAKE) bootstrap-libpng
	# Apply CRC patch even for vanilla (to allow mutations to reach code)
	cd $(LIB_DIR_QEMU) && (patch -p0 -N < $(AFL_PATCH) || true)
	cd $(LIB_DIR_QEMU) && \
	CC=$(STD_CC) CFLAGS="-g -O1" ./configure --disable-shared && \
	make -j$$(nproc)
	# Build the black-box harness
	$(STD_CC) -g -O1 $(HARNESS_SRC) \
		-I$(LIB_DIR_QEMU) $(LIB_DIR_QEMU)/.libs/libpng12.a \
		-lz -lm -o harness_blackbox

# 5. BUGGED BUILD (Instrumented + ASan + synthetic heap overflow for validation)
build-bugged:
	@echo "[*] Setting up bugged build for fuzzer validation..."
	$(MAKE) bootstrap-libpng
	cd $(LIB_DIR_BUGGED) && (patch -p0 -N < $(AFL_PATCH) || true)
	cd $(LIB_DIR_BUGGED) && \
	CC=$(AFL_CC) CFLAGS="-fsanitize=address -g -O1" ./configure --disable-shared && \
	make -j$$(nproc)
	$(AFL_CC) -fsanitize=address -g -O1 $(HARNESS_SRC) \
		-I$(LIB_DIR_BUGGED) $(LIB_DIR_BUGGED)/.libs/libpng12.a \
		-lz -lm -o harness_bugged

# 6. PERSISTENT MODE BUILD (for Q8)
build-persistent: build
	@echo "[*] Building persistent mode harness..."
	$(AFL_CC) -fsanitize=address -g -O1 $(HARNESS_PERSISTENT_SRC) \
		-I$(LIB_DIR) $(LIB_DIR)/.libs/libpng12.a \
		-lz -lm -o harness_persistent

# 7. NO-SANITIZER BUILD (for Q8 baseline benchmark)
build-nosanit:
	@echo "[*] Building no-sanitizer instrumented harness for Q8 benchmark..."
	$(MAKE) bootstrap-libpng
	cd $(LIB_DIR) && (patch -p0 -N < $(AFL_PATCH) || true)
	cd $(LIB_DIR) && \
	CC=$(AFL_CC) CFLAGS="-g -O1" ./configure --disable-shared && \
	make -j$$(nproc)
	$(AFL_CC) -g -O1 $(HARNESS_SRC) \
		-I$(LIB_DIR) $(LIB_DIR)/.libs/libpng12.a \
		-lz -lm -o harness_nosanit

# 6. EXECUTION TARGETS
fuzz: build
	rm -rf findings/default
	afl-fuzz -i $(SEEDS) -o findings -x $(DICT) -- ./harness_whitebox @@

fuzz-qemu: build-qemu
	rm -rf findings-qemu/default
	afl-fuzz -Q -i $(SEEDS) -o findings-qemu -x $(DICT) -- ./harness_blackbox @@

fuzz-bugged: build-bugged
	rm -rf findings-bugged/default
	afl-fuzz -i $(SEEDS) -o findings-bugged -x $(DICT) -- ./harness_bugged @@

fuzz-persistent: build-persistent
	rm -rf findings-persistent/default
	afl-fuzz -i $(SEEDS) -o findings-persistent -x $(DICT) -- ./harness_persistent

fuzz-nosanit: build-nosanit
	rm -rf findings-nosanit/default
	afl-fuzz -i $(SEEDS) -o findings-nosanit -x $(DICT) -- ./harness_nosanit @@

plot:
	afl-plot findings/default/ plot_output/
	afl-plot findings-qemu/default/ plot_output_qemu/
	afl-plot findings-bugged/default/ plot_output_bugged/

clean:
	rm -rf findings/ findings-qemu/ findings-bugged/ findings-persistent/ findings-nosanit/ plot_output/ plot_output_qemu/ plot_output_bugged/
	rm -f harness_whitebox harness_blackbox harness_persistent harness_bugged harness_nosanit
	rm -rf $(LIB_DIR) $(LIB_DIR_QEMU) $(LIB_DIR_BUGGED) *.tar.gz

build-docker:
	docker build -t cs412-fuzz-env .

run-docker:
	mkdir -p findings findings-qemu findings-bugged plot_output plot_output_qemu plot_output_bugged
	docker run -it --rm \
		--user $(shell id -u):$(shell id -g) \
		-v $(shell pwd)/findings:/fuzzing/findings \
		-v $(shell pwd)/findings-qemu:/fuzzing/findings-qemu \
		-v $(shell pwd)/findings-bugged:/fuzzing/findings-bugged \
		cs412-fuzz-env bash

# 8. HELP TARGET
help:
	@echo ""
	@echo "CS-412 Fuzzing Lab -- Available Makefile targets:"
	@echo "=================================================="
	@echo ""
	@echo "  Setup:"
	@echo "    build-docker       Build the Docker container (AFL++ + libpng)"
	@echo "    run-docker         Launch the container with findings dirs mounted"
	@echo "    bootstrap-libpng   Download and extract libpng source trees"
	@echo ""
	@echo "  Build:"
	@echo "    build              Instrumented white-box harness (AFL + ASan)"
	@echo "    build-qemu         Uninstrumented black-box harness (gcc, QEMU mode)"
	@echo "    build-bugged       Instrumented harness with synthetic heap overflow"
	@echo "    build-persistent   Persistent-mode harness for Q8 (requires build)"
	@echo "    build-nosanit      Instrumented harness without ASan (Q8 benchmark)"
	@echo "    all                Run build + build-qemu + build-persistent"
	@echo ""
	@echo "  Fuzz:"
	@echo "    fuzz               White-box instrumented campaign"
	@echo "    fuzz-qemu          Black-box QEMU campaign"
	@echo "    fuzz-bugged        Validate fuzzer on bugged (synthetic vuln) build"
	@echo "    fuzz-persistent    Persistent-mode campaign (Q8)"
	@echo "    fuzz-nosanit       No-sanitizer campaign (Q8 baseline benchmark)"
	@echo ""
	@echo "  Reporting:"
	@echo "    plot               Generate afl-plot graphs for all campaigns"
	@echo "    clean              Remove all findings, plots, and build artifacts"
	@echo ""
	@echo "  Typical workflow:"
	@echo "    make build-docker -> make run-docker -> make fuzz -> make plot"
	@echo ""
