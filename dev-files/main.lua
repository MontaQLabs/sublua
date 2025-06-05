local http = require("socket.http")
local json = require("dkjson")

local function polkadot_rpc(method, params)
    local request_body = json.encode({
        jsonrpc = "2.0",
        id = 1,
        method = method,
        params = params or {}
    })

    local response_body = {}

    local res, code, headers = http.request{
        url = "https://rpc.polkadot.io", -- Or use a parachain node
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = tostring(#request_body)
        },
        source = ltn12.source.string(request_body),
        sink = ltn12.sink.table(response_body)
    }

    if not res then
        error("Failed request: " .. tostring(code))
    end

    local response = table.concat(response_body)
    return json.decode(response)
end

-- Example usage
local result = polkadot_rpc("chain_getBlock")
print(json.encode(result, { indent = true }))
