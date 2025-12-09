-- sublua/websocket.lua
-- WebSocket connection management for real-time blockchain interactions

local ffi_mod = require("sublua.polkadot_ffi")

local WebSocket = {}

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

--- Connect to a WebSocket endpoint and add to connection pool
-- Connections are automatically managed with heartbeat monitoring and reconnection
-- @param rpc_url string - WebSocket RPC endpoint (e.g., "wss://westend-rpc.polkadot.io")
-- @return table, string - Connection info or nil, error
--
-- Example:
--   local info, err = ws.connect("wss://westend-rpc.polkadot.io")
--   if info then
--       print("Connected:", info.url)
--   end
function WebSocket.connect(rpc_url)
    local result = get_lib().ws_connect(rpc_url)
    return parse_ffi_result(result)
end

--- Get connection statistics
-- @param rpc_url string - WebSocket RPC endpoint
-- @return table, string - Stats {uptime_seconds, reconnect_count, total_messages} or nil, error
--
-- Example:
--   local stats, err = ws.get_stats("wss://westend-rpc.polkadot.io")
--   print("Uptime:", stats.uptime_seconds, "seconds")
--   print("Reconnections:", stats.reconnect_count)
function WebSocket.get_stats(rpc_url)
    local result = get_lib().ws_get_stats(rpc_url)
    return parse_ffi_result(result)
end

--- Manually trigger reconnection
-- Usually not needed as connections auto-reconnect, but useful for testing
-- @param rpc_url string - WebSocket RPC endpoint
-- @return string, string - Success message or nil, error
function WebSocket.reconnect(rpc_url)
    local result = get_lib().ws_reconnect(rpc_url)
    if not result.success then
        local error_msg = ffi_mod.ffi.string(result.error)
        get_lib().free_string(result.error)
        return nil, error_msg
    end
    
    local msg = ffi_mod.ffi.string(result.data)
    get_lib().free_string(result.data)
    return msg, nil
end

--- Disconnect from WebSocket endpoint and remove from pool
-- @param rpc_url string - WebSocket RPC endpoint
-- @return string, string - Success message or nil, error
function WebSocket.disconnect(rpc_url)
    local result = get_lib().ws_disconnect(rpc_url)
    if not result.success then
        local error_msg = ffi_mod.ffi.string(result.error)
        get_lib().free_string(result.error)
        return nil, error_msg
    end
    
    local msg = ffi_mod.ffi.string(result.data)
    get_lib().free_string(result.data)
    return msg, nil
end

--- List all active WebSocket connections
-- @return table, string - {connections = [...], count = N} or nil, error
function WebSocket.list_connections()
    local result = get_lib().ws_list_connections()
    return parse_ffi_result(result)
end

--- Query balance using WebSocket connection pool
-- This automatically uses connection pooling with automatic reconnection
-- @param rpc_url string - WebSocket RPC endpoint
-- @param address string - SS58 address to query
-- @return string, string - Balance data or nil, error
--
-- Example:
--   local balance, err = ws.query_balance(
--       "wss://westend-rpc.polkadot.io",
--       "5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY"
--   )
function WebSocket.query_balance(rpc_url, address)
    local result = get_lib().ws_query_balance(rpc_url, address)
    if not result.success then
        local error_msg = ffi_mod.ffi.string(result.error)
        get_lib().free_string(result.error)
        return nil, error_msg
    end
    
    local data = ffi_mod.ffi.string(result.data)
    get_lib().free_string(result.data)
    return data, nil
end

--- Check if WebSocket support is available
-- @return boolean
function WebSocket.is_available()
    -- Check if FFI has WebSocket functions
    local lib = get_lib()
    return lib.ws_connect ~= nil
end

--- Get connection pool size
-- @return number - Number of active connections
function WebSocket.connection_count()
    local info, err = WebSocket.list_connections()
    if not info then
        return 0
    end
    return info.count or 0
end

--- Disconnect all connections
-- Useful for cleanup
-- @return number - Number of connections disconnected
function WebSocket.disconnect_all()
    local info, err = WebSocket.list_connections()
    if not info or not info.connections then
        return 0
    end
    
    local count = 0
    for _, url in ipairs(info.connections) do
        local success, _ = WebSocket.disconnect(url)
        if success then
            count = count + 1
        end
    end
    
    return count
end

return WebSocket

