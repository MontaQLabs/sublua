#!/bin/bash

# SubLua Installation Script
# Handles FFI library compilation and package installation

set -e

echo "🚀 Installing SubLua..."

# Check prerequisites
check_prerequisites() {
    echo "🔍 Checking prerequisites..."
    
    # Check for Lua
    if ! command -v lua &> /dev/null && ! command -v luajit &> /dev/null; then
        echo "❌ Lua or LuaJIT not found. Please install Lua 5.1+ or LuaJIT."
        exit 1
    fi
    
    # Check for LuaRocks
    if ! command -v luarocks &> /dev/null; then
        echo "❌ LuaRocks not found. Please install LuaRocks."
        echo "   Visit: https://luarocks.org/"
        exit 1
    fi
    
    # Check for Rust
    if ! command -v cargo &> /dev/null; then
        echo "❌ Rust/Cargo not found. Please install Rust."
        echo "   Visit: https://rustup.rs/"
        exit 1
    fi
    
    echo "✅ Prerequisites check passed!"
}

# Install dependencies
install_dependencies() {
    echo "📦 Installing Lua dependencies..."
    luarocks install luasocket
    luarocks install lua-cjson
    luarocks install luasec
    echo "✅ Dependencies installed!"
}

# Build FFI library
build_ffi() {
    echo "🔧 Building FFI library..."
    cd polkadot-ffi-subxt
    cargo build --release
    cd ..
    echo "✅ FFI library built!"
}

# Install SubLua
install_sublua() {
    echo "📥 Installing SubLua package..."
    luarocks install sublua-scm-0.rockspec
    echo "✅ SubLua installed!"
}

# Verify installation
verify_installation() {
    echo "🧪 Verifying installation..."
    lua -e "local sdk = require('sdk.init'); print('✅ SubLua loaded successfully!')"
    echo "✅ Installation verified!"
}

# Main installation process
main() {
    check_prerequisites
    install_dependencies
    build_ffi
    install_sublua
    verify_installation
    
    echo ""
    echo "🎉 SubLua installation complete!"
    echo ""
    echo "Quick start:"
    echo "  local sdk = require('sdk.init')"
    echo "  local rpc = sdk.rpc.new('wss://westend-rpc.polkadot.io')"
    echo ""
    echo "Run examples:"
    echo "  make example  # Basic usage"
    echo "  make game     # Game integration"
    echo "  make test     # Run tests"
}

# Run main function
main "$@"