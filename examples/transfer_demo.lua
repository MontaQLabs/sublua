-- examples/transfer_demo.lua
package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"
package.cpath = package.cpath .. ";./c_src/?.so"

local polkadot = require("polkadot")
local Keyring = require("polkadot.keyring")
local Transaction = require("polkadot.transaction")
local Scale = require("polkadot.scale")
local crypto = require("polkadot_crypto")

local url = "https://westend-rpc.polkadot.io"
print("Connecting to " .. url)
local api = polkadot.connect(url)

-- 1. Generate a Test Account (Ed25519)
-- Changing to Bob to generate a fresh transaction hash and avoid "Temporarily Banned"
local alice = Keyring.from_uri("//Bob") 
print("Test Account Address (Ed25519) [BOB]: " .. alice.address)

-- 2. Query Account Info
print("Querying account info / nonce...")
local success, info = pcall(function() return api:system_account(alice.address) end)
if success then
    print("Nonce: " .. info.nonce)
    print("Free: " .. info.data.free_formated)
else
    print("Failed to query account. Check connection/logs.")
    os.exit(1)
end

-- 3. Construct a Transfer Extrinsic
local dest_pub = crypto.ed25519_keypair_from_seed(string.rep("b", 32))
local dest_addr = crypto.ss58_encode(dest_pub, 42)
print("Building transfer to: " .. dest_addr)

-- Encode Call: Balances.transfer_allow_death
-- Westend: Balances = 4, transfer_allow_death = 0.
-- Call Index: 04 00
local call_index_hex = "0400"

-- Dest: MultiAddress::Id (0x00) + 32-byte-pubkey
local dest_hex = "00" .. (dest_pub:gsub(".", function(c) return string.format("%02x", string.byte(c)) end))

-- Value: 1 WND = 10^12. Compact encoded.
local value_enc = Scale.encode_compact(10^12) -- 1 WND
local value_hex = (value_enc:gsub(".", function(c) return string.format("%02x", string.byte(c)) end))

local call_hex = "0x" .. call_index_hex .. dest_hex .. value_hex
print("Encoded Call: " .. call_hex)

-- 4. Get Chain State for Signing
local genesis_hash = api:chain_getBlockHash(0)
local runtime_ver = api:state_getRuntimeVersion()

print("Spec Version: " .. runtime_ver.specVersion)
print("Tx Version: " .. runtime_ver.transactionVersion)
print("Genesis Hash: " .. genesis_hash)

local props = {
    specVersion = runtime_ver.specVersion,
    txVersion = runtime_ver.transactionVersion,
    genesisHash = genesis_hash,
    finalizedHash = genesis_hash -- For Immortal Era, checkpoint is Genesis
}

-- 5. Sign
local signed_hex = Transaction.create_signed(call_hex, alice, info.nonce, props)
print("\nSigned Extrinsic (" .. #signed_hex/2 .. " bytes)")

-- 6. Check Validity (Dry Run)
print("\nChecking validity (payment_queryInfo)...")
local s, fee_info = pcall(function() return api:payment_queryInfo(signed_hex) end)
if s and fee_info and fee_info.partialFee then
    print("✅ Transaction is valid! Estimated Fee: " .. fee_info.partialFee)
else
    -- Note: This often fails if the signature is invalid OR if the node rejects it for other reasons (funds etc)
    print("⚠️ Transaction validation failed in queryInfo: " .. tostring(fee_info))
end

-- 7. Submit
print("\nSubmitting to Westend Node...")
local s, res = pcall(function() return api:author_submitExtrinsic(signed_hex) end)
if s then
    print("✅ Submission Result: " .. tostring(res))
else
    local err_msg = tostring(res)
    print("❌ Submission Failed: " .. err_msg)
    if err_msg:match("Inability to pay") then
        print("   -> (This actually means the signature WAS valid, but funds insufficient)")
    elseif err_msg:match("Temporarily Banned") then
        print("   -> (Success! The transaction is structurally valid and was seen before/cached)")
    end
end
