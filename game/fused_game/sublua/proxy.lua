-- sublua/proxy.lua
-- Proxy account management for Substrate chains

local ffi_mod = require("sublua.polkadot_ffi")

local Proxy = {}

-- Proxy types available in Substrate
Proxy.TYPES = {
    ANY = "Any",              -- Allow all calls
    NON_TRANSFER = "NonTransfer",  -- Disallow balance transfers
    GOVERNANCE = "Governance",     -- Only governance calls
    STAKING = "Staking",          -- Only staking calls
    IDENTITY_JUDGEMENT = "IdentityJudgement",  -- Only identity judgement
    CANCEL_PROXY = "CancelProxy",  -- Only cancel proxy calls
}

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

--- Add a proxy for your account
-- @param rpc_url string - RPC endpoint URL
-- @param mnemonic string - Your account's mnemonic phrase
-- @param delegate string - SS58 address of the delegate (proxy) account
-- @param proxy_type string - Type of proxy (use Proxy.TYPES constants)
-- @param delay number - Block delay before proxy can execute (0 for no delay)
-- @return string, string - Transaction hash or nil, error
--
-- Example:
--   local tx_hash, err = proxy.add(
--       "wss://westend-rpc.polkadot.io",
--       "your mnemonic here",
--       "5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty",
--       proxy.TYPES.ANY,
--       0
--   )
function Proxy.add(rpc_url, mnemonic, delegate, proxy_type, delay)
    delay = delay or 0
    proxy_type = proxy_type or Proxy.TYPES.ANY
    
    local result = get_lib().add_proxy(rpc_url, mnemonic, delegate, proxy_type, delay)
    return parse_transfer_result(result)
end

--- Remove a proxy from your account
-- @param rpc_url string - RPC endpoint URL
-- @param mnemonic string - Your account's mnemonic phrase
-- @param delegate string - SS58 address of the delegate (proxy) account to remove
-- @param proxy_type string - Type of proxy (must match the type when it was added)
-- @param delay number - Block delay (must match the delay when it was added)
-- @return string, string - Transaction hash or nil, error
function Proxy.remove(rpc_url, mnemonic, delegate, proxy_type, delay)
    delay = delay or 0
    proxy_type = proxy_type or Proxy.TYPES.ANY
    
    local result = get_lib().remove_proxy(rpc_url, mnemonic, delegate, proxy_type, delay)
    return parse_transfer_result(result)
end

--- Execute a call through a proxy
-- Currently supports: Balances::transfer_keep_alive
-- @param rpc_url string - RPC endpoint URL
-- @param proxy_mnemonic string - The proxy account's mnemonic
-- @param real_account string - SS58 address of the real account you're acting on behalf of
-- @param pallet_name string - Pallet name (e.g., "Balances")
-- @param call_name string - Call name (e.g., "transfer_keep_alive")
-- @param call_args table - Call arguments as Lua table
-- @return string, string - Transaction hash or nil, error
--
-- Example:
--   local tx_hash, err = proxy.call(
--       "wss://westend-rpc.polkadot.io",
--       "proxy account mnemonic",
--       "5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY",
--       "Balances",
--       "transfer_keep_alive",
--       {dest = "5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty", amount = 1000000000000}
--   )
function Proxy.call(rpc_url, proxy_mnemonic, real_account, pallet_name, call_name, call_args)
    -- Convert call_args table to JSON
    local json_parts = {}
    for key, value in pairs(call_args) do
        if type(value) == "string" then
            table.insert(json_parts, '"' .. key .. '":"' .. value .. '"')
        else
            table.insert(json_parts, '"' .. key .. '":' .. tostring(value))
        end
    end
    local args_json = "{" .. table.concat(json_parts, ",") .. "}"
    
    local result = get_lib().proxy_call(
        rpc_url,
        proxy_mnemonic,
        real_account,
        pallet_name,
        call_name,
        args_json
    )
    return parse_transfer_result(result)
end

--- Transfer tokens through a proxy
-- Convenience wrapper for executing a balance transfer through a proxy
-- @param rpc_url string - RPC endpoint URL
-- @param proxy_mnemonic string - The proxy account's mnemonic
-- @param real_account string - SS58 address of the real account
-- @param destination string - SS58 address of the recipient
-- @param amount number - Amount to transfer (in smallest unit, e.g., plancks)
-- @return string, string - Transaction hash or nil, error
function Proxy.transfer(rpc_url, proxy_mnemonic, real_account, destination, amount)
    return Proxy.call(
        rpc_url,
        proxy_mnemonic,
        real_account,
        "Balances",
        "transfer_keep_alive",
        {dest = destination, amount = amount}
    )
end

--- Query all proxies for an account
-- @param rpc_url string - RPC endpoint URL
-- @param account string - SS58 address to query proxies for
-- @return string, string - Proxies data (as raw string) or nil, error
function Proxy.query(rpc_url, account)
    local result = get_lib().query_proxies(rpc_url, account)
    return parse_query_result(result)
end

--- Validate proxy parameters
-- @param proxy_type string - Proxy type to validate
-- @return boolean, string - true if valid, or false and error message
function Proxy.validate_type(proxy_type)
    for _, valid_type in pairs(Proxy.TYPES) do
        if proxy_type == valid_type then
            return true, nil
        end
    end
    
    local valid_types = {}
    for _, t in pairs(Proxy.TYPES) do
        table.insert(valid_types, t)
    end
    
    return false, "Invalid proxy type. Must be one of: " .. table.concat(valid_types, ", ")
end

return Proxy

