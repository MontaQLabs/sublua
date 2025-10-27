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

-- Initialize FFI with specified path
function M.load_ffi(path)
    if not path then
        path = get_default_ffi_path()
    end
    
    lib = load_ffi_library(path)
    print("✅ FFI library loaded from:", path)
    return lib
end

-- Expose ffi for direct access
M.ffi = ffi

-- Get current FFI library (loads default if not initialized)
function M.get_lib()
    if not lib then
        M.load_ffi() -- Load with default path
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
function M.download_ffi_library()
    local os_name, arch = detect_platform()
    local platform_dir = os_name .. "-" .. arch
    
    -- Determine file extension and name
    local ext = ".so"
    local filename = "libpolkadot_ffi.so"
    if os_name == 'windows' then
        ext = ".dll"
        filename = "polkadot_ffi.dll"
    elseif os_name == 'macos' then
        ext = ".dylib"
        filename = "libpolkadot_ffi.dylib"
    end
    
    local url = "https://github.com/MontaQLabs/sublua/releases/latest/download/" .. filename
    local local_path = "./precompiled/" .. platform_dir .. "/" .. filename
    
    print("📥 Downloading FFI library for " .. platform_dir .. "...")
    print("   URL:", url)
    print("   Local path:", local_path)
    
    -- Create directory if it doesn't exist
    os.execute("mkdir -p ./precompiled/" .. platform_dir)
    
    -- Download using curl
    local cmd = "curl -L -o '" .. local_path .. "' '" .. url .. "'"
    local result = os.execute(cmd)
    
    if result == 0 then
        print("✅ FFI library downloaded successfully!")
        return local_path
    else
        error("Failed to download FFI library")
    end
end

-- Auto-detect and load FFI library
function M.auto_load()
    local os_name, arch = detect_platform()
    local platform_dir = os_name .. "-" .. arch
    
    -- Try to load from precompiled directory
    local default_path = get_default_ffi_path()
    local ok, lib = pcall(ffi.load, default_path)
    
    if ok then
        print("✅ FFI library auto-loaded from:", default_path)
        return lib
    else
        print("⚠️  FFI library not found at:", default_path)
        print("💡 Run: sublua.download_ffi_library() to download it")
        return nil
    end
end

-- Expose ffi for direct access
M.ffi = ffi

return M