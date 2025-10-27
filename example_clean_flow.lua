#!/usr/bin/env luajit

-- Sublua Clean Usage Example
-- Shows the complete clean installation flow

print("🚀 Sublua Clean Usage Example")
print("=" .. string.rep("=", 50))

-- Load Sublua SDK (development mode)
local sublua = require("sdk.init")

print("✅ Sublua SDK loaded successfully!")
print("   Version:", sublua.version)

-- Detect platform
local os_name, arch = sublua.detect_platform()
print("🖥️  Platform detected:", os_name, arch)

-- Get recommended FFI path
local recommended_path = sublua.get_recommended_path()
print("📁 Recommended FFI path:", recommended_path)

-- Load FFI library
print("\n🔧 Loading FFI library...")
local lib = sublua.ffi()
print("✅ FFI library loaded successfully!")

-- Test basic functionality
print("\n🧪 Testing basic functionality...")

-- Test signer (without dependencies)
local signer_success, signer = pcall(function()
    local signer_module = sublua.signer()
    return signer_module.new("0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef")
end)

if signer_success then
    print("✅ Signer module loaded successfully!")
    print("   Signer type:", type(signer))
else
    print("⚠️  Signer module failed (dependency issue):", signer)
end

print("\n" .. string.rep("=", 50))
print("🎉 Clean Sublua Usage Example Complete!")

print("\n📋 Summary:")
print("   • SDK Version:", sublua.version)
print("   • Platform:", os_name, arch)
print("   • FFI Library:", lib and "✅ Loaded" or "❌ Failed")
print("   • Signer Module:", signer_success and "✅ Loaded" or "⚠️  Partial")

print("\n🚀 Your Sublua is ready!")
print("   You can now start building blockchain applications with Lua!")

print("\n💡 Next steps:")
print("   1. Create a signer: local signer = sublua.signer().new()")
print("   2. Connect to a chain: local rpc = sublua.rpc().new('wss://rpc.polkadot.io')")
print("   3. Build transactions: local builder = sublua.extrinsic_builder().new(rpc)")
print("   4. Sign and submit: builder:sign_and_submit(signer)")