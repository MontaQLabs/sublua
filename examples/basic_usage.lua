#!/usr/bin/env luajit
-- examples/basic_usage.lua
-- Basic usage example for SubLua SDK
--
-- Install SubLua:
--   curl -sSL https://raw.githubusercontent.com/MontaQLabs/sublua/main/install_sublua.sh | bash
--
-- Then run:
--   luajit examples/basic_usage.lua

-- For local development, add path (not needed after luarocks install)
package.path = package.path .. ";./?.lua;./?/init.lua;./sublua/?.lua"

local sublua = require("sublua")

print("🚀 SubLua Basic Usage Example")
print("=============================")
print("Version:", sublua.version)
print("")

-- 1. Load FFI (auto-finds the library!)
print("1️⃣ Loading FFI...")
sublua.ffi()  -- That's it! No paths needed.
print("✅ FFI loaded\n")

-- 2. Create a signer from mnemonic
print("2️⃣ Creating signer from mnemonic...")
local signer = sublua.signer().from_mnemonic(
    "bottom drive obey lake curtain smoke basket hold race lonely fit walk"
)

local polkadot_addr = signer:get_ss58_address(0)   -- Polkadot
local westend_addr = signer:get_ss58_address(42)  -- Westend

print("   Polkadot:", polkadot_addr)
print("   Westend:", westend_addr)
print("")

-- 3. Create a signer from seed (hex)
print("3️⃣ Creating signer from seed...")
local seed = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
local signer2 = sublua.signer().new(seed)
print("   Address:", signer2:get_ss58_address(0))
print("")

print("✅ Basic setup complete!")
print("")
print("📚 Next steps:")
print("   - Run 'luajit examples/websocket_example.lua' for live blockchain queries")
print("   - Run 'luajit examples/multisig_example.lua' for multi-signature wallets")
print("   - See documentation: https://github.com/MontaQLabs/sublua")
