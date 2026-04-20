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

# TODO: Once the library is chosen, add any specific dependencies here
# e.g., RUN apt-get install -y libjpeg-dev for SDL image support

# Set up working directory
WORKDIR /fuzzing

# Copy the local repository (harness, patches, etc.) into the container
COPY . .

# Environment variables to optimize AFL++ behavior in Docker
ENV AFL_SKIP_CPUFREQ=1
ENV AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1

# The container stays open for you to run 'make' targets manually
CMD ["/bin/bash"]