-- sdk/core/extrinsic.lua

local ffi_mod = require("sdk.polkadot_ffi")
local ffi  = ffi_mod.ffi
local lib  = ffi_mod.lib
local bit  = require("bit")
local util = require("sdk.core.util")

local Extrinsic = {}
Extrinsic.__index = Extrinsic

--- Create a new Extrinsic object.
-- @param call_index table<int,int> two bytes identifying pallet+call
-- @param call_data  string|table hex string or byte array of call arguments (SCALE pre-encoded)
function Extrinsic.new(call_index, call_data)
    assert(type(call_index) == "table" and #call_index == 2,
           "call_index must be {pallet, call}")
    local self = setmetatable({}, Extrinsic)
    self.call_index = call_index
    self.call_data  = call_data
    self.nonce      = 0
    self.tip        = 0
    self.era        = { mortal=false, period=0, phase=0 }
    return self
end

function Extrinsic:set_nonce(n)
    self.nonce = assert(tonumber(n), "nonce must be number")
    return self
end

function Extrinsic:set_tip(t)
    self.tip = assert(tonumber(t), "tip must be number")
    return self
end

function Extrinsic:set_era(mortal, period, phase)
    self.era = { mortal=not not mortal, period=period or 0, phase=phase or 0 }
    return self
end

function Extrinsic:set_era_immortal()
    self.era = { mortal=false, period=0, phase=0 }
    return self
end

-- Internal: encode call_data into byte buffer
local function prepare_buffer(bytes)
    local buf = ffi.new("uint8_t[?]", #bytes)
    for i = 1, #bytes do buf[i-1] = bytes[i] end
    return buf
end

--- Encode unsigned extrinsic, returns hex string (with 0x prefix)
function Extrinsic:encode_unsigned()
    local data_bytes = type(self.call_data)=="string" and util.hex_to_bytes(self.call_data) or self.call_data
    local data_buf   = prepare_buffer(data_bytes)
    local out_ptr    = ffi.new("uint8_t*[1]")
    local out_len    = ffi.new("size_t[1]")

    local ret = lib.encode_unsigned_extrinsic(self.call_index[1], self.call_index[2],
                                              data_buf, #data_bytes, out_ptr, out_len)
    assert(ret == 0, "encode_unsigned_extrinsic failed (code "..ret..")")

    local result = ffi.string(out_ptr[0], out_len[0])
    lib.free_encoded_extrinsic(out_ptr[0], out_len[0])
    return "0x" .. util.bytes_to_hex{string.byte(result,1,#result)}
end

--- Encode signed extrinsic, returns hex string (with 0x prefix)
function Extrinsic:encode_signed(signature, public_key, transaction_version)
    transaction_version = transaction_version or 4  -- Default to version 4 for backward compatibility
    
    local data_bytes   = type(self.call_data)=="string" and util.hex_to_bytes(self.call_data) or self.call_data
    local data_buf     = prepare_buffer(data_bytes)
    local signature_b  = util.hex_to_bytes(signature)
    local public_b     = util.hex_to_bytes(public_key)

    local sig_buf      = prepare_buffer(signature_b)
    local pub_buf      = prepare_buffer(public_b)

    local tip_low  = self.tip % bit.lshift(1,64)
    local tip_high = math.floor(self.tip / bit.lshift(1,64))

    local out_ptr = ffi.new("uint8_t*[1]")
    local out_len = ffi.new("size_t[1]")

    local ret = lib.encode_signed_extrinsic(self.call_index[1], self.call_index[2],
                                            data_buf, #data_bytes,
                                            pub_buf, sig_buf,
                                            self.nonce,
                                            tip_low, tip_high,
                                            self.era.mortal, self.era.period, self.era.phase,
                                            transaction_version,
                                            out_ptr, out_len)
    assert(ret == 0, "encode_signed_extrinsic failed (code "..ret..")")

    local result = ffi.string(out_ptr[0], out_len[0])
    lib.free_encoded_extrinsic(out_ptr[0], out_len[0])
    return "0x" .. util.bytes_to_hex{string.byte(result,1,#result)}
end

return Extrinsic 