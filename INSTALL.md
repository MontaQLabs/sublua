# SubLua Installation Guide

This guide explains how to install SubLua as a proper Lua package, similar to `pip install` for Python.

## 🎯 Installation Methods

SubLua supports multiple installation methods to suit different use cases:

### Method 1: LuaRocks (Recommended for Development)

LuaRocks is the standard package manager for Lua, similar to `pip` for Python.

```bash
# Install dependencies first
luarocks install luasocket
luarocks install lua-cjson
luarocks install luasec

# Install SubLua
luarocks install sublua-scm-0.rockspec
```

**Pros:**
- Standard Lua package management
- Automatic dependency resolution
- Easy updates and uninstallation

**Cons:**
- Requires manual FFI library compilation
- Platform-specific setup needed

### Method 2: Automated Install Script (Recommended for Users)

```bash
# Clone the repository
git clone https://github.com/MontaQLabs/sublua.git
cd sublua

# Run the install script
chmod +x install.sh
./install.sh
```

**Pros:**
- Fully automated installation
- Handles all dependencies and FFI compilation
- Cross-platform support
- Comprehensive error checking

**Cons:**
- Requires cloning the repository
- Less flexible than manual installation

### Method 3: Makefile (Recommended for Contributors)

```bash
# Clone the repository
git clone https://github.com/MontaQLabs/sublua.git
cd sublua

# Install with one command
make install
```

**Pros:**
- Simple one-command installation
- Includes FFI library compilation
- Good for development workflow

**Cons:**
- Requires Make
- Less portable than other methods

### Method 4: Manual Installation

For advanced users who need custom configuration:

```bash
# 1. Install Lua dependencies
luarocks install luasocket lua-cjson luasec

# 2. Build FFI library
cd polkadot-ffi-subxt
cargo build --release
cd ..

# 3. Install SubLua
luarocks install sublua-scm-0.rockspec
```

## 🔧 Prerequisites

### Required Software

1. **Lua or LuaJIT** (5.1+)
   - Ubuntu/Debian: `sudo apt install lua5.3` or `sudo apt install luajit`
   - macOS: `brew install lua` or `brew install luajit`
   - Windows: Download from [Lua.org](https://www.lua.org/download.html)

2. **LuaRocks** (Package Manager)
   - Ubuntu/Debian: `sudo apt install luarocks`
   - macOS: `brew install luarocks`
   - Windows: Download from [LuaRocks.org](https://luarocks.org/)

3. **Rust** (For FFI Library Compilation)
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   source ~/.cargo/env
   ```

### Platform-Specific Requirements

#### Linux
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install build-essential pkg-config libssl-dev

# CentOS/RHEL/Fedora
sudo yum groupinstall "Development Tools"
sudo yum install openssl-devel
```

#### macOS
```bash
# Install Xcode command line tools
xcode-select --install

# Install dependencies via Homebrew
brew install openssl pkg-config
```

#### Windows
- Install [Visual Studio Build Tools](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022)
- Install [Git for Windows](https://git-scm.com/download/win)
- Use Windows Subsystem for Linux (WSL) for easier setup

## 🚀 Quick Start After Installation

```lua
-- Test your installation
local sdk = require("sdk.init")
print("✅ SubLua loaded successfully!")

-- Connect to a chain
local rpc = sdk.rpc.new("wss://westend-rpc.polkadot.io")

-- Create a signer
local signer = sdk.signer.from_mnemonic("your twelve word mnemonic phrase here")

-- Get account info
local account = rpc:get_account_info(signer:get_ss58_address(42))
print("Balance:", account.data.free_tokens)
```

## 🔍 How FFI Works in the Package

### FFI Library Compilation

SubLua uses a Rust FFI library (`polkadot-ffi-subxt`) that provides:

1. **Cryptographic Operations**: Sr25519 keypair management, signing
2. **Address Management**: SS58 address encoding/decoding
3. **Transaction Building**: SCALE encoding, extrinsic creation
4. **Chain Interaction**: Substrate client functionality

The FFI library is compiled to a shared library:
- **Linux**: `libpolkadot_ffi.so`
- **macOS**: `libpolkadot_ffi.dylib`
- **Windows**: `polkadot_ffi.dll`

### Library Discovery

The Lua FFI binding (`sdk/polkadot_ffi.lua`) automatically searches for the compiled library in:

1. System library paths (`/usr/lib/`, `/usr/local/lib/`)
2. LuaRocks installation directory
3. Relative paths from the SDK directory
4. Environment variables (`LD_LIBRARY_PATH`)

### FFI Integration

```lua
local ffi = require("ffi")
local polkadot_ffi = require("sdk.polkadot_ffi")

-- FFI library is automatically loaded
local lib = polkadot_ffi.lib

-- Call Rust functions through FFI
local result = lib.derive_sr25519_from_mnemonic(mnemonic_cstr)
```

## 🐛 Troubleshooting

### Common Issues

#### 1. FFI Library Not Found
```
Error: Unable to locate libpolkadot_ffi.so
```

**Solutions:**
- Ensure Rust is installed: `cargo --version`
- Rebuild FFI library: `cd polkadot-ffi-subxt && cargo build --release`
- Check library path: `find . -name "libpolkadot_ffi.so"`

#### 2. Missing Dependencies
```
Error: module 'luasocket' not found
```

**Solutions:**
- Install missing dependencies: `luarocks install luasocket lua-cjson luasec`
- Check LuaRocks path: `luarocks path`

#### 3. Rust Compilation Errors
```
Error: failed to compile polkadot-ffi-subxt
```

**Solutions:**
- Update Rust: `rustup update`
- Clean build: `cargo clean && cargo build --release`
- Check Rust toolchain: `rustup show`

#### 4. Permission Issues
```
Error: Permission denied
```

**Solutions:**
- Use `sudo` for system-wide installation
- Or install to user directory: `luarocks install --local`

### Verification Commands

```bash
# Check Lua installation
lua -v
luajit -v

# Check LuaRocks
luarocks --version

# Check Rust
cargo --version

# Test SubLua installation
lua -e "require('sdk.init'); print('SubLua OK')"

# Run examples
make example
make test
```

## 📦 Package Structure

After installation, SubLua provides:

```
/usr/local/share/lua/5.3/sdk/          # Lua modules
├── init.lua                           # Main SDK entry point
├── rpc.lua                           # RPC client
├── signer.lua                        # Cryptographic operations
├── chain_config.lua                  # Chain configuration
├── extrinsic_builder.lua             # Transaction building
├── extrinsic.lua                     # Transaction handling
├── metadata.lua                      # Chain metadata
├── util.lua                          # Utilities
└── polkadot_ffi.lua                  # FFI bindings

/usr/local/lib/lua/5.3/               # FFI libraries
└── polkadot_ffi.so                   # Compiled Rust library

/usr/local/share/sublua/              # Examples and docs
├── examples/
├── test/
└── docs/
```

## 🔄 Updates and Uninstallation

### Updating SubLua
```bash
# Via LuaRocks
luarocks update sublua

# Via Make
make clean && make install

# Via Script
./install.sh
```

### Uninstalling SubLua
```bash
# Via LuaRocks
luarocks remove sublua

# Via Make
make uninstall

# Manual cleanup
rm -rf /usr/local/share/lua/*/sdk/
rm -f /usr/local/lib/lua/*/polkadot_ffi.so
```

## 🤝 Getting Help

- **Documentation**: [docs.sublua.dev](https://docs.sublua.dev)
- **Issues**: [GitHub Issues](https://github.com/MontaQLabs/sublua/issues)
- **Discord**: [SubLua Community](https://discord.gg/sublua)
- **Examples**: Check the `examples/` directory

## 📄 License

SubLua is licensed under the MIT License. See [LICENSE](LICENSE) for details.
