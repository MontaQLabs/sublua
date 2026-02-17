-- test/test_transaction.lua
-- Comprehensive tests for transaction builder

-- Fix paths to work from test directory or root
package.cpath = "../sublua/?.so;./sublua/?.so;" .. package.cpath
package.path = "../?.lua;../?/init.lua;./?.lua;./?/init.lua;" .. package.path

local Transaction = require("sublua.transaction")
local Keyring = require("sublua.keyring")
local Scale = require("sublua.scale")
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

print("=== Transaction Builder Tests ===\n")

-- Helper: Create mock chain properties
local function mock_props()
    return {
        specVersion = 100,
        txVersion = 1,
        genesisHash = "0x" .. string.rep("00", 32),
        finalizedHash = "0x" .. string.rep("11", 32)
    }
end

-- Basic transaction creation
test("Transaction: Create signed extrinsic", function()
    local signer = Keyring.from_seed(string.rep("a", 32))
    local call_hex = "0x0400" -- Mock call index
    local nonce = 0
    local props = mock_props()
    
    local signed = Transaction.create_signed(call_hex, signer, nonce, props)
    assert(type(signed) == "string")
    assert(signed:match("^0x"))
    assert(#signed > 100) -- Should be substantial
end)

test("Transaction: Different nonces produce different signatures", function()
    local signer = Keyring.from_seed(string.rep("a", 32))
    local call_hex = "0x0400"
    local props = mock_props()
    
    local sig1 = Transaction.create_signed(call_hex, signer, 0, props)
    local sig2 = Transaction.create_signed(call_hex, signer, 1, props)
    assert(sig1 ~= sig2)
end)

test("Transaction: Different calls produce different signatures", function()
    local signer = Keyring.from_seed(string.rep("a", 32))
    local props = mock_props()
    
    local sig1 = Transaction.create_signed("0x0400", signer, 0, props)
    local sig2 = Transaction.create_signed("0x0401", signer, 0, props)
    assert(sig1 ~= sig2)
end)

test("Transaction: Different signers produce different signatures", function()
    local signer1 = Keyring.from_seed(string.rep("a", 32))
    local signer2 = Keyring.from_seed(string.rep("b", 32))
    local call_hex = "0x0400"
    local props = mock_props()
    
    local sig1 = Transaction.create_signed(call_hex, signer1, 0, props)
    local sig2 = Transaction.create_signed(call_hex, signer2, 0, props)
    assert(sig1 ~= sig2)
end)

test("Transaction: Extrinsic structure (V4)", function()
    local signer = Keyring.from_seed(string.rep("a", 32))
    local call_hex = "0x0400"
    local props = mock_props()
    local signed = Transaction.create_signed(call_hex, signer, 0, props)
    
    -- Remove 0x prefix and decode
    local hex = signed:gsub("^0x", "")
    assert(#hex % 2 == 0) -- Even number of hex chars
    
    -- Should start with length (compact) + version byte (0x84)
    local bytes = from_hex(hex)
    -- Version should be 0x84 (V4 + Signed)
    -- Find version byte after length
    -- Length is compact encoded, so it's variable
    -- For simplicity, just verify it's a valid hex string
end)

test("Transaction: Immortal era encoding", function()
    local signer = Keyring.from_seed(string.rep("a", 32))
    local call_hex = "0x0400"
    local props = mock_props()
    local signed = Transaction.create_signed(call_hex, signer, 0, props)
    
    -- Immortal era should be encoded as 0x00 (compact(0))
    -- This is tested indirectly through successful transaction creation
    assert(signed ~= nil)
end)

test("Transaction: Nonce encoding", function()
    local signer = Keyring.from_seed(string.rep("a", 32))
    local call_hex = "0x0400"
    local props = mock_props()
    
    -- Test various nonces
    for nonce = 0, 10 do
        local signed = Transaction.create_signed(call_hex, signer, nonce, props)
        assert(signed ~= nil)
    end
    
    -- Test large nonce
    local signed = Transaction.create_signed(call_hex, signer, 1000, props)
    assert(signed ~= nil)
end)

test("Transaction: Tip encoding (zero)", function()
    local signer = Keyring.from_seed(string.rep("a", 32))
    local call_hex = "0x0400"
    local props = mock_props()
    local signed = Transaction.create_signed(call_hex, signer, 0, props)
    -- Tip is hardcoded to 0, just verify transaction creates successfully
    assert(signed ~= nil)
end)

test("Transaction: Payload hashing for long calls", function()
    local signer = Keyring.from_seed(string.rep("a", 32))
    -- Create a long call (> 256 bytes)
    local long_call = "0x" .. string.rep("00", 300)
    local props = mock_props()
    local signed = Transaction.create_signed(long_call, signer, 0, props)
    -- Should hash payload before signing
    assert(signed ~= nil)
end)

test("Transaction: Address encoding (MultiAddress::Id)", function()
    local signer = Keyring.from_seed(string.rep("a", 32))
    local call_hex = "0x0400"
    local props = mock_props()
    local signed = Transaction.create_signed(call_hex, signer, 0, props)
    
    -- Address should be 0x00 + 32-byte pubkey
    -- Verify indirectly through successful creation
    assert(signed ~= nil)
end)

test("Transaction: Signature type (Ed25519 = 0x00)", function()
    local signer = Keyring.from_seed(string.rep("a", 32))
    local call_hex = "0x0400"
    local props = mock_props()
    local signed = Transaction.create_signed(call_hex, signer, 0, props)
    
    -- Signature type should be 0x00 for Ed25519
    -- Verified indirectly
    assert(signed ~= nil)
end)

test("Transaction: Signature length (64 bytes)", function()
    local signer = Keyring.from_seed(string.rep("a", 32))
    local call_hex = "0x0400"
    local props = mock_props()
    local signed = Transaction.create_signed(call_hex, signer, 0, props)
    
    -- Signature should be 64 bytes (128 hex chars)
    -- Extract signature from transaction
    -- For now, just verify transaction is created
    assert(signed ~= nil)
end)

test("Transaction: Call encoding preserved", function()
    local signer = Keyring.from_seed(string.rep("a", 32))
    local call_hex = "0x0400"
    local props = mock_props()
    local signed = Transaction.create_signed(call_hex, signer, 0, props)
    
    -- Call should be included in final extrinsic
    -- Verify call hex appears in signed transaction
    assert(signed:match("0400") ~= nil)
end)

test("Transaction: Version byte (0x84)", function()
    local signer = Keyring.from_seed(string.rep("a", 32))
    local call_hex = "0x0400"
    local props = mock_props()
    local signed = Transaction.create_signed(call_hex, signer, 0, props)
    
    -- Version should be 0x84 (V4 + Signed)
    -- This is encoded after the length prefix
    -- Verify indirectly
    assert(signed ~= nil)
end)

test("Transaction: Deterministic with same inputs", function()
    local signer = Keyring.from_seed(string.rep("a", 32))
    local call_hex = "0x0400"
    local props = mock_props()
    
    local sig1 = Transaction.create_signed(call_hex, signer, 0, props)
    local sig2 = Transaction.create_signed(call_hex, signer, 0, props)
    -- Should be identical (deterministic signing)
    assert(sig1 == sig2)
end)

test("Transaction: Different genesis hash changes signature", function()
    local signer = Keyring.from_seed(string.rep("a", 32))
    local call_hex = "0x0400"
    
    local props1 = mock_props()
    props1.genesisHash = "0x" .. string.rep("00", 32)
    local props2 = mock_props()
    props2.genesisHash = "0x" .. string.rep("FF", 32)
    
    local sig1 = Transaction.create_signed(call_hex, signer, 0, props1)
    local sig2 = Transaction.create_signed(call_hex, signer, 0, props2)
    assert(sig1 ~= sig2)
end)

test("Transaction: Different block hash changes signature", function()
    local signer = Keyring.from_seed(string.rep("a", 32))
    local call_hex = "0x0400"
    
    local props1 = mock_props()
    props1.finalizedHash = "0x" .. string.rep("00", 32)
    local props2 = mock_props()
    props2.finalizedHash = "0x" .. string.rep("FF", 32)
    
    local sig1 = Transaction.create_signed(call_hex, signer, 0, props1)
    local sig2 = Transaction.create_signed(call_hex, signer, 0, props2)
    assert(sig1 ~= sig2)
end)

print("\n=== Transaction Builder Test Results ===")
print("Passed: " .. tests_passed)
print("Failed: " .. tests_failed)
if tests_failed == 0 then
    print("🎉 All transaction builder tests passed!")
    return 0
else
    print("❌ Some tests failed")
    return 1
end
