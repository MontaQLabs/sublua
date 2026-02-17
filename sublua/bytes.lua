-- polkadot/bytes.lua
-- Helper functions for working with raw byte strings (u128 representation)
-- Pure Lua implementation for big number operations on 16-byte strings

local Bytes = {}

-- Convert decimal string to 16-byte little-endian u128
function Bytes.decimal_to_bytes(decimal_str)
    assert(type(decimal_str) == "string", "decimal_to_bytes requires a string")
    
    -- Remove leading/trailing whitespace
    decimal_str = decimal_str:match("^%s*(.-)%s*$")
    assert(decimal_str:match("^%d+$"), "decimal_to_bytes requires a numeric string")
    
    -- Initialize result as 16 zero bytes (little-endian)
    local bytes = {}
    for i = 1, 16 do bytes[i] = 0 end
    
    -- Grade-school multiplication: multiply by 10 for each digit
    for digit in decimal_str:gmatch(".") do
        local d = tonumber(digit)
        local carry = 0
        
        -- Multiply each byte by 10 and add carry (process from least significant to most)
        for i = 1, 16 do
            local product = bytes[i] * 10 + carry
            bytes[i] = product % 256
            carry = math.floor(product / 256)
        end
        
        -- Add the current digit
        carry = d
        for i = 1, 16 do
            local sum = bytes[i] + carry
            bytes[i] = sum % 256
            carry = math.floor(sum / 256)
            if carry == 0 then break end
        end
        
        assert(carry == 0, "decimal_to_bytes: value exceeds u128 range")
    end
    
    -- Convert to little-endian string
    local result = ""
    for i = 1, 16 do
        result = result .. string.char(bytes[i])
    end
    
    return result
end

-- Convert 16-byte little-endian u128 to decimal string
function Bytes.bytes_to_decimal(bytes)
    assert(type(bytes) == "string", "bytes_to_decimal requires a string")
    assert(#bytes == 16, "bytes_to_decimal requires exactly 16 bytes")
    
    -- Convert bytes to array of numbers
    local digits = {}
    for i = 1, 16 do
        digits[i] = string.byte(bytes, i)
    end
    
    -- Grade-school division: repeatedly divide by 10
    local result_digits = {}
    local has_nonzero = true
    
    while has_nonzero do
        local remainder = 0
        has_nonzero = false
        
        -- Divide from most significant byte to least
        for i = 16, 1, -1 do
            local value = remainder * 256 + digits[i]
            digits[i] = math.floor(value / 10)
            remainder = value % 10
            
            if digits[i] ~= 0 then
                has_nonzero = true
            end
        end
        
        if has_nonzero or remainder ~= 0 then
            table.insert(result_digits, 1, tostring(remainder))
        end
    end
    
    if #result_digits == 0 then
        return "0"
    end
    
    return table.concat(result_digits)
end

-- Format balance bytes with decimal point
function Bytes.format_balance(bytes, decimals, symbol)
    symbol = symbol or ""
    local decimal_str = Bytes.bytes_to_decimal(bytes)
    
    -- Pad with zeros if needed
    if #decimal_str <= decimals then
        decimal_str = string.rep("0", decimals - #decimal_str + 1) .. decimal_str
    end
    
    -- Insert decimal point
    local integer_part = decimal_str:sub(1, -decimals - 1)
    local fractional_part = decimal_str:sub(-decimals)
    
    -- Remove trailing zeros from fractional part
    fractional_part = fractional_part:match("^(.-)0*$") or ""
    
    if fractional_part == "" then
        return integer_part .. (symbol ~= "" and " " .. symbol or "")
    else
        return integer_part .. "." .. fractional_part .. (symbol ~= "" and " " .. symbol or "")
    end
end

-- Compare two 16-byte strings (returns -1, 0, or 1)
function Bytes.compare(a, b)
    assert(type(a) == "string" and type(b) == "string", "compare requires two strings")
    assert(#a == 16 and #b == 16, "compare requires 16-byte strings")
    
    -- Compare from most significant byte to least
    for i = 16, 1, -1 do
        local byte_a = string.byte(a, i)
        local byte_b = string.byte(b, i)
        
        if byte_a < byte_b then
            return -1
        elseif byte_a > byte_b then
            return 1
        end
    end
    
    return 0
end

-- Add two 16-byte strings (returns 16-byte string)
function Bytes.add(a, b)
    assert(type(a) == "string" and type(b) == "string", "add requires two strings")
    assert(#a == 16 and #b == 16, "add requires 16-byte strings")
    
    local result = {}
    local carry = 0
    
    for i = 1, 16 do
        local sum = string.byte(a, i) + string.byte(b, i) + carry
        result[i] = sum % 256
        carry = math.floor(sum / 256)
    end
    
    assert(carry == 0, "add: result exceeds u128 range (overflow)")
    
    local result_str = ""
    for i = 1, 16 do
        result_str = result_str .. string.char(result[i])
    end
    
    return result_str
end

-- Subtract two 16-byte strings (returns 16-byte string)
function Bytes.subtract(a, b)
    assert(type(a) == "string" and type(b) == "string", "subtract requires two strings")
    assert(#a == 16 and #b == 16, "subtract requires 16-byte strings")
    
    local result = {}
    local borrow = 0
    
    for i = 1, 16 do
        local diff = string.byte(a, i) - string.byte(b, i) - borrow
        if diff < 0 then
            diff = diff + 256
            borrow = 1
        else
            borrow = 0
        end
        result[i] = diff
    end
    
    assert(borrow == 0, "subtract: result would be negative (underflow)")
    
    local result_str = ""
    for i = 1, 16 do
        result_str = result_str .. string.char(result[i])
    end
    
    return result_str
end

-- Convert Lua number to bytes (only if within safe range)
function Bytes.number_to_bytes(n, decimals)
    assert(type(n) == "number", "number_to_bytes requires a number")
    assert(n >= 0, "number_to_bytes requires non-negative number")
    
    -- For values within safe range, convert via decimal string
    if n <= 2^53 then
        -- Multiply by 10^decimals to get planck units
        local planck = n * (10 ^ (decimals or 0))
        local planck_str = string.format("%.0f", planck)
        return Bytes.decimal_to_bytes(planck_str)
    else
        error("number_to_bytes: value exceeds Lua number precision (2^53)")
    end
end

return Bytes
