-- examples/basic_usage.lua
-- Basic usage example for SubLua SDK

local sdk = require("sublua")

print("🚀 SubLua Basic Usage Example")
print("=============================")

-- Configuration
local RPC_URL = "wss://westend-rpc.polkadot.io"
local TEST_MNEMONIC = "helmet myself order all require large unusual verify ritual final apart nut"

-- 1. Connect to the chain
print("\n1️⃣ Connecting to Westend testnet...")
local rpc = sdk.rpc.new(RPC_URL)
local chain_config = sdk.chain_config.detect_from_url(RPC_URL)

print("Chain:", chain_config.name)
print("Token:", chain_config.token_symbol)
print("Decimals:", chain_config.token_decimals)

-- 2. Create a signer
print("\n2️⃣ Creating signer from mnemonic...")
local signer = sdk.signer.from_mnemonic(TEST_MNEMONIC)
local address = signer:get_ss58_address(chain_config.ss58_prefix)
print("Address:", address)

-- 3. Check account balance
print("\n3️⃣ Checking account balance...")
local account = rpc:get_account_info(address)

if account then
    local balance = account.data.free_tokens or account.data.free or 0
    print("Balance:", string.format("%.5f %s", balance, chain_config.token_symbol))
    print("Nonce:", account.nonce)
else
    print("Account not found - needs funding")
end

-- 4. Transfer example (commented out for safety)
print("\n4️⃣ Transfer example (commented out for safety)")
print("To enable transfers, uncomment the code below:")

--[[
local recipient = "5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY"
local amount = 1000000000000  -- 1 WND in units

print("Transferring", amount / (10 ^ chain_config.token_decimals), chain_config.token_symbol, "to", recipient)

local tx_hash = signer:transfer(rpc, recipient, amount)
print("Transaction hash:", tx_hash)
--]]

print("\n✅ Basic usage example completed!")
print("Check the SDK documentation for more advanced features.")
