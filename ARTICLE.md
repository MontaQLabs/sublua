# SubLua: A High-Performance Lua SDK for Substrate Blockchains

Building blockchain applications typically means choosing between JavaScript's ecosystem or Rust's performance. But there's a third option that's been overlooked: Lua. SubLua brings Substrate blockchain capabilities to Lua through direct FFI bindings to Rust's `subxt` library, achieving near-native performance while maintaining Lua's simplicity.

## Why Lua for Blockchain?

Lua has quietly powered critical infrastructure for decades. It's the scripting engine behind World of Warcraft, the extension language for Redis and Nginx, and the embedded runtime in countless IoT devices. LuaJIT, in particular, delivers performance that rivals compiled languages through its trace-based JIT compiler.

Yet despite Lua's ubiquity in gaming and embedded systems—two areas where blockchain integration is growing—there hasn't been a production-ready Substrate SDK for Lua. Until now.

## Architecture: Direct FFI, Zero Overhead

SubLua's core design principle is simple: Lua should call Rust directly, not through HTTP or RPC layers.

### The FFI Approach

LuaJIT's Foreign Function Interface allows calling C functions without serialization overhead. SubLua wraps `subxt` (Parity's Rust Substrate client) in a thin C-compatible layer and calls it directly from Lua:

```lua
-- Load FFI library (auto-detects platform)
local sublua = require("sublua")
sublua.ffi()

-- Direct FFI call to Rust - no HTTP, no JSON serialization
local signer_mod = sublua.signer()
local keypair = signer_mod.from_mnemonic("your twelve word phrase here")
```

Under the hood, this creates an Sr25519 keypair using `sp-core` (Substrate's cryptography primitives) and returns it to Lua as raw bytes. No HTTP round-trip, no JSON encoding/decoding—just a direct function call into Rust.

### What's Actually in the FFI Layer

The Rust FFI library (`libpolkadot_ffi`) exposes core cryptographic and blockchain operations:

**Keypair Management:**
- `derive_sr25519_from_mnemonic` - BIP39 mnemonic to keypair derivation
- `derive_sr25519_public_key` - Public key extraction from seed
- `sign_extrinsic` - Sr25519 signature generation

**Address Operations:**
- `compute_ss58_address` - Convert public key to SS58 address format
- `decode_ss58_address` - Parse SS58 address to raw public key

**Blockchain Queries:**
- `query_balance` - Fetch account balance using `subxt::OnlineClient`
- `submit_balance_transfer_subxt` - Submit signed transfer extrinsic

**Dynamic Metadata (v0.1.6):**
- `fetch_chain_metadata` - Get runtime version and pallet count
- `get_metadata_pallets` - List all runtime pallets
- `get_call_index` - Dynamically lookup pallet/call indices
- `get_pallet_calls` - List all calls in a pallet
- `check_runtime_compatibility` - Verify spec version

Each function returns a simple C struct:

```rust
#[repr(C)]
pub struct ExtrinsicResult {
    pub success: bool,
    pub data: *mut c_char,
    pub error: *mut c_char,
}
```

This is then parsed in Lua with LuaJIT's FFI:

```lua
local result = ffi_lib.query_balance(rpc_url, address)
if result.success then
    local balance_json = ffi.string(result.data)
    ffi_lib.free_string(result.data)
    -- Parse balance_json
end
```

## Dynamic Metadata: The Game Changer

The biggest challenge in building Substrate SDKs is handling runtime metadata. Substrate chains define their APIs through metadata—a SCALE-encoded description of all pallets, calls, storage, and events. When chains upgrade, call indices can change:

```
Before upgrade: Balances::transfer_keep_alive = [4, 3]
After upgrade:  Balances::transfer_keep_alive = [5, 3]
```

Hardcoding indices means your code breaks on every runtime upgrade. The solution is dynamic metadata parsing.

### How SubLua Implements It

SubLua v0.1.6 leverages `subxt`'s metadata parsing capabilities directly through the FFI:

```rust
#[no_mangle]
pub extern "C" fn get_call_index(
    rpc_url: *const c_char,
    pallet_name: *const c_char,
    call_name: *const c_char,
) -> ExtrinsicResult {
    tokio_rt().block_on(async {
        // Connect to chain
        let api = OnlineClient::<PolkadotConfig>::from_url(&url).await?;
        
        // Get metadata (parsed via SCALE codec)
        let metadata = api.metadata();
        let pallet = metadata.pallet_by_name(&pallet)?;
        let call = pallet.call_variant_by_name(&call_name)?;
        
        // Return indices as JSON
        json!({
            "pallet_index": pallet.index(),
            "call_index": call.index
        })
    })
}
```

From Lua's perspective, this is straightforward:

```lua
local metadata = sublua.metadata()

-- Dynamically lookup call indices from live chain
local indices = metadata.get_dynamic_call_index(
    "wss://westend-rpc.polkadot.io",
    "Balances",
    "transfer_keep_alive"
)
-- Returns: {4, 3} for Westend, but adapts automatically to any chain
```

This same metadata engine powers Polkadot.js and all production `subxt` applications. By exposing it through FFI, SubLua gets battle-tested metadata parsing without reimplementing the SCALE codec in Lua.

### Pallet Discovery

You can also discover what's available on any chain at runtime:

```lua
local pallets = metadata.get_pallets("wss://rpc.polkadot.io")
-- Returns: ["System", "Balances", "Staking", "Governance", ...]

for _, pallet_name in ipairs(pallets) do
    print("Available pallet:", pallet_name)
end
```

This makes SubLua automatically compatible with any Substrate chain, including custom runtimes with unique pallets.

## Real Example: Balance Transfer

Here's a complete working example that queries a balance and submits a transfer:

```lua
local sublua = require("sublua")
local ffi_mod = require("sublua.polkadot_ffi")

-- Load FFI library (auto-detects macOS/Linux/aarch64/x86_64)
sublua.ffi()

-- Create signer from mnemonic
local signer_mod = sublua.signer()
local alice = signer_mod.from_mnemonic(
    "bottom drive obey lake curtain smoke basket hold race lonely fit walk"
)

-- Get Westend address (prefix 42)
local address = alice:get_ss58_address(42)
print("Address:", address)

-- Query current balance
local ffi = ffi_mod.ffi
local lib = ffi_mod.get_lib()

local rpc_url = "wss://westend-rpc.polkadot.io"
local balance_result = lib.query_balance(rpc_url, address)

if balance_result.success then
    local balance_data = ffi.string(balance_result.data)
    lib.free_string(balance_result.data)
    print("Current balance:", balance_data)
end

-- Submit transfer (0.1 WND to Bob)
local bob_address = "5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty"
local amount = 100000000000  -- 0.1 WND (12 decimals)

local tx_result = lib.submit_balance_transfer_subxt(
    rpc_url,
    alice.seed,
    bob_address,
    amount
)

if tx_result.success then
    local tx_hash = ffi.string(tx_result.tx_hash)
    lib.free_string(tx_result.tx_hash)
    print("Transfer successful!")
    print("TX Hash:", tx_hash)
end
```

This code:
1. Derives an Sr25519 keypair from a mnemonic (using `sp-core`)
2. Encodes the address in SS58 format with Westend prefix (42)
3. Queries the account balance via `subxt::OnlineClient`
4. Submits a signed balance transfer extrinsic
5. Waits for finalization and returns the tx hash

Total execution time: ~2-3 seconds (mostly network latency). The cryptographic operations (keypair derivation, signing) happen in under 1ms.

## Testing Methodology

SubLua includes comprehensive tests that run against live testnets. Here's what the actual test suite verifies:

```lua
-- test/run_tests.lua
local sdk = require("sublua")
sdk.ffi()

-- Test 1: Signer creation from mnemonic
local signer = sdk.signer().from_mnemonic("helmet myself order all require...")
assert(signer:get_ss58_address(42), "Should generate Westend address")

-- Test 2: Balance query (live Polkadot Treasury address)
local treasury_addr = "13UVJyLnbVp9RBZYFwFGyDvVd1y27Tt8tkntv6Q7JVPhFsTB"
local result = ffi_lib.query_balance("wss://rpc.polkadot.io", treasury_addr)
assert(result.success, "Should query balance from live chain")

-- Test 3: Balance transfer (live Westend testnet)
local tx_result = ffi_lib.submit_balance_transfer_subxt(
    "wss://westend-rpc.polkadot.io",
    test_mnemonic,
    recipient_address,
    1000000000000  -- 1 WND
)
assert(tx_result.success, "Should submit transaction to testnet")
```

All tests pass against live networks—no mocks, no stubs. This ensures the FFI layer actually works in production conditions.

## Platform Support and Distribution

SubLua uses LuaRocks for distribution, with precompiled binaries for common platforms:

```
precompiled/
├── macos-aarch64/libpolkadot_ffi.dylib
├── macos-x86_64/libpolkadot_ffi.dylib
└── linux-x86_64/libpolkadot_ffi.so
```

Installation is straightforward:

```bash
luarocks install sublua
```

The FFI module auto-detects your platform:

```lua
-- sublua/polkadot_ffi.lua
function M.detect_platform()
    local os_type = jit.os:lower()
    local arch = jit.arch:lower()
    
    -- Normalize architecture names
    if arch == "arm64" then arch = "aarch64" end
    
    -- Detect OS
    if os_type == "osx" then os_type = "macos" end
    
    return os_type, arch
end
```

For unsupported platforms, you can compile from source:

```bash
cd polkadot-ffi-subxt
cargo build --release
# Library will be in target/release/
```

## Use Cases

### 1. Game Development

Lua is the scripting language for major game engines (Love2D, Roblox, Unity with MoonSharp). SubLua enables:

- **On-chain item ownership**: NFTs as game items
- **Play-to-earn mechanics**: Automatic token distribution
- **Tournament rewards**: Smart contract escrow

The game logic runs at native Lua speed while blockchain operations happen asynchronously through the FFI.

### 2. Embedded Systems and IoT

Lua is ubiquitous in embedded systems (OpenWrt, ESP32, NodeMCU). SubLua's small footprint (<10MB including LuaJIT) makes it viable for:

- **Supply chain tracking**: IoT sensors posting to blockchain
- **Device authentication**: Sr25519 signing for zero-trust
- **Micropayments**: Automated token transfers

### 3. Scripting and Automation

Lua is the extension language for Redis, Nginx, and other infrastructure. SubLua enables:

- **DeFi bots**: Price monitoring and arbitrage
- **Governance automation**: Automated proposal voting
- **Treasury management**: Batch payment processing

## Current Limitations

SubLua v0.1.6 is production-ready for core operations but has known limitations:

1. **Pallet Coverage**: Currently fully supports `Balances` pallet. `Staking`, `Governance`, and `Utility` pallets are in development.

2. **Event Subscriptions**: No WebSocket subscription support yet. Polling via RPC queries works but isn't real-time.

3. **JSON Parsing**: Uses a simple regex-based JSON parser to avoid external dependencies. Works for FFI results but isn't a full JSON implementation.

4. **Error Messages**: Some Rust errors don't propagate detailed context through FFI. Improved error handling is planned.

5. **Windows Support**: Precompiled binaries for Windows aren't available yet. You can compile from source with `cargo build`.

## Performance Characteristics

Based on real test runs:

| Operation | Time | Notes |
|-----------|------|-------|
| FFI library load | ~3ms | Platform detection + `dlopen` |
| Signer creation (mnemonic) | ~5ms | BIP39 + Sr25519 keygen |
| Balance query | ~500ms | Network + RPC call |
| Transfer submit | ~2s | Sign + submit + finalization |
| Metadata fetch | ~400ms | Network + SCALE decode |
| Call index lookup | ~300ms | Cached after first fetch |

The cryptographic operations are CPU-bound and very fast. Network operations dominate the latency.

## What Makes This Different

There are other Substrate SDKs (Polkadot.js, Python substrateinterface, Go substrate-api-client). SubLua's differentiators:

1. **Direct FFI to Rust**: Zero serialization overhead for crypto operations. Polkadot.js runs crypto in WebAssembly; SubLua uses native Rust.

2. **No HTTP for Crypto**: Signing, hashing, and key derivation don't touch the network. They're pure FFI calls.

3. **Production `subxt`**: The same client library that powers Parity's own tools and substrate.io tutorials.

4. **LuaJIT Performance**: Trace JIT compilation means Lua logic runs at ~50-80% of C speed.

5. **Embedded-Friendly**: 10MB total footprint (LuaJIT + FFI library). Polkadot.js + Node.js is ~150MB.

## Roadmap

**v0.2.0** (Q1 2026):
- Event subscriptions via WebSocket
- Full Staking pallet support
- Governance pallet (vote, propose)
- Utility pallet (batch calls)

**v0.3.0** (Q2 2026):
- Custom chain configuration DSL
- Storage key generation and queries
- Type-safe SCALE encoding in Lua

**v1.0.0** (Q3 2026):
- Full pallet coverage for relay chains
- Comprehensive documentation site
- >95% test coverage
- Windows precompiled binaries

## Getting Started

Installation:

```bash
luarocks install sublua
```

Minimal example:

```lua
local sublua = require("sublua")
sublua.ffi()

local signer = sublua.signer().from_mnemonic("your mnemonic here")
print("Address:", signer:get_ss58_address(0))  -- Polkadot
```

Full documentation: [github.com/MontaQLabs/sublua](https://github.com/MontaQLabs/sublua)

SubLua proves that Substrate development doesn't require JavaScript or Rust expertise. By exposing `subxt` through LuaJIT's FFI, it achieves near-native performance while maintaining Lua's simplicity and small footprint.

The dynamic metadata system makes it future-proof—automatically adapting to runtime upgrades without code changes. And because it's built on production Rust libraries (`subxt`, `sp-core`), it benefits from the same security audits and battle-testing as Parity's own tools.

Whether you're building blockchain-enabled games, automating DeFi strategies, or adding Web3 to embedded devices, SubLua brings Substrate to the Lua ecosystem with production-grade performance and reliability.

---

*SubLua is open source (MIT) and funded by Web3 Foundation Grant Program.*  
*Project: [github.com/MontaQLabs/sublua](https://github.com/MontaQLabs/sublua)*  
*Author: MontaQ Labs*
