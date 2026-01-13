-- sdk/polkadot_ffi.lua
-- Clean FFI binding for the Polkadot SDK
-- Users can specify FFI path directly: sublua.ffi("./path/to/lib.so")

local ffi = require("ffi")

-- C definitions shared by multiple modules
ffi.cdef[[
    typedef struct {
        bool success;
        char* data;   // allocated C string (hex encoded)
        char* error;  // allocated C string on failure
    } ExtrinsicResult;
    
    typedef struct {
        bool success;
        char* tx_hash; // allocated C string (transaction hash)
        char* error;   // allocated C string on failure
    } TransferResult;

    /* Signing */
    ExtrinsicResult sign_extrinsic(const char* seed_hex, const char* extrinsic_hex);
    ExtrinsicResult derive_sr25519_public_key(const char* seed_hex);
    ExtrinsicResult compute_ss58_address(const char* public_key_hex, uint16_t network_prefix);
    ExtrinsicResult decode_ss58_address(const char* ss58_address);
    ExtrinsicResult derive_sr25519_from_mnemonic(const char* mnemonic);
    ExtrinsicResult blake2_128_hash(const char* data);
    void            free_string(char* ptr);
    
    /* Balance Query */
    ExtrinsicResult query_balance(const char* node_url, const char* address);
    
    /* Balance Transfer */
    TransferResult submit_balance_transfer_subxt(const char* node_url, const char* mnemonic, const char* dest_address, unsigned long long amount);

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
    
    // Metadata functions
    ExtrinsicResult fetch_chain_metadata(const char* rpc_url);
    ExtrinsicResult get_metadata_pallets(const char* rpc_url);
    ExtrinsicResult get_call_index(const char* rpc_url, const char* pallet_name, const char* call_name);
    ExtrinsicResult get_pallet_calls(const char* rpc_url, const char* pallet_name);
    ExtrinsicResult check_runtime_compatibility(const char* rpc_url, uint32_t expected_spec_version);
    
    // Advanced Cryptographic Features
    // Multi-signature
    ExtrinsicResult create_multisig_address(const char* signatories_json, uint16_t threshold);
    
    // Proxy operations
    TransferResult add_proxy(const char* rpc_url, const char* mnemonic, const char* delegate, const char* proxy_type, uint32_t delay);
    TransferResult remove_proxy(const char* rpc_url, const char* mnemonic, const char* delegate, const char* proxy_type, uint32_t delay);
    TransferResult proxy_call(const char* rpc_url, const char* proxy_mnemonic, const char* real_account, const char* pallet_name, const char* call_name, const char* call_args_json);
    ExtrinsicResult query_proxies(const char* rpc_url, const char* account);
    
    // Identity operations
    TransferResult set_identity(const char* rpc_url, const char* mnemonic, const char* display_name, const char* legal_name, const char* web, const char* email, const char* twitter);
    TransferResult clear_identity(const char* rpc_url, const char* mnemonic);
    ExtrinsicResult query_identity(const char* rpc_url, const char* account);
    
    // WebSocket connection management
    ExtrinsicResult ws_connect(const char* rpc_url);
    ExtrinsicResult ws_get_stats(const char* rpc_url);
    ExtrinsicResult ws_reconnect(const char* rpc_url);
    ExtrinsicResult ws_disconnect(const char* rpc_url);
    ExtrinsicResult ws_list_connections();
    ExtrinsicResult ws_query_balance(const char* node_url, const char* address);
]]

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

-- Get the default FFI library path for current platform
local function get_default_ffi_path()
    local os_name, arch = detect_platform()
    local platform_dir = os_name .. "-" .. arch
    
    -- Determine file extension
    local ext = ".so"
    if os_name == 'windows' then
        ext = ".dll"
    elseif os_name == 'macos' then
        ext = ".dylib"
    end
    
    return "./precompiled/" .. platform_dir .. "/libpolkadot_ffi" .. ext
end

-- Load FFI library from specified path
local function load_ffi_library(path)
    local ok, lib = pcall(ffi.load, path)
    if not ok then
        error("Failed to load FFI library from: " .. path .. "\nError: " .. lib)
    end
    return lib
end

-- Main FFI module
local M = {}

-- Global FFI library instance
local lib = nil

-- Smart path finder - searches ALL possible locations
local function find_ffi_library()
    local os_name, arch = detect_platform()
    local platform_dir = os_name .. "-" .. arch
    
    -- Determine file extension and name
    local ext = ".so"
    local filename = "libpolkadot_ffi"
    if os_name == 'windows' then
        ext = ".dll"
        filename = "polkadot_ffi"
    elseif os_name == 'macos' then
        ext = ".dylib"
    end
    
    local lib_file = filename .. ext
    local home = os.getenv("HOME") or ""
    
    -- Build search paths (avoiding nil which breaks ipairs)
    local search_paths = {}
    
    -- 1. Environment variable (user override)
    local env_path = os.getenv("SUBLUA_FFI_PATH")
    if env_path then table.insert(search_paths, env_path) end
    
    -- 2. Current directory (development)
    table.insert(search_paths, "./precompiled/" .. platform_dir .. "/" .. lib_file)
    table.insert(search_paths, "precompiled/" .. platform_dir .. "/" .. lib_file)
    table.insert(search_paths, "./" .. lib_file)
    
    -- 3. SubLua-specific install location (installer puts it here)
    table.insert(search_paths, home .. "/.sublua/lib/" .. lib_file)
    
    -- 4. LuaRocks installed location
    table.insert(search_paths, home .. "/.luarocks/lib/lua/5.1/" .. lib_file)
    table.insert(search_paths, home .. "/.luarocks/lib/lua/5.4/" .. lib_file)
    table.insert(search_paths, home .. "/.luarocks/share/lua/5.1/precompiled/" .. platform_dir .. "/" .. lib_file)
    table.insert(search_paths, home .. "/.luarocks/share/lua/5.4/precompiled/" .. platform_dir .. "/" .. lib_file)
    
    -- 5. System locations
    table.insert(search_paths, "/usr/local/lib/" .. lib_file)
    table.insert(search_paths, "/opt/homebrew/lib/" .. lib_file)
    
    -- 6. Relative to script location (for bundled apps)
    table.insert(search_paths, "../precompiled/" .. platform_dir .. "/" .. lib_file)
    
    -- Try each path
    for _, path in ipairs(search_paths) do
        local ok, result = pcall(ffi.load, path)
        if ok then
            return result, path
        end
    end
    
    -- Last resort: try just the library name (system LD_LIBRARY_PATH)
    local ok, loaded = pcall(ffi.load, filename)
    if ok then
        return loaded, "system path (" .. filename .. ")"
    end
    
    return nil, nil
end

-- Initialize FFI - SMART auto-finding
function M.load_ffi(path)
    -- If already loaded, return it
    if lib then
        return lib
    end
    
    -- If specific path provided, use it
    if path then
        -- Path might be a directory or a file
        local os_name, arch = detect_platform()
        local ext = (os_name == 'macos') and ".dylib" or (os_name == 'windows') and ".dll" or ".so"
        local filename = (os_name == 'windows') and "polkadot_ffi" or "libpolkadot_ffi"
        
        local full_path = path
        if not path:match(ext .. "$") then
            -- It's a directory, append the filename
            local platform_dir = os_name .. "-" .. arch
            if path:match("/$") then
                full_path = path .. platform_dir .. "/" .. filename .. ext
            elseif path:match("precompiled$") or path:match("precompiled/$") then
                full_path = path .. "/" .. platform_dir .. "/" .. filename .. ext
            else
                full_path = path .. "/" .. filename .. ext
            end
        end
        
        local ok, loaded = pcall(ffi.load, full_path)
        if ok then
            lib = loaded
            return lib
        else
            -- Try just the raw path
            ok, loaded = pcall(ffi.load, path)
            if ok then
                lib = loaded
                return lib
            end
            error("Failed to load FFI library from: " .. path .. " (or " .. full_path .. ")")
        end
    end
    
    -- Auto-find the library
    local loaded, found_path = find_ffi_library()
    if loaded then
        lib = loaded
        return lib
    end
    
    -- Give helpful error
    local os_name, arch = detect_platform()
    error([[
FFI library not found! 

To fix this, run one of:
  1. curl -sSL https://raw.githubusercontent.com/MontaQLabs/sublua/main/install_sublua.sh | bash
  2. Or manually download from: https://github.com/MontaQLabs/sublua/releases

Expected location: ~/.sublua/lib/libpolkadot_ffi]] .. ((os_name == 'macos') and ".dylib" or ".so"))
end

-- Expose ffi for direct access
M.ffi = ffi

-- Get current FFI library (auto-loads if needed)
function M.get_lib()
    if not lib then
        M.load_ffi()
    end
    return lib
end

-- Platform detection
function M.detect_platform()
    return detect_platform()
end

-- Get recommended FFI path for current platform
function M.get_recommended_path()
    return get_default_ffi_path()
end

-- Download FFI library for current platform
function M.download_ffi_library(target_dir)
    local os_name, arch = detect_platform()
    local platform_dir = os_name .. "-" .. arch
    
    local ext = ".so"
    local filename = "libpolkadot_ffi.so"
    if os_name == 'windows' then
        ext = ".dll"
        filename = "polkadot_ffi.dll"
    elseif os_name == 'macos' then
        ext = ".dylib"
        filename = "libpolkadot_ffi.dylib"
    end
    
    local home = os.getenv("HOME") or "."
    target_dir = target_dir or (home .. "/.sublua/lib")
    
    local url = "https://github.com/MontaQLabs/sublua/releases/latest/download/" .. filename
    local local_path = target_dir .. "/" .. filename
    
    print("📥 Downloading FFI library for " .. platform_dir .. "...")
    print("   URL:", url)
    print("   Target:", local_path)
    
    os.execute("mkdir -p '" .. target_dir .. "'")
    
    local cmd = "curl -L -o '" .. local_path .. "' '" .. url .. "'"
    local result = os.execute(cmd)
    
    if result == 0 then
        print("✅ FFI library installed to:", local_path)
        return local_path
    else
        error("Failed to download FFI library. Check your internet connection.")
    end
end

-- Expose ffi for direct access
M.ffi = ffi

return M