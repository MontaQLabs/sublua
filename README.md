

<img src="https://github.com/user-attachments/assets/176ee468-6acb-43e5-8792-c16ff2ecd2d0" alt="SubLua SDK Logo Design" width="300">

# SubLua - Substrate SDK for Lua

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Lua](https://img.shields.io/badge/Lua-5.1+-blue.svg)](https://www.lua.org/)
[![Substrate](https://img.shields.io/badge/Substrate-Compatible-green.svg)](https://substrate.io/)

SubLua is a high-performance Lua SDK for interacting with Substrate-based blockchains. It provides type-safe cryptographic operations, transaction submission, and chain data querying through a clean Lua API.

## 🚀 Features

- **Type-Safe Cryptography**: Sr25519 keypair management, signing, and address generation
- **Transaction Support**: Submit transactions to any Substrate-based blockchain
- **Chain Metadata**: Dynamic metadata fetching and parsing
- **Multi-Chain Support**: Works with Polkadot, Kusama, Westend, and custom chains
- **High Performance**: Optimized FFI bindings to Rust libraries
- **Production Ready**: Comprehensive error handling and testing

## 📦 Installation

SubLua follows a clean installation flow similar to `pip install` for Python.

### Prerequisites

- **LuaJIT** (required for FFI support)
- LuaRocks (Lua package manager)

> **Note**: SubLua requires LuaJIT for FFI functionality. Standard Lua is not supported.

### Clean Installation Flow

#### Step 1: Install Sublua SDK
```bash
# Install Sublua via LuaRocks
luarocks install sublua
```

#### Step 2: Download FFI Library
```bash
# Download the appropriate FFI library for your platform
./download_ffi.sh
```

#### Step 3: Use Sublua in Your Code
```lua
-- Load Sublua SDK
local sublua = require("sublua")

-- Load FFI library (auto-detects platform)
sublua.ffi()

-- Or specify path directly
sublua.ffi("./precompiled/macos-aarch64/libpolkadot_ffi.dylib")

-- Start using Sublua
local signer = sublua.signer().new()
local rpc = sublua.rpc().new("wss://rpc.polkadot.io")
```

### Alternative Installation Methods

#### Option 1: Automated Install Script
```bash
# Clone and install with one command
git clone https://github.com/MontaQLabs/sublua.git
cd sublua
chmod +x install.sh
./install.sh
```

#### Option 2: Manual Compilation
```bash
# Clone repository
git clone https://github.com/MontaQLabs/sublua.git
cd sublua

# Build FFI library
cd polkadot-ffi-subxt
cargo build --release

# Install Lua dependencies
luarocks install luasocket lua-cjson luasec

# Install SubLua
luarocks make sublua-0.1.2-1.rockspec
```

> 📖 **Detailed Installation Guide**: See [INSTALL.md](INSTALL.md) for comprehensive installation instructions, troubleshooting, and platform-specific setup.
> 
> 🚀 **Publishing Guide**: See [PUBLISHING.md](PUBLISHING.md) for instructions on publishing SubLua to LuaRocks repository.

## 🛠️ Development Commands

The Makefile provides convenient commands for development:

```bash
make install    # Install SubLua
make test       # Run test suite
make example    # Run basic usage example
make game       # Run game integration example
make clean      # Clean build artifacts
make uninstall  # Remove SubLua
make help       # Show all commands
```

## 🎯 Quick Start

```lua
local sdk = require("sdk.init")

-- Connect to a chain
local rpc = sdk.rpc.new("wss://westend-rpc.polkadot.io")

-- Create a signer from mnemonic
local signer = sdk.signer.from_mnemonic("your twelve word mnemonic phrase here")

-- Get account info
local account = rpc:get_account_info(signer:get_ss58_address(42))
print("Balance:", account.data.free_tokens, account.data.token_symbol)

-- Transfer tokens
local tx_hash = signer:transfer(rpc, "5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY", 1000000000000)
print("Transaction hash:", tx_hash)
```

## 📚 API Reference

### SDK Core

#### `sdk.rpc.new(url)`
Creates a new RPC client connection.

```lua
local rpc = sdk.rpc.new("wss://westend-rpc.polkadot.io")
```

#### `rpc:get_account_info(address)`
Fetches account information including balance and nonce.

```lua
local account = rpc:get_account_info("5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY")
print("Balance:", account.data.free_tokens)
print("Nonce:", account.nonce)
```

### Signer Management

#### `sdk.signer.from_mnemonic(mnemonic)`
Creates a signer from a mnemonic phrase.

```lua
local signer = sdk.signer.from_mnemonic("your twelve word mnemonic phrase here")
```

#### `signer:get_ss58_address(prefix)`
Generates an SS58 address for the specified network prefix.

```lua
local address = signer:get_ss58_address(42)  -- Westend
local address = signer:get_ss58_address(0)   -- Polkadot
```

#### `signer:transfer(rpc, destination, amount)`
Submits a balance transfer transaction.

```lua
local tx_hash = signer:transfer(rpc, "5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY", 1000000000000)
```

### Chain Configuration

#### `sdk.chain_config.detect_from_url(url)`
Automatically detects chain configuration from RPC URL.

```lua
local config = sdk.chain_config.detect_from_url("wss://westend-rpc.polkadot.io")
print("Token:", config.token_symbol)
print("Decimals:", config.token_decimals)
```

## 🔧 Advanced Usage

### Custom Chain Configuration

```lua
local config = {
    name = "Custom Chain",
    token_symbol = "CST",
    token_decimals = 12,
    ss58_prefix = 42,
    existential_deposit = 1000000000000
}

local rpc = sdk.rpc.new("wss://your-chain-rpc.com", config)
```

### Batch Transactions

```lua
-- Create multiple transactions
local batch = sdk.extrinsic_builder.new(rpc)
batch:balances_transfer(dest1, amount1)
batch:balances_transfer(dest2, amount2)

-- Submit batch
local tx_hash = signer:submit_batch(batch)
```

### Event Monitoring

```lua
-- Subscribe to events
local subscription = rpc:subscribe_events(function(event)
    if event.pallet == "Balances" and event.event == "Transfer" then
        print("Transfer:", event.data)
    end
end)
```

## 🧪 Testing

Run the test suite:

```bash
# Run all tests
luajit test/run_tests.lua

# Run specific test
luajit test/test_transfers.lua
```

## 📖 Examples

See the `examples/` directory for comprehensive examples:

- `examples/basic_usage.lua` - Basic SDK usage
- `examples/game_integration.lua` - Game integration example
- `examples/advanced_features.lua` - Advanced features demonstration

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Documentation**: [docs.sublua.dev](https://docs.sublua.dev)
- **Issues**: [GitHub Issues](https://github.com/your-org/sublua/issues)
- **Discord**: [SubLua Community](https://discord.gg/sublua)

## 🙏 Acknowledgments

- [Substrate](https://substrate.io/) - The blockchain framework
- [subxt](https://github.com/paritytech/subxt) - Rust Substrate client
- [LuaJIT](https://luajit.org/) - High-performance Lua implementation
