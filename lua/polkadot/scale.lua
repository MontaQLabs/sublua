-- polkadot/scale.lua
-- Pure Lua Implementation of SCALE Codec
-- See: https://docs.substrate.io/reference/scale-codec/
--
-- Internal convention: All functions work with raw bytes (not hex strings)
-- This matches Substrate's wire format and avoids conversion overhead

local Scale = {}

-- Helper: Little Endian conversions
local function u16_le(v) 
    return string.char(v % 256, (math.floor(v/256)) % 256) 
end

local function u32_le(v)
    return string.char(
        v % 256, 
        (math.floor(v/256)) % 256, 
        (math.floor(v/65536)) % 256, 
        (math.floor(v/16777216)) % 256
    )
end

-- SCALE Encode: Compact Integer
function Scale.encode_compact(n)
    assert(type(n) == "number", "encode_compact requires a number")
    assert(n >= 0, "encode_compact requires non-negative number")
    assert(n <= 2^53, "encode_compact value exceeds Lua number precision (2^53)")
    
    if n < 64 then
        -- Single byte: 0b00 + value (value << 2)
        return string.char(n * 4)
    elseif n < 16384 then -- 2^14
        -- Two bytes: 0b01 + value (little endian, value << 2 + 1)
        local value = n * 4 + 1
        return u16_le(value)
    elseif n < 1073741824 then -- 2^30
        -- Four bytes: 0b10 + value (little endian, value << 2 + 2)
        local value = n * 4 + 2
        return u32_le(value)
    else
        -- Big Integer Mode: 0b11 + length-4 + bytes
        -- For values >= 2^30, encode as variable-length bytes
        local bytes = {}
        local temp = n
        while temp > 0 do
            table.insert(bytes, temp % 256)
            temp = math.floor(temp / 256)
        end
        
        local len = #bytes
        assert(len >= 4, "BigInt mode requires at least 4 bytes")
        local header = (len - 4) * 4 + 3
        local res = string.char(header)
        for i = len, 1, -1 do  -- Most significant byte first
            res = res .. string.char(bytes[i])
        end
        return res
    end
end

-- SCALE Decode: Compact Integer (from raw bytes)
function Scale.decode_compact(data, offset)
    offset = offset or 1  -- Lua strings are 1-indexed
    assert(type(data) == "string", "decode_compact requires raw bytes (string)")
    assert(offset <= #data, "offset out of bounds")
    
    local b1 = string.byte(data, offset)
    local mode = b1 % 4
    
    if mode == 0 then
        -- Single byte: value = byte >> 2
        return math.floor(b1 / 4), offset + 1
    elseif mode == 1 then
        -- Two bytes: read as u16, shift right by 2
        assert(offset + 1 <= #data, "insufficient data for 2-byte compact")
        local b2 = string.byte(data, offset + 1)
        local u16_val = b1 + (b2 * 256)  -- Little-endian u16
        local val = math.floor(u16_val / 4)
        return val, offset + 2
    elseif mode == 2 then
        -- Four bytes: read as u32, shift right by 2
        assert(offset + 3 <= #data, "insufficient data for 4-byte compact")
        local b2 = string.byte(data, offset + 1)
        local b3 = string.byte(data, offset + 2)
        local b4 = string.byte(data, offset + 3)
        local u32_val = b1 + (b2 * 256) + (b3 * 65536) + (b4 * 16777216)  -- Little-endian u32
        local val = math.floor(u32_val / 4)
        return val, offset + 4
    else
        -- BigInt mode (0b11): length = (byte >> 2) + 4
        local len = math.floor(b1 / 4) + 4
        assert(offset + len - 1 <= #data, "insufficient data for bigint compact")
        
        -- Read len bytes as little-endian integer
        local val = 0
        for i = 0, len - 1 do
            local byte = string.byte(data, offset + 1 + i)
            val = val + byte * (256^i)
        end
        return val, offset + len
    end
end

-- SCALE Encode: Option<T>
-- 0x00 = None
-- 0x01 + encoded(value) = Some(value)
function Scale.encode_option(encoder, value)
    if value == nil then
        return "\0"
    else
        return "\1" .. encoder(value)
    end
end

-- SCALE Encode: Vector<T>
-- Compact(len) + encoded(item1) + ...
function Scale.encode_vector(encoder, list)
    local res = Scale.encode_compact(#list)
    for _, item in ipairs(list) do
        res = res .. encoder(item)
    end
    return res
end

-- SCALE Encode: Fixed-width integers
function Scale.encode_u8(n)
    assert(type(n) == "number", "encode_u8 requires a number")
    assert(n >= 0 and n <= 255, "encode_u8 value out of range [0, 255]")
    return string.char(n % 256)
end

function Scale.encode_u16(n)
    assert(type(n) == "number", "encode_u16 requires a number")
    assert(n >= 0 and n <= 65535, "encode_u16 value out of range [0, 65535]")
    return u16_le(n)
end

function Scale.encode_u32(n)
    assert(type(n) == "number", "encode_u32 requires a number")
    assert(n >= 0 and n <= 4294967295, "encode_u32 value out of range [0, 2^32-1]")
    return u32_le(n)
end

function Scale.encode_u64(n)
    assert(type(n) == "number", "encode_u64 requires a number")
    assert(n >= 0, "encode_u64 requires non-negative number")
    assert(n <= 2^53, "encode_u64 value exceeds Lua number precision (2^53)")
    
    local low = n % 4294967296  -- 2^32
    local high = math.floor(n / 4294967296)
    return u32_le(low) .. u32_le(high)
end

-- SCALE Encode: U128 (raw bytes input)
-- Input: 16-byte string (little-endian u128)
-- Output: same 16-byte string (identity function)
function Scale.encode_u128(bytes)
    assert(type(bytes) == "string", "encode_u128 requires raw bytes (string)")
    assert(#bytes == 16, "encode_u128 requires exactly 16 bytes")
    return bytes  -- Identity function - already in correct format
end

-- SCALE Decode: Fixed-width integers (from raw bytes)
function Scale.decode_u8(data, offset)
    offset = offset or 1
    assert(offset <= #data, "offset out of bounds")
    return string.byte(data, offset), offset + 1
end

function Scale.decode_u16(data, offset)
    offset = offset or 1
    assert(offset + 1 <= #data, "insufficient data for u16")
    local b1 = string.byte(data, offset)
    local b2 = string.byte(data, offset + 1)
    local val = b1 + (b2 * 256)  -- Little-endian
    return val, offset + 2
end

function Scale.decode_u32(data, offset)
    offset = offset or 1
    assert(offset + 3 <= #data, "insufficient data for u32")
    local b1 = string.byte(data, offset)
    local b2 = string.byte(data, offset + 1)
    local b3 = string.byte(data, offset + 2)
    local b4 = string.byte(data, offset + 3)
    local val = b1 + (b2 * 256) + (b3 * 65536) + (b4 * 16777216)  -- Little-endian
    return val, offset + 4
end

function Scale.decode_u64(data, offset)
    offset = offset or 1
    assert(offset + 7 <= #data, "insufficient data for u64")
    local low, _ = Scale.decode_u32(data, offset)
    local high, _ = Scale.decode_u32(data, offset + 4)
    -- Note: Only safe up to 2^53 due to Lua number precision
    local val = low + (high * 4294967296)
    return val, offset + 8
end

-- SCALE Decode: U128 (returns raw bytes)
-- Input: raw bytes, offset
-- Output: 16-byte string (little-endian u128), new offset
function Scale.decode_u128(data, offset)
    offset = offset or 1
    assert(offset + 15 <= #data, "insufficient data for u128")
    local bytes = data:sub(offset, offset + 15)  -- Extract 16 bytes
    return bytes, offset + 16
end

return Scale
