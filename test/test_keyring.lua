-- test/test_keyring.lua
-- Comprehensive tests for keyring module

-- Fix paths to work from test directory or root
package.cpath = package.cpath .. ";../c_src/?.so;./c_src/?.so"
package.path = package.path .. ";../lua/?.lua;../lua/?/init.lua;./lua/?.lua;./lua/?/init.lua"

local Keyring = require("polkadot.keyring")
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

print("=== Keyring Tests ===\n")

-- from_seed Tests
test("Keyring: from_seed with hex string", function()
    local seed_hex = "0x" .. string.rep("00", 32)
    local keypair = Keyring.from_seed(seed_hex)
    assert(keypair.seed ~= nil)
    assert(#keypair.seed == 32)
    assert(#keypair.pubkey == 32)
    assert(type(keypair.address) == "string")
    assert(#keypair.address > 0)
    assert(type(keypair.sign) == "function")
end)

test("Keyring: from_seed without 0x prefix (raw bytes)", function()
    -- Pass raw bytes (32 bytes of zeros)
    local seed = string.rep("\0", 32)
    local keypair = Keyring.from_seed(seed)
    assert(#keypair.seed == 32)
    assert(keypair.seed == seed)
end)

test("Keyring: from_seed with raw bytes", function()
    local seed = string.rep("\0", 32)
    local keypair = Keyring.from_seed(seed)
    assert(keypair.seed == seed)
end)

test("Keyring: Deterministic key generation", function()
    local seed = string.rep("a", 32)
    local k1 = Keyring.from_seed(seed)
    local k2 = Keyring.from_seed(seed)
    assert(k1.pubkey == k2.pubkey)
    assert(k1.address == k2.address)
end)

test("Keyring: Different seeds produce different keys", function()
    local k1 = Keyring.from_seed(string.rep("a", 32))
    local k2 = Keyring.from_seed(string.rep("b", 32))
    assert(k1.pubkey ~= k2.pubkey)
    assert(k1.address ~= k2.address)
end)

test("Keyring: Error on invalid seed length", function()
    local ok, err = pcall(function() Keyring.from_seed("short") end)
    assert(not ok)
end)

test("Keyring: SS58 address format", function()
    local keypair = Keyring.from_seed(string.rep("a", 32))
    -- Address should be valid SS58
    local pub, ver = crypto.ss58_decode(keypair.address)
    assert(pub == keypair.pubkey)
    assert(ver == 42) -- Default Substrate version
end)

-- Signing Tests
test("Keyring: Sign message", function()
    local keypair = Keyring.from_seed(string.rep("a", 32))
    local message = "Hello, Substrate!"
    local sig = keypair:sign(message)
    assert(#sig == 64)
    
    -- Verify signature
    local valid = crypto.ed25519_verify(keypair.pubkey, message, sig)
    assert(valid == true)
end)

test("Keyring: Sign different messages", function()
    local keypair = Keyring.from_seed(string.rep("a", 32))
    local sig1 = keypair:sign("message1")
    local sig2 = keypair:sign("message2")
    assert(sig1 ~= sig2)
end)

test("Keyring: Sign empty message", function()
    local keypair = Keyring.from_seed(string.rep("a", 32))
    local sig = keypair:sign("")
    assert(#sig == 64)
    local valid = crypto.ed25519_verify(keypair.pubkey, "", sig)
    assert(valid == true)
end)

test("Keyring: Sign long message", function()
    local keypair = Keyring.from_seed(string.rep("a", 32))
    local long_msg = string.rep("x", 10000)
    local sig = keypair:sign(long_msg)
    local valid = crypto.ed25519_verify(keypair.pubkey, long_msg, sig)
    assert(valid == true)
end)

-- from_uri Tests
test("Keyring: from_uri with //Alice", function()
    local keypair = Keyring.from_uri("//Alice")
    assert(keypair ~= nil)
    assert(#keypair.seed == 32)
    assert(#keypair.pubkey == 32)
    -- Should be deterministic
    local k2 = Keyring.from_uri("//Alice")
    assert(k2.pubkey == keypair.pubkey)
end)

test("Keyring: from_uri error on unsupported URI", function()
    local ok, err = pcall(function() Keyring.from_uri("//Bob") end)
    assert(not ok)
end)

-- Address generation with different SS58 versions
test("Keyring: Address generation consistency", function()
    local seed = string.rep("a", 32)
    local k1 = Keyring.from_seed(seed)
    local k2 = Keyring.from_seed(seed)
    -- Should generate same address
    assert(k1.address == k2.address)
end)

-- Edge cases
test("Keyring: Seed with all zeros", function()
    local keypair = Keyring.from_seed(string.rep("\0", 32))
    assert(keypair ~= nil)
    assert(#keypair.pubkey == 32)
end)

test("Keyring: Seed with all 0xFF", function()
    local keypair = Keyring.from_seed(string.rep("\255", 32))
    assert(keypair ~= nil)
    assert(#keypair.pubkey == 32)
end)

test("Keyring: Public key matches C module", function()
    local seed = string.rep("a", 32)
    local keypair = Keyring.from_seed(seed)
    local c_pubkey = crypto.ed25519_keypair_from_seed(seed)
    assert(keypair.pubkey == c_pubkey)
end)

print("\n=== Keyring Test Results ===")
print("Passed: " .. tests_passed)
print("Failed: " .. tests_failed)
if tests_failed == 0 then
    print("🎉 All keyring tests passed!")
    return 0
else
    print("❌ Some tests failed")
    return 1
end
