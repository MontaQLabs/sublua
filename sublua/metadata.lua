-- polkadot/metadata.lua
-- SCALE metadata parser for Substrate RuntimeMetadataV14
-- Schema-driven approach: parse everything correctly, keep what we need

local Scale = require("sublua.scale")

local Metadata = {}

-- Helper to ensure integer offsets
local function ensure_int(n)
    if n ~= math.floor(n) then
        error("Non-integer offset: " .. tostring(n))
    end
    return math.floor(n)
end

-- Primitive decoders
local function decode_string(data, offset)
    offset = ensure_int(offset)
    if offset > #data then
        error("decode_string: offset " .. offset .. " exceeds data length " .. #data)
    end
    local len, off = Scale.decode_compact(data, offset)
    len = ensure_int(len)
    off = ensure_int(off)
    assert(off >= 1 and off <= #data, "decode_string: decoded offset " .. off .. " out of bounds")
    local end_pos = off + len - 1
    if end_pos > #data then
        error("decode_string: length " .. len .. " exceeds data bounds")
    end
    return data:sub(off, end_pos), ensure_int(off + len)
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

local function decode_compact(data, offset)
    return Scale.decode_compact(data, offset)
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

-- StorageEntryType decoder
local function decode_storage_entry_type(data, offset)
    local variant = string.byte(data, offset)
    offset = offset + 1
    if variant == 0 then
        local value, off = decode_compact(data, offset)
        return { type = "Plain", value = value }, off
    elseif variant == 1 then
        local hashers, hashers_off = decode_vec(data, offset, decode_u8)
        local key, key_off = decode_compact(data, hashers_off)
        local value, value_off = decode_compact(data, key_off)
        return { type = "Map", hashers = hashers, key = key, value = value }, value_off
    else
        error("Unknown StorageEntryType variant: " .. variant)
    end
end

-- StorageEntryMetadata decoder
local function decode_storage_entry(data, offset)
    local entry = {}
    entry.name, offset = decode_string(data, offset)
    entry.modifier, offset = decode_u8(data, offset)
    entry.storage_type, offset = decode_storage_entry_type(data, offset)
    entry.default, offset = decode_vec(data, offset, decode_u8)
    entry.docs, offset = decode_vec(data, offset, decode_string)
    return entry, offset
end

-- PalletStorageMetadata decoder
local function decode_pallet_storage(data, offset)
    local storage = {}
    storage.prefix, offset = decode_string(data, offset)
    storage.entries, offset = decode_vec(data, offset, decode_storage_entry)
    return storage, offset
end

-- PalletConstantMetadata decoder
local function decode_constant(data, offset)
    local constant = {}
    constant.name, offset = decode_string(data, offset)
    constant.type_id, offset = decode_compact(data, offset)
    constant.value, offset = decode_vec(data, offset, decode_u8)
    constant.docs, offset = decode_vec(data, offset, decode_string)
    return constant, offset
end

-- Si1TypeParameter decoder
local function decode_type_parameter(data, offset)
    local param = {}
    param.name, offset = decode_string(data, offset)
    param.type_id, offset = decode_option(data, offset, decode_compact)
    return param, offset
end

-- Si1Field decoder
local function decode_field(data, offset)
    local field = {}
    field.name, offset = decode_option(data, offset, decode_string)
    field.type_id, offset = decode_compact(data, offset)
    field.type_name, offset = decode_option(data, offset, decode_string)
    field.docs, offset = decode_vec(data, offset, decode_string)
    return field, offset
end

-- Si1Variant decoder
local function decode_variant(data, offset)
    local variant = {}
    variant.name, offset = decode_string(data, offset)
    variant.fields, offset = decode_vec(data, offset, decode_field)
    variant.index, offset = decode_u8(data, offset)
    variant.docs, offset = decode_vec(data, offset, decode_string)
    return variant, offset
end

-- Si1TypeDef decoder
local function decode_type_def(data, offset)
    local variant = string.byte(data, offset)
    offset = offset + 1
    if variant == 0 then
        local fields, off = decode_vec(data, offset, decode_field)
        return { type = "Composite", fields = fields }, off
    elseif variant == 1 then
        local variants, off = decode_vec(data, offset, decode_variant)
        return { type = "Variant", variants = variants }, off
    elseif variant == 2 then
        local type_id, off = decode_compact(data, offset)
        return { type = "Sequence", type_id = type_id }, off
    elseif variant == 3 then
        local len, len_off = decode_u32(data, offset)
        local type_id, type_off = decode_compact(data, len_off)
        return { type = "Array", len = len, type_id = type_id }, type_off
    elseif variant == 4 then
        local types, off = decode_vec(data, offset, decode_compact)
        return { type = "Tuple", types = types }, off
    elseif variant == 5 then
        local primitive, off = decode_u8(data, offset)
        return { type = "Primitive", value = primitive }, off
    elseif variant == 6 then
        local type_id, off = decode_compact(data, offset)
        return { type = "Compact", type_id = type_id }, off
    elseif variant == 7 then
        local bit_store, store_off = decode_compact(data, offset)
        local bit_order, order_off = decode_compact(data, store_off)
        return { type = "BitSequence", bit_store_type = bit_store, bit_order_type = bit_order }, order_off
    else
        error("Unknown Si1TypeDef variant: " .. variant)
    end
end

-- Si1Type decoder (PortableType)
local function decode_type(data, offset)
    local type_entry = {}
    -- id: Compact<u32> (CRITICAL FIX)
    type_entry.id, offset = Scale.decode_compact(data, offset)
    type_entry.path, offset = decode_vec(data, offset, decode_string)
    type_entry.type_params, offset = decode_vec(data, offset, decode_type_parameter)
    type_entry.type_def, offset = decode_type_def(data, offset)
    type_entry.docs, offset = decode_vec(data, offset, decode_string)
    return type_entry, offset
end

-- PalletMetadata decoder (V14 — no docs field)
local function decode_pallet(data, offset)
    local pallet = {}
    pallet.name, offset = decode_string(data, offset)
    pallet.storage, offset = decode_option(data, offset, decode_pallet_storage)
    pallet.calls_type_id, offset = decode_option(data, offset, decode_compact)
    pallet.events_type_id, offset = decode_option(data, offset, decode_compact)
    pallet.constants, offset = decode_vec(data, offset, decode_constant)
    pallet.errors_type_id, offset = decode_option(data, offset, decode_compact)
    pallet.index, offset = decode_u8(data, offset)
    return pallet, offset
end

-- SignedExtensionMetadata decoder
local function decode_signed_extension(data, offset)
    local ext = {}
    ext.identifier, offset = decode_string(data, offset)
    ext.type_id, offset = decode_compact(data, offset)
    ext.additional_signed, offset = decode_compact(data, offset)
    return ext, offset
end

-- ExtrinsicMetadata decoder
local function decode_extrinsic_metadata(data, offset)
    local extrinsic = {}
    extrinsic.type_id, offset = decode_compact(data, offset)
    extrinsic.version, offset = decode_u8(data, offset)
    extrinsic.signed_extensions, offset = decode_vec(data, offset, decode_signed_extension)
    return extrinsic, offset
end

-- Main parser
function Metadata.parse(hex_data)
    assert(type(hex_data) == "string", "parse requires a string")
    hex_data = hex_data:gsub("^0x", "")
    local data = (hex_data:gsub("..", function(cc) return string.char(tonumber(cc, 16)) end))
    
    local meta = { pallets = {}, types = {}, version = nil }
    local offset = 1
    
    local magic = data:sub(offset, offset + 3)
    if magic ~= "meta" then error("Invalid metadata: missing magic bytes") end
    offset = offset + 4
    
    local version = string.byte(data, offset)
    meta.version = version
    offset = offset + 1
    
    if version ~= 14 and version ~= 15 then error("Unsupported metadata version") end
    
    local types, types_offset = decode_vec(data, offset, decode_type)
    offset = types_offset
    for i, type_entry in ipairs(types) do meta.types[i - 1] = type_entry end
    
    local pallets, pallets_offset = decode_vec(data, offset, decode_pallet)
    offset = pallets_offset
    for _, pallet in ipairs(pallets) do
        meta.pallets[pallet.name] = {
            index = pallet.index,
            calls_type_id = pallet.calls_type_id,
            events_type_id = pallet.events_type_id,
            errors_type_id = pallet.errors_type_id
        }
    end
    
    local extrinsic, ext_offset = decode_extrinsic_metadata(data, offset)
    meta.extrinsic = extrinsic
    offset = ext_offset
    
    local runtime_type, rt_offset = decode_compact(data, offset)
    meta.runtime_type = runtime_type
    offset = rt_offset
    
    -- Resolve calls
    for pallet_name, pallet_info in pairs(meta.pallets) do
        if pallet_info.calls_type_id then
            local type_entry = meta.types[pallet_info.calls_type_id]
            if type_entry and type_entry.type_def.type == "Variant" then
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

function Metadata.get_call_index(meta, pallet_name, call_name)
    local pallet = meta.pallets[pallet_name]
    if not pallet then return nil, nil, "Pallet not found" end
    if not pallet.calls then return nil, nil, "Pallet has no calls" end
    local call_index = pallet.calls[call_name]
    if not call_index then return nil, nil, "Call not found" end
    return pallet.index, call_index
end

return Metadata
