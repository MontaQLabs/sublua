#!/bin/bash

# Sublua FFI Library Downloader
# Downloads the appropriate FFI library for your platform

set -e

echo "🔍 Sublua FFI Library Downloader"
echo "================================="

# Detect platform
OS_NAME=""
ARCH=""

if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    OS_NAME="windows"
    ARCH="x86_64"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS_NAME="macos"
    ARCH=$(uname -m)
    if [[ "$ARCH" == "arm64" ]]; then
        ARCH="aarch64"
    fi
else
    OS_NAME="linux"
    ARCH=$(uname -m)
fi

PLATFORM="${OS_NAME}-${ARCH}"

echo "🖥️  Detected platform: $PLATFORM"

# Determine file extension and name
if [[ "$OS_NAME" == "windows" ]]; then
    EXT=".dll"
    FILENAME="polkadot_ffi.dll"
elif [[ "$OS_NAME" == "macos" ]]; then
    EXT=".dylib"
    FILENAME="libpolkadot_ffi.dylib"
else
    EXT=".so"
    FILENAME="libpolkadot_ffi.so"
fi

# Create precompiled directory
mkdir -p "precompiled/$PLATFORM"

# Download URL
URL="https://github.com/MontaQLabs/sublua/releases/latest/download/$FILENAME"
LOCAL_PATH="precompiled/$PLATFORM/$FILENAME"

echo "📥 Downloading FFI library..."
echo "   URL: $URL"
echo "   Local path: $LOCAL_PATH"

# Download using curl or wget
if command -v curl >/dev/null 2>&1; then
    curl -L -o "$LOCAL_PATH" "$URL"
elif command -v wget >/dev/null 2>&1; then
    wget -O "$LOCAL_PATH" "$URL"
else
    echo "❌ Error: Neither curl nor wget found. Please install one of them."
    exit 1
fi

# Check if download was successful
if [[ -f "$LOCAL_PATH" ]]; then
    echo "✅ FFI library downloaded successfully!"
    echo "   Size: $(du -h "$LOCAL_PATH" | cut -f1)"
    echo ""
    echo "🚀 You can now use Sublua:"
    echo "   luajit -e \"local sublua = require('sdk.init'); sublua.ffi('./$LOCAL_PATH')\""
else
    echo "❌ Download failed!"
    exit 1
fi
