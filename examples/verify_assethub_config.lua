-- examples/verify_assethub_config.lua
-- Brute Force Configuration Verification for Westend AssetHub
-- Combinations of: Call Index, Extension List

package.path = "./?.lua;./?/init.lua;" .. package.path
package.cpath = "./sublua/?.so;" .. package.cpath

local polkadot = require("sublua.init")
local Keyring = require("sublua.keyring")
local Transaction = require("sublua.transaction")
local Scale = require("sublua.scale")
local crypto = require("polkadot_crypto")

local url = "https://westend-asset-hub-rpc.polkadot.io"
print("Connecting to " .. url)
local api = polkadot.connect(url)

-- Setup State
local genesis_hash = api:chain_getBlockHash(0)
local runtime_ver = api:state_getRuntimeVersion()
print("Spec: " .. runtime_ver.specVersion .. " TxVer: " .. runtime_ver.transactionVersion)

local props = {
    specVersion = runtime_ver.specVersion,
    txVersion = runtime_ver.transactionVersion,
    genesisHash = genesis_hash,
    finalizedHash = genesis_hash
}

-- 1 WND encoded
local value_enc = Scale.encode_compact(10^12)
local value_hex = (value_enc:gsub(".", function(c) return string.format("%02x", string.byte(c)) end))

-- Destination (Bob)
local dest_pub = crypto.ed25519_keypair_from_seed(string.rep("b", 32))
local dest_hex = "00" .. (dest_pub:gsub(".", function(c) return string.format("%02x", string.byte(c)) end))

-- Test Configurations
local call_indices = { 
    "0400", -- Relay Chain default (Balances=4)
    "0a00", -- Balances=10?
    "3200", -- Balances=50 (0x32)?
    "1f00", -- Assets? (31=0x1f)
    "0000", -- System.remark? (Pallet 0, Call 0)
    "0001"  -- System.remark? (Pallet 0, Call 1)
}

local ext_configs = {
    {
        name = "AssetTx + MetadataHash",
        list = {
            "CheckNonZeroSender", "CheckSpecVersion", "CheckTxVersion", "CheckGenesis",
            "CheckMortality", "CheckNonce", "CheckWeight",
            "ChargeAssetTxPayment", "CheckMetadataHash"
        }
    },
    {
        name = "AssetTx ONLY",
        list = {
            "CheckNonZeroSender", "CheckSpecVersion", "CheckTxVersion", "CheckGenesis",
            "CheckMortality", "CheckNonce", "CheckWeight",
            "ChargeAssetTxPayment"
        }
    },
    {
        name = "Legacy ChargeTx + MetadataHash",
        list = {
            "CheckNonZeroSender", "CheckSpecVersion", "CheckTxVersion", "CheckGenesis",
            "CheckMortality", "CheckNonce", "CheckWeight",
            "ChargeTransactionPayment", "CheckMetadataHash"
        }
    }
}

-- Run Tests
math.randomseed(os.time())

for _, idx in ipairs(call_indices) do
    for _, ext_cfg in ipairs(ext_configs) do
        print("\n---------------------------------------------------")
        print("Testing: CallIndex=0x" .. idx .. " | Extensions=" .. ext_cfg.name)
        
        -- Generate fresh account
        local seed = ""
        for i=1,32 do seed = seed .. string.char(math.random(0,255)) end
        local alice = Keyring.from_seed(seed)
        
        -- Construct Call
        local call_hex = "0x" .. idx .. dest_hex .. value_hex
        
        -- Sign
        local signed_hex = Transaction.create_signed(call_hex, alice, 0, props, ext_cfg.list)
        
        -- Submit
        local s, res = pcall(function() return api:author_submitExtrinsic(signed_hex) end)
        
        if s then
            print("✅ RESULT: " .. tostring(res))
        else
            local err = tostring(res)
            print("❌ ERROR: " .. err)
            
            if err:match("Inability to pay") then
                print("🎉 MATCH FOUND! valid structure, insufficient funds.")
                print("   -> Correct Config: Index=" .. idx .. ", Ext=" .. ext_cfg.name)
                os.exit(0)
            elseif err:match("Temporarily Banned") then
                 print("🎉 MACTH FOUND! (Duplicate?)")
                 os.exit(0)
            end
        end
    end
end
print("\nNo working configuration found.")
