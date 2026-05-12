# Use the official AFL++ image as a base
FROM aflplusplus/aflplusplus:latest

# Install common build dependencies for C libraries
RUN apt-get update && apt-get install -y \
    build-essential \
    automake \
    autoconf \
    libtool \
    wget \
    git \
    zlib1g-dev \
    libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Set up working directory
WORKDIR /fuzzing

# Copy the local repository (harness, patches, etc.) into the container
COPY . .

# Download libpng 1.2.56 and extract three copies: instrumented, QEMU, and bugged
RUN wget https://download.sourceforge.net/libpng/libpng-1.2.56.tar.gz && \
    tar xf libpng-1.2.56.tar.gz && \
    cp -a libpng-1.2.56 libpng-1.2.56_qemu && \
    cp -a libpng-1.2.56 libpng-1.2.56_bugged && \
    # Apply synthetic heap overflow to the bugged tree only
    python3 /fuzzing/patches/insert_synthetic.py libpng-1.2.56_bugged/pngread.c || true && \
    mkdir -p findings findings-qemu findings-bugged plot_output plot_output_qemu plot_output_bugged && \
    chown -R ubuntu:ubuntu /fuzzing

# Environment variables to optimize AFL++ behavior in Docker
ENV AFL_SKIP_CPUFREQ=1
ENV AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1

# The container stays open for you to run 'make' targets manually
CMD ["/bin/bash"]