#!/usr/bin/env luajit

-- Example: Using Sublua with Custom FFI Path
-- This shows how users can specify custom FFI library paths

print("🚀 Sublua Custom FFI Path Example")
print("=" .. string.rep("=", 60))

local sublua = require("sdk.init")

-- Method 1: Auto-detect (recommended)
print("\n1️⃣  Auto-detect FFI library:")
local lib1 = sublua.ffi()
print("   ✅ Loaded:", type(lib1))

-- Method 2: Specify custom path
print("\n2️⃣  Custom FFI path:")
local custom_path = "./precompiled/macos-aarch64/libpolkadot_ffi.dylib"
local lib2 = sublua.ffi(custom_path)
print("   ✅ Loaded from:", custom_path)

-- Method 3: Environment variable
print("\n3️⃣  Environment variable:")
local env_path = os.getenv("SUBLUA_FFI_PATH")
if env_path then
    print("   Found SUBLUA_FFI_PATH:", env_path)
    local lib3 = sublua.ffi(env_path)
    print("   ✅ Loaded from environment")
else
    print("   ℹ️  SUBLUA_FFI_PATH not set, using auto-detect")
    sublua.ffi()
end

-- Method 4: Conditional loading based on platform
print("\n4️⃣  Conditional loading:")
local os_name, arch = sublua.detect_platform()
print("   Platform:", os_name, arch)

local ffi_path
if os_name == "macos" and arch == "aarch64" then
    ffi_path = "./precompiled/macos-aarch64/libpolkadot_ffi.dylib"
elseif os_name == "macos" and arch == "x86_64" then
    ffi_path = "./precompiled/macos-x86_64/libpolkadot_ffi.dylib"
elseif os_name == "linux" and arch == "x86_64" then
    ffi_path = "./precompiled/linux-x86_64/libpolkadot_ffi.so"
elseif os_name == "windows" then
    ffi_path = "./precompiled/windows-x86_64/polkadot_ffi.dll"
else
    print("   ⚠️  Unknown platform, using auto-detect")
    ffi_path = nil
end

if ffi_path then
    print("   Selected path:", ffi_path)
end

-- Test with the loaded FFI
print("\n5️⃣  Test FFI functionality:")
local seed = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
local signer = sublua.signer().new(seed)
local address = signer:get_ss58_address(0)
print("   ✅ Generated address:", address)

print("\n" .. string.rep("=", 60))
print("🎉 All FFI path methods work!")
print()
print("💡 Recommendations:")
print("   • Use sublua.ffi() for automatic detection (easiest)")
print("   • Use sublua.ffi(path) for custom deployments")
print("   • Set SUBLUA_FFI_PATH env var for system-wide config")
print()
