-- sdk/polkadot_ffi.lua
-- Centralised FFI binding for the Polkadot SDK
-- Tries several strategies to locate and load the compiled Rust shared object.

local ffi = require("ffi")

-- C definitions shared by multiple modules
ffi.cdef[[
    typedef struct {
        bool success;
        char* data;   // allocated C string (hex encoded)
        char* error;  // allocated C string on failure
    } ExtrinsicResult;

    /* Signing */
    ExtrinsicResult sign_extrinsic(const char* seed_hex, const char* extrinsic_hex);
    ExtrinsicResult derive_sr25519_public_key(const char* seed_hex);
    ExtrinsicResult compute_ss58_address(const char* public_key_hex, uint16_t network_prefix);
    ExtrinsicResult decode_ss58_address(const char* ss58_address);
    ExtrinsicResult derive_sr25519_from_mnemonic(const char* mnemonic);
    ExtrinsicResult blake2_128_hash(const char* data);
    void            free_string(char* ptr);

    /* SCALE / Extrinsics */
    int encode_unsigned_extrinsic(
        uint8_t module_index,
        uint8_t function_index,
        const uint8_t* arguments_ptr,
        size_t arguments_len,
        uint8_t** out_ptr,
        size_t* out_len);

    int encode_signed_extrinsic(
        uint8_t module_index,
        uint8_t function_index,
        const uint8_t* arguments_ptr,
        size_t arguments_len,
        const uint8_t* signer_ptr,
        const uint8_t* signature_ptr,
        uint32_t nonce,
        uint64_t tip_low,
        uint64_t tip_high,
        bool era_mortal,
        uint8_t era_period,
        uint8_t era_phase,
        uint32_t transaction_version,
        uint8_t** out_ptr,
        size_t* out_len);

    void free_encoded_extrinsic(uint8_t* ptr, size_t len);
]]

-- Helper to attempt loading the library from multiple candidate paths
local function try_load(paths)
    for _, p in ipairs(paths) do
        local ok, lib = pcall(ffi.load, p)
        if ok then return lib end
    end
    return nil, "Unable to locate libpolkadot_ffi.so – tried: " .. table.concat(paths, ", ")
end

-- Form candidate paths (relative to this file as well as CWD)
local this_dir = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"

-- Detect platform and architecture
local function detect_platform()
    local os_name = package.config:sub(1,1) == '\\' and 'windows' or 'unix'
    local arch = nil
    
    if os_name == 'windows' then
        arch = 'x86_64'  -- Assume 64-bit for Windows
    else
        -- Try to detect architecture
        local handle = io.popen("uname -m 2>/dev/null")
        if handle then
            arch = handle:read("*l")
            handle:close()
        end
        arch = arch or 'x86_64'  -- fallback
        
        -- Map architecture names to our directory structure
        if arch == 'arm64' then
            arch = 'aarch64'
        end
        
        -- Detect macOS vs Linux
        local uname_handle = io.popen("uname -s 2>/dev/null")
        if uname_handle then
            local uname = uname_handle:read("*l")
            uname_handle:close()
            if uname == 'Darwin' then
                os_name = 'macos'
            else
                os_name = 'linux'
            end
        end
    end
    
    return os_name, arch
end

local os_name, arch = detect_platform()

-- Get LuaRocks installation path
local function get_luarocks_path()
    local handle = io.popen("luarocks path --lr-path 2>/dev/null")
    if handle then
        local path = handle:read("*a"):match("([^;]+)")
        handle:close()
        if path then
            return path:gsub("/?$", "") .. "/"
        end
    end
    return nil
end

local luarocks_path = get_luarocks_path()

-- Build candidate paths in order of preference
local candidates = {}

-- 1. Precompiled binaries (platform-specific)
local platform_dir = os_name .. "-" .. arch
local precompiled_path = this_dir .. "../precompiled/" .. platform_dir .. "/"
if os_name == 'windows' then
    table.insert(candidates, precompiled_path .. "polkadot_ffi.dll")
elseif os_name == 'macos' then
    table.insert(candidates, precompiled_path .. "libpolkadot_ffi.dylib")
elseif os_name == 'linux' then
    table.insert(candidates, precompiled_path .. "libpolkadot_ffi.so")
end

-- 2. System library paths
table.insert(candidates, "polkadot_ffi")                       -- in LD_LIBRARY_PATH / system path
table.insert(candidates, "libpolkadot_ffi.so")                 -- likewise
table.insert(candidates, "polkadot_ffi.so")                    -- LuaRocks installed name

-- 3. LuaRocks installation paths
if luarocks_path then
    table.insert(candidates, luarocks_path .. "polkadot_ffi.so")
    table.insert(candidates, luarocks_path .. "libpolkadot_ffi.so")
end

-- 4. Source compilation paths (fallback)
table.insert(candidates, this_dir .. "../polkadot-ffi-subxt/target/release/libpolkadot_ffi.so")
table.insert(candidates, this_dir .. "../../polkadot-ffi-subxt/target/release/libpolkadot_ffi.so")

-- 5. System library paths
local system_paths = {
    "/usr/local/lib/",
    "/usr/lib/",
    "/lib/",
}

for _, sys_path in ipairs(system_paths) do
    table.insert(candidates, sys_path .. "libpolkadot_ffi.so")
    table.insert(candidates, sys_path .. "polkadot_ffi.so")
end

local lib, err = try_load(candidates)
if not lib then
    error(err)
end

return {
    ffi = ffi,
    lib = lib,
} 