-- sdk/core/util.lua

local M = {}

-- Convert hex string (with or without 0x) to a table of bytes
function M.hex_to_bytes(hex)
    hex = hex:gsub("^0x", "")
    local bytes = {}
    for i = 1, #hex, 2 do
        bytes[#bytes+1] = tonumber(hex:sub(i, i+1), 16)
    end
    return bytes
end

-- Convert table/array of bytes to hex string (no 0x prefix)
function M.bytes_to_hex(bytes)
    local t = {}
    for i = 1, #bytes do
        t[#t+1] = string.format("%02x", bytes[i])
    end
    return table.concat(t)
end

return M 