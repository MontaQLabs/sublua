<img src="https://github.com/user-attachments/assets/176ee468-6acb-43e5-8792-c16ff2ecd2d0" alt="SubLua SDK Logo Design" width="300">

# SubLua - Substrate SDK for Lua

A development SDK that brings Substrate blockchain functionality to Lua through FFI bindings.

**SubLua** = **Sub**strate + **Lua** - because sometimes you need to interact with Substrate chains from Lua.

## What This Is

This is a working proof-of-concept SDK that allows Lua scripts to:
- Connect to any Substrate-based blockchain
- Query account balances and chain state
- Create and sign transactions
- Submit transactions to the network

Built with a Rust FFI layer for cryptographic operations and a Lua interface for ease of use.

## The Need for SubLua

Before SubLua, integrating Substrate chains with Lua-based applications required complex workarounds or learning entirely new languages. This created a barrier for:

**Game Developers**: Popular game engines like LÖVE2D, Defold, and Corona SDK use Lua for scripting. Game developers wanting to add blockchain features (player-owned assets, token rewards, leaderboards) had no direct path to Substrate chains.

**Roblox Developers**: While Roblox uses Luau (not standard Lua), the concepts are similar. SubLua's HTTP proxy architecture could enable Roblox games to interact with Substrate chains through external services.

**IoT and Embedded Systems**: Many IoT devices and embedded systems use Lua for configuration and scripting (OpenWrt, NodeMCU, etc.). SubLua enables these devices to participate in Substrate networks for micropayments, data verification, or device authentication.

**Existing Lua Applications**: Millions of applications already use Lua - from web servers (OpenResty) to network equipment. SubLua lets these systems integrate blockchain functionality without major rewrites.

SubLua opens up the entire Substrate ecosystem to these use cases, enabling new types of applications that bridge traditional software with blockchain capabilities.

## What's Actually Implemented

### ✅ Core Features
- **Chain Connection**: Connect to any Substrate RPC endpoint
- **Account Management**: Generate addresses, check balances
- **Transaction Creation**: Build balance transfer transactions
- **Cryptographic Signing**: Sr25519 signatures via Rust FFI
- **Chain Queries**: Get runtime info, storage, account data

### ✅ Supported Chains
Tested and working with:
- Polkadot
- Kusama  
- Westend Testnet
- Paseo Testnet
- Any Substrate-based chain with standard pallets

### ✅ Transaction Types
Currently implemented:
- Balance transfers (`balances.transfer`)
- System remarks (`system.remark`)

## Architecture

```
┌─────────────────┐
│   Lua Scripts   │
├─────────────────┤
│   SubLua SDK    │
├─────────────────┤
│  Rust FFI Lib   │  ← Handles crypto operations
├─────────────────┤
│ Substrate Chain │
└─────────────────┘
```

## Quick Start

### Prerequisites
```bash
# Install Lua and LuaJIT
sudo pacman -S lua luajit  # Arch Linux
# or
sudo apt install lua5.1 luajit  # Ubuntu/Debian

# Install Lua dependencies
luarocks install luasocket lua-cjson
```

### Build
```bash
git clone https://github.com/MontaQLabs/sublua.git
cd sublua

# Build the Rust FFI library
cd polkadot-ffi
cargo build --release
cd ..

# Test the SDK
luajit example_game.lua
```

### Basic Usage

```lua
local sublua = require("sdk.init")

-- Connect to a Substrate chain
local rpc = sublua.rpc.new("wss://rpc.polkadot.io")
local config = sublua.chain_config.detect_from_url("wss://rpc.polkadot.io")

-- Create a signer from mnemonic
local signer = sublua.signer.from_mnemonic("your twelve word mnemonic here")
local address = signer:get_ss58_address(config.ss58_prefix)

-- Check balance
local account = rpc:get_account_info(address)
print("Balance: " .. account.data.free_tokens .. " " .. config.token_symbol)

-- Create a transfer
local transfer = sublua.extrinsic.balance_transfer({
    from = signer,
    to = "5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY",
    amount = 1000000000000,  -- 1 DOT in plancks
    config = config,
    nonce = account.nonce
})

-- Sign and submit
local signed = transfer:sign()
local tx_hash = rpc:author_submitExtrinsic(signed)
print("Transaction hash: " .. tx_hash)
```

## File Structure

```
sublua/
├── sdk/                    # Main SDK code
│   ├── init.lua           # SDK entry point
│   ├── ffi.lua            # FFI bindings to Rust
│   └── core/              # Core modules
│       ├── chain_config.lua  # Chain configuration detection
│       ├── extrinsic.lua     # Transaction building
│       ├── rpc.lua           # RPC client
│       ├── signer.lua        # Cryptographic signing
│       └── util.lua          # Utilities
├── polkadot-ffi/          # Rust FFI library
│   ├── src/lib.rs         # Main FFI exports
│   └── src/extrinsic.rs   # Transaction utilities
├── example_game.lua       # Complete usage example
└── README.md             # This file
```

## Current Limitations

- **Transaction Types**: Only balance transfers and system remarks implemented
- **Error Handling**: Basic error handling, could be more robust  
- **Testing**: Limited automated testing
- **Documentation**: Minimal inline documentation
- **Performance**: Not optimized for high-throughput applications

## Development Status

This is a **development SDK** - it works for basic use cases but needs more work for production use.

### What Works Well
- Basic Substrate integration
- Transaction creation and signing
- Multi-chain support through auto-detection
- Clean Lua API

### What Needs Work
- More transaction types (staking, governance, etc.)
- Better error handling and validation
- Comprehensive testing suite
- Performance optimization
- More complete documentation

## Example: DOT Catcher game in LOVE2D

![Screenshot From 2025-06-08 04-26-30](https://github.com/user-attachments/assets/cb1db54b-4c0a-40c6-9a7b-f200da78f6c8)

![Screenshot From 2025-06-08 04-26-09](https://github.com/user-attachments/assets/82969351-cf52-4c5f-a7b1-789a0d070392)

## Example: Complete Transfer

See `example_game.lua` for a full working example that:
1. Connects to Paseo testnet
2. Creates player accounts
3. Checks balances
4. Creates and signs a transfer transaction
5. Demonstrates various chain queries

## Why Lua?

Lua is lightweight, embeddable, and widely used in:
- Game development (World of Warcraft, Roblox, etc.)
- Network applications (nginx, OpenResty)
- Embedded systems
- Scripting and automation

SubLua makes Substrate accessible to these ecosystems without requiring developers to learn Rust or JavaScript.

## Contributing

This is early-stage development. Areas that need work:
- Additional transaction types
- Better error handling
- More comprehensive testing
- Documentation improvements
- Performance optimization

## License

MIT License - see LICENSE file for details.

---

*SubLua: Making Substrate accessible to Lua developers* 
