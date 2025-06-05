#!/usr/bin/env luajit

-- Fix module search path for SDK
package.path = "./?.lua;./?/init.lua;./sdk/?.lua;./sdk/?/init.lua;" .. package.path

local sdk = require("sdk.init")

print("🧪 Testing Small Transfer (1 PAS)")
print("=================================")

-- Configuration
local RPC_URL = "wss://paseo.dotters.network"
local ALICE_MNEMONIC = "bottom drive obey lake curtain smoke basket hold race lonely fit walk"
local BOB_ADDRESS = "1yMmfLti1k3huRQM2c47WugwonQMqTvQ2GUFxnU7Pcs7xPo"

-- Auto-detect chain configuration
local chain_config = sdk.chain_config.detect_from_url(RPC_URL)

-- Connect to chain
local rpc = sdk.rpc.new(RPC_URL)

-- Get Alice's signer
local alice_signer, alice_info = sdk.signer.from_mnemonic(ALICE_MNEMONIC)
local alice_address = alice_signer:get_ss58_address(chain_config.ss58_prefix)

-- Get account info
local alice_account = rpc:get_account_info(alice_address)
local bob_account = rpc:get_account_info(BOB_ADDRESS)

print(string.format("👤 Alice: %s", alice_address))
print(string.format("👤 Bob: %s", BOB_ADDRESS))
print(string.format("💰 Alice balance: %.5f PAS", alice_account.data.free_tokens))
print(string.format("💰 Bob balance: %.5f PAS", bob_account.data.free_tokens))
print(string.format("🔢 Alice nonce: %d", alice_account.nonce))
print(string.format("❄️  Alice frozen: %.5f PAS", alice_account.data.frozen_tokens))

-- Test 1 PAS transfer
print("\n🎯 Testing 1 PAS Transfer")
print("========================")

local transfer_amount = 1 * 10000000000 -- 1 PAS in units

-- Create transfer call data
local function create_transfer_call_data(recipient_address, amount)
    -- Get FFI access like in working examples
    local ffi_module = require('sdk.ffi')
    local ffi = ffi_module.ffi
    local lib = ffi_module.lib
    
    -- Decode recipient address to AccountId32 using FFI
    local bob_result = lib.decode_ss58_address(recipient_address)
    
    if not bob_result.success then
        local error_msg = ffi.string(bob_result.error)
        lib.free_string(bob_result.error)
        error("Failed to decode SS58 address: " .. error_msg)
    end
    
    local decoded_address = ffi.string(bob_result.data)
    lib.free_string(bob_result.data)
    
    -- Remove 0x prefix if present
    decoded_address = decoded_address:gsub("^0x", "")
    
    -- Convert hex string to bytes
    local address_bytes = ""
    for i = 1, #decoded_address, 2 do
        local byte_val = tonumber(decoded_address:sub(i, i+1), 16)
        address_bytes = address_bytes .. string.char(byte_val)
    end
    
    -- Create call data: MultiAddress(Id) + AccountId32 + Compact(amount)
    local call_data = "\x00" -- MultiAddress::Id variant
    call_data = call_data .. address_bytes -- 32-byte AccountId32
    
    -- Encode amount as compact integer
    local function encode_compact(value)
        if value < 64 then
            return string.char(value * 4)
        elseif value < 16384 then
            return string.char(((value % 256) * 4) + 1) .. string.char(math.floor(value / 256))
        else
            -- For larger values, use 4-byte encoding
            local bytes = {}
            bytes[1] = ((value % 256) * 4) + 2
            bytes[2] = math.floor(value / 256) % 256
            bytes[3] = math.floor(value / 65536) % 256
            bytes[4] = math.floor(value / 16777216) % 256
            return string.char(bytes[1], bytes[2], bytes[3], bytes[4])
        end
    end
    
    call_data = call_data .. encode_compact(amount)
    return call_data
end

-- Create transfer extrinsic
local call_data = create_transfer_call_data(BOB_ADDRESS, transfer_amount)
local extrinsic = sdk.extrinsic.new({5, 3}, call_data) -- Balances.transferKeepAlive

-- Set transaction parameters
extrinsic:set_nonce(alice_account.nonce)
extrinsic:set_tip(0)
extrinsic:set_era_immortal()

-- Sign and encode
local unsigned_hex = extrinsic:encode_unsigned()
local signature = alice_signer:sign(unsigned_hex)
local signed_hex = extrinsic:encode_signed(signature, alice_signer:get_public_key())

print("Signed extrinsic:", signed_hex)

-- Submit transaction
local success, result = pcall(function()
    return rpc:author_submitExtrinsic(signed_hex)
end)

if success then
    print("✅ 1 PAS transfer succeeded!")
    print(string.format("📋 Transaction hash: %s", result))
else
    print("❌ 1 PAS transfer failed:")
    print(result)
end

-- Test System.remark to isolate the issue
print("\n🎯 Testing System.remark (Non-balance transaction)")
print("=================================================")

local remark_data = "test"
local remark_hex = "0x"
for i = 1, #remark_data do
    remark_hex = remark_hex .. string.format("%02x", string.byte(remark_data, i))
end

local remark_extrinsic = sdk.extrinsic.new({0, 1}, remark_hex) -- System.remark
remark_extrinsic:set_nonce(alice_account.nonce + 1) -- Increment nonce
remark_extrinsic:set_tip(0)
remark_extrinsic:set_era_immortal()

local remark_unsigned = remark_extrinsic:encode_unsigned()
local remark_signature = alice_signer:sign(remark_unsigned)
local remark_signed = remark_extrinsic:encode_signed(remark_signature, alice_signer:get_public_key())

local success2, result2 = pcall(function()
    return rpc:author_submitExtrinsic(remark_signed)
end)

if success2 then
    print("✅ System.remark succeeded!")
    print(string.format("📋 Transaction hash: %s", result2))
else
    print("❌ System.remark failed:")
    print(result2)
end

print("\n📋 Analysis:")
print("============")
if success then
    print("✅ Transfer functionality works - issue was with 10 PAS amount vs frozen balance")
elseif success2 then
    print("✅ Transaction structure works - issue is balance-specific")
else
    print("❌ Fundamental transaction structure issue remains")
end 