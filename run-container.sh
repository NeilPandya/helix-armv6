#!/bin/bash

clear && \

# Run the container
docker run \
    --name rust-bookworm-slim-crosscompile-armv6 \
    --hostname crosscompile-helix-armv6 \
    --rm \
    -it \
    -v "$PWD"/:/helix-armv6 \
    -w /helix-armv6 \
    neilpandya/rust:1.76.0-slim-bookworm-crosscompile-armv6
