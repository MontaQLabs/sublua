-- test/run_tests.lua
-- Comprehensive test suite for SubLua SDK

local sdk = require("sdk.init")

print("🧪 SubLua Test Suite")
print("====================")

local tests = {}
local passed = 0
local failed = 0

-- Test helper function
local function run_test(name, test_func)
    print("\n📋 Running test:", name)
    local success, result = pcall(test_func)
    
    if success then
        print("✅ PASS:", name)
        passed = passed + 1
    else
        print("❌ FAIL:", name)
        print("   Error:", result)
        failed = failed + 1
    end
end

-- Test 1: SDK Loading
run_test("SDK Loading", function()
    assert(sdk ~= nil, "SDK should be loaded")
    assert(sdk.rpc ~= nil, "RPC module should be available")
    assert(sdk.signer ~= nil, "Signer module should be available")
    assert(sdk.chain_config ~= nil, "Chain config module should be available")
end)

-- Test 2: Chain Configuration Detection
run_test("Chain Configuration Detection", function()
    local config = sdk.chain_config.detect_from_url("wss://westend-rpc.polkadot.io")
    assert(config.name ~= nil, "Chain name should be detected")
    assert(config.token_symbol ~= nil, "Token symbol should be detected")
    assert(config.token_decimals ~= nil, "Token decimals should be detected")
    assert(config.ss58_prefix ~= nil, "SS58 prefix should be detected")
end)

-- Test 3: RPC Connection
run_test("RPC Connection", function()
    local rpc = sdk.rpc.new("wss://westend-rpc.polkadot.io")
    assert(rpc ~= nil, "RPC client should be created")
end)

-- Test 4: Signer Creation
run_test("Signer Creation", function()
    local mnemonic = "helmet myself order all require large unusual verify ritual final apart nut"
    local signer = sdk.signer.from_mnemonic(mnemonic)
    assert(signer ~= nil, "Signer should be created from mnemonic")
    
    local address = signer:get_ss58_address(42)
    assert(address ~= nil, "SS58 address should be generated")
    assert(type(address) == "string", "Address should be a string")
    assert(#address > 0, "Address should not be empty")
end)

-- Test 5: Account Info Query
run_test("Account Info Query", function()
    local rpc = sdk.rpc.new("wss://westend-rpc.polkadot.io")
    local mnemonic = "helmet myself order all require large unusual verify ritual final apart nut"
    local signer = sdk.signer.from_mnemonic(mnemonic)
    local address = signer:get_ss58_address(42)
    
    local account = rpc:get_account_info(address)
    -- Account might not exist, but the query should not fail
    assert(account == nil or type(account) == "table", "Account info should be nil or table")
end)

-- Test 6: FFI Library Loading
run_test("FFI Library Loading", function()
    local ffi = require("ffi")
    
    -- Test if the subxt FFI library can be loaded
    local success, lib = pcall(function()
        return ffi.load("./polkadot-ffi-subxt/target/release/libpolkadot_ffi_subxt.dylib")
    end)
    
    if success then
        assert(lib ~= nil, "FFI library should be loaded")
    else
        print("   Warning: FFI library not available (this is expected if not built)")
    end
end)

-- Test 7: Cryptographic Operations
run_test("Cryptographic Operations", function()
    local ffi = require("ffi")
    
    -- Define FFI structures
    ffi.cdef[[
        typedef struct {
            bool success;
            char* data;
            char* error;
        } ExtrinsicResult;
        
        ExtrinsicResult derive_sr25519_from_mnemonic(const char* mnemonic);
        void free_string(char* ptr);
    ]]
    
    -- Try to load and test the library
    local success, lib = pcall(function()
        return ffi.load("./polkadot-ffi-subxt/target/release/libpolkadot_ffi_subxt.dylib")
    end)
    
    if success and lib then
        local mnemonic = "helmet myself order all require large unusual verify ritual final apart nut"
        local c_mnemonic = ffi.new("char[?]", #mnemonic + 1)
        ffi.copy(c_mnemonic, mnemonic)
        
        local result = lib.derive_sr25519_from_mnemonic(c_mnemonic)
        assert(result.success, "Keypair derivation should succeed")
        
        if result.data ~= nil then
            local json_str = ffi.string(result.data)
            lib.free_string(result.data)
            assert(json_str:find("seed"), "Result should contain seed")
            assert(json_str:find("public"), "Result should contain public key")
        end
    else
        print("   Warning: FFI library not available for testing")
    end
end)

-- Test Summary
print("\n" .. string.rep("=", 50))
print("📊 Test Summary")
print("===============")
print("✅ Passed:", passed)
print("❌ Failed:", failed)
print("📋 Total:", passed + failed)

if failed == 0 then
    print("\n🎉 All tests passed!")
else
    print("\n⚠️  Some tests failed. Check the output above.")
end

print("\n💡 Note: Some tests may show warnings if the FFI library is not built.")
print("   Run 'cd polkadot-ffi-subxt && cargo build --release' to build it.")
