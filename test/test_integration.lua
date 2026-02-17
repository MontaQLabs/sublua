-- test/test_integration.lua
-- Integration tests (may require network access)

-- Fix paths to work from test directory or root
package.cpath = package.cpath .. ";../c_src/?.so;./c_src/?.so"
package.path = package.path .. ";../lua/?.lua;../lua/?/init.lua;./lua/?.lua;./lua/?/init.lua"

local polkadot = require("polkadot")
local Keyring = require("polkadot.keyring")
local Transaction = require("polkadot.transaction")
local Scale = require("polkadot.scale")
local crypto = require("polkadot_crypto")

local tests_passed = 0
local tests_failed = 0
local tests_skipped = 0

local function test(name, fn, requires_network)
    if requires_network then
        -- Check if we should skip network tests
        local skip_network = os.getenv("SKIP_NETWORK_TESTS")
        if skip_network == "1" then
            tests_skipped = tests_skipped + 1
            print("⏭️  " .. name .. " (skipped - SKIP_NETWORK_TESTS=1)")
            return
        end
    end
    
    local ok, err = pcall(fn)
    if ok then
        tests_passed = tests_passed + 1
        print("✅ " .. name)
    else
        tests_failed = tests_failed + 1
        print("❌ " .. name .. ": " .. tostring(err))
    end
end

print("=== Integration Tests ===\n")
print("Note: Network tests can be skipped with SKIP_NETWORK_TESTS=1\n")

-- Local Integration Tests (no network)
test("Integration: Module loading", function()
    assert(polkadot ~= nil)
    assert(polkadot.crypto ~= nil)
    assert(polkadot.rpc ~= nil)
    assert(type(polkadot.connect) == "function")
end)

test("Integration: Keyring -> Address -> SS58 roundtrip", function()
    local seed = string.rep("a", 32)
    local keypair = Keyring.from_seed(seed)
    local addr = keypair.address
    
    -- Decode address
    local pub, ver = crypto.ss58_decode(addr)
    assert(pub == keypair.pubkey)
    assert(ver == 42)
end)

test("Integration: Keyring -> Sign -> Verify", function()
    local keypair = Keyring.from_seed(string.rep("a", 32))
    local message = "test message"
    local sig = keypair:sign(message)
    
    local valid = crypto.ed25519_verify(keypair.pubkey, message, sig)
    assert(valid == true)
end)

test("Integration: SCALE encode -> Transaction -> Sign", function()
    local keypair = Keyring.from_seed(string.rep("a", 32))
    local call_index = Scale.encode_u16(4) .. Scale.encode_u16(0) -- Balances.transfer
    local call_hex = "0x" .. (call_index:gsub(".", function(c) return string.format("%02x", string.byte(c)) end))
    
    local props = {
        specVersion = 100,
        txVersion = 1,
        genesisHash = "0x" .. string.rep("00", 32),
        finalizedHash = "0x" .. string.rep("11", 32)
    }
    
    local signed = Transaction.create_signed(call_hex, keypair, 0, props)
    assert(signed ~= nil)
    assert(signed:match("^0x"))
end)

test("Integration: Storage key construction -> SS58", function()
    local seed = string.rep("a", 32)
    local pubkey = crypto.ed25519_keypair_from_seed(seed)
    local addr = crypto.ss58_encode(pubkey, 42)
    
    -- Construct storage key
    local k1 = (crypto.twox128("System"):gsub(".", function(c) return string.format("%02x", string.byte(c)) end))
    local k2 = (crypto.twox128("Account"):gsub(".", function(c) return string.format("%02x", string.byte(c)) end))
    local k3 = (crypto.blake2b(pubkey, 16):gsub(".", function(c) return string.format("%02x", string.byte(c)) end))
    local k4 = (pubkey:gsub(".", function(c) return string.format("%02x", string.byte(c)) end))
    
    local storage_key = "0x" .. k1 .. k2 .. k3 .. k4
    assert(storage_key:match("^0x"))
    assert(#storage_key == 2 + 32 + 32 + 32 + 64)
end)

-- Network Integration Tests
test("Integration: Connect to Westend RPC", function()
    local url = "https://westend-rpc.polkadot.io"
    local api = polkadot.connect(url)
    assert(api ~= nil)
    assert(api.url == url)
end, true)

test("Integration: Get finalized head", function()
    local api = polkadot.connect("https://westend-rpc.polkadot.io")
    local head = api:chain_getFinalizedHead()
    assert(head ~= nil)
    assert(type(head) == "string")
    assert(head:match("^0x"))
end, true)

test("Integration: Get genesis hash", function()
    local api = polkadot.connect("https://westend-rpc.polkadot.io")
    local genesis = api:chain_getBlockHash(0)
    assert(genesis ~= nil)
    assert(type(genesis) == "string")
    assert(genesis:match("^0x"))
end, true)

test("Integration: Get runtime version", function()
    local api = polkadot.connect("https://westend-rpc.polkadot.io")
    local runtime = api:state_getRuntimeVersion()
    assert(runtime ~= nil)
    assert(runtime.specVersion ~= nil)
    assert(runtime.transactionVersion ~= nil)
    assert(type(runtime.specVersion) == "number")
end, true)

test("Integration: Get chain properties", function()
    local api = polkadot.connect("https://westend-rpc.polkadot.io")
    local props = api:get_chain_properties()
    assert(props ~= nil)
    assert(props.decimals ~= nil)
    assert(props.symbol ~= nil)
    assert(props.divisor ~= nil)
end, true)

test("Integration: Query account (empty account)", function()
    local api = polkadot.connect("https://westend-rpc.polkadot.io")
    local keypair = Keyring.from_seed(string.rep("a", 32))
    
    local info = api:system_account(keypair.address)
    assert(info ~= nil)
    assert(info.nonce ~= nil)
    assert(info.data ~= nil)
    assert(info.data.free ~= nil)
end, true)

test("Integration: Full transaction flow", function()
    local api = polkadot.connect("https://westend-rpc.polkadot.io")
    local keypair = Keyring.from_seed(string.rep("a", 32))
    
    -- Get account info
    local info = api:system_account(keypair.address)
    
    -- Get chain state
    local finalized = api:chain_getFinalizedHead()
    local genesis = api:chain_getBlockHash(0)
    local runtime = api:state_getRuntimeVersion()
    
    -- Build call
    local call_index = Scale.encode_u16(4) .. Scale.encode_u16(0)
    local call_hex = "0x" .. (call_index:gsub(".", function(c) return string.format("%02x", string.byte(c)) end))
    
    -- Create transaction
    local props = {
        specVersion = runtime.specVersion,
        txVersion = runtime.transactionVersion,
        genesisHash = genesis,
        finalizedHash = finalized
    }
    
    local signed = Transaction.create_signed(call_hex, keypair, info.nonce, props)
    assert(signed ~= nil)
    assert(signed:match("^0x"))
end, true)

print("\n=== Integration Test Results ===")
print("Passed: " .. tests_passed)
print("Failed: " .. tests_failed)
print("Skipped: " .. tests_skipped)
if tests_failed == 0 then
    print("🎉 All integration tests passed!")
    return 0
else
    print("❌ Some tests failed")
    return 1
end
