#!/bin/bash
# SubLua Installer
# One-line installation: curl -sSL https://raw.githubusercontent.com/your-org/sublua/main/install.sh | bash

set -e

echo "🚀 SubLua Installer"
echo "==================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
check_prereq() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}❌ $1 not found${NC}"
        echo "Please install $1 first:"
        case $1 in
            "luajit")
                echo "  macOS: brew install luajit"
                echo "  Ubuntu: sudo apt-get install luajit"
                ;;
            "cargo")
                echo "  Visit: https://rustup.rs/"
                ;;
            "luarocks")
                echo "  Visit: https://luarocks.org/"
                ;;
        esac
        exit 1
    fi
    echo -e "${GREEN}✅ $1 found${NC}"
}

echo "Checking prerequisites..."
check_prereq "luajit"
check_prereq "cargo"
check_prereq "luarocks"

# Clone repository
echo -e "\n${YELLOW}📦 Cloning SubLua repository...${NC}"
if [ -d "sublua" ]; then
    echo "Repository already exists, updating..."
    cd sublua
    git pull origin main
else
    git clone https://github.com/your-org/sublua.git
    cd sublua
fi

# Install dependencies
echo -e "\n${YELLOW}📦 Installing Lua dependencies...${NC}"
luarocks install luasocket
luarocks install lua-cjson
luarocks install luasec

# Build FFI library
echo -e "\n${YELLOW}🔧 Building FFI library...${NC}"
cd polkadot-ffi-subxt
cargo build --release
cd ..

# Install SubLua
echo -e "\n${YELLOW}📦 Installing SubLua...${NC}"
luarocks install sublua-scm-0.rockspec

# Test installation
echo -e "\n${YELLOW}🧪 Testing installation...${NC}"
if luajit -e "local sdk = require('sdk.init'); print('✅ SDK loaded successfully')"; then
    echo -e "${GREEN}✅ Installation successful!${NC}"
else
    echo -e "${RED}❌ Installation test failed${NC}"
    exit 1
fi

echo -e "\n${GREEN}🎉 SubLua installed successfully!${NC}"
echo ""
echo "📚 Next steps:"
echo "  1. Run: luajit examples/basic_usage.lua"
echo "  2. Run: luajit test/run_tests.lua"
echo "  3. Check: docs/API.md for API reference"
echo ""
echo "🔗 Quick start:"
echo "  local sdk = require('sdk.init')"
echo "  local rpc = sdk.rpc.new('wss://westend-rpc.polkadot.io')"
echo ""
echo "📖 Documentation: https://github.com/your-org/sublua"
