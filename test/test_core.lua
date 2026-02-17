-- test/test_core.lua
-- Fix paths to work from test directory or root
package.cpath = package.cpath .. ";../c_src/?.so;./c_src/?.so"

local crypto = require("polkadot_crypto")
print("✅ Module loaded successfully: " .. tostring(crypto))

-- Test Blake2b
local input = "abc"
local hash = crypto.blake2b(input, 32)
local hex = (hash:gsub(".", function(c) return string.format("%02x", string.byte(c)) end))
print("Blake2b('abc'): " .. hex)
assert(hex == "bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319")

-- Test Twox128
local twox = crypto.twox128(input)
print("Twox128('abc'): " .. (twox:gsub(".", function(c) return string.format("%02x", string.byte(c)) end)))

-- Test Ed25519
local seed = string.rep("\0", 32)
local pubkey = crypto.ed25519_keypair_from_seed(seed)
local sig = crypto.ed25519_sign(seed, "hello")
local valid = crypto.ed25519_verify(pubkey, "hello", sig)
assert(valid == true)
print("✅ Ed25519 verification successful")

-- Test SS58
local addr = crypto.ss58_encode(pubkey, 42)
print("SS58 Address (v42): " .. addr)
local d_pub, d_ver = crypto.ss58_decode(addr)
assert(d_pub == pubkey)
assert(d_ver == 42)
print("✅ SS58 roundtrip successful")

print("\n🚀 ALL CORE TESTS PASSED")
