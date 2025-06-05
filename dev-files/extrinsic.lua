local ffi = require("ffi")
local bit = require("bit")

-- Get the script's directory
local script_dir = debug.getinfo(1, "S").source:match("@?(.*/)")

-- Define the FFI functions
ffi.cdef[[
    int encode_unsigned_extrinsic(
        uint8_t module_index,
        uint8_t function_index,
        const uint8_t* arguments_ptr,
        size_t arguments_len,
        uint8_t** out_ptr,
        size_t* out_len
    );

    int encode_signed_extrinsic(
        uint8_t module_index,
        uint8_t function_index,
        const uint8_t* arguments_ptr,
        size_t arguments_len,
        const uint8_t* signer_ptr,
        const uint8_t* signature_ptr,
        uint32_t nonce,
        uint64_t tip_low,
        uint64_t tip_high,
        bool era_mortal,
        uint8_t era_period,
        uint8_t era_phase,
        uint8_t** out_ptr,
        size_t* out_len
    );

    int make_signing_payload(
        uint8_t module_index,
        uint8_t function_index,
        const uint8_t* arguments_ptr,
        size_t arguments_len,
        uint32_t nonce,
        uint64_t tip_low,
        uint64_t tip_high,
        bool era_mortal,
        uint8_t era_period,
        uint8_t era_phase,
        uint32_t spec_version,
        uint32_t transaction_version,
        const uint8_t* genesis_hash_ptr,
        const uint8_t* block_hash_ptr,
        uint8_t** out_ptr,
        size_t* out_len
    );

    void free_encoded_extrinsic(uint8_t* ptr, size_t len);
]]

-- Load the library
local lib = ffi.load("./polkadot-ffi/target/release/libpolkadot_ffi.so")

local Extrinsic = {}
Extrinsic.__index = Extrinsic

-- Helper function to ensure hex format
local function ensure_hex_prefix(str)
    if not str:match("^0x") then
        return "0x" .. str
    end
    return str
end

-- Helper function to convert hex string to bytes
local function hex_to_bytes(hex)
    hex = hex:gsub("^0x", "")
    local bytes = {}
    for i = 1, #hex, 2 do
        bytes[#bytes + 1] = tonumber(hex:sub(i, i + 1), 16)
    end
    return bytes
end

-- Helper function to convert bytes to hex string
local function bytes_to_hex(bytes)
    local hex = ""
    for _, byte in ipairs(bytes) do
        hex = hex .. string.format("%02x", byte)
    end
    return hex
end

-- Create a new extrinsic
function Extrinsic.new(call_index, call_data)
    local self = setmetatable({}, Extrinsic)
    self.call_index = call_index
    self.call_data = ensure_hex_prefix(call_data)
    self.nonce = 0
    self.tip = 0
    self.era = {mortal = false, period = 0, phase = 0}
    return self
end

-- Set the nonce (transaction index)
function Extrinsic:set_nonce(nonce)
    self.nonce = nonce
    return self
end

-- Set the tip (transaction fee)
function Extrinsic:set_tip(tip)
    self.tip = tip
    return self
end

-- Set the era (transaction validity period)
function Extrinsic:set_era(mortal, period, phase)
    self.era = {
        mortal = mortal or false,
        period = period or 0,
        phase = phase or 0
    }
    return self
end

-- Encode an unsigned extrinsic
function Extrinsic:encode()
    local call_data_bytes = hex_to_bytes(self.call_data)
    local out_ptr = ffi.new("uint8_t*[1]")
    local out_len = ffi.new("size_t[1]")
    
    -- Create FFI array for call data
    local call_data_buf = ffi.new("uint8_t[?]", #call_data_bytes)
    for i = 1, #call_data_bytes do
        call_data_buf[i-1] = call_data_bytes[i]
    end
    
    local result = lib.encode_unsigned_extrinsic(
        self.call_index[1],
        self.call_index[2],
        call_data_buf,
        #call_data_bytes,
        out_ptr,
        out_len
    )
    
    if result == 0 then
        local data = ffi.string(out_ptr[0], out_len[0])
        lib.free_encoded_extrinsic(out_ptr[0], out_len[0])
        return "0x" .. data:gsub(".", function(c) return string.format("%02x", string.byte(c)) end)
    else
        error("Failed to encode extrinsic")
    end
end

-- caching runtime constants per process
local _runtime_cache = nil

local json = require("dkjson")
local http = require("ssl.https")
local ltn12 = require("ltn12")

local RPC_URL = "https://paseo.rpc.amforc.com" -- Paseo testnet via Amforc

local function rpc_request(method, params)
    params = params or {}
    local payload = json.encode({jsonrpc="2.0", id=1, method=method, params=params})
    local response_chunks = {}
    local res, code = http.request{
        url = RPC_URL,
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = tostring(#payload)
        },
        source = ltn12.source.string(payload),
        sink = ltn12.sink.table(response_chunks),
    }
    if code ~= 200 then
        error("HTTP request failed with code " .. tostring(code))
    end
    local body = table.concat(response_chunks)
    local obj, pos, err = json.decode(body, 1, nil)
    if err then
        error("JSON decode error: " .. err)
    end
    if obj.error then
        error("RPC error: " .. json.encode(obj.error))
    end
    return obj.result
end

local function get_runtime_info()
    if _runtime_cache then return _runtime_cache end

    local version = rpc_request("state_getRuntimeVersion")
    local spec_version = tonumber(version.specVersion)
    local tx_version = tonumber(version.transactionVersion)

    local genesis_hash = rpc_request("chain_getBlockHash", {0})
    local block_hash = rpc_request("chain_getBlockHash")

    _runtime_cache = {
        spec_version = spec_version,
        tx_version = tx_version,
        genesis_hash = genesis_hash,
        block_hash = block_hash
    }
    return _runtime_cache
end

function Extrinsic:create_signed(signer)
    local call_data_bytes = hex_to_bytes(self.call_data)

    -- Convert arrays to C buffers
    local call_data_buf = ffi.new("uint8_t[?]", #call_data_bytes)
    for i = 1, #call_data_bytes do call_data_buf[i-1] = call_data_bytes[i] end

    -- Runtime info
    local rt = get_runtime_info()

    -- Prepare hashes bytes
    local genesis_bytes = hex_to_bytes(rt.genesis_hash)
    local block_bytes = hex_to_bytes(rt.block_hash)
    local genesis_buf = ffi.new("uint8_t[32]")
    local block_buf = ffi.new("uint8_t[32]")
    for i = 1, 32 do genesis_buf[i-1] = genesis_bytes[i] end
    for i = 1, 32 do block_buf[i-1] = block_bytes[i] end

    local tip_low = self.tip % (2^64)
    local tip_high = math.floor(self.tip / (2^64))

    -- Build signing payload via FFI
    local payload_ptr = ffi.new("uint8_t*[1]")
    local payload_len = ffi.new("size_t[1]")
    local res = lib.make_signing_payload(
        self.call_index[1],
        self.call_index[2],
        call_data_buf,
        #call_data_bytes,
        self.nonce,
        tip_low,
        tip_high,
        self.era.mortal,
        self.era.period,
        self.era.phase,
        rt.spec_version,
        rt.tx_version,
        genesis_buf,
        block_buf,
        payload_ptr,
        payload_len
    )
    if res ~= 0 then
        error("Failed to build signing payload")
    end

    local payload_data = ffi.string(payload_ptr[0], payload_len[0])
    lib.free_encoded_extrinsic(payload_ptr[0], payload_len[0])

    -- Convert payload bytes to hex
    local payload_hex = "0x" .. payload_data:gsub(".", function(c) return string.format("%02x", string.byte(c)) end)

    -- Sign
    local signature = signer:sign(payload_hex)
    local signature_bytes = hex_to_bytes(signature)

    -- Prepare buffers for encode_signed_extrinsic
    local signer_pub_hex = signer:get_public_key()
    local signer_bytes = hex_to_bytes(signer_pub_hex)

    local signer_buf = ffi.new("uint8_t[?]", #signer_bytes)
    local signature_buf = ffi.new("uint8_t[?]", #signature_bytes)
    for i = 1, #signer_bytes do signer_buf[i-1] = signer_bytes[i] end
    for i = 1, #signature_bytes do signature_buf[i-1] = signature_bytes[i] end

    -- Encode final extrinsic
    local out_ptr = ffi.new("uint8_t*[1]")
    local out_len = ffi.new("size_t[1]")
    local result = lib.encode_signed_extrinsic(
        self.call_index[1],
        self.call_index[2],
        call_data_buf,
        #call_data_bytes,
        signer_buf,
        signature_buf,
        self.nonce,
        tip_low,
        tip_high,
        self.era.mortal,
        self.era.period,
        self.era.phase,
        out_ptr,
        out_len
    )
    if result ~= 0 then error("Failed to encode signed extrinsic") end

    local data = ffi.string(out_ptr[0], out_len[0])
    lib.free_encoded_extrinsic(out_ptr[0], out_len[0])
    return "0x" .. data:gsub(".", function(c) return string.format("%02x", string.byte(c)) end)
end

return Extrinsic 