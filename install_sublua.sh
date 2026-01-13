#!/bin/bash
#
# SubLua One-Line Installer
# =========================
# Install with: curl -sSL https://raw.githubusercontent.com/MontaQLabs/sublua/main/install_sublua.sh | bash
#
# This script:
# 1. Detects your operating system and architecture
# 2. Installs LuaJIT if not present
# 3. Installs LuaRocks if not present
# 4. Installs SubLua from LuaRocks
# 5. Downloads the precompiled FFI library for your platform
# 6. Verifies the installation
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
}

print_step() {
    echo -e "${YELLOW}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "  $1"
}

# Detect OS and Architecture
detect_platform() {
    OS=""
    ARCH=""
    
    case "$(uname -s)" in
        Linux*)     OS="linux";;
        Darwin*)    OS="macos";;
        MINGW*|MSYS*|CYGWIN*) OS="windows";;
        *)          OS="unknown";;
    esac
    
    case "$(uname -m)" in
        x86_64|amd64)   ARCH="x86_64";;
        arm64|aarch64)  ARCH="aarch64";;
        *)              ARCH="unknown";;
    esac
    
    PLATFORM="${OS}-${ARCH}"
    
    print_info "Operating System: $OS"
    print_info "Architecture: $ARCH"
    print_info "Platform: $PLATFORM"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install LuaJIT
install_luajit() {
    print_step "Checking LuaJIT..."
    
    if command_exists luajit; then
        LUAJIT_VERSION=$(luajit -v 2>&1 | head -1)
        print_success "LuaJIT already installed: $LUAJIT_VERSION"
        return 0
    fi
    
    print_info "LuaJIT not found. Installing..."
    
    case "$OS" in
        macos)
            if command_exists brew; then
                brew install luajit
            else
                print_error "Homebrew not found. Please install Homebrew first:"
                print_info "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
                exit 1
            fi
            ;;
        linux)
            if command_exists apt-get; then
                sudo apt-get update
                sudo apt-get install -y luajit
            elif command_exists dnf; then
                sudo dnf install -y luajit
            elif command_exists pacman; then
                sudo pacman -S --noconfirm luajit
            elif command_exists apk; then
                sudo apk add luajit
            else
                print_error "Could not detect package manager. Please install LuaJIT manually."
                exit 1
            fi
            ;;
        windows)
            print_error "On Windows, please install LuaJIT manually from: https://luajit.org/download.html"
            print_info "Or use chocolatey: choco install luajit"
            exit 1
            ;;
        *)
            print_error "Unsupported OS. Please install LuaJIT manually."
            exit 1
            ;;
    esac
    
    if command_exists luajit; then
        print_success "LuaJIT installed successfully"
    else
        print_error "LuaJIT installation failed"
        exit 1
    fi
}

# Install LuaRocks
install_luarocks() {
    print_step "Checking LuaRocks..."
    
    if command_exists luarocks; then
        LUAROCKS_VERSION=$(luarocks --version 2>&1 | head -1)
        print_success "LuaRocks already installed: $LUAROCKS_VERSION"
        return 0
    fi
    
    print_info "LuaRocks not found. Installing..."
    
    case "$OS" in
        macos)
            if command_exists brew; then
                brew install luarocks
            else
                print_error "Homebrew not found."
                exit 1
            fi
            ;;
        linux)
            if command_exists apt-get; then
                sudo apt-get install -y luarocks
            elif command_exists dnf; then
                sudo dnf install -y luarocks
            elif command_exists pacman; then
                sudo pacman -S --noconfirm luarocks
            elif command_exists apk; then
                sudo apk add luarocks
            else
                print_error "Could not detect package manager. Please install LuaRocks manually."
                exit 1
            fi
            ;;
        windows)
            print_error "On Windows, please install LuaRocks manually from: https://luarocks.org/"
            exit 1
            ;;
        *)
            print_error "Unsupported OS. Please install LuaRocks manually."
            exit 1
            ;;
    esac
    
    if command_exists luarocks; then
        print_success "LuaRocks installed successfully"
    else
        print_error "LuaRocks installation failed"
        exit 1
    fi
}

# Install SubLua from LuaRocks
install_sublua() {
    print_step "Installing SubLua from LuaRocks..."
    
    # Check if already installed
    if luarocks show sublua >/dev/null 2>&1; then
        SUBLUA_VERSION=$(luarocks show sublua 2>&1 | grep -m1 "sublua" | awk '{print $2}')
        print_success "SubLua already installed: $SUBLUA_VERSION"
        
        read -p "Do you want to upgrade to the latest version? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi
    
    luarocks install sublua
    
    if luarocks show sublua >/dev/null 2>&1; then
        print_success "SubLua installed successfully"
    else
        print_error "SubLua installation failed"
        exit 1
    fi
}

# Download precompiled FFI library
download_ffi_library() {
    print_step "Downloading precompiled FFI library..."
    
    # Determine library filename
    case "$OS" in
        macos)   LIB_NAME="libpolkadot_ffi.dylib";;
        linux)   LIB_NAME="libpolkadot_ffi.so";;
        windows) LIB_NAME="polkadot_ffi.dll";;
        *)       print_error "Unsupported OS"; exit 1;;
    esac
    
    # Standard install directory (SubLua will auto-find this)
    INSTALL_DIR="$HOME/.sublua/lib"
    mkdir -p "$INSTALL_DIR"
    
    # Download URLs (try multiple)
    URLS=(
        "https://github.com/MontaQLabs/sublua/releases/latest/download/$LIB_NAME"
        "https://github.com/MontaQLabs/sublua/releases/download/v0.3.0/$LIB_NAME"
    )
    
    print_info "Install directory: $INSTALL_DIR"
    
    # Try each URL
    DOWNLOADED=false
    for URL in "${URLS[@]}"; do
        print_info "Trying: $URL"
        if command_exists curl; then
            if curl -sSL -f -o "$INSTALL_DIR/$LIB_NAME" "$URL" 2>/dev/null; then
                DOWNLOADED=true
                break
            fi
        elif command_exists wget; then
            if wget -q -O "$INSTALL_DIR/$LIB_NAME" "$URL" 2>/dev/null; then
                DOWNLOADED=true
                break
            fi
        fi
    done
    
    if $DOWNLOADED; then
        chmod +x "$INSTALL_DIR/$LIB_NAME" 2>/dev/null || true
        print_success "FFI library installed to: $INSTALL_DIR/$LIB_NAME"
        print_info "SubLua will automatically find this library - no env vars needed!"
    else
        print_info "Release binary not available for $PLATFORM."
        print_info "You may need to build from source:"
        print_info "  https://github.com/MontaQLabs/sublua#building-from-source"
        return 1
    fi
}

# Verify installation
verify_installation() {
    print_step "Verifying installation..."
    
    # Create test script
    TEST_SCRIPT=$(mktemp)
    cat > "$TEST_SCRIPT" << 'EOF'
local sublua = require("sublua")
print("SubLua version: " .. sublua.version)

-- Try to load FFI
local ok, err = pcall(function()
    sublua.ffi()
end)

if ok then
    print("FFI loaded successfully!")
    
    -- Test signer creation
    local signer = sublua.signer().from_mnemonic("bottom drive obey lake curtain smoke basket hold race lonely fit walk")
    local address = signer:get_ss58_address(0)
    print("Test address: " .. address)
    print("\n✓ SubLua is fully functional!")
else
    print("FFI not loaded: " .. tostring(err))
    print("\nSubLua Lua modules are installed.")
    print("To use blockchain features, you need the FFI library.")
    print("See: https://github.com/MontaQLabs/sublua#building-from-source")
end
EOF
    
    echo ""
    if luajit "$TEST_SCRIPT" 2>/dev/null; then
        print_success "Installation verified!"
    else
        print_info "Lua modules installed. FFI may need manual setup."
    fi
    
    rm -f "$TEST_SCRIPT"
}

# Print usage instructions
print_usage() {
    print_header "🎉 SubLua Installation Complete!"
    
    echo "Quick Start:"
    echo ""
    echo "  1. Create a new Lua file:"
    echo ""
    echo "     local sublua = require('sublua')"
    echo "     sublua.ffi()  -- Load FFI"
    echo ""
    echo "     local signer = sublua.signer().from_mnemonic('your mnemonic here')"
    echo "     print('Address:', signer:get_ss58_address(0))"
    echo ""
    echo "  2. Run with LuaJIT:"
    echo ""
    echo "     luajit your_script.lua"
    echo ""
    echo "Documentation: https://github.com/MontaQLabs/sublua"
    echo "LuaRocks:      https://luarocks.org/modules/montaqlabs/sublua"
    echo ""
}

# Main installation flow
main() {
    print_header "🚀 SubLua Installer"
    
    print_step "Detecting platform..."
    detect_platform
    
    if [ "$OS" = "unknown" ] || [ "$ARCH" = "unknown" ]; then
        print_error "Could not detect platform. Please install manually."
        exit 1
    fi
    
    echo ""
    install_luajit
    echo ""
    install_luarocks
    echo ""
    install_sublua
    echo ""
    download_ffi_library
    echo ""
    verify_installation
    echo ""
    print_usage
}

# Run main
main "$@"
