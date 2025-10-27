-- sdk/core/rpc.lua
-- JSON-RPC client for Substrate chains

-- Simple JSON encoder/decoder (basic functionality)
local function json_encode(obj)
    if type(obj) == "table" then
        local parts = {}
        local is_array = true
        local count = 0
        
        -- Check if it's an array
        for k, v in pairs(obj) do
            count = count + 1
            if type(k) ~= "number" or k ~= count then
                is_array = false
                break
            end
        end
        
        if is_array then
            for i, v in ipairs(obj) do
                table.insert(parts, json_encode(v))
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            for k, v in pairs(obj) do
                table.insert(parts, '"' .. tostring(k) .. '":' .. json_encode(v))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    elseif type(obj) == "string" then
        return '"' .. obj:gsub('"', '\\"') .. '"'
    elseif type(obj) == "number" then
        return tostring(obj)
    elseif type(obj) == "boolean" then
        return obj and "true" or "false"
    else
        return "null"
    end
end

local function json_decode(str)
    -- Very basic JSON decoder - for production use a proper library
    local function parse_value(s, pos)
        local char = s:sub(pos, pos)
        if char == '"' then
            local end_pos = s:find('"', pos + 1)
            return s:sub(pos + 1, end_pos - 1), end_pos + 1
        elseif char == '{' then
            local obj = {}
            pos = pos + 1
            while s:sub(pos, pos) ~= '}' do
                local key, new_pos = parse_value(s, pos)
                pos = s:find(':', new_pos) + 1
                local value, val_pos = parse_value(s, pos)
                obj[key] = value
                pos = val_pos
                if s:sub(pos, pos) == ',' then pos = pos + 1 end
            end
            return obj, pos + 1
        elseif char:match('%d') or char == '-' then
            local end_pos = pos
            while s:sub(end_pos + 1, end_pos + 1):match('[%d%.]') do
                end_pos = end_pos + 1
            end
            return tonumber(s:sub(pos, end_pos)), end_pos + 1
        end
        return nil, pos
    end
    
    local result, _ = parse_value(str:gsub('%s+', ''), 1)
    return result
end

-- Try to load external JSON library, fallback to simple implementation
local json
local json_ok, json_lib = pcall(require, "cjson")
if json_ok then
    json = json_lib
else
    json = {
        encode = json_encode,
        decode = json_decode
    }
end

local http = require("socket.http")
local ltn12 = require("ltn12")

local metadata = require("sdk.metadata")

local RPC = {}

function RPC.new(url)
    -- Convert WebSocket URLs to HTTP for compatibility
    if url:match("^wss://") then
        url = url:gsub("^wss://", "https://")
    elseif url:match("^ws://") then
        url = url:gsub("^ws://", "http://")
    end
    
    local self = {
        url = url,
        id = 1,
        chain_properties = nil  -- Cache for chain properties
    }
    setmetatable(self, {__index = RPC})
    return self
end

function RPC:request(method, params)
    local request_data = {
        jsonrpc = "2.0",
        method = method,
        params = params or {},
        id = self.id
    }
    self.id = self.id + 1
    
    local body = json.encode(request_data)
    local response_body = {}
    
    local success, status_code, headers = http.request{
        url = self.url,
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = tostring(#body)
        },
        source = ltn12.source.string(body),
        sink = ltn12.sink.table(response_body),
        redirect = true  -- Follow redirects
    }
    
    if not success then
        error("HTTP request failed: " .. tostring(status_code))
    end
    
    if status_code ~= 200 then
        error("HTTP error code " .. status_code)
    end
    
    local response_text = table.concat(response_body)
    local response = json.decode(response_text)
    
    if response.error then
        error("RPC error: " .. response.error.message)
    end
    
    return response.result
end

-- Get chain properties (token decimals, symbol, etc.)
function RPC:get_chain_properties()
    if self.chain_properties then
        return self.chain_properties
    end
    
    local success, properties = pcall(function()
        return self:request("system_properties")
    end)
    
    if success and properties then
        -- Handle both single values and arrays
        local decimals = properties.tokenDecimals
        local symbol = properties.tokenSymbol
        
        if type(decimals) == "table" then
            decimals = decimals[1] or 12  -- Use first token's decimals, fallback to 12
        end
        if type(symbol) == "table" then
            symbol = symbol[1] or "UNIT"  -- Use first token's symbol, fallback to "UNIT"
        end
        
        self.chain_properties = {
            decimals = decimals or 12,  -- Default to 12 decimals if not found
            symbol = symbol or "UNIT",  -- Default to "UNIT" if not found
            divisor = 10 ^ (decimals or 12)
        }
    else
        -- Fallback for chains that don't support system_properties
        self.chain_properties = {
            decimals = 12,
            symbol = "UNIT",
            divisor = 10 ^ 12
        }
    end
    
    return self.chain_properties
end

-- Chain methods
function RPC:chain_getBlockHash(block_number)
    if block_number then
        return self:request("chain_getBlockHash", {block_number})
    else
        return self:request("chain_getBlockHash")
    end
end

function RPC:chain_getFinalizedHead()
    return self:request("chain_getFinalizedHead")
end

-- State methods
function RPC:state_getRuntimeVersion(at_block)
    return self:request("state_getRuntimeVersion", at_block and {at_block} or {})
end

function RPC:state_getStorage(key, at_block)
    local params = {key}
    if at_block then
        table.insert(params, at_block)
    end
    return self:request("state_getStorage", params)
end

function RPC:state_getKeys(prefix, count)
    local params = {prefix}
    if count then
        table.insert(params, count)
    end
    return self:request("state_getKeys", params)
end

-- System methods
function RPC:system_account(address)
    return self:request("state_call", {"AccountStore", "account", address})
end

function RPC:system_accountNextIndex(address)
    return self:request("system_accountNextIndex", {address})
end

-- Author methods
function RPC:author_submitExtrinsic(hex)
    return self:request("author_submitExtrinsic", {hex})
end

function RPC:author_submitAndWatchExtrinsic(hex)
    return self:request("author_submitAndWatchExtrinsic", {hex})
end

function RPC:system_dryRun(hex, at_block)
    local params = {hex}
    if at_block then
        table.insert(params, at_block)
    end
    return self:request("system_dryRun", params)
end

-- Helper function to decode compact integer from hex
local function decode_compact_int(hex_str, offset)
    if not hex_str or #hex_str < offset + 2 then
        return 0, offset
    end
    
    local first_byte = tonumber(hex_str:sub(offset + 1, offset + 2), 16)
    if not first_byte then return 0, offset end
    
    local mode = first_byte % 4
    
    if mode == 0 then
        -- Single byte mode
        return math.floor(first_byte / 4), offset + 2
    elseif mode == 1 then
        -- Two byte mode
        if #hex_str < offset + 4 then return 0, offset end
        local second_byte = tonumber(hex_str:sub(offset + 3, offset + 4), 16) or 0
        return math.floor(first_byte / 4) + second_byte * 64, offset + 4
    elseif mode == 2 then
        -- Four byte mode
        if #hex_str < offset + 8 then return 0, offset end
        local value = 0
        for i = 0, 3 do
            local byte = tonumber(hex_str:sub(offset + 1 + i * 2, offset + 2 + i * 2), 16) or 0
            if i == 0 then
                byte = math.floor(byte / 4)
            end
            value = value + byte * (256 ^ i)
        end
        return value, offset + 8
    else
        -- Big integer mode - simplified for demo
        local length = math.floor(first_byte / 4)
        local bytes_needed = length + 4
        if #hex_str < offset + 2 + bytes_needed * 2 then return 0, offset end
        
        -- For simplicity, just read as much as we can
        local value = 0
        for i = 0, math.min(7, length + 3) do
            local byte = tonumber(hex_str:sub(offset + 3 + i * 2, offset + 4 + i * 2), 16) or 0
            value = value + byte * (256 ^ i)
        end
        return value, offset + 2 + bytes_needed * 2
    end
end

-- Helper function to convert SS58 address to AccountId32 (public key)
local function ss58_to_account_id(ss58_address)
    local ffi_module = require('sdk.polkadot_ffi')
    local ffi = ffi_module.ffi
    local lib = ffi_module.lib
    
    local result = lib.decode_ss58_address(ss58_address)
    
    if result.success then
        local public_key_hex = ffi.string(result.data)
        lib.free_string(result.data)
        return public_key_hex
    else
        local error_msg = ffi.string(result.error)
        lib.free_string(result.error)
        error("Failed to decode SS58 address: " .. error_msg)
    end
end

-- Helper function to get account info
function RPC:get_account_info(address)
    -- Convert SS58 address to AccountId32 (public key)
    local account_id = ss58_to_account_id(address)
    if not account_id then
        return nil, "Invalid address format"
    end
    
    -- Get FFI access for blake2_128 hashing
    local ffi_module = require('sdk.polkadot_ffi')
    local ffi = ffi_module.ffi
    local lib = ffi_module.lib
    
    -- Compute blake2_128_concat for the AccountId
    -- blake2_128_concat = blake2_128(data) + data
    local hash_result = lib.blake2_128_hash(account_id)
    if not hash_result.success then
        local error_msg = ffi.string(hash_result.error)
        lib.free_string(hash_result.error)
        return nil, "Failed to hash AccountId: " .. error_msg
    end
    
    local account_hash = ffi.string(hash_result.data)
    lib.free_string(hash_result.data)
    
    -- Construct the correct storage key for System.Account
    -- Format: blake2_128_concat("System") + blake2_128_concat("Account") + blake2_128_concat(AccountId32)
    local system_prefix = "0x26aa394eea5630e07c48ae0c9558cef7"  -- blake2_128_concat("System")
    local account_prefix = "b99d880ec681799c0cf30e8886371da9"   -- blake2_128_concat("Account")
    
    -- blake2_128_concat(AccountId) = blake2_128(AccountId) + AccountId
    local storage_key = system_prefix .. account_prefix .. account_hash .. account_id
    
    local result = self:state_getStorage(storage_key)
    if not result or type(result) ~= "string" or result == "0x" then
        -- Account doesn't exist or has no balance
        return {
            nonce = 0,
            consumers = 0,
            providers = 0,
            sufficients = 0,
            data = {
                free = 0,
                reserved = 0,
                frozen = 0,
                flags = 0
            }
        }
    end
    
    -- Decode the SCALE-encoded account info
    return self:decode_account_info(result)
end

-- Helper function to decode u32 little-endian
local function decode_u32_le(hex_str, offset)
    local bytes = hex_str:sub(offset + 1, offset + 8)
    if #bytes < 8 then return 0, offset end
    
    -- Convert little-endian hex to number
    local b1 = tonumber(bytes:sub(1, 2), 16)
    local b2 = tonumber(bytes:sub(3, 4), 16)
    local b3 = tonumber(bytes:sub(5, 6), 16)
    local b4 = tonumber(bytes:sub(7, 8), 16)
    
    local value = b1 + (b2 * 256) + (b3 * 65536) + (b4 * 16777216)
    return value, offset + 8
end

-- Helper function to decode u128 little-endian
local function decode_u128_le(hex_str, offset)
    local bytes = hex_str:sub(offset + 1, offset + 32)
    if #bytes < 32 then return 0, offset end
    
    -- For simplicity, just decode the first 8 bytes (u64) as most balances fit
    local low_bytes = bytes:sub(1, 16)
    local value = 0
    for i = 1, 16, 2 do
        local byte_val = tonumber(low_bytes:sub(i, i + 1), 16)
        value = value + (byte_val * (256 ^ ((i - 1) / 2)))
    end
    
    return value, offset + 32
end

-- Helper function to decode SCALE-encoded account info
function RPC:decode_account_info(hex_data)
    -- Remove 0x prefix if present
    local clean_data = hex_data:gsub("^0x", "")
    
    local offset = 0
    
    -- Decode AccountInfo structure:
    -- nonce: u32, consumers: u32, providers: u32, sufficients: u32
    -- data: { free: u128, reserved: u128, frozen: u128, flags: u128 }
    
    local nonce, new_offset = decode_u32_le(clean_data, offset)
    offset = new_offset
    
    local consumers, new_offset = decode_u32_le(clean_data, offset)
    offset = new_offset
    
    local providers, new_offset = decode_u32_le(clean_data, offset)
    offset = new_offset
    
    local sufficients, new_offset = decode_u32_le(clean_data, offset)
    offset = new_offset
    
    -- Decode AccountData
    local free_balance, new_offset = decode_u128_le(clean_data, offset)
    offset = new_offset
    
    local reserved_balance, new_offset = decode_u128_le(clean_data, offset)
    offset = new_offset
    
    local frozen_balance, new_offset = decode_u128_le(clean_data, offset)
    offset = new_offset
    
    local flags, new_offset = decode_u128_le(clean_data, offset)
    
    -- Get chain properties for dynamic token conversion
    local properties = self:get_chain_properties()
    
    return {
        nonce = nonce,
        consumers = consumers,
        providers = providers,
        sufficients = sufficients,
        data = {
            free = free_balance,
            reserved = reserved_balance,
            frozen = frozen_balance,
            flags = flags,
            -- Add convenience fields with dynamic token conversion
            free_tokens = free_balance / properties.divisor,
            reserved_tokens = reserved_balance / properties.divisor,
            frozen_tokens = frozen_balance / properties.divisor,
            token_symbol = properties.symbol,
            token_decimals = properties.decimals
        }
    }
end

-- Runtime metadata methods
function RPC:state_getMetadata(at_block)
    local params = at_block and {at_block} or {}
    return self:request("state_getMetadata", params)
end

-- Get call indices using the metadata module
function RPC:get_call_index(pallet_name, call_name)
    local runtime_version = self:state_getRuntimeVersion()
    return metadata.get_call_index(runtime_version.spec_name, pallet_name, call_name)
end

-- Convenience methods for common calls
function RPC:get_system_remark_call_index()
    local runtime_version = self:state_getRuntimeVersion()
    return metadata.get_system_remark_index(runtime_version.spec_name)
end

function RPC:get_balances_transfer_call_index()
    local runtime_version = self:state_getRuntimeVersion()
    return metadata.get_balances_transfer_index(runtime_version.spec_name)
end

return RPC 