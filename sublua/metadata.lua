-- sublua/metadata.lua
-- Dynamic metadata handling using subxt FFI for runtime parsing

local ffi_mod = require("sublua.polkadot_ffi")

local Metadata = {}

-- Cache for validated metadata
local metadata_cache = {}
local ffi_lib = nil

-- Get the FFI library instance
local function get_lib()
    if not ffi_lib then
        ffi_lib = ffi_mod.get_lib()
    end
    return ffi_lib
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
        -- Remove whitespace
        str = str:gsub("%s+", "")
        
        -- Try to extract key-value pairs
        local obj = {}
        for key, value in str:gmatch('"([^"]+)"%s*:%s*([^,}]+)') do
            -- Try to convert to number
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
                obj[key] = value
            end
        end
        
        -- Also try to extract arrays
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

-- Validate call indices against runtime metadata
function Metadata.validate_call_indices(rpc, spec_name)
    local cache_key = spec_name
    if metadata_cache[cache_key] then
        return metadata_cache[cache_key]
    end
    
    -- Skip validation and use direct indices - dry run is not available externally
    print("🔍 Using direct call indices (dry run validation unavailable)")
    
    local indices = Metadata.get_fallback_indices(spec_name)
    metadata_cache[cache_key] = indices
    return indices
end

-- Get fallback indices based on detected chain type
function Metadata.get_fallback_indices(spec_name)
    local chain_type = Metadata.detect_chain_type(spec_name)
    
    -- Updated indices based on working Polkadot.js transaction analysis
    local fallback_indices = {
        polkadot = {
            system = { pallet = 0, remark_with_event = 7 },
            balances = { pallet = 5, transfer_keep_alive = 3 }  -- CORRECTED: 5, not 4
        },
        kusama = {
            system = { pallet = 0, remark_with_event = 7 },
            balances = { pallet = 5, transfer_keep_alive = 3 }  -- CORRECTED: 5, not 4
        },
        westend = {
            system = { pallet = 0, remark_with_event = 7 },
            balances = { pallet = 5, transfer_keep_alive = 3 }  -- CORRECTED: 5, not 4
        },
        paseo = {
            system = { pallet = 0, remark_with_event = 7 },
            balances = { pallet = 5, transfer_allow_death = 0 }  -- CORRECTED: Use transferAllowDeath [5, 0] = 0500
        },
        rococo = {
            system = { pallet = 0, remark_with_event = 7 },
            balances = { pallet = 5, transfer_keep_alive = 3 }  -- CORRECTED: 5, not 4
        },
        substrate = {
            system = { pallet = 0, remark_with_event = 7 },
            balances = { pallet = 5, transfer_keep_alive = 3 }  -- CORRECTED: 5, not 4
        }
    }
    
    return fallback_indices[chain_type] or fallback_indices.substrate
end

-- Detect chain type from runtime spec name
function Metadata.detect_chain_type(spec_name)
    if not spec_name then return "substrate" end
    
    local spec_lower = spec_name:lower()
    
    if spec_lower:find("polkadot") then
        return "polkadot"
    elseif spec_lower:find("kusama") then
        return "kusama"
    elseif spec_lower:find("westend") then
        return "westend"
    elseif spec_lower:find("paseo") then
        return "paseo"
    elseif spec_lower:find("rococo") then
        return "rococo"
    else
        return "substrate"
    end
end

-- Get validated call indices (with RPC validation if available)
function Metadata.get_call_indices(spec_name, rpc)
    if rpc then
        return Metadata.validate_call_indices(rpc, spec_name)
    else
        return Metadata.get_fallback_indices(spec_name)
    end
end

-- Get specific call index for a pallet and call
function Metadata.get_call_index(spec_name, pallet_name, call_name, rpc)
    local indices = Metadata.get_call_indices(spec_name, rpc)
    
    if pallet_name == "system" or pallet_name == "System" then
        if call_name == "remark_with_event" or call_name == "remark" then
            return {indices.system.pallet, indices.system.remark_with_event}
        end
    elseif pallet_name == "balances" or pallet_name == "Balances" then
        if call_name == "transfer_keep_alive" or call_name == "transfer" then
            return {indices.balances.pallet, indices.balances.transfer_keep_alive}
        elseif call_name == "transfer_allow_death" or call_name == "transferAllowDeath" then
            return {indices.balances.pallet, indices.balances.transfer_allow_death}
        end
    end
    
    error("Unknown pallet/call combination: " .. pallet_name .. "." .. call_name)
end

-- Convenience methods with RPC validation
function Metadata.get_system_remark_index(spec_name, rpc)
    local indices = Metadata.get_call_indices(spec_name, rpc)
    return {indices.system.pallet, indices.system.remark_with_event}
end

function Metadata.get_balances_transfer_index(spec_name, rpc)
    local indices = Metadata.get_call_indices(spec_name, rpc)
    -- Use transfer_allow_death for Paseo, transfer_keep_alive for others
    if spec_name and spec_name:lower():find("paseo") then
        return {indices.balances.pallet, indices.balances.transfer_allow_death}
    else
        return {indices.balances.pallet, indices.balances.transfer_keep_alive}
    end
end

-- DYNAMIC METADATA FUNCTIONS (using subxt FFI)

--- Fetch and parse runtime metadata from a chain
function Metadata.fetch_metadata(rpc_url)
    local result = get_lib().fetch_chain_metadata(rpc_url)
    return parse_ffi_result(result)
end

--- Get all pallets from chain metadata
function Metadata.get_pallets(rpc_url)
    local result = get_lib().get_metadata_pallets(rpc_url)
    local data, err = parse_ffi_result(result)
    if not data then return nil, err end
    return data.pallets, nil
end

--- Get call index for a specific pallet and call name (DYNAMIC)
function Metadata.get_dynamic_call_index(rpc_url, pallet_name, call_name)
    local result = get_lib().get_call_index(rpc_url, pallet_name, call_name)
    local data, err = parse_ffi_result(result)
    if not data then return nil, err end
    return {tonumber(data.pallet_index), tonumber(data.call_index)}, nil
end

--- Get all calls for a specific pallet
function Metadata.get_pallet_calls_list(rpc_url, pallet_name)
    local result = get_lib().get_pallet_calls(rpc_url, pallet_name)
    local data, err = parse_ffi_result(result)
    if not data then return nil, err end
    return data.calls, nil
end

--- Check runtime compatibility
function Metadata.check_compatibility(rpc_url, expected_spec_version)
    local result = get_lib().check_runtime_compatibility(rpc_url, expected_spec_version)
    local data, err = parse_ffi_result(result)
    if not data then return false, err end
    return data.compatible, data.message
end

--- Auto-discover call indices from chain (RECOMMENDED for production)
function Metadata.discover_call_index(rpc_url, pallet_name, call_name)
    -- Try dynamic discovery first
    local indices, err = Metadata.get_dynamic_call_index(rpc_url, pallet_name, call_name)
    if indices then
        -- Cache it
        local cache_key = rpc_url .. ":" .. pallet_name .. ":" .. call_name
        metadata_cache[cache_key] = indices
        return indices
    end
    
    -- Fallback to static indices
    print("⚠️  Dynamic discovery failed: " .. (err or "unknown error"))
    print("📋 Falling back to static indices")
    return Metadata.get_fallback_indices("substrate")[pallet_name]
end

return Metadata 