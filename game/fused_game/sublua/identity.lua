-- sublua/identity.lua
-- Identity management for Substrate chains

local ffi_mod = require("sublua.polkadot_ffi")

local Identity = {}

-- Get the FFI library instance
local function get_lib()
    return ffi_mod.get_lib()
end

-- Helper to parse transfer result
local function parse_transfer_result(result)
    if not result.success then
        local error_msg = ffi_mod.ffi.string(result.error)
        get_lib().free_string(result.error)
        return nil, error_msg
    end
    
    local tx_hash = ffi_mod.ffi.string(result.tx_hash)
    get_lib().free_string(result.tx_hash)
    return tx_hash, nil
end

-- Helper to parse query result
local function parse_query_result(result)
    if not result.success then
        local error_msg = ffi_mod.ffi.string(result.error)
        get_lib().free_string(result.error)
        return nil, error_msg
    end
    
    local data_str = ffi_mod.ffi.string(result.data)
    get_lib().free_string(result.data)
    return data_str, nil
end

--- Set identity information for your account
-- @param rpc_url string - RPC endpoint URL
-- @param mnemonic string - Your account's mnemonic phrase
-- @param info table - Identity information with optional fields:
--   - display_name string - Display name
--   - legal_name string - Legal name
--   - web string - Website URL
--   - email string - Email address
--   - twitter string - Twitter handle
-- @return string, string - Transaction hash or nil, error
--
-- Example:
--   local tx_hash, err = identity.set(
--       "wss://westend-rpc.polkadot.io",
--       "your mnemonic here",
--       {
--           display_name = "Alice",
--           web = "https://alice.example.com",
--           email = "alice@example.com",
--           twitter = "@alice"
--       }
--   )
function Identity.set(rpc_url, mnemonic, info)
    info = info or {}
    
    local display = info.display_name or ""
    local legal = info.legal_name or ""
    local web = info.web or ""
    local email = info.email or ""
    local twitter = info.twitter or ""
    
    local result = get_lib().set_identity(
        rpc_url,
        mnemonic,
        display,
        legal,
        web,
        email,
        twitter
    )
    return parse_transfer_result(result)
end

--- Clear identity information for your account
-- @param rpc_url string - RPC endpoint URL
-- @param mnemonic string - Your account's mnemonic phrase
-- @return string, string - Transaction hash or nil, error
--
-- Example:
--   local tx_hash, err = identity.clear(
--       "wss://westend-rpc.polkadot.io",
--       "your mnemonic here"
--   )
function Identity.clear(rpc_url, mnemonic)
    local result = get_lib().clear_identity(rpc_url, mnemonic)
    return parse_transfer_result(result)
end

--- Query identity information for an account
-- @param rpc_url string - RPC endpoint URL
-- @param account string - SS58 address to query
-- @return string, string - Identity data (as raw string) or nil, error
--
-- Example:
--   local identity_data, err = identity.query(
--       "wss://westend-rpc.polkadot.io",
--       "5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY"
--   )
function Identity.query(rpc_url, account)
    local result = get_lib().query_identity(rpc_url, account)
    return parse_query_result(result)
end

--- Validate identity information
-- @param info table - Identity info to validate
-- @return boolean, string - true if valid, or false and error message
function Identity.validate(info)
    if type(info) ~= "table" then
        return false, "Identity info must be a table"
    end
    
    -- Validate field lengths (Substrate has max lengths)
    local max_lengths = {
        display_name = 32,
        legal_name = 32,
        web = 100,
        email = 100,
        twitter = 32,
    }
    
    for field, max_len in pairs(max_lengths) do
        local value = info[field]
        if value and type(value) == "string" and #value > max_len then
            return false, field .. " exceeds maximum length of " .. max_len .. " bytes"
        end
    end
    
    -- Validate Twitter handle format (if provided)
    if info.twitter and #info.twitter > 0 then
        if not info.twitter:match("^@?[A-Za-z0-9_]+$") then
            return false, "Invalid Twitter handle format"
        end
    end
    
    -- Validate email format (basic check, if provided)
    if info.email and #info.email > 0 then
        if not info.email:match("^[^@]+@[^@]+%.[^@]+$") then
            return false, "Invalid email format"
        end
    end
    
    -- Validate URL format (basic check, if provided)
    if info.web and #info.web > 0 then
        if not info.web:match("^https?://") then
            return false, "Web URL must start with http:// or https://"
        end
    end
    
    return true, nil
end

--- Create an empty identity info table with all fields
-- Useful as a template for setting identity
-- @return table - Empty identity info structure
function Identity.create_info()
    return {
        display_name = "",
        legal_name = "",
        web = "",
        email = "",
        twitter = "",
    }
end

return Identity

