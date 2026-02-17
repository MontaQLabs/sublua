-- polkadot/transaction.lua
-- Constructs and signs extrinsics (transactions)

local Scale = require("polkadot.scale")
local crypto = require("polkadot_crypto")

local Transaction = {}

-- Enum for transaction versions
local TRANSACTION_VERSION = 4

-- Helper: Convert string to hex
local function to_hex(s)
    return (s:gsub(".", function(c) return string.format("%02x", string.byte(c)) end))
end

-- Construct a signed extrinsic (V4)
function Transaction.create_signed(call_hex, signer, nonce, props)
    -- Validate inputs
    assert(signer.pubkey and #signer.pubkey == 32, "signer.pubkey must be 32 bytes")
    assert(signer.seed and #signer.seed == 32, "signer.seed must be 32 bytes")
    assert(type(call_hex) == "string", "call_hex must be a string")
    assert(props.genesisHash and props.finalizedHash, "props must include genesisHash and finalizedHash")
    
    -- 1. Decode hex strings to bytes
    local function from_hex(hex_str)
        hex_str = hex_str:gsub("^0x", "")
        assert(#hex_str % 2 == 0, "Hex string must have even length")
        return (hex_str:gsub("..", function(cc) return string.char(tonumber(cc, 16)) end))
    end
    
    local genesis = from_hex(props.genesisHash)
    local block_hash = from_hex(props.finalizedHash)
    local call_bytes = from_hex(call_hex)
    
    assert(#genesis == 32, "genesisHash must decode to 32 bytes")
    assert(#block_hash == 32, "finalizedHash must decode to 32 bytes")
    assert(#call_bytes > 0, "call_bytes must not be empty")
    
    -- 2. Construct Extra (signed extension data)
    -- Immortal era is a single byte 0x00, NOT a compact integer
    local era = "\0"  -- Immortal era, single raw byte
    local nonce_enc = Scale.encode_compact(nonce)
    local tip_enc = Scale.encode_compact(0)
    local metadata_hash_mode = "\0" -- Mode 0 (Disabled)
    
    -- Extra: Era, Nonce, Tip, Mode
    local extra = era .. nonce_enc .. tip_enc .. metadata_hash_mode
    
    -- 3. Construct Additional Signed data
    local spec_ver = Scale.encode_u32(props.specVersion)
    local tx_ver = Scale.encode_u32(props.txVersion)
    
    -- 4. Construct Payload to Sign:
    -- Order: Call | Extra | AdditionalSigned
    -- Extra: era, nonce, tip, mode
    -- AdditionalSigned: specVersion, txVersion, genesisHash, blockHash
    -- CheckMetadataHash (Mode 0):
    -- Extra: "\0" (Mode) -> ALREADY IN 'extra'
    -- Additional: Option<H256>::None (0x00)
    local metadata_hash_additional = "\0"
    local payload = call_bytes .. extra .. spec_ver .. tx_ver .. genesis .. block_hash .. metadata_hash_additional
    
    -- 5. Sign Payload
    -- If > 256 bytes, hash payload first (Substrate convention)
    if #payload > 256 then
        payload = crypto.blake2b(payload, 32)
    end
    
    local sig = crypto.ed25519_sign(signer.seed, payload)
    assert(#sig == 64, "Ed25519 signature must be 64 bytes")
    
    -- 6. Construct Final Extrinsic
    -- Format: compact_length( 0x84 | MultiAddress | MultiSignature | Extra | Call )
    -- Where MultiSignature for Ed25519 is: 0x00 + 64-byte signature
    
    local version = string.char(0x84)  -- V4 (0x04) + Signed bit (0x80)
    local address = "\0" .. signer.pubkey  -- MultiAddress::Id (0x00 + 32-byte AccountId)
    local multi_sig = "\0" .. sig  -- MultiSignature::Ed25519 (0x00 + 64-byte signature)
    
    -- Inner content (everything that gets length-prefixed)
    local inner = version .. address .. multi_sig .. extra .. call_bytes
    
    -- Length prefix covers the entire inner content
    local len = Scale.encode_compact(#inner)
    
    return "0x" .. to_hex(len .. inner)
end

return Transaction
