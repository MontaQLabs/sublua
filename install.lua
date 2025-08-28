#!/usr/bin/env luajit
-- install.lua
-- Production installation script for SubLua

local http = require("socket.http")
local ltn12 = require("ltn12")
local json = require("cjson")

print("🚀 SubLua Installation Script")
print("=============================")

-- Configuration
local LUA_ROCKS_URL = "https://luarocks.org"
local REQUIRED_PACKAGES = {
    "luasocket",
    "lua-cjson",
    "luasec"
}

-- Helper functions
local function run_command(cmd)
    print("Running:", cmd)
    local handle = io.popen(cmd .. " 2>&1")
    local result = handle:read("*a")
    local success = handle:close()
    return success, result
end

local function check_command_exists(cmd)
    local success, _ = run_command("which " .. cmd)
    return success
end

local function install_luarocks_package(package)
    print("Installing", package, "...")
    local success, output = run_command("luarocks install " .. package)
    if not success then
        print("❌ Failed to install", package)
        print("Output:", output)
        return false
    end
    print("✅ Installed", package)
    return true
end

-- Check prerequisites
print("\n1️⃣ Checking prerequisites...")

if not check_command_exists("luajit") then
    print("❌ LuaJIT not found. Please install LuaJIT first.")
    print("   macOS: brew install luajit")
    print("   Ubuntu: sudo apt-get install luajit")
    os.exit(1)
end
print("✅ LuaJIT found")

if not check_command_exists("cargo") then
    print("❌ Cargo not found. Please install Rust first.")
    print("   Visit: https://rustup.rs/")
    os.exit(1)
end
print("✅ Cargo found")

if not check_command_exists("luarocks") then
    print("❌ LuaRocks not found. Please install LuaRocks first.")
    print("   Visit: https://luarocks.org/")
    os.exit(1)
end
print("✅ LuaRocks found")

-- Install Lua dependencies
print("\n2️⃣ Installing Lua dependencies...")
for _, package in ipairs(REQUIRED_PACKAGES) do
    if not install_luarocks_package(package) then
        print("❌ Installation failed. Please check your LuaRocks setup.")
        os.exit(1)
    end
end

-- Build FFI library
print("\n3️⃣ Building FFI library...")
local success, output = run_command("cd polkadot-ffi-subxt && cargo build --release")
if not success then
    print("❌ Failed to build FFI library")
    print("Output:", output)
    print("Please check that Rust is properly installed.")
    os.exit(1)
end
print("✅ FFI library built successfully")

-- Verify installation
print("\n4️⃣ Verifying installation...")
local success, output = run_command("luajit test/run_tests.lua")
if not success then
    print("❌ Installation verification failed")
    print("Output:", output)
    print("Please check the test output above for issues.")
    os.exit(1)
end

-- Create environment script
print("\n5️⃣ Creating environment script...")
local env_script = [[
#!/bin/bash
# SubLua environment setup script

export LUA_PATH="$(pwd)/?.lua;$(pwd)/?/init.lua;$LUA_PATH"
export LUA_CPATH="$(pwd)/?.so;$LUA_CPATH"

echo "SubLua environment loaded!"
echo "Run: source sublua-env.sh to load the environment"
]]

local file = io.open("sublua-env.sh", "w")
if file then
    file:write(env_script)
    file:close()
    run_command("chmod +x sublua-env.sh")
    print("✅ Environment script created: sublua-env.sh")
else
    print("⚠️  Could not create environment script")
end

-- Installation complete
print("\n" .. string.rep("=", 50))
print("🎉 SubLua Installation Complete!")
print("================================")

print("\n📋 Next steps:")
print("1. Load the environment: source sublua-env.sh")
print("2. Run the basic example: luajit examples/basic_usage.lua")
print("3. Run the test suite: luajit test/run_tests.lua")
print("4. Check the documentation: README.md")

print("\n🔗 Useful commands:")
print("  luajit examples/basic_usage.lua    # Basic usage example")
print("  luajit test/run_tests.lua          # Run test suite")
print("  luajit examples/game_integration.lua # Game integration example")

print("\n📚 Documentation:")
print("  README.md                          # Main documentation")
print("  docs/                              # Detailed documentation")

print("\n💡 Support:")
print("  GitHub Issues: https://github.com/your-org/sublua/issues")
print("  Discord: https://discord.gg/sublua")

print("\n✅ Installation completed successfully!")
