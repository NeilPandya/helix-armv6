#!/bin/bash
# With this setup, if `TARGET_CPU` is not set, the compilation will use the default
# "generic" target CPU and the corresponding default compiler flags in
# helix-loader/src/grammar.rs. This ensures that the compilation process will
# not throw an error if `TARGET_CPU` is not set.

clear && \

# ASCII Art Banner
cat << "EOF"

###x.        .|
d#####x,   ,v||
 '+#####v||||||
    ,v|||||+'.      _     _           _
 ,v|||||^'>####    | |   | |   ___   | | (_) __  __
|||||^'  .v####    | |___| |  /   \  | |  _  \ \/ /
||||=..v#####P'    |  ___  | /  ^  | | | |  \  /
''v'>#####P'       | |   | | |  ---  | | | |  /  \
,######/P||x.      |_|   |_|  \___/  |_| |_| /_/\_\
####P' "x|||||,
|/'       'x|||    A post-modern modal text editor.
 '           '|

EOF

echo "*=====================*"
echo "| Helix ARMv6 Builder |"
echo "*=====================*"

# Define constants
LOG_DIR="logs"
CURRENT_TIME=$(date +%Y%m%d_%H%M%S)

# Prompt user to continue or quit
read -n 1 -s -r -p "Press any key to continue or press q to quit..." key
echo
if [[ $key == "q" ]]; then
    echo "Exiting script..."
    exit 0
fi

# Check if logs directory exists, create if it doesn't
if [ ! -d "$LOG_DIR" ]; then
    echo "Creating logs directory..."
    mkdir -p "$LOG_DIR" && chmod -v -R 777 "$LOG_DIR"
else
    echo "Logs directory already exists"
    # Ensure proper permissions even if directory already exists
    chmod -v -R 777 "$LOG_DIR"
fi

# Set environment variables
export CARGO_BUILD_JOBS="$(($(nproc) * 95 / 100))"
export RUST_LOG=debug
export CC_DEBUG=1
export RUST_BACKTRACE=full
export CARGO_LOG=debug
export CARGO_PROFILE_OPT_BUILD_OVERRIDE_DEBUG=1
export TARGET_CPU="arm1176jzf-s"
export HELIX_DEFAULT_RUNTIME="/usr/local/lib/helix/runtime"
export RUSTFLAGS="\
    -C target-cpu=arm1176jzf-s \
    -C linker=arm-linux-gnueabi-gcc \
    -C target-feature=-crt-static \
    -C link-arg=-Wl,--as-needed \
    -C link-arg=-Wl,--gc-sections \
    -C link-arg=-L/usr/lib/arm-linux-gnueabi \
    -C link-arg=-L/usr/arm-linux-gnueabi/lib \
    --cfg tokio_unstable \
    -C link-arg=-Wl,--dynamic-linker=/lib/ld-linux-armhf.so.3"

# Print environment variables and prompt user to continue
echo "Environment variables set:"
printenv
read -n 1 -s -r -p "Press any key to continue or press q to quit..." key
echo
if [[ $key == "q" ]]; then
    echo "Exiting script..."
    exit 0
fi

# Clean up target directory
echo "Cleaning target directory..."
cargo clean

# Clean up runtime directory
echo "Cleaning runtime directory..."
rm -v runtime/grammars/*.so

# Install the required Rust target
rustup target add arm-unknown-linux-gnueabihf && \
echo "Installed Target(s): " && \
rustup target list --installed

# Build Helix for armv6 architecture
echo "Starting build process..."
cargo build \
    --target=arm-unknown-linux-gnueabi \
    --profile opt \
    --locked \
    -vv \
    --message-format=json-diagnostic-rendered-ansi \
    --color=always \
    2> >(tee "$LOG_DIR/helix.armv6.build.errors.${CURRENT_TIME}.log" >&2) \
    | grep -v "Compiling" \
    | grep -v "Finished" \
    | grep -v "Fresh" \
    > >(tee "$LOG_DIR/helix.armv6.build.output.${CURRENT_TIME}.log")

# Capture build status
BUILD_STATUS=$?

# Clean up old logs only if build generated new ones
if [ $BUILD_STATUS -eq 0 ]; then
    echo "Cleaning old log files and archives..."
    find "$LOG_DIR" -type f -name "*.log" -not -name "*${CURRENT_TIME}*" -delete -print
    find "$LOG_DIR" -type f -name "build_logs_*.tar.gz" -not -name "*${CURRENT_TIME}*" -delete -print

    # Compress current logs
    if ! command -v pigz &> /dev/null; then
        echo "Warning: pigz not found, falling back to gzip"
        tar -czf "$LOG_DIR/build_logs_${CURRENT_TIME}.tar.gz" "$LOG_DIR"/*.log
    else
        tar -cf - "$LOG_DIR"/*.log | pigz -p $(($(nproc) * 95 / 100)) > "$LOG_DIR/build_logs_${CURRENT_TIME}.tar.gz"
    fi
    echo "Log cleanup and compression complete"
else
    echo "Build failed with status $BUILD_STATUS"
fi

exit $BUILD_STATUS
