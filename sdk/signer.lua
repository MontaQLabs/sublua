-- sdk/core/signer.lua

local ffi_mod = require("sdk.polkadot_ffi")
local ffi  = ffi_mod.ffi
local util = require("sdk.util")

-- Get the FFI library instance
local function get_lib()
    return ffi_mod.get_lib()
end

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

--- Create a new signer from a raw 32-byte seed hex string.
-- Optionally, a public key hex string can be provided if already known.
function Signer.new(seed_hex, public_hex)
    assert(type(seed_hex) == "string", "seed_hex must be hex string")
    local self = setmetatable({}, Signer)
    self.seed = seed_hex:gsub("^0x", "")
    self.public = public_hex and public_hex:gsub("^0x", "") or nil
    self._public_override = nil
    return self
end

-- Create signer from mnemonic phrase
function Signer.from_mnemonic(mnemonic)
    if not mnemonic or mnemonic == "" then 
        error("Mnemonic required") 
    end
    
    local c_str = ffi.new("char[?]", #mnemonic + 1)
    ffi.copy(c_str, mnemonic)
    local result = get_lib().derive_sr25519_from_mnemonic(c_str)
    
    if not result.success then
        local err_msg = ffi.string(result.error)
        get_lib().free_string(result.error)
        error("Mnemonic derivation failed: " .. err_msg)
    end
    
    local json_str = ffi.string(result.data)
    get_lib().free_string(result.data)
    
    -- Parse JSON result (simple manual parsing to avoid cjson dependency)
    local seed_hex = json_str:match('"seed"%s*:%s*"([^"]+)"')
    local public_hex = json_str:match('"public"%s*:%s*"([^"]+)"')
    
    if not seed_hex or seed_hex == "" then
        error("Seed not found in derivation result")
    end
    
    local signer = Signer.new(seed_hex)
    if public_hex then
        signer._public_override = ensure_hex_prefix(public_hex)
    end
    return signer
end

--- Sign an extrinsic hex string, returns signature hex.
function Signer:sign(extrinsic_hex)
    if not extrinsic_hex then
        error("Extrinsic hex is required")
    end

    -- Ensure extrinsic is properly formatted
    extrinsic_hex = ensure_hex_prefix(extrinsic_hex)
    
    if not is_valid_hex(extrinsic_hex) then
        error("Invalid extrinsic hex format: " .. extrinsic_hex)
    end

    local result = get_lib().sign_extrinsic(self.seed, extrinsic_hex)
    if not result.success then
        local msg = ffi.string(result.error)
        get_lib().free_string(result.error)
        error("sign_extrinsic failed: " .. msg)
    end
    local sig_hex = ffi.string(result.data)
    get_lib().free_string(result.data)
    return ensure_hex_prefix(sig_hex)
end

--- Get public key (use cached value if available from mnemonic derivation)
function Signer:get_public_key()
    if self._public_override then
        return self._public_override
    end
    
    local result = get_lib().derive_sr25519_public_key(ensure_hex_prefix(self.seed))
    if result.success then
        local data = ffi.string(result.data)
        get_lib().free_string(result.data)
        return ensure_hex_prefix(data)
    else
        local error_msg = ffi.string(result.error)
        get_lib().free_string(result.error)
        error("Failed to derive public key: " .. error_msg)
    end
end

--- Get SS58 address for specific network
-- @param network_prefix Network prefix (0=Polkadot/Paseo, 42=Substrate/Westend, 2=Kusama, etc.)
function Signer:get_ss58_address(network_prefix)
    network_prefix = network_prefix or 42  -- Default to Substrate generic (42), not chain-specific
    
    local public_key = self:get_public_key()
    local result = get_lib().compute_ss58_address(public_key, network_prefix)
    
    if result.success then
        local address = ffi.string(result.data)
        get_lib().free_string(result.data)
        return address
    else
        local error_msg = ffi.string(result.error)
        get_lib().free_string(result.error)
        error("Failed to compute SS58 address: " .. error_msg)
    end
end

return Signer 