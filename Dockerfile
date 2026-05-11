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

# Download libpng 1.2.56 and extract two copies: one original and one that we will patch with a synthetic bug
RUN wget https://download.sourceforge.net/libpng/libpng-1.2.56.tar.gz && \
    # Extract original (untouched) copy
    tar xf libpng-1.2.56.tar.gz && \
    mv libpng-1.2.56 libpng-1.2.56 && \
    # Extract a second copy which we will patch inside the image
    tar xf libpng-1.2.56.tar.gz && \
    mv libpng-1.2.56 libpng-1.2.56_bugged && \
    # Apply container-only synthetic bug to the bugged tree only
    python3 /fuzzing/patches/insert_synthetic.py libpng-1.2.56_bugged/pngread.c || true && \
    chown -R ubuntu:ubuntu /fuzzing

# Environment variables to optimize AFL++ behavior in Docker
ENV AFL_SKIP_CPUFREQ=1
ENV AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1

# The container stays open for you to run 'make' targets manually
CMD ["/bin/bash"]