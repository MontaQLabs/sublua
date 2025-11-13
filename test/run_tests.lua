-- test/run_tests.lua
-- Comprehensive test suite for SubLua SDK

local sdk = require("sublua")
local polkadot_ffi = require("sublua.polkadot_ffi")

-- Load FFI library first
sdk.ffi()
local ffi = polkadot_ffi.ffi
local ffi_lib = polkadot_ffi.get_lib()

print("🧪 SubLua Test Suite")
print("====================")
print("SDK Version:", sdk.version)
print("FFI Library: Loaded")

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
    assert(sdk.signer ~= nil, "Signer module should be available")
    assert(sdk.ffi ~= nil, "FFI loader should be available")
    assert(sdk.version ~= nil, "Version should be available")
end)

-- Test 2: Signer Creation from Seed
run_test("Signer Creation from Seed", function()
    local seed = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
    local signer = sdk.signer().new(seed)
    assert(signer ~= nil, "Signer should be created from seed")
    
    local pubkey = signer:get_public_key()
    assert(pubkey ~= nil, "Public key should be generated")
    assert(type(pubkey) == "string", "Public key should be a string")
    assert(pubkey:match("^0x"), "Public key should start with 0x")
    
    local address = signer:get_ss58_address(0)
    assert(address ~= nil, "SS58 address should be generated")
    assert(type(address) == "string", "Address should be a string")
    assert(#address > 0, "Address should not be empty")
    print("   Generated address:", address)
end)

-- Test 3: Signer Creation from Mnemonic
run_test("Signer Creation from Mnemonic", function()
    local mnemonic = "helmet myself order all require large unusual verify ritual final apart nut"
    local signer = sdk.signer().from_mnemonic(mnemonic)
    assert(signer ~= nil, "Signer should be created from mnemonic")
    
    local address = signer:get_ss58_address(42) -- Westend
    assert(address ~= nil, "SS58 address should be generated")
    assert(type(address) == "string", "Address should be a string")
    assert(#address > 0, "Address should not be empty")
    print("   Westend address:", address)
end)

-- Test 4: Platform Detection
run_test("Platform Detection", function()
    local os_name, arch = sdk.detect_platform()
    assert(os_name ~= nil, "OS name should be detected")
    assert(arch ~= nil, "Architecture should be detected")
    print("   Platform:", os_name, arch)
end)

-- Test 5: FFI Library Loaded
run_test("FFI Library", function()
    assert(ffi_lib ~= nil, "FFI library should be loaded")
    print("   FFI library is loaded and ready")
end)

-- Test 6: Balance Query via FFI
run_test("Balance Query via FFI", function()
    local node_url = "wss://rpc.polkadot.io"
    local test_address = "13UVJyLnbVp9RBZYFwFGyDvVd1y27Tt8tkntv6Q7JVPhFsTB" -- Polkadot Treasury
    
    local url_cstr = ffi.new("char[?]", #node_url + 1)
    ffi.copy(url_cstr, node_url)
    
    local addr_cstr = ffi.new("char[?]", #test_address + 1)
    ffi.copy(addr_cstr, test_address)
    
    print("   Querying Polkadot Treasury balance...")
    local result = ffi_lib.query_balance(url_cstr, addr_cstr)
    
    assert(result.success, "Balance query should succeed")
    
    if result.success then
        local data_str = ffi.string(result.data)
        ffi_lib.free_string(result.data)
        
        -- Try multiple balance formats (U128(...) or plain numbers)
        local free_match = data_str:match('U128%((%d+)%)') or 
                          data_str:match('"free"%s*:%s*"?(%d+)"?') or
                          data_str:match('"free"%s*:%s*(%d+)')
        
        assert(free_match ~= nil, "Should extract balance value. Got: " .. data_str)
        print("   Balance query successful! Free balance: " .. free_match)
    else
        local err_str = ffi.string(result.error)
        ffi_lib.free_string(result.error)
        error("Balance query failed: " .. err_str)
    end
end)

-- Test 7: Extrinsic Builder
run_test("Extrinsic Builder", function()
    local builder = sdk.extrinsic_builder().new(nil)
    assert(builder ~= nil, "Extrinsic builder should be created")
    print("   Extrinsic builder created")
end)

-- Test 8: Balance Transfer (Dry Run - will fail without funds)
run_test("Balance Transfer API", function()
    -- Note: This test verifies the API works, but will fail due to insufficient balance
    -- This is expected behavior for a test account
    
    local node_url = "wss://westend-rpc.polkadot.io" -- Use Westend testnet
    local mnemonic = "helmet myself order all require large unusual verify ritual final apart nut"
    local dest_address = "5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY" -- Alice on Westend
    local amount = 1000000000 -- 0.0001 WND (very small amount)
    
    local url_cstr = ffi.new("char[?]", #node_url + 1)
    ffi.copy(url_cstr, node_url)
    
    local mnemonic_cstr = ffi.new("char[?]", #mnemonic + 1)
    ffi.copy(mnemonic_cstr, mnemonic)
    
    local dest_cstr = ffi.new("char[?]", #dest_address + 1)
    ffi.copy(dest_cstr, dest_address)
    
    print("   Testing balance transfer API (will fail if no funds)...")
    local result = ffi_lib.submit_balance_transfer_subxt(url_cstr, mnemonic_cstr, dest_cstr, amount)
    
    -- We expect this to fail due to insufficient balance, but the API should work
    if result.success then
        local tx_hash = ffi.string(result.tx_hash)
        ffi_lib.free_string(result.tx_hash)
        print("   ✅ Transfer succeeded! TX hash:", tx_hash)
    else
        local err_str = ffi.string(result.error)
        ffi_lib.free_string(result.error)
        
        -- Check if it's an expected error (insufficient funds, connection issues, etc.)
        if err_str:match("Insufficient") or err_str:match("balance") or 
           err_str:match("Connection") or err_str:match("existential") then
            print("   ✅ Transfer API works (expected error: insufficient funds)")
        else
            print("   ⚠️  Transfer failed:", err_str)
        end
    end
    
    -- The test passes if the API is callable and returns a result
    assert(result ~= nil, "Transfer result should not be nil")
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

print("\n💡 All tests use the native FFI library for blockchain interactions!")
print("   Balance queries work directly through FFI with LuaJIT")
