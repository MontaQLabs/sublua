-- Calculate hash for Bob's transaction
package.path = "./?.lua;./?/init.lua;" .. package.path
package.cpath = "./sublua/?.so;" .. package.cpath

local polkadot = require("sublua.init")
local Keyring = require("sublua.keyring")
local Transaction = require("sublua.transaction")
local Scale = require("sublua.scale")
local crypto = require("polkadot_crypto")

-- Use Bob's account
local bob = Keyring.from_uri("//Bob") 
print("Account: " .. bob.address)

-- Reconstruct the exact same extrinsic as transfer_demo.lua
local dest_pub = crypto.ed25519_keypair_from_seed(string.rep("a", 32)) -- Alice
local call_index_hex = "0400"
local dest_hex = "00" .. (dest_pub:gsub(".", function(c) return string.format("%02x", string.byte(c)) end))
local value_enc = Scale.encode_compact(10^12) -- 1 WND
local value_hex = (value_enc:gsub(".", function(c) return string.format("%02x", string.byte(c)) end))
local call_hex = "0x" .. call_index_hex .. dest_hex .. value_hex

-- Chain Props (must match what was used)
local props = {
    specVersion = 1021002, -- Hardcoded from last run output
    txVersion = 27,
    genesisHash = "0xe143f23803ac50e8f6f8e62695d1ce9e4e1d68aa36c1cd2cfd15340213f3423e"
}

local signed_hex = Transaction.create_signed(call_hex, bob, 0, props)
print("Extrinsic Hex: " .. signed_hex)

-- Hash calculation: Blake2-256 of the extrinsic bytes (excluding the length prefix if it's the 0x... format usually, but Substrate hash is for the bytes)
-- Actually, Substrate transaction hash is Blake2-256 of the encoding.
local bytes = (signed_hex:gsub("^0x", ""):gsub("..", function(cc) return string.char(tonumber(cc, 16)) end))
local hash = crypto.blake2b(bytes, 32)
local hash_hex = "0x" .. (hash:gsub(".", function(c) return string.format("%02x", string.byte(c)) end))
print("Tx Hash: " .. hash_hex)
