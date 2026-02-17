-- polkadot/metadata.lua
-- SCALE metadata parser for Substrate RuntimeMetadataV14
-- Schema-driven approach: parse everything correctly, keep what we need

local Scale = require("polkadot.scale")

local Metadata = {}

-- Helper to ensure integer offsets
local function ensure_int(n)
    -- Ensure number is a valid integer for string operations
    if n ~= math.floor(n) then
        error("Non-integer offset: " .. tostring(n))
    end
    return math.floor(n)
end

-- Primitive decoders (work with raw bytes, return value and new offset)
local function decode_string(data, offset)
    offset = ensure_int(offset)
    if offset > #data then
        error("decode_string: offset " .. offset .. " exceeds data length " .. #data)
    end
    local len, off = Scale.decode_compact(data, offset)
    len = ensure_int(len)
    off = ensure_int(off)
    assert(off >= 1 and off <= #data, "decode_string: decoded offset " .. off .. " out of bounds [1, " .. #data .. "]")
    assert(len >= 0, "decode_string: negative length " .. len)
    local end_pos = off + len - 1
    if end_pos > #data then
        error("decode_string: length " .. len .. " at offset " .. off .. " exceeds data bounds (end_pos=" .. end_pos .. ", data_len=" .. #data .. ")")
    end
    local str = data:sub(off, end_pos)
    return str, ensure_int(off + len)
end

local function decode_u8(data, offset)
    offset = ensure_int(offset)
    return string.byte(data, offset), offset + 1
end

local function decode_u32(data, offset)
    offset = ensure_int(offset)
    local val, off = Scale.decode_u32(data, offset)
    return val, ensure_int(off)
end

local function decode_option(data, offset, inner_decoder)
    offset = ensure_int(offset)
    local flag = string.byte(data, offset)
    if flag == 0 then
        return nil, offset + 1
    else
        local result, new_offset = inner_decoder(data, offset + 1)
        return result, ensure_int(new_offset)
    end
end

local function decode_vec(data, offset, inner_decoder)
    offset = ensure_int(offset)
    local len, off = Scale.decode_compact(data, offset)
    len = ensure_int(len)
    off = ensure_int(off)
    local items = {}
    for i = 1, len do
        items[i], off = inner_decoder(data, off)
        off = ensure_int(off)
    end
    return items, off
end

-- StorageEntryType decoder (enum)
local function decode_storage_entry_type(data, offset)
    local variant = string.byte(data, offset)
    offset = offset + 1
    
    if variant == 0 then
        -- Plain { value: u32 }
        local value, off = decode_u32(data, offset)
        return { type = "Plain", value = value }, off
    elseif variant == 1 then
        -- Map { hashers: Vec<u8>, key: u32, value: u32 }
        local hashers, hashers_off = decode_vec(data, offset, decode_u8)
        local key, key_off = decode_u32(data, hashers_off)
        local value, value_off = decode_u32(data, key_off)
        return { type = "Map", hashers = hashers, key = key, value = value }, value_off
    else
        error("Unknown StorageEntryType variant: " .. variant)
    end
end

-- StorageEntryMetadata decoder
local function decode_storage_entry(data, offset)
    local entry = {}
    
    -- name: String
    entry.name, offset = decode_string(data, offset)
    
    -- modifier: u8
    entry.modifier, offset = decode_u8(data, offset)
    
    -- type: StorageEntryType
    entry.storage_type, offset = decode_storage_entry_type(data, offset)
    
    -- default: Vec<u8> (this is actually Bytes, which is Vec<u8>)
    entry.default, offset = decode_vec(data, offset, decode_u8)
    
    -- docs: Vec<String>
    entry.docs, offset = decode_vec(data, offset, decode_string)
    
    return entry, offset
end

-- PalletStorageMetadata decoder
local function decode_pallet_storage(data, offset)
    local storage = {}
    
    -- prefix: String
    storage.prefix, offset = decode_string(data, offset)
    
    -- entries: Vec<StorageEntryMetadata>
    storage.entries, offset = decode_vec(data, offset, decode_storage_entry)
    
    return storage, offset
end

-- PalletConstantMetadata decoder
local function decode_constant(data, offset)
    local constant = {}
    
    -- name: String
    constant.name, offset = decode_string(data, offset)
    
    -- type: u32
    constant.type_id, offset = decode_u32(data, offset)
    
    -- value: Vec<u8>
    constant.value, offset = decode_vec(data, offset, decode_u8)
    
    -- docs: Vec<String>
    constant.docs, offset = decode_vec(data, offset, decode_string)
    
    return constant, offset
end

-- Si1TypeParameter decoder
local function decode_type_parameter(data, offset)
    local param = {}
    
    -- name: String
    param.name, offset = decode_string(data, offset)
    
    -- type: Option<u32>
    param.type_id, offset = decode_option(data, offset, decode_u32)
    
    return param, offset
end

-- Si1Field decoder
local function decode_field(data, offset)
    local field = {}
    
    -- name: Option<String>
    field.name, offset = decode_option(data, offset, decode_string)
    
    -- type: u32
    field.type_id, offset = decode_u32(data, offset)
    
    -- type_name: Option<String>
    field.type_name, offset = decode_option(data, offset, decode_string)
    
    -- docs: Vec<String>
    field.docs, offset = decode_vec(data, offset, decode_string)
    
    return field, offset
end

-- Si1Variant decoder
local function decode_variant(data, offset)
    local variant = {}
    
    -- name: String
    variant.name, offset = decode_string(data, offset)
    
    -- fields: Vec<Si1Field>
    variant.fields, offset = decode_vec(data, offset, decode_field)
    
    -- index: u8
    variant.index, offset = decode_u8(data, offset)
    
    -- docs: Vec<String>
    variant.docs, offset = decode_vec(data, offset, decode_string)
    
    return variant, offset
end

-- Si1TypeDef decoder (enum)
local function decode_type_def(data, offset)
    local variant = string.byte(data, offset)
    offset = offset + 1
    
    if variant == 0 then
        -- Composite { fields: Vec<Si1Field> }
        local fields, off = decode_vec(data, offset, decode_field)
        return { type = "Composite", fields = fields }, off
    elseif variant == 1 then
        -- Variant { variants: Vec<Si1Variant> }
        local variants, off = decode_vec(data, offset, decode_variant)
        return { type = "Variant", variants = variants }, off
    elseif variant == 2 then
        -- Sequence { type: u32 }
        local type_id, off = decode_u32(data, offset)
        return { type = "Sequence", type_id = type_id }, off
    elseif variant == 3 then
        -- Array { len: u32, type: u32 }
        local len, len_off = decode_u32(data, offset)
        local type_id, type_off = decode_u32(data, len_off)
        return { type = "Array", len = len, type_id = type_id }, type_off
    elseif variant == 4 then
        -- Tuple(Vec<u32>)
        local types, off = decode_vec(data, offset, decode_u32)
        return { type = "Tuple", types = types }, off
    elseif variant == 5 then
        -- Primitive(u8)
        local primitive, off = decode_u8(data, offset)
        return { type = "Primitive", value = primitive }, off
    elseif variant == 6 then
        -- Compact { type: u32 }
        local type_id, off = decode_u32(data, offset)
        return { type = "Compact", type_id = type_id }, off
    elseif variant == 7 then
        -- BitSequence { bit_store_type: u32, bit_order_type: u32 }
        local bit_store, store_off = decode_u32(data, offset)
        local bit_order, order_off = decode_u32(data, store_off)
        return { type = "BitSequence", bit_store_type = bit_store, bit_order_type = bit_order }, order_off
    else
        error("Unknown Si1TypeDef variant: " .. variant)
    end
end

-- Si1Type decoder (type registry entry)
local function decode_type(data, offset)
    local type_entry = {}
    
    -- path: Vec<String>
    type_entry.path, offset = decode_vec(data, offset, decode_string)
    
    -- type_params: Vec<Si1TypeParameter>
    type_entry.type_params, offset = decode_vec(data, offset, decode_type_parameter)
    
    -- type_def: Si1TypeDef
    type_entry.type_def, offset = decode_type_def(data, offset)
    
    -- docs: Vec<String>
    type_entry.docs, offset = decode_vec(data, offset, decode_string)
    
    return type_entry, offset
end

-- PalletMetadata decoder (correct field order)
local function decode_pallet(data, offset)
    local pallet = {}
    
    -- 1. name: String
    pallet.name, offset = decode_string(data, offset)
    
    -- 2. storage: Option<PalletStorageMetadata>
    pallet.storage, offset = decode_option(data, offset, decode_pallet_storage)
    
    -- 3. calls: Option<PalletCallMetadata> (just type_id: u32)
    pallet.calls_type_id, offset = decode_option(data, offset, decode_u32)
    
    -- 4. events: Option<PalletEventMetadata> (just type_id: u32)
    pallet.events_type_id, offset = decode_option(data, offset, decode_u32)
    
    -- 5. constants: Vec<PalletConstantMetadata>
    pallet.constants, offset = decode_vec(data, offset, decode_constant)
    
    -- 6. errors: Option<PalletErrorMetadata> (just type_id: u32)
    pallet.errors_type_id, offset = decode_option(data, offset, decode_u32)
    
    -- 7. index: u8
    pallet.index, offset = decode_u8(data, offset)
    
    -- 8. docs: Vec<String>
    pallet.docs, offset = decode_vec(data, offset, decode_string)
    
    return pallet, offset
end

-- Main parser
function Metadata.parse(hex_data)
    assert(type(hex_data) == "string", "parse requires a string")
    
    -- Remove 0x prefix if present
    hex_data = hex_data:gsub("^0x", "")
    
    -- Convert hex to bytes
    local data = (hex_data:gsub("..", function(cc) return string.char(tonumber(cc, 16)) end))
    
    local meta = {
        pallets = {},
        types = {},
        version = nil
    }
    
    local offset = 1
    
    -- Step 1: Check magic bytes "meta" (4 bytes)
    local magic = data:sub(offset, offset + 3)
    if magic ~= "meta" then
        error("Invalid metadata: missing magic bytes")
    end
    offset = offset + 4
    
    -- Step 2: Read version byte
    local version = string.byte(data, offset)
    meta.version = version
    offset = offset + 1
    
    if version ~= 14 and version ~= 15 then
        error("Unsupported metadata version: " .. version .. " (only V14/V15 supported)")
    end
    
    -- Step 3: Decode type registry Vec<Si1Type> (comes BEFORE pallets in V14)
    local types, types_offset = decode_vec(data, offset, decode_type)
    offset = types_offset
    
    -- Store types by index (0-indexed)
    for i, type_entry in ipairs(types) do
        meta.types[i - 1] = type_entry  -- 0-indexed
    end
    
    -- Step 4: Decode pallets Vec<PalletMetadata>
    local pallets, pallets_offset = decode_vec(data, offset, decode_pallet)
    offset = pallets_offset
    
    -- Store pallets by name
    for _, pallet in ipairs(pallets) do
        meta.pallets[pallet.name] = {
            index = pallet.index,
            calls_type_id = pallet.calls_type_id,
            events_type_id = pallet.events_type_id,
            errors_type_id = pallet.errors_type_id
        }
    end
    
    -- Step 5: Resolve call indices for each pallet
    for pallet_name, pallet_info in pairs(meta.pallets) do
        if pallet_info.calls_type_id then
            local type_entry = meta.types[pallet_info.calls_type_id]
            if type_entry and type_entry.type_def.type == "Variant" then
                -- Extract variant names and indices
                local calls = {}
                for _, variant in ipairs(type_entry.type_def.variants) do
                    calls[variant.name] = variant.index
                end
                pallet_info.calls = calls
            end
        end
    end
    
    return meta
end

-- Get call index for a pallet and call name
function Metadata.get_call_index(meta, pallet_name, call_name)
    local pallet = meta.pallets[pallet_name]
    if not pallet then
        return nil, nil, "Pallet not found: " .. pallet_name
    end
    
    if not pallet.calls then
        return nil, nil, "Pallet has no calls: " .. pallet_name
    end
    
    local call_index = pallet.calls[call_name]
    if not call_index then
        return nil, nil, "Call not found: " .. pallet_name .. "." .. call_name
    end
    
    return pallet.index, call_index
end

return Metadata
