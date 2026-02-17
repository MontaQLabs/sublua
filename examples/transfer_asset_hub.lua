-- examples/transfer_asset_hub.lua
-- Demo of transfer on Westend AssetHub (Parachain)
-- Uses ChargeAssetTxPayment instead of ChargeTransactionPayment

package.path = "./?.lua;./?/init.lua;" .. package.path
package.cpath = "./sublua/?.so;" .. package.cpath

local polkadot = require("sublua.init")
local Keyring = require("sublua.keyring")
local Transaction = require("sublua.transaction")
local Scale = require("sublua.scale")
local crypto = require("polkadot_crypto")

-- Westend AssetHub RPC
local url = "https://westend-asset-hub-rpc.polkadot.io"
print("Connecting to " .. url)
local api = polkadot.connect(url)

-- 1. Generate a Test Account (Random) - Expect "Inability to pay"
math.randomseed(os.time())
local seed = ""
for i=1,32 do seed = seed .. string.char(math.random(0,255)) end
local alice = Keyring.from_seed(seed)
print("Test Account Address (Ed25519) [RANDOM]: " .. alice.address)

-- 2. Query Account Info (System.Account)
-- AssetHub System Account info is compatible with Relay Chain
print("Querying account info / nonce...")
local success, info = pcall(function() return api:system_account(alice.address) end)
local nonce = (success and info.nonce) or 0
print("Nonce: " .. nonce)

-- 3. Construct Transfer
-- AssetHub Balances Pallet Index?
-- Often 10 on Parachains, but let's try to fetch Metadata first.
local has_meta, meta = pcall(api.get_metadata, api)
local call_index_hex = "0a00" -- Default fallback: Pallet 10 (Balances), Call 0 (transfer_allow_death) for AssetHub?
-- Westend AssetHub likely: Balances=10.
-- Let's check metadata if available.

if has_meta and meta.pallets["Balances"] then
    local p_idx = meta.pallets["Balances"].index
    -- Assuming transfer_allow_death is index 0. 
    -- We can't easily resolve call names without full metadata parsing which might fail.
    -- We'll assume Call 0.
    print("Found Balances Pallet Index: " .. p_idx)
    call_index_hex = string.format("%02x00", p_idx)
else
    print("WARNING: Using DEFAULT Call Index (0x" .. call_index_hex .. ") - Metadata check failed/skipped")
end

-- Send to Bob
local dest_pub = crypto.ed25519_keypair_from_seed(string.rep("b", 32))
local dest_hex = "00" .. (dest_pub:gsub(".", function(c) return string.format("%02x", string.byte(c)) end))
local value_enc = Scale.encode_compact(10^12) -- 1 WND
local value_hex = (value_enc:gsub(".", function(c) return string.format("%02x", string.byte(c)) end))

local call_hex = "0x" .. call_index_hex .. dest_hex .. value_hex
print("Encoded Call: " .. call_hex)

-- 4. Get Chain State
local genesis_hash = api:chain_getBlockHash(0)
local runtime_ver = api:state_getRuntimeVersion()
print("Spec Version: " .. runtime_ver.specVersion)
print("Tx Version: " .. runtime_ver.transactionVersion)

local props = {
    specVersion = runtime_ver.specVersion,
    txVersion = runtime_ver.transactionVersion,
    genesisHash = genesis_hash,
    finalizedHash = genesis_hash
}

-- 5. Define Extensions for AssetHub
-- Order matters! AssetHub usually:
-- CheckNonZeroSender, CheckSpecVersion, CheckTxVersion, CheckGenesis, CheckMortality, CheckNonce, CheckWeight, ChargeAssetTxPayment, CheckMetadataHash
local extensions = {
    "CheckNonZeroSender",
    "CheckSpecVersion",
    "CheckTxVersion",
    "CheckGenesis",
    "CheckMortality",
    "CheckNonce",
    "CheckWeight",
    "ChargeAssetTxPayment", -- THE KEY DIFFERENCE
    -- "CheckMetadataHash"
}
print("Using Explicit AssetHub Extensions List")

-- 6. Sign
local signed_hex = Transaction.create_signed(call_hex, alice, nonce, props, extensions)
print("Signed Extrinsic (" .. #signed_hex/2 .. " bytes)")

-- 7. Submit
print("\nSubmitting to Westend AssetHub...")
local s, res = pcall(function() return api:author_submitExtrinsic(signed_hex) end)

if s then
    print("✅ Submission Result: " .. tostring(res))
else
    local err_msg = tostring(res)
    print("❌ Submission Failed: " .. err_msg)
    
    if err_msg:match("Inability to pay") then
        print("\n🎉 SUCCESS! 'Inability to pay' means the node accepted the signature and structure.")
        print("   This confirms valid transaction construction for Westend AssetHub.")
    elseif err_msg:match("wasm trap") then
        print("\n🔥 FAILURE! 'wasm trap' means the runtime rejected the transaction structure.")
        print("   Likely an extension mismatch or Call Index issue.")
    elseif err_msg:match("Temporarily Banned") then
         print("\n🎉 SUCCESS! 'Temporarily Banned' means acceptable duplicate.")
    end
end
