-- test/test_scale.lua
-- Comprehensive tests for SCALE codec

-- Fix paths to work from test directory or root
package.cpath = package.cpath .. ";../c_src/?.so;./c_src/?.so"
package.path = package.path .. ";../lua/?.lua;../lua/?/init.lua;./lua/?.lua;./lua/?/init.lua"

local Scale = require("polkadot.scale")

local function to_hex(str)
    return (str:gsub(".", function(c) return string.format("%02x", string.byte(c)) end))
end

local function from_hex(hex)
    hex = hex:gsub("^0x", "")
    return (hex:gsub("..", function(cc) return string.char(tonumber(cc, 16)) end))
end

local tests_passed = 0
local tests_failed = 0

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        tests_passed = tests_passed + 1
        print("✅ " .. name)
    else
        tests_failed = tests_failed + 1
        print("❌ " .. name .. ": " .. tostring(err))
    end
end

print("=== SCALE Codec Tests ===\n")

-- Compact Integer Tests
test("Compact: Single byte (0-63)", function()
    for i = 0, 63 do
        local enc = Scale.encode_compact(i)
        assert(#enc == 1)
        local dec, offset = Scale.decode_compact(to_hex(enc))
        assert(dec == i)
        assert(offset == 2)
    end
end)

test("Compact: Two bytes (64-16383)", function()
    local test_cases = {64, 255, 1000, 16383}
    for _, n in ipairs(test_cases) do
        local enc = Scale.encode_compact(n)
        assert(#enc == 2)
        local dec, offset = Scale.decode_compact(to_hex(enc))
        assert(dec == n)
        assert(offset == 4)
    end
end)

test("Compact: Four bytes (16384-1073741823)", function()
    local test_cases = {16384, 65535, 1000000, 1073741823}
    for _, n in ipairs(test_cases) do
        local enc = Scale.encode_compact(n)
        assert(#enc == 4)
        local dec, offset = Scale.decode_compact(to_hex(enc))
        assert(dec == n)
        assert(offset == 8)
    end
end)

test("Compact: BigInt mode (>= 1073741824)", function()
    local test_cases = {1073741824, 2^31, 10^12}
    for _, n in ipairs(test_cases) do
        local enc = Scale.encode_compact(n)
        assert(#enc >= 5)
        local dec, offset = Scale.decode_compact(to_hex(enc))
        -- Note: May lose precision for very large numbers due to Lua number limits
        if n < 2^53 then
            assert(dec == n)
        end
    end
end)

test("Compact: Roundtrip edge cases", function()
    local cases = {0, 1, 63, 64, 65, 16383, 16384, 16385, 65535, 65536}
    for _, n in ipairs(cases) do
        local enc = Scale.encode_compact(n)
        local dec, _ = Scale.decode_compact(to_hex(enc))
        assert(dec == n, "Failed for " .. n)
    end
end)

-- U8 Tests
test("U8: Encode", function()
    assert(#Scale.encode_u8(0) == 1)
    assert(#Scale.encode_u8(255) == 1)
    assert(Scale.encode_u8(0) == string.char(0))
    assert(Scale.encode_u8(255) == string.char(255))
end)

test("U8: Wrap around", function()
    assert(Scale.encode_u8(256) == Scale.encode_u8(0))
    assert(Scale.encode_u8(257) == Scale.encode_u8(1))
end)

-- U16 Tests
test("U16: Encode", function()
    assert(#Scale.encode_u16(0) == 2)
    assert(#Scale.encode_u16(65535) == 2)
    local enc = Scale.encode_u16(0x1234)
    assert(string.byte(enc, 1) == 0x34)
    assert(string.byte(enc, 2) == 0x12)
end)

test("U16: Little endian", function()
    local enc = Scale.encode_u16(1)
    assert(string.byte(enc, 1) == 1)
    assert(string.byte(enc, 2) == 0)
end)

-- U32 Tests
test("U32: Encode", function()
    assert(#Scale.encode_u32(0) == 4)
    assert(#Scale.encode_u32(4294967295) == 4)
    local enc = Scale.encode_u32(0x12345678)
    assert(string.byte(enc, 1) == 0x78)
    assert(string.byte(enc, 4) == 0x12)
end)

test("U32: Little endian", function()
    local enc = Scale.encode_u32(1)
    assert(string.byte(enc, 1) == 1)
    assert(string.byte(enc, 2) == 0)
    assert(string.byte(enc, 3) == 0)
    assert(string.byte(enc, 4) == 0)
end)

-- U64 Tests
test("U64: Encode", function()
    assert(#Scale.encode_u64(0) == 8)
    assert(#Scale.encode_u64(2^32) == 8)
    local enc = Scale.encode_u64(1)
    assert(string.byte(enc, 1) == 1)
    assert(string.byte(enc, 5) == 0)
end)

test("U64: High bits", function()
    local enc = Scale.encode_u64(2^32)
    assert(string.byte(enc, 5) == 1)
    assert(string.byte(enc, 1) == 0)
end)

-- U128 Tests
test("U128: Encode", function()
    assert(#Scale.encode_u128(0) == 16)
    assert(#Scale.encode_u128(1000000) == 16)
end)

test("U128: Large values", function()
    local enc = Scale.encode_u128(10^12)
    assert(#enc == 16)
end)

-- Option Tests
test("Option: None (nil)", function()
    local enc = Scale.encode_option(function() return "" end, nil)
    assert(enc == "\0")
    assert(#enc == 1)
end)

test("Option: Some(value)", function()
    local enc = Scale.encode_option(Scale.encode_u8, 42)
    assert(string.byte(enc, 1) == 1)
    assert(string.byte(enc, 2) == 42)
end)

test("Option: Some with complex value", function()
    local enc = Scale.encode_option(Scale.encode_u32, 1000)
    assert(string.byte(enc, 1) == 1)
    assert(#enc == 5) -- 1 byte flag + 4 bytes u32
end)

-- Vector Tests
test("Vector: Empty", function()
    local enc = Scale.encode_vector(Scale.encode_u8, {})
    local len, offset = Scale.decode_compact(to_hex(enc))
    assert(len == 0)
end)

test("Vector: Single element", function()
    local enc = Scale.encode_vector(Scale.encode_u8, {42})
    local len, offset = Scale.decode_compact(to_hex(enc))
    assert(len == 1)
    assert(string.byte(enc, 2) == 42)
end)

test("Vector: Multiple elements", function()
    local vec = {1, 2, 3, 4, 5}
    local enc = Scale.encode_vector(Scale.encode_u8, vec)
    local len, offset = Scale.decode_compact(to_hex(enc))
    assert(len == 5)
    for i = 1, 5 do
        assert(string.byte(enc, offset/2 + i) == i)
    end
end)

test("Vector: U32 elements", function()
    local vec = {100, 200, 300}
    local enc = Scale.encode_vector(Scale.encode_u32, vec)
    local len, offset = Scale.decode_compact(to_hex(enc))
    assert(len == 3)
    assert(#enc == 1 + 3*4) -- 1 byte length + 3*4 bytes
end)

-- Integration: Real-world SCALE encoding patterns
test("SCALE: Account nonce pattern", function()
    -- AccountInfo nonce is u32
    local nonce = 42
    local enc = Scale.encode_u32(nonce)
    assert(#enc == 4)
end)

test("SCALE: Balance pattern", function()
    -- Balance is Compact<u128>
    local balance = 1000000000000 -- 1 DOT (assuming 12 decimals)
    local enc = Scale.encode_compact(balance)
    assert(#enc > 0)
end)

test("SCALE: Call index pattern", function()
    -- Call index is u16 (palette index) + u16 (call index)
    local palette_idx = 4
    local call_idx = 0
    local enc = Scale.encode_u16(palette_idx) .. Scale.encode_u16(call_idx)
    assert(#enc == 4)
end)

print("\n=== SCALE Codec Test Results ===")
print("Passed: " .. tests_passed)
print("Failed: " .. tests_failed)
if tests_failed == 0 then
    print("🎉 All SCALE codec tests passed!")
    return 0
else
    print("❌ Some tests failed")
    return 1
end
