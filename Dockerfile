FROM rust:1.76.0-slim-bookworm

LABEL org.opencontainers.image.title="Rust ARMv6 Cross-Compilation Image" \
    org.opencontainers.image.description="Cross-compilation environment from x86_64 to armv6 using Rust" \
    org.opencontainers.image.version="0.0.1" \
    org.opencontainers.image.source="https://github.com/neilpandya/helix-armv6/" \
    org.opencontainers.image.url="https://hub.docker.com/r/neilpandya/rust" \
    org.opencontainers.image.authors="dev@neilpandya.com" \
    org.opencontainers.image.vendor="Neil Pandya"

# Install required packages for cross-compilation to armv6l
RUN apt-get update && \
    apt-get install -y \
    pkg-config \
    pigz \
    git \
    gcc-arm-linux-gnueabihf \
    g++-arm-linux-gnueabihf \
    gcc-arm-linux-gnueabi \
    g++-arm-linux-gnueabi \
    libgcc-s1-armhf-cross \
    libc6-armel-cross \
    libc6-armhf-cross \
    libc6-dev-armhf-cross \
    libc6-dev-armel-cross \
    libssl-dev \
    cmake \
    binutils-arm-linux-gnueabihf \
    binutils-arm-linux-gnueabi \
    ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["bash"]
