# Precompiled Binary Strategy for SubLua

## 🎯 **The Problem**
Users shouldn't need to install Rust and compile FFI libraries manually. They should be able to `luarocks install sublua` and have it work immediately.

## 🚀 **The Solution: Hybrid Approach**

### **1. Precompiled Binaries (Primary)**
- **Include `.so`/`.dll` files** for common platforms
- **Automatic detection** of user's platform
- **Works immediately** without compilation

### **2. Source Compilation (Fallback)**
- **Fallback option** if no precompiled binary exists
- **For advanced users** who want to compile from source
- **For custom platforms** not covered by precompiled binaries

## 📁 **Directory Structure**

```
precompiled/
├── linux-x86_64/
│   └── libpolkadot_ffi.so
├── macos-x86_64/
│   └── libpolkadot_ffi.dylib
├── macos-aarch64/
│   └── libpolkadot_ffi.dylib
└── windows-x86_64/
    └── polkadot_ffi.dll
```

## 🔍 **How It Works**

### **Step 1: Platform Detection**
```lua
-- Automatically detects:
-- - Operating System (Linux/macOS/Windows)
-- - Architecture (x86_64/aarch64)
-- - Library naming convention (.so/.dylib/.dll)
```

### **Step 2: Smart Loading**
```lua
-- Tries in this order:
-- 1. Precompiled binary for user's platform
-- 2. System library paths
-- 3. LuaRocks installation paths
-- 4. Source compilation paths (fallback)
```

### **Step 3: User Experience**
```bash
# User just runs:
luarocks install sublua

# And it works immediately! No Rust needed.
luajit -e "require('sdk.init'); print('SubLua ready!')"
```

## 🎯 **Benefits**

### **For Users:**
- ✅ **No Rust required** - works out of the box
- ✅ **Fast installation** - no compilation time
- ✅ **Simple command** - just `luarocks install sublua`
- ✅ **Cross-platform** - works on Linux, macOS, Windows

### **For Developers:**
- ✅ **Fallback support** - still works if no precompiled binary
- ✅ **Flexible** - users can still compile from source
- ✅ **Maintainable** - easy to add new platforms
- ✅ **Professional** - follows industry best practices

## 📊 **Platform Coverage**

| Platform | Architecture | Library | Status |
|----------|-------------|---------|---------|
| Linux | x86_64 | libpolkadot_ffi.so | ✅ Supported |
| macOS | x86_64 | libpolkadot_ffi.dylib | ✅ Supported |
| macOS | aarch64 | libpolkadot_ffi.dylib | ✅ Supported |
| Windows | x86_64 | polkadot_ffi.dll | ✅ Supported |

## 🔧 **Implementation Details**

### **FFI Loader Logic:**
1. **Detect platform** using `uname` and system calls
2. **Build candidate paths** in order of preference
3. **Try loading** each path until one works
4. **Provide clear error** if none work

### **Build Process:**
1. **Build script** compiles for current platform
2. **Copy to precompiled/** directory
3. **Include in package** via rockspec
4. **Automatic distribution** via LuaRocks

## 🚀 **User Experience**

### **Before (Bad):**
```bash
# User has to do this:
luarocks install sublua
cd polkadot-ffi-subxt
cargo build --release  # Requires Rust!
# Then it might work...
```

### **After (Good):**
```bash
# User just does this:
luarocks install sublua
luajit -e "require('sdk.init'); print('SubLua ready!')"
# Works immediately! 🎉
```

## 📈 **Comparison with Other Packages**

| Package | Approach | User Experience |
|---------|----------|-----------------|
| **lua-cjson** | Precompiled binaries | ✅ Excellent |
| **luasocket** | Precompiled binaries | ✅ Excellent |
| **SubLua (old)** | Source only | ❌ Poor |
| **SubLua (new)** | Hybrid approach | ✅ Excellent |

## 🎉 **Result**

SubLua now works like a **professional Lua package**:
- ✅ **Easy installation** - `luarocks install sublua`
- ✅ **No dependencies** - no Rust required
- ✅ **Cross-platform** - works everywhere
- ✅ **Fast setup** - works immediately
- ✅ **Fallback support** - still flexible

**This is exactly how packages should work!** 🚀
