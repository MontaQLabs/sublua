-- sublua/multisig.lua
-- Multi-signature account management for Substrate chains

local ffi_mod = require("sublua.polkadot_ffi")

local Multisig = {}

-- Get the FFI library instance
local function get_lib()
    return ffi_mod.get_lib()
end

-- Helper to parse JSON result from FFI
local function parse_ffi_result(result)
    if not result.success then
        local error_msg = ffi_mod.ffi.string(result.error)
        get_lib().free_string(result.error)
        return nil, error_msg
    end
    
    local json_str = ffi_mod.ffi.string(result.data)
    get_lib().free_string(result.data)
    
    -- Simple JSON parser
    local function parse_json(str)
        str = str:gsub("%s+", "")
        local obj = {}
        
        -- Parse simple key-value pairs
        for key, value in str:gmatch('"([^"]+)"%s*:%s*([^,}]+)') do
            local num = tonumber(value)
            if num then
                obj[key] = num
            elseif value == "true" then
                obj[key] = true
            elseif value == "false" then
                obj[key] = false
            elseif value:sub(1,1) == '"' then
                obj[key] = value:gsub('"', '')
            else
                obj[key] = value:gsub('"', '')
            end
        end
        
        -- Parse arrays
        for key in str:gmatch('"([^"]+)"%s*:%s*%[') do
            local array_start = str:find('"' .. key .. '"%s*:%s*%[')
            if array_start then
                local array_end = str:find('%]', array_start)
                if array_end then
                    local array_str = str:sub(array_start, array_end)
                    local arr = {}
                    for item in array_str:gmatch('"([^"]+)"') do
                        table.insert(arr, item)
                    end
                    if #arr > 0 then
                        obj[key] = arr
                    end
                end
            end
        end
        
        return obj
    end
    
    return parse_json(json_str), nil
end

--- Create a multi-signature address from a list of signatories and threshold
-- @param signatories table - Array of SS58 addresses that will be signatories
-- @param threshold number - Number of signatures required to execute transactions
-- @return table, string - Multisig info {multisig_address, threshold, signatories} or nil, error
--
-- Example:
--   local info, err = multisig.create_address({
--       "5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY",
--       "5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty"
--   }, 2)
function Multisig.create_address(signatories, threshold)
    if type(signatories) ~= "table" or #signatories < 2 then
        return nil, "At least 2 signatories required"
    end
    
    if type(threshold) ~= "number" or threshold < 1 or threshold > #signatories then
        return nil, "Threshold must be between 1 and number of signatories"
    end
    
    -- Convert signatories array to JSON
    local json_parts = {}
    for _, addr in ipairs(signatories) do
        table.insert(json_parts, '"' .. addr .. '"')
    end
    local signatories_json = "[" .. table.concat(json_parts, ",") .. "]"
    
    local result = get_lib().create_multisig_address(signatories_json, threshold)
    return parse_ffi_result(result)
end

--- Get the deterministic multisig address for a set of signatories
-- This is a convenience wrapper around create_address that just returns the address
-- @param signatories table - Array of SS58 addresses
-- @param threshold number - Number of signatures required
-- @return string, string - Multisig address or nil, error
function Multisig.get_address(signatories, threshold)
    local info, err = Multisig.create_address(signatories, threshold)
    if not info then
        return nil, err
    end
    return info.multisig_address, nil
end

--- Validate multisig parameters
-- @param signatories table - Array of SS58 addresses
-- @param threshold number - Required signatures
-- @return boolean, string - true if valid, or false and error message
function Multisig.validate_params(signatories, threshold)
    if type(signatories) ~= "table" then
        return false, "Signatories must be a table"
    end
    
    if #signatories < 2 then
        return false, "At least 2 signatories required for multisig"
    end
    
    if type(threshold) ~= "number" then
        return false, "Threshold must be a number"
    end
    
    if threshold < 1 then
        return false, "Threshold must be at least 1"
    end
    
    if threshold > #signatories then
        return false, "Threshold cannot exceed number of signatories"
    end
    
    -- Check for duplicate addresses
    local seen = {}
    for _, addr in ipairs(signatories) do
        if seen[addr] then
            return false, "Duplicate signatory address: " .. addr
        end
        seen[addr] = true
    end
    
    return true, nil
end

return Multisig

