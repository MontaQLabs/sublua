-- test/test_transfer.lua
-- Test transfer transaction creation and validation

package.cpath = "../sublua/?.so;./sublua/?.so;" .. package.cpath
package.path = "../?.lua;../?/init.lua;./?.lua;./?/init.lua;" .. package.path

local polkadot = require("sublua")
local Keyring = require("sublua.keyring")
local Transaction = require("sublua.transaction")
local Scale = require("sublua.scale")
local crypto = require("polkadot_crypto")

local function to_hex(str)
    return (str:gsub(".", function(c) return string.format("%02x", string.byte(c)) end))
end

local function from_hex(hex)
    hex = hex:gsub("^0x", "")
    return (hex:gsub("..", function(cc) return string.char(tonumber(cc, 16)) end))
end

print("=== Transfer Transaction Test ===\n")

-- Test 1: Create account
print("1. Creating test account...")
local alice = Keyring.from_seed(string.rep("a", 32))
print("   Address: " .. alice.address)
print("   ✅ Account created\n")

-- Test 2: Build transfer call
print("2. Building transfer call...")
local dest_pub = crypto.ed25519_keypair_from_seed(string.rep("b", 32))
local dest_addr = crypto.ss58_encode(dest_pub, 42)
print("   Destination: " .. dest_addr)

-- Call index: Balances(4).transfer_allow_death(0) = 0x0400
local call_index = Scale.encode_u16(4) .. Scale.encode_u16(0)
local call_index_hex = to_hex(call_index)
print("   Call Index: " .. call_index_hex)

-- Destination: MultiAddress::Id (0x00) + 32-byte pubkey
local dest_encoded = "\0" .. dest_pub
local dest_hex = to_hex(dest_encoded)
print("   Dest Encoded: " .. dest_hex)

-- Value: 1 WND (10^12) as Compact<u128>
local value = 10^12
local value_enc = Scale.encode_compact(value)
local value_hex = to_hex(value_enc)
print("   Value: " .. value .. " (" .. value_hex .. ")")

-- Full call
local call_bytes = call_index .. dest_encoded .. value_enc
local call_hex = "0x" .. to_hex(call_bytes)
print("   Full Call: " .. call_hex)
print("   ✅ Call built\n")

-- Test 3: Create mock chain properties
print("3. Creating mock chain properties...")
local props = {
    specVersion = 100,
    txVersion = 1,
    genesisHash = "0x" .. string.rep("00", 32),
    finalizedHash = "0x" .. string.rep("11", 32)
}
print("   Spec Version: " .. props.specVersion)
print("   Tx Version: " .. props.txVersion)
print("   ✅ Properties created\n")

-- Test 4: Sign transaction
print("4. Signing transaction...")
local signed = Transaction.create_signed(call_hex, alice, 0, props)
print("   Signed Extrinsic Length: " .. (#signed - 2) / 2 .. " bytes")
print("   Signed Extrinsic: " .. signed:sub(1, 100) .. "...")
print("   ✅ Transaction signed\n")

-- Test 5: Validate transaction structure
print("5. Validating transaction structure...")
local hex = signed:gsub("^0x", "")
assert(#hex % 2 == 0, "Hex string must have even length")
local bytes = from_hex(hex)

-- Decode length (compact)
local len_hex = hex:sub(1, 2)
local len_byte = tonumber(len_hex, 16)
local len_mode = len_byte % 4

if len_mode == 0 then
    local len = math.floor(len_byte / 4)
    print("   Length (compact): " .. len .. " bytes")
    assert(len > 0, "Length must be positive")
else
    print("   Length (compact): multi-byte")
end

-- Check version byte (should be 0x84 after length)
local version_offset = 2 -- After first byte
if len_mode > 0 then
    version_offset = len_mode == 1 and 4 or (len_mode == 2 and 8 or 16)
end
local version_byte = tonumber(hex:sub(version_offset + 1, version_offset + 2), 16)
print("   Version Byte: 0x" .. string.format("%02x", version_byte))
assert(version_byte == 0x84, "Version should be 0x84 (V4 + Signed)")

-- Check address (should be 0x00 + 32 bytes)
local addr_offset = version_offset + 2
local addr_type = tonumber(hex:sub(addr_offset + 1, addr_offset + 2), 16)
print("   Address Type: 0x" .. string.format("%02x", addr_type))
assert(addr_type == 0x00, "Address type should be 0x00 (MultiAddress::Id)")

-- Check signature type (should be 0x00 for Ed25519)
local sig_type_offset = addr_offset + 2 + 64 -- After address (33 bytes = 66 hex)
local sig_type = tonumber(hex:sub(sig_type_offset + 1, sig_type_offset + 2), 16)
print("   Signature Type: 0x" .. string.format("%02x", sig_type))
assert(sig_type == 0x00, "Signature type should be 0x00 (Ed25519)")

print("   ✅ Transaction structure valid\n")

-- Test 6: Verify signature
print("6. Verifying signature...")
-- Reconstruct payload matching Transaction.create_signed signed extensions:
-- Extra: era(0x00) + compact_nonce + compact_tip + metadata_mode(0x00)
-- Additional: u32_specVersion + u32_txVersion + genesis + checkpoint + metadata_option_none(0x00)
local era = "\0" -- Immortal era byte
local nonce_enc = Scale.encode_compact(0)
local tip_enc = Scale.encode_compact(0)
local metadata_mode = "\0" -- CheckMetadataHash mode byte (disabled)
local spec_ver = Scale.encode_u32(props.specVersion)
local tx_ver = Scale.encode_u32(props.txVersion)
local genesis = from_hex(props.genesisHash:gsub("^0x", ""))
local block_hash = from_hex(props.finalizedHash:gsub("^0x", ""))
local metadata_additional = "\0" -- CheckMetadataHash additional (Option::None)

local extra = era .. nonce_enc .. tip_enc .. metadata_mode
local additional = spec_ver .. tx_ver .. genesis .. block_hash .. metadata_additional
local payload = call_bytes .. extra .. additional
if #payload > 256 then
    payload = crypto.blake2b(payload, 32)
end

-- Extract signature from transaction
local sig_start = sig_type_offset + 2
local sig_hex = hex:sub(sig_start + 1, sig_start + 128) -- 64 bytes = 128 hex chars
local sig_bytes = from_hex(sig_hex)

local valid = crypto.ed25519_verify(alice.pubkey, payload, sig_bytes)
assert(valid == true, "Signature verification failed")
print("   ✅ Signature verified\n")

print("=== All Transfer Tests Passed! ===")
print("\nNote: To test actual submission, run:")
print("  lua examples/transfer_demo.lua")
print("\nThe transaction structure is correct and ready for submission.")
