#!/usr/bin/env luajit
-- setup.lua
-- Simplified setup script for SubLua

print("🚀 SubLua Setup")
print("===============")

-- Check if we're in a LuaRocks installation
local function is_luarocks_install()
    local package_path = package.path
    return package_path:find("luarocks") ~= nil
end

if is_luarocks_install() then
    print("✅ SubLua installed via LuaRocks")
    print("📦 Package location:", package.path)
    
    -- Test the installation
    local success, sdk = pcall(require, "sdk.init")
    if success then
        print("✅ SDK loaded successfully")
        print("🔧 Available modules:")
        print("   - sdk.rpc")
        print("   - sdk.signer") 
        print("   - sdk.chain_config")
        print("   - sdk.extrinsic_builder")
    else
        print("❌ Failed to load SDK:", sdk)
    end
else
    print("📦 Installing SubLua via LuaRocks...")
    
    -- Check if luarocks is available
    local handle = io.popen("which luarocks")
    local result = handle:read("*a")
    handle:close()
    
    if result:match("luarocks") then
        print("✅ LuaRocks found")
        
        -- Install SubLua
        local install_cmd = "luarocks install sublua-scm-0.rockspec"
        print("Running:", install_cmd)
        
        local handle = io.popen(install_cmd .. " 2>&1")
        local output = handle:read("*a")
        local success = handle:close()
        
        if success then
            print("✅ SubLua installed successfully!")
            print("📦 You can now use: require('sdk.init')")
        else
            print("❌ Installation failed:")
            print(output)
        end
    else
        print("❌ LuaRocks not found")
        print("💡 Please install LuaRocks first:")
        print("   Visit: https://luarocks.org/")
    end
end

print("\n📚 Next steps:")
print("1. Run: luajit examples/basic_usage.lua")
print("2. Run: luajit test/run_tests.lua")
print("3. Check: docs/API.md for API reference")

print("\n🔗 Quick start:")
print("local sdk = require('sdk.init')")
print("local rpc = sdk.rpc.new('wss://westend-rpc.polkadot.io')")
