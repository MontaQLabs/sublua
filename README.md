# SubLua

Lightweight Polkadot/Substrate SDK for Lua. **Pure C + Pure Lua** — no Rust, no Node.js, no complex toolchains.

Works with **Lua 5.1–5.4** and **LuaJIT**. One `luarocks install` and you're ready.

## Install

```bash
luarocks install sublua
```

LuaRocks compiles the small C crypto module automatically (needs `gcc` or `clang`). All Lua modules are pure Lua.

### Build from Source

```bash
git clone https://github.com/MontaQLabs/sublua.git
cd sublua
make        # builds sublua/polkadot_crypto.so
make test   # runs 133 tests across 7 suites
```

## Quick Start

```lua
local sublua = require("sublua")

-- Connect to Westend testnet
local api = sublua.connect("https://westend-rpc.polkadot.io")

-- Create a keypair
local alice = sublua.keyring.from_uri("//Alice")
print("Address:", alice.address)

-- Query balance
local account = api:system_account(alice.address)
print("Balance:", account.data.free)
```

## Transfer Tokens

```lua
local sublua = require("sublua")

local api = sublua.connect("https://westend-rpc.polkadot.io")
local bob = sublua.keyring.from_uri("//Bob")
local alice = sublua.keyring.from_uri("//Alice")

-- Build transfer call
local meta = api:get_metadata()
local balances = meta.pallets["Balances"]
local call = sublua.call.encode_transfer(
    balances.index, balances.calls["transfer_allow_death"],
    alice.pubkey, 1000000000000  -- 1 WND
)

-- Sign and submit
local signed = sublua.transaction.create_signed_from_api(api, bob, call)
-- submit via RPC...
```

## XCM Cross-Chain Transfers

Teleport tokens from relay chain to parachains (e.g., AssetHub):

```lua
local sublua = require("sublua")

local api = sublua.connect("https://westend-rpc.polkadot.io")
local bob = sublua.keyring.from_uri("//Bob")

-- Teleport 1 WND to AssetHub (parachain 1000)
local signed = sublua.xcm.teleport_to_parachain(
    api, bob, bob.pubkey,
    1000000000000,          -- 1 WND (12 decimals)
    { para_id = 1000 }     -- Westend AssetHub
)
```

## Features

| Feature | Module | Type |
|---------|--------|------|
| Ed25519 signing (RFC 8032) | `sublua.crypto` | C |
| Blake2b, xxHash | `sublua.crypto` | C |
| SS58 addresses | `sublua.crypto` | C |
| SCALE codec | `sublua.scale` | Pure Lua |
| Transaction builder (V4) | `sublua.transaction` | Pure Lua |
| XCM teleport/reserve transfers | `sublua.xcm` | Pure Lua |
| Runtime metadata V14 parser | `sublua.metadata` | Pure Lua |
| RPC client (HTTP/HTTPS) | `sublua.rpc` | Pure Lua |
| Keyring management | `sublua.keyring` | Pure Lua |

## Game Engine & Embedded Compatibility

SubLua is designed to work anywhere Lua runs:

| Platform | Status | Notes |
|----------|--------|-------|
| **LÖVE 2D** | ✅ | Drop `polkadot_crypto.so` next to your game files |
| **Defold** | ✅ | Add as native extension, Lua modules work as-is |
| **Solar2D** | ✅ | Include `.so`/`.dll` as plugin |
| **OpenResty** | ✅ | `luarocks install sublua` on server |
| **Lapis** | ✅ | Same as OpenResty |
| **ESP32/IoT** | ✅ | Cross-compile C module for target arch |
| **LuaJIT** | ✅ | Compatible with LuaJIT 2.0+ |
| **Standalone Lua** | ✅ | 5.1, 5.2, 5.3, 5.4 |

**For game distribution:** Bundle `polkadot_crypto.so` (Linux), `.dylib` (macOS), or `.dll` (Windows) with your game. The pure Lua modules just need to be on `package.path`. Players don't need Lua or LuaRocks installed — the game engine embeds everything.

**Architecture:** Only the crypto module (`polkadot_crypto`) is C. Everything else — SCALE codec, transaction builder, XCM, RPC, metadata parser — is **pure Lua** and works on any Lua VM without modification.

## Testing

```bash
make test                    # 133 tests across 7 suites
lua test/run_tests.lua       # same thing, explicit
lua test/test_crypto.lua     # just crypto
lua test/test_xcm.lua        # just XCM
```

## Modules

```
sublua/
├── init.lua              -- Entry point: require("sublua")
├── polkadot_crypto.so    -- C module: Ed25519, Blake2b, xxHash, SS58
├── scale.lua             -- SCALE codec (Pure Lua)
├── keyring.lua           -- Keypair management
├── call.lua              -- Call encoding helpers
├── transaction.lua       -- Extrinsic builder + signer
├── xcm.lua               -- XCM cross-chain transfer builders
├── rpc.lua               -- HTTP/HTTPS RPC client
├── metadata.lua          -- Runtime metadata V14 parser
└── bytes.lua             -- Byte manipulation utilities
```

## License

MIT
