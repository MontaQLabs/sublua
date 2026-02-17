-- polkadot/call.lua
-- Helper functions for constructing Substrate calls

local Scale = require("polkadot.scale")
local crypto = require("polkadot_crypto")

local Call = {}

-- Helper: Convert string to hex
local function to_hex(s)
    return (s:gsub(".", function(c) return string.format("%02x", string.byte(c)) end))
end

-- Encode call index
-- In Substrate, call index is encoded as u16 in little-endian
-- Format: (call_index << 8) | module_index
-- But encoded as bytes: [call_index, module_index] (little-endian)
-- So for module 4, call 0: bytes are [0x00, 0x04] = 0x0004 hex
-- When read as little-endian u16: 0x0400
function Call.encode_index(module_index, call_index)
    -- Encode as two u8s: call_index (low byte), module_index (high byte)
    -- But in little-endian, low byte comes first
    return string.char(call_index, module_index)
end

-- Encode MultiAddress::Id (AccountId)
function Call.encode_address_id(pubkey)
    -- MultiAddress::Id = 0x00 + 32-byte AccountId
    return "\0" .. pubkey
end

-- Encode transfer call
-- module_index: Balances module index (typically 4 or 5)
-- call_index: transfer_allow_death index (typically 0)
-- dest_pubkey: 32-byte destination public key
-- amount: amount in smallest unit (e.g., 10^12 for 1 DOT/WND)
function Call.encode_transfer(module_index, call_index, dest_pubkey, amount)
    local Scale = require("polkadot.scale")
    
    -- Call index
    local call_idx = Call.encode_index(module_index, call_index)
    
    -- Destination: MultiAddress::Id
    local dest = Call.encode_address_id(dest_pubkey)
    
    -- Amount: Compact<u128>
    local value = Scale.encode_compact(amount)
    
    -- Full call
    return call_idx .. dest .. value
end

-- Helper to convert call bytes to hex
function Call.to_hex(call_bytes)
    return (call_bytes:gsub(".", function(c) return string.format("%02x", string.byte(c)) end))
end

return Call
