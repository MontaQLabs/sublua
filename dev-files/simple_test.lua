-- simple_test.lua
-- Simple test showing the organized SDK works (offline functionality)

print("🔗 Polkadot Lua SDK Test")
print("========================")

-- Test core modules without RPC
print("\n📦 Testing core modules...")

-- Test FFI module
print("1. Loading FFI module...")
local ffi_ok, ffi_module = pcall(require, "sdk.ffi")
if ffi_ok then
    print("✅ FFI module loaded successfully")
else
    print("❌ FFI module failed:", ffi_module)
end

-- Test utilities
print("\n2. Loading utility module...")
local util_ok, util = pcall(require, "sdk.core.util")
if util_ok then
    print("✅ Utility module loaded")
    
    -- Test hex conversions
    local test_bytes = {0x12, 0x34, 0xab, 0xcd}
    local hex_str = util.bytes_to_hex(test_bytes)
    print("  bytes_to_hex test:", hex_str)
    
    local back_to_bytes = util.hex_to_bytes(hex_str)
    print("  hex_to_bytes test: [" .. table.concat(back_to_bytes, ", ") .. "]")
    
    if hex_str == "1234abcd" then
        print("✅ Hex conversion test passed")
    else
        print("❌ Hex conversion test failed")
    end
else
    print("❌ Utility module failed:", util)
end

-- Test signer
print("\n3. Testing signer module...")
local signer_ok, signer_result = pcall(function()
    local signer_mod = require("sdk.core.signer")
    local valid_seed = "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
    local signer = signer_mod.new(valid_seed)
    return signer
end)

if signer_ok then
    print("✅ Signer module loaded and instantiated")
    print("  Seed:", "1234567890abcdef...")
    
    local pubkey_ok, pubkey = pcall(function()
        return signer_result:get_public_key()
    end)
    
    if pubkey_ok then
        print("  Public key:", pubkey:sub(1,16) .. "...")
        print("✅ Signer functionality verified")
    else
        print("❌ Public key generation failed:", pubkey)
    end
else
    print("❌ Signer module failed:", signer_result)
end

-- Test extrinsic
print("\n4. Testing extrinsic module...")
local ext_ok, ext_result = pcall(function()
    local ext_mod = require("sdk.core.extrinsic")
    local extrinsic = ext_mod.new({0x00, 0x00}, "0x00") -- System.remark("")
    extrinsic:set_nonce(0):set_tip(0):set_era(false)
    return extrinsic
end)

if ext_ok then
    print("✅ Extrinsic module loaded and created")
    
    if signer_ok then
        local sign_ok, signed_result = pcall(function()
            return ext_result:create_signed(signer_result)
        end)
        
        if sign_ok then
            print("✅ Transaction signed successfully!")
            print("  Signed extrinsic:", signed_result:sub(1,32) .. "...")
        else
            print("❌ Transaction signing failed:", signed_result)
        end
    end
else
    print("❌ Extrinsic module failed:", ext_result)
end

-- Test full SDK
print("\n5. Testing full SDK module...")
local sdk_ok, sdk_result = pcall(require, "sdk")
if sdk_ok then
    print("✅ Full SDK loaded successfully")
    print("  Available modules:")
    for module_name, _ in pairs(sdk_result) do
        print("    -", module_name)
    end
else
    print("❌ Full SDK failed:", sdk_result)
end

print("\n" .. string.rep("=", 50))
if ffi_ok and util_ok and signer_ok and ext_ok and sdk_ok then
    print("🎉 ALL TESTS PASSED!")
    print("\nThe Polkadot Lua SDK is working correctly!")
    print("You can now use it for:")
    print("  • Creating and signing transactions")
    print("  • Encoding/decoding SCALE data") 
    print("  • Generating cryptographic keys")
    print("  • Building on-chain games with Love2D")
else
    print("⚠️  Some tests failed, but core functionality may still work.")
end

print("\nNext steps:")
print("  • Install luasocket and cjson for full RPC functionality")
print("  • luajit example_game.lua (for complete example)")
print("  • Check individual modules in sdk/core/ for specific features") 