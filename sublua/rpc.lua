local http = require("socket.http")
local ltn12 = require("ltn12")
local json = require("cjson")
local crypto = require("polkadot_crypto") -- Found in package.cpath
local Metadata = require("sublua.metadata")

local RPC = {}
RPC.__index = RPC

-- Helper: Byte string to Hex
local function to_hex(str)
    return (str:gsub(".", function(c) return string.format("%02x", string.byte(c)) end))
end

-- Helper: Hex to Byte string
local function from_hex(hex)
    hex = hex:gsub("^0x", "")
    return (hex:gsub("..", function(cc) return string.char(tonumber(cc, 16)) end))
end

function RPC.new(url)
    if url:match("^wss://") then
        url = url:gsub("^wss://", "https://")
    elseif url:match("^ws://") then
        url = url:gsub("^ws://", "http://")
    end
    
    return setmetatable({
        url = url,
        id = 1,
        chain_properties = nil,
        metadata = nil  -- Cached metadata
    }, RPC)
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
        redirect = true
    }
    
    if not success then error("HTTP request failed: " .. tostring(status_code)) end
    if status_code ~= 200 then error("HTTP error code " .. status_code) end
    
    local response = json.decode(table.concat(response_body))
    if response.error then error("RPC error: " .. response.error.message) end
    
    return response.result
end

-- Chain Properties
function RPC:get_chain_properties()
    if self.chain_properties then return self.chain_properties end
    
    local success, props = pcall(function() return self:request("system_properties") end)
    if success and props then
        local decimals = type(props.tokenDecimals) == "table" and props.tokenDecimals[1] or props.tokenDecimals or 12
        local symbol = type(props.tokenSymbol) == "table" and props.tokenSymbol[1] or props.tokenSymbol or "UNIT"
        self.chain_properties = {
            decimals = decimals,
            symbol = symbol,
            divisor = 10 ^ decimals
        }
    else
        self.chain_properties = {decimals = 12, symbol = "UNIT", divisor = 10^12}
    end
    return self.chain_properties
end

-- Basic RPC wrappers
function RPC:chain_getBlockHash(num) return self:request("chain_getBlockHash", num and {num} or {}) end
function RPC:chain_getFinalizedHead() return self:request("chain_getFinalizedHead") end
function RPC:state_getRuntimeVersion(at) return self:request("state_getRuntimeVersion", at and {at} or {}) end
function RPC:state_getMetadata(at) return self:request("state_getMetadata", at and {at} or {}) end
function RPC:payment_queryInfo(extrinsic, at) 
    local p = {extrinsic}; if at then table.insert(p, at) end
    return self:request("payment_queryInfo", p)
end
function RPC:state_getStorage(key, at) 
    local p = {key}; if at then table.insert(p, at) end
    return self:request("state_getStorage", p)
end
function RPC:author_submitExtrinsic(hex) return self:request("author_submitExtrinsic", {hex}) end

-- Metadata
function RPC:state_getMetadata(at) 
    local p = at and {at} or {}
    return self:request("state_getMetadata", p)
end

-- Get and parse metadata (cached)
function RPC:get_metadata()
    if self.metadata then
        return self.metadata
    end
    
    print("Fetching runtime metadata...")
    local metadata_hex = self:state_getMetadata()
    self.metadata = Metadata.parse(metadata_hex)
    print("Metadata parsed: " .. self.metadata.version .. " pallets found")
    return self.metadata
end

-- Get call index for a pallet and call name
function RPC:get_call_index(pallet_name, call_name)
    local meta = self:get_metadata()
    local pallet_idx, call_idx, err = Metadata.get_call_index(meta, pallet_name, call_name)
    if err then
        error(err)
    end
    return pallet_idx, call_idx
end

-- Account Info
function RPC:system_account(address)
    local pubkey, ver = crypto.ss58_decode(address)
    if not pubkey then error("Invalid SS58 address") end

    -- Storage Key for System.Account:
    -- Twox128("System") + Twox128("Account") + Blake2_128(Pubkey) + Pubkey
    local k1 = to_hex(crypto.twox128("System"))
    local k2 = to_hex(crypto.twox128("Account"))
    local k3 = to_hex(crypto.blake2b(pubkey, 16)) -- Blake2_128
    local k4 = to_hex(pubkey)
    
    local key = "0x" .. k1 .. k2 .. k3 .. k4
    local data = self:state_getStorage(key)
    
    if not data or data == "null" or data == "0x" or data == json.null then
        local props = self:get_chain_properties()
        return {
            nonce = 0,
            data = {
                free = 0,
                reserved = 0, 
                free_formated = "0 " .. props.symbol
            }
        }
    end
    
    if type(data) ~= "string" then
       error("Unexpected data type from storage query: " .. type(data))
    end
    
    return self:decode_account_info(data)
end

-- Minimal SCALE decoder for AccountInfo
function RPC:decode_account_info(hex)
    hex = hex:gsub("^0x", "")
    local function decode_u32(h, off)
        local b = h:sub(off+1, off+8)
        local n = tonumber(b:sub(7,8)..b:sub(5,6)..b:sub(3,4)..b:sub(1,2), 16)
        return n, off+8
    end
    -- u128 decode (simplified to double)
    local function decode_u128(h, off)
        -- We only take lower 64 bits for Lua double safety
        local b = h:sub(off+1, off+16)
        -- little endian
        local n = 0
        for i=0,7 do
             local byte = tonumber(b:sub(i*2+1, i*2+2), 16)
             n = n + byte * (256^i)
        end
        return n, off+32 -- skip full 32 hex chars (16 bytes)
    end
    
    local off = 0
    local nonce; nonce, off = decode_u32(hex, off)
    local consumers; consumers, off = decode_u32(hex, off)
    local providers; providers, off = decode_u32(hex, off)
    local sufficients; sufficients, off = decode_u32(hex, off)
    
    local free; free, off = decode_u128(hex, off)
    local reserved; reserved, off = decode_u128(hex, off)
    -- ... ignore rest for now
    
    local props = self:get_chain_properties()
    
    return {
        nonce = nonce,
        data = {
            free = free,
            reserved = reserved,
            free_formated = free / props.divisor .. " " .. props.symbol
        }
    }
end

return RPC
