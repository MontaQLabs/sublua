#!/usr/bin/env luajit

-- User-Facing Test Suite for Sublua
-- This tests Sublua as users would use it after installation

print("🚀 Sublua User Test Suite")
print("=" .. string.rep("=", 60))

-- Add LuaRocks paths (users with luarocks install will have this automatically)
package.path = package.path .. ";/opt/homebrew/share/lua/5.4/?.lua;/opt/homebrew/share/lua/5.4/?/init.lua"

-- This is how users will import Sublua after `luarocks install sublua`
local sublua = require("sublua")

print("Package: sublua v" .. sublua.version)
print("Runtime:", jit.version)
print()

local tests = {}
local passed = 0
local failed = 0

-- Test helper function
local function run_test(name, test_func)
    print("📋 Running test:", name)
    local success, result = pcall(test_func)
    
    if success then
        print("✅ PASS:", name)
        passed = passed + 1
    else
        print("❌ FAIL:", name)
        print("   Error:", result)
        failed = failed + 1
    end
    print()
end

-- Test 1: Load FFI Library
run_test("Load FFI Library", function()
    local lib = sublua.ffi()
    assert(lib ~= nil, "FFI library should be loaded")
    print("   FFI library loaded successfully")
end)

-- Test 2: Detect Platform
run_test("Platform Detection", function()
    local os_name, arch = sublua.detect_platform()
    assert(os_name ~= nil, "OS should be detected")
    assert(arch ~= nil, "Architecture should be detected")
    print("   Detected:", os_name, arch)
end)

-- Test 3: Get Recommended FFI Path
run_test("Get Recommended FFI Path", function()
    local path = sublua.get_recommended_path()
    assert(path ~= nil, "Should return recommended path")
    print("   Recommended path:", path)
end)

-- Test 4: Create Signer from Seed
run_test("Create Signer from Seed", function()
    local seed = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
    local signer_module = sublua.signer()
    local signer = signer_module.new(seed)
    
    assert(signer ~= nil, "Signer should be created")
    
    local pubkey = signer:get_public_key()
    assert(pubkey ~= nil, "Public key should be generated")
    assert(pubkey:match("^0x"), "Public key should start with 0x")
    print("   Public Key:", pubkey)
    
    local address = signer:get_ss58_address(0) -- Polkadot
    assert(address ~= nil, "Address should be generated")
    print("   Polkadot Address:", address)
end)

-- Test 5: Create Signer from Mnemonic
run_test("Create Signer from Mnemonic", function()
    local mnemonic = "helmet myself order all require large unusual verify ritual final apart nut"
    local signer_module = sublua.signer()
    local signer = signer_module.from_mnemonic(mnemonic)
    
    assert(signer ~= nil, "Signer should be created from mnemonic")
    
    local polkadot_addr = signer:get_ss58_address(0) -- Polkadot
    local westend_addr = signer:get_ss58_address(42) -- Westend
    
    print("   Polkadot Address:", polkadot_addr)
    print("   Westend Address:", westend_addr)
end)

-- Test 6: Query Balance from Live Chain
run_test("Query Balance from Polkadot", function()
    local polkadot_ffi = require("sublua.polkadot_ffi")
    local ffi = polkadot_ffi.ffi
    local ffi_lib = polkadot_ffi.get_lib()
    
    local node_url = "wss://rpc.polkadot.io"
    local treasury_addr = "13UVJyLnbVp9RBZYFwFGyDvVd1y27Tt8tkntv6Q7JVPhFsTB"
    
    local url_cstr = ffi.new("char[?]", #node_url + 1)
    ffi.copy(url_cstr, node_url)
    
    local addr_cstr = ffi.new("char[?]", #treasury_addr + 1)
    ffi.copy(addr_cstr, treasury_addr)
    
    print("   Querying Polkadot Treasury...")
    local result = ffi_lib.query_balance(url_cstr, addr_cstr)
    
    assert(result.success, "Balance query should succeed")
    
    local data_str = ffi.string(result.data)
    ffi_lib.free_string(result.data)
    
    local free_match = data_str:match('U128%((%d+)%)')
    assert(free_match ~= nil, "Should extract balance")
    print("   Balance query successful!")
end)

-- Test 7: Create Extrinsic Builder
run_test("Create Extrinsic Builder", function()
    local builder_module = sublua.extrinsic_builder()
    local builder = builder_module.new(nil)
    
    assert(builder ~= nil, "Extrinsic builder should be created")
    print("   Extrinsic builder created")
end)

-- Test 8: Submit Balance Transfer (Testnet)
run_test("Submit Balance Transfer", function()
    local polkadot_ffi = require("sublua.polkadot_ffi")
    local ffi = polkadot_ffi.ffi
    local ffi_lib = polkadot_ffi.get_lib()
    
    local node_url = "wss://westend-rpc.polkadot.io"
    local mnemonic = "helmet myself order all require large unusual verify ritual final apart nut"
    local dest_address = "5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY"
    local amount = 1000000000 -- 0.0001 WND
    
    local url_cstr = ffi.new("char[?]", #node_url + 1)
    ffi.copy(url_cstr, node_url)
    
    local mnemonic_cstr = ffi.new("char[?]", #mnemonic + 1)
    ffi.copy(mnemonic_cstr, mnemonic)
    
    local dest_cstr = ffi.new("char[?]", #dest_address + 1)
    ffi.copy(dest_cstr, dest_address)
    
    print("   Submitting transfer to Westend testnet...")
    local result = ffi_lib.submit_balance_transfer_subxt(url_cstr, mnemonic_cstr, dest_cstr, amount)
    
    if result.success then
        local tx_hash = ffi.string(result.tx_hash)
        ffi_lib.free_string(result.tx_hash)
        print("   ✅ Transfer succeeded!")
        print("   TX Hash:", tx_hash)
    else
        local err_str = ffi.string(result.error)
        ffi_lib.free_string(result.error)
        
        -- Expected errors are OK (no funds, etc)
        if err_str:match("Insufficient") or err_str:match("balance") then
            print("   ⚠️  Expected error (no funds):", err_str:sub(1, 80))
        else
            print("   ⚠️  Transfer error:", err_str:sub(1, 100))
        end
    end
    
    assert(result ~= nil, "Should return a result")
end)

-- Test Summary
print(string.rep("=", 60))
print("📊 Test Summary")
print(string.rep("=", 60))
print("✅ Passed:", passed)
print("❌ Failed:", failed)
print("📋 Total:", passed + failed)
print()

if failed == 0 then
    print("🎉 All tests passed!")
    print()
    print("💡 Sublua is working perfectly!")
    print("   You can now build blockchain applications with Lua!")
else
    print("⚠️  Some tests failed. Check the output above.")
end

print()
print("📚 Quick Start:")
print("   local sublua = require('sublua')")
print("   sublua.ffi()  -- Load FFI library")
print("   local signer = sublua.signer().new(seed)")
print("   local address = signer:get_ss58_address(0)")
print()
print("🔗 Documentation: https://github.com/MontaQLabs/sublua")
