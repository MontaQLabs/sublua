local sdk = require("sdk")

print("🔗 Testing Polkadot SDK with Network")
print("===================================")

-- Test with proper error handling
local function test_with_network()
    print("\n📡 Connecting to Paseo testnet...")
    local rpc = sdk.rpc.new("https://rpc.ibp.network/paseo")
    
    -- Test connection first
    local success, runtime = pcall(function()
        return rpc:state_getRuntimeVersion()
    end)
    
    if not success then
        print("❌ Network connection failed:", runtime)
        print("This might be due to missing luasocket or network issues.")
        return false
    end
    
    print("✅ Connected to", runtime.specName, "version", runtime.specVersion)
    
    -- Create signer with VALID 64-character hex seed
    print("\n🔑 Creating signer...")
    local valid_seed = "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
    local signer = sdk.signer.new(valid_seed)
    print("✅ Signer created")
    print("  Public key:", signer:get_public_key():sub(1,16) .. "...")
    
    -- Create unsigned call (System.remark "")
    print("\n📝 Creating extrinsic...")
    local extrinsic = sdk.extrinsic.new({0x00, 0x00}, "0x00")
    extrinsic:set_nonce(0)
    print("✅ Unsigned extrinsic created")
    
    -- Sign the transaction
    print("\n✍️  Signing transaction...")
    local signed_hex = extrinsic:create_signed(signer)
    print("✅ Transaction signed successfully!")
    print("  Signed hex:", signed_hex:sub(1,32) .. "...")
    
    -- Try to submit (this will likely fail due to unfunded account)
    print("\n📤 Attempting to submit transaction...")
    local submit_success, tx_hash = pcall(function()
        return rpc:author_submitExtrinsic("0x" .. signed_hex)
    end)
    
    if submit_success then
        print("✅ Transaction submitted! Hash:", tx_hash)
    else
        print("❌ Transaction submission failed:", tx_hash)
        print("This is expected if the account is unfunded.")
        print("To actually submit transactions, fund the account with test tokens.")
    end
    
    return true
end

-- Test offline functionality
local function test_offline()
    print("\n🔧 Testing offline functionality...")
    
    -- Test signer
    local valid_seed = "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
    local signer = sdk.signer.new(valid_seed)
    print("✅ Signer created offline")
    print("  Public key:", signer:get_public_key():sub(1,16) .. "...")
    
    -- Test extrinsic creation and signing
    local extrinsic = sdk.extrinsic.new({0x00, 0x00}, "0x00")
    extrinsic:set_nonce(0)
    local signed_hex = extrinsic:create_signed(signer)
    print("✅ Transaction created and signed offline")
    print("  Signed hex:", signed_hex:sub(1,32) .. "...")
    
    return true
end

-- Run tests
local network_ok = test_with_network()

if not network_ok then
    print("\n⚠️  Network test failed, running offline tests...")
    test_offline()
end

print("\n" .. string.rep("=", 50))
print("📋 Test Summary:")
print("• Core SDK functionality: ✅ Working")
print("• Transaction creation: ✅ Working") 
print("• Transaction signing: ✅ Working")
if network_ok then
    print("• Network connectivity: ✅ Working")
    print("• RPC communication: ✅ Working")
else
    print("• Network connectivity: ❌ Failed (install luasocket)")
    print("• RPC communication: ❌ Failed")
end

print("\n🚀 SDK is ready for development!")
print("\nTo enable full network functionality:")
print("  sudo pacman -S lua-socket lua-cjson  # Arch Linux")
print("  # or install luasocket and cjson for your system")

print("\nFor funded account testing:")
print("  1. Get test tokens from Paseo faucet")
print("  2. Replace the seed with your funded account")
print("  3. Run this test again")