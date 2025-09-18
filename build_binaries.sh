#!/bin/bash

# build_binaries.sh
# Script to build precompiled binaries for different platforms

set -e

echo "🔧 Building precompiled binaries for SubLua..."

# Check if Rust is installed
if ! command -v cargo &> /dev/null; then
    echo "❌ Rust/Cargo not found. Please install Rust first."
    echo "   Visit: https://rustup.rs/"
    exit 1
fi

# Create precompiled directories
mkdir -p precompiled/{linux-x86_64,macos-x86_64,macos-aarch64,windows-x86_64}

# Build for current platform
echo "📦 Building for current platform..."
cd polkadot-ffi-subxt

# Detect current platform
OS_NAME=$(uname -s)
ARCH=$(uname -m)

echo "   Platform: $OS_NAME $ARCH"

# Build the library
cargo build --release

# Copy to appropriate directory
if [[ "$OS_NAME" == "Darwin" ]]; then
    if [[ "$ARCH" == "arm64" ]]; then
        PLATFORM_DIR="macos-aarch64"
        LIB_NAME="libpolkadot_ffi.dylib"
    else
        PLATFORM_DIR="macos-x86_64"
        LIB_NAME="libpolkadot_ffi.dylib"
    fi
elif [[ "$OS_NAME" == "Linux" ]]; then
    PLATFORM_DIR="linux-x86_64"
    LIB_NAME="libpolkadot_ffi.so"
else
    echo "❌ Unsupported platform: $OS_NAME"
    exit 1
fi

# Copy the built library
if [ -f "target/release/$LIB_NAME" ]; then
    cp "target/release/$LIB_NAME" "../precompiled/$PLATFORM_DIR/"
    echo "✅ Copied $LIB_NAME to precompiled/$PLATFORM_DIR/"
else
    echo "❌ Built library not found: target/release/$LIB_NAME"
    exit 1
fi

cd ..

echo ""
echo "🎉 Precompiled binary created!"
echo "   Platform: $PLATFORM_DIR"
echo "   Library: $LIB_NAME"
echo ""
echo "📋 To build for other platforms:"
echo "   1. Use cross-compilation with cargo"
echo "   2. Or build on each target platform"
echo "   3. Copy binaries to precompiled/<platform>/"
echo ""
echo "📁 Current precompiled structure:"
ls -la precompiled/*/
