local ffi = require("ffi")

-- Define the FFI functions
ffi.cdef[[
    typedef struct {
        bool success;
        char* data;
        char* error;
    } ExtrinsicResult;

    ExtrinsicResult sign_extrinsic(const char* seed_hex, const char* extrinsic_hex);
    ExtrinsicResult derive_sr25519_public_key(const char* seed_hex);
    ExtrinsicResult compute_ss58_address(const char* public_key_hex, uint16_t network_prefix);
    ExtrinsicResult derive_sr25519_from_mnemonic(const char* mnemonic);
    void free_string(char* ptr);
]]

-- Load the library
local lib = ffi.load("./polkadot-ffi/target/release/libpolkadot_ffi.so")

local Signer = {}
Signer.__index = Signer

-- Helper function to ensure hex format
local function ensure_hex_prefix(str)
    if not str:match("^0x") then
        return "0x" .. str
    end
    return str
end

-- Helper function to validate hex string
local function is_valid_hex(str)
    str = str:gsub("^0x", "")
    -- Allow empty strings and ensure the rest is valid hex
    return str == "" or str:match("^[0-9a-fA-F]+$") ~= nil
end

-- Create a new signer
function Signer.new(seed_hex)
    if not seed_hex then
        error("Seed hex is required")
    end
    
    -- Ensure seed is properly formatted
    seed_hex = ensure_hex_prefix(seed_hex)
    if not is_valid_hex(seed_hex) then
        error("Invalid seed hex format")
    end
    
    return setmetatable({ seed_hex = seed_hex, _public_override = nil }, { __index = Signer })
end

-- Sign an extrinsic
function Signer:sign(extrinsic_hex)
    if not extrinsic_hex then
        error("Extrinsic hex is required")
    end

    -- Ensure extrinsic is properly formatted
    extrinsic_hex = ensure_hex_prefix(extrinsic_hex)
    
    -- Debug information
    print("Debug - Extrinsic hex before validation:", extrinsic_hex)
    print("Debug - Extrinsic hex without prefix:", extrinsic_hex:gsub("^0x", ""))
    
    if not is_valid_hex(extrinsic_hex) then
        error("Invalid extrinsic hex format: " .. extrinsic_hex)
    end

    -- Call the FFI function
    local result = lib.sign_extrinsic(self.seed_hex, extrinsic_hex)
    
    if result.success then
        local data = ffi.string(result.data)
        lib.free_string(result.data)
        return ensure_hex_prefix(data)
    else
        local error_msg = ffi.string(result.error)
        lib.free_string(result.error)
        error(error_msg)
    end
end

-- Read functions for different data types
function Signer:read_balance(hex)
    if not hex then return nil end
    hex = ensure_hex_prefix(hex)
    -- Convert hex to number (assuming it's a compact integer)
    return tonumber(hex:sub(3), 16)
end

function Signer:read_account_info(hex)
    if not hex then return nil end
    hex = ensure_hex_prefix(hex)
    -- Parse account info from hex
    -- Format: nonce (u32) + consumers (u32) + providers (u32) + sufficients (u32) + data (balance)
    local nonce = tonumber(hex:sub(3, 10), 16)
    local consumers = tonumber(hex:sub(11, 18), 16)
    local providers = tonumber(hex:sub(19, 26), 16)
    local sufficients = tonumber(hex:sub(27, 34), 16)
    local balance = tonumber(hex:sub(35), 16)
    
    return {
        nonce = nonce,
        consumers = consumers,
        providers = providers,
        sufficients = sufficients,
        balance = balance
    }
end

function Signer:read_extrinsic_status(hex)
    if not hex then return nil end
    hex = ensure_hex_prefix(hex)
    -- Parse extrinsic status from hex
    -- Format: is_success (bool) + error (if any)
    local is_success = hex:sub(3, 4) == "01"
    local error = nil
    if not is_success then
        error = hex:sub(5)
    end
    
    return {
        success = is_success,
        error = error
    }
end

-- Override get_public_key to use cached value if set
function Signer:get_public_key()
    if self._public_override then
        return self._public_override
    end
    local result = lib.derive_sr25519_public_key(self.seed_hex)
    if result.success then
        local data = ffi.string(result.data)
        lib.free_string(result.data)
        return ensure_hex_prefix(data)
    else
        local error_msg = ffi.string(result.error)
        lib.free_string(result.error)
        error(error_msg)
    end
end

-- Get the SS58 address for a specific network
function Signer:get_ss58_address(network_prefix)
    network_prefix = network_prefix or 42  -- Default to Westend
    local public_key = self:get_public_key()
    
    local result = lib.compute_ss58_address(public_key, network_prefix)
    if result.success then
        local data = ffi.string(result.data)
        lib.free_string(result.data)
        return data
    else
        local error_msg = ffi.string(result.error)
        lib.free_string(result.error)
        error(error_msg)
    end
end

-- Update from_mnemonic to cache public
function Signer.from_mnemonic(mnemonic)
    if not mnemonic or mnemonic == "" then error("Mnemonic required") end
    local c_str = ffi.new("char[?]", #mnemonic + 1)
    ffi.copy(c_str, mnemonic)
    local result = lib.derive_sr25519_from_mnemonic(c_str)
    if not result.success then
        local err_msg = ffi.string(result.error)
        lib.free_string(result.error)
        error("Mnemonic derivation failed: " .. err_msg)
    end
    local json_str = ffi.string(result.data)
    lib.free_string(result.data)
    local ok, tbl = pcall(require("dkjson").decode, json_str)
    if not ok then error("Failed to decode derivation JSON: " .. tostring(tbl)) end
    local signer = Signer.new(tbl.seed)
    signer._public_override = ensure_hex_prefix(tbl.public)
    return signer, tbl -- returns signer and key info
end

return Signer 