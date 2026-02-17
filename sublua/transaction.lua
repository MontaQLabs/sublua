-- polkadot/transaction.lua
-- Constructs and signs extrinsics (transactions) with dynamic Signed Extensions

local Scale = require("sublua.scale")
local crypto = require("polkadot_crypto")
-- local Metadata = require("sublua.metadata") -- Not strictly needed if we don't access meta directly

local Transaction = {}

-- Helper: Hex <-> Bytes
local function from_hex(hex)
    hex = hex:gsub("^0x", "")
    return (hex:gsub("..", function(cc) return string.char(tonumber(cc, 16)) end))
end

local function to_hex(str)
    return (str:gsub(".", function(c) return string.format("%02x", string.byte(c)) end))
end

-- Extension Handlers
-- Each handler returns { extra = "...", additional = "..." }
-- p: props (specVersion, txVersion, genesisHash, blockHash, nonce, tip, era, assetId, metadata_hash)
local handlers = {}

handlers["CheckNonZeroSender"] = function(p) return { extra = "", additional = "" } end

handlers["CheckSpecVersion"] = function(p) 
    return { extra = "", additional = Scale.encode_u32(p.specVersion) } 
end

handlers["CheckTxVersion"] = function(p)
    return { extra = "", additional = Scale.encode_u32(p.txVersion) }
end

handlers["CheckGenesis"] = function(p)
    return { extra = "", additional = from_hex(p.genesisHash) }
end

handlers["CheckMortality"] = function(p)
    -- Era (Immortal = 0x00)
    -- Additional: BlockHash (Genesis for immortal)
    local era = "\0" -- TODO: Support mortal eras
    local checkpoint = from_hex(p.finalizedHash or p.genesisHash)
    return { extra = era, additional = checkpoint }
end

handlers["CheckNonce"] = function(p)
    return { extra = Scale.encode_compact(p.nonce), additional = "" }
end

handlers["CheckWeight"] = function(p)
    return { extra = "", additional = "" }
end

handlers["ChargeTransactionPayment"] = function(p)
    return { extra = Scale.encode_compact(p.tip or 0), additional = "" }
end

handlers["ChargeAssetTxPayment"] = function(p)
    -- Tip (Compact) + AssetId (Option<AssetId>)
    -- AssetId often u32 or generic. Option::None = 0x00.
    local tip = Scale.encode_compact(p.tip or 0)
    -- For AssetId, we assume None (0x00) for native token
    local asset_id = "\0" 
    if p.assetId then
         -- If AssetId is u32, use encode_u32. If compact? Westend uses u32.
         -- But wrapped in Option.
         asset_id = "\1" .. Scale.encode_u32(p.assetId)
    end
    return { extra = tip .. asset_id, additional = "" }
end

handlers["CheckMetadataHash"] = function(p)
    -- Mode (u8) + Additional (Option<H256>)
    local mode_byte = "\0" -- Disabled (Mode 0)
    -- RFC-000078: If mode=0, additional signed data is Option<Hash>::None = 0x00.
    local additional = "\0"
    return { extra = mode_byte, additional = additional }
end

handlers["AuthorizeCall"] = function(p)
    -- Empty composite struct — zero fields, zero bytes
    return { extra = "", additional = "" }
end

handlers["WeightReclaim"] = function(p)
    return { extra = "", additional = "" }
end

-- Default signed extensions for Westend (order matters)
local DEFAULT_EXTENSIONS = {
    "CheckNonZeroSender",
    "CheckSpecVersion",
    "CheckTxVersion",
    "CheckGenesis",
    "CheckMortality",
    "CheckNonce",
    "CheckWeight",
    "ChargeTransactionPayment",
    "CheckMetadataHash"
}

-- Construct a signed extrinsic (V4)
function Transaction.create_signed(call_hex, signer, nonce, props, extensions)
    -- Validate inputs
    assert(signer.pubkey and #signer.pubkey == 32, "signer.pubkey must be 32 bytes")
    assert(signer.seed and #signer.seed == 32, "signer.seed must be 32 bytes")
    assert(type(call_hex) == "string", "call_hex must be a string")
    
    local call_bytes = from_hex(call_hex)
    
    -- Default Props
    props.nonce = nonce
    props.tip = props.tip or 0
    
    -- Resolve Extensions list
    local ext_list = extensions or DEFAULT_EXTENSIONS
    
    local extra = ""
    local additional = ""
    
    for _, name in ipairs(ext_list) do
        local h = handlers[name]
        if h then
            local res = h(props)
            extra = extra .. res.extra
            additional = additional .. res.additional
        else
            -- Unknown extensions with empty extra/additional are safe to skip
        end
    end
    
    -- Construct Payload
    -- Payload = Call | Extra | Additional
    local payload = call_bytes .. extra .. additional
    
    -- Sign Payload
    -- If > 256 bytes, hash payload first
    if #payload > 256 then
        payload = crypto.blake2b(payload, 32)
    end
    
    local sig = crypto.ed25519_sign(signer.seed, payload)
    
    -- Construct Final Extrinsic
    -- Format: compact_length( 0x84 | MultiAddress | MultiSignature | Extra | Call )
    local version = string.char(0x84)
    local address = "\0" .. signer.pubkey
    local multi_sig = "\0" .. sig -- Ed25519
    
    local inner = version .. address .. multi_sig .. extra .. call_bytes
    local len = Scale.encode_compact(#inner)
    
    return "0x" .. to_hex(len .. inner)
end

-- Production-grade: build signed extrinsic using live chain state
-- api: RPC client (from rpc.new(url))
-- signer: keyring pair (from keyring.from_seed)
-- call_bytes: raw call bytes (NOT hex)
-- opts: { tip = 0 } optional overrides
function Transaction.create_signed_from_api(api, signer, call_bytes, opts)
    opts = opts or {}
    
    -- Fetch chain state in parallel-safe order
    local genesis = api:chain_getBlockHash(0)
    local finalized = api:chain_getFinalizedHead()
    local runtime = api:state_getRuntimeVersion()
    local account = api:system_account(signer.address)
    
    -- Get signed extensions from metadata
    local meta = api:get_metadata()
    local ext_list = {}
    for _, ext in ipairs(meta.extrinsic.signed_extensions) do
        table.insert(ext_list, ext.identifier)
    end
    
    -- Build props from real chain state
    local props = {
        specVersion = runtime.specVersion,
        txVersion = runtime.transactionVersion,
        genesisHash = genesis,
        finalizedHash = finalized,
        tip = opts.tip or 0
    }
    
    local call_hex = "0x" .. to_hex(call_bytes)
    local nonce = account.nonce
    
    return Transaction.create_signed(call_hex, signer, nonce, props, ext_list), {
        nonce = nonce,
        specVersion = props.specVersion,
        txVersion = props.txVersion,
        genesisHash = genesis,
        finalizedHash = finalized,
        extensions = ext_list
    }
end

return Transaction
