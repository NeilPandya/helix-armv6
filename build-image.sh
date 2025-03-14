#!/bin/bash

clear && \

# Build the Docker image with BuildKit.
docker buildx build \
    -t neilpandya/rust:1.76.0-slim-bookworm-crosscompile-armv6 . \
    --load
