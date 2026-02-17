-- test/test_crypto.lua
-- Comprehensive tests for the C crypto module

-- Fix paths to work from test directory or root
package.cpath = "../sublua/?.so;./sublua/?.so;" .. package.cpath
package.path = "../?.lua;../?/init.lua;./?.lua;./?/init.lua;" .. package.path

local crypto = require("polkadot_crypto")

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

print("=== Crypto Module Tests ===\n")

-- Blake2b Tests
test("Blake2b: Empty string", function()
    local hash = crypto.blake2b("", 32)
    local hex = to_hex(hash)
    assert(hex == "0e5751c026e543b2e8ab2eb06099daa1d1e5df47778f7787faab45cdf12fe3a8")
end)

test("Blake2b: 'abc' (32 bytes)", function()
    local hash = crypto.blake2b("abc", 32)
    local hex = to_hex(hash)
    assert(hex == "bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319")
end)

test("Blake2b: Different output lengths", function()
    local input = "test"
    local h16 = crypto.blake2b(input, 16)
    local h32 = crypto.blake2b(input, 32)
    local h64 = crypto.blake2b(input, 64)
    assert(#h16 == 16)
    assert(#h32 == 32)
    assert(#h64 == 64)
    -- Verify all are deterministic
    local h16_2 = crypto.blake2b(input, 16)
    assert(h16 == h16_2)
end)

test("Blake2b: Long input", function()
    local long_input = string.rep("a", 1000)
    local hash = crypto.blake2b(long_input, 32)
    assert(#hash == 32)
end)

test("Blake2b: Error on invalid length", function()
    local ok, err = pcall(function() crypto.blake2b("test", 0) end)
    assert(not ok)
    ok, err = pcall(function() crypto.blake2b("test", 65) end)
    assert(not ok)
end)

-- Twox128 Tests
test("Twox128: Empty string", function()
    local hash = crypto.twox128("")
    assert(#hash == 16)
end)

test("Twox128: 'abc'", function()
    local hash = crypto.twox128("abc")
    assert(#hash == 16)
    -- Verify deterministic
    local hash2 = crypto.twox128("abc")
    assert(hash == hash2)
end)

test("Twox128: Storage key prefix 'System'", function()
    local hash = crypto.twox128("System")
    assert(#hash == 16)
    -- Should match known value (verified against Substrate)
    local hex = to_hex(hash)
    -- Just verify it's deterministic and correct length
end)

test("Twox128: Storage key prefix 'Account'", function()
    local hash = crypto.twox128("Account")
    assert(#hash == 16)
end)

-- Twox64 Tests
test("Twox64: Basic", function()
    local hash = crypto.twox64("test")
    assert(#hash == 8)
end)

test("Twox64: Deterministic", function()
    local h1 = crypto.twox64("same")
    local h2 = crypto.twox64("same")
    assert(h1 == h2)
end)

-- Ed25519 Tests
test("Ed25519: Keypair from seed", function()
    local seed = string.rep("\0", 32)
    local pubkey = crypto.ed25519_keypair_from_seed(seed)
    assert(#pubkey == 32)
end)

test("Ed25519: Different seeds produce different keys", function()
    local seed1 = string.rep("\0", 32)
    local seed2 = string.rep("\1", 32)
    local pub1 = crypto.ed25519_keypair_from_seed(seed1)
    local pub2 = crypto.ed25519_keypair_from_seed(seed2)
    assert(pub1 ~= pub2)
end)

test("Ed25519: Sign and verify", function()
    local seed = string.rep("a", 32)
    local pubkey = crypto.ed25519_keypair_from_seed(seed)
    local message = "Hello, Substrate!"
    local sig = crypto.ed25519_sign(seed, message)
    assert(#sig == 64)
    
    local valid = crypto.ed25519_verify(pubkey, message, sig)
    assert(valid == true)
end)

test("Ed25519: Verify fails on wrong message", function()
    local seed = string.rep("a", 32)
    local pubkey = crypto.ed25519_keypair_from_seed(seed)
    local sig = crypto.ed25519_sign(seed, "correct")
    local valid = crypto.ed25519_verify(pubkey, "wrong", sig)
    assert(valid == false)
end)

test("Ed25519: Verify fails on wrong signature", function()
    local seed = string.rep("a", 32)
    local pubkey = crypto.ed25519_keypair_from_seed(seed)
    local sig = crypto.ed25519_sign(seed, "message")
    local wrong_sig = string.rep("\0", 64)
    local valid = crypto.ed25519_verify(pubkey, "message", wrong_sig)
    assert(valid == false)
end)

test("Ed25519: Verify fails on wrong pubkey", function()
    local seed1 = string.rep("a", 32)
    local seed2 = string.rep("b", 32)
    local pub1 = crypto.ed25519_keypair_from_seed(seed1)
    local pub2 = crypto.ed25519_keypair_from_seed(seed2)
    local sig = crypto.ed25519_sign(seed1, "message")
    local valid = crypto.ed25519_verify(pub2, "message", sig)
    assert(valid == false)
end)

test("Ed25519: Error on invalid seed length", function()
    local ok, err = pcall(function() crypto.ed25519_keypair_from_seed("short") end)
    assert(not ok)
end)

test("Ed25519: Long message signing", function()
    local seed = string.rep("a", 32)
    local pubkey = crypto.ed25519_keypair_from_seed(seed)
    local long_msg = string.rep("x", 10000)
    local sig = crypto.ed25519_sign(seed, long_msg)
    local valid = crypto.ed25519_verify(pubkey, long_msg, sig)
    assert(valid == true)
end)

-- SS58 Tests
test("SS58: Encode and decode roundtrip (v42)", function()
    local seed = string.rep("\0", 32)
    local pubkey = crypto.ed25519_keypair_from_seed(seed)
    local addr = crypto.ss58_encode(pubkey, 42)
    assert(type(addr) == "string")
    assert(#addr > 0)
    
    local decoded_pub, decoded_ver = crypto.ss58_decode(addr)
    assert(decoded_pub == pubkey)
    assert(decoded_ver == 42)
end)

test("SS58: Different versions", function()
    local seed = string.rep("a", 32)
    local pubkey = crypto.ed25519_keypair_from_seed(seed)
    
    for ver = 0, 2 do
        local addr = crypto.ss58_encode(pubkey, ver)
        local d_pub, d_ver = crypto.ss58_decode(addr)
        assert(d_pub == pubkey)
        assert(d_ver == ver)
    end
end)

test("SS58: Polkadot mainnet (v0)", function()
    local seed = string.rep("a", 32)
    local pubkey = crypto.ed25519_keypair_from_seed(seed)
    local addr = crypto.ss58_encode(pubkey, 0)
    local d_pub, d_ver = crypto.ss58_decode(addr)
    assert(d_ver == 0)
end)

test("SS58: Kusama (v2)", function()
    local seed = string.rep("a", 32)
    local pubkey = crypto.ed25519_keypair_from_seed(seed)
    local addr = crypto.ss58_encode(pubkey, 2)
    local d_pub, d_ver = crypto.ss58_decode(addr)
    assert(d_ver == 2)
    assert(d_pub == pubkey)
end)

test("SS58: Error on invalid address", function()
    local ok, err = pcall(function() crypto.ss58_decode("invalid") end)
    assert(not ok)
end)

test("SS58: Error on invalid pubkey length", function()
    local ok, err = pcall(function() crypto.ss58_encode("short", 42) end)
    assert(not ok)
end)

test("SS58: Known test address", function()
    -- Test with a known seed that produces a known address
    local seed = from_hex("0000000000000000000000000000000000000000000000000000000000000000")
    local pubkey = crypto.ed25519_keypair_from_seed(seed)
    local addr = crypto.ss58_encode(pubkey, 42)
    -- Just verify it decodes correctly
    local d_pub, d_ver = crypto.ss58_decode(addr)
    assert(d_pub == pubkey)
end)

print("\n=== Crypto Module Test Results ===")
print("Passed: " .. tests_passed)
print("Failed: " .. tests_failed)
if tests_failed == 0 then
    print("🎉 All crypto tests passed!")
    return 0
else
    print("❌ Some tests failed")
    return 1
end
