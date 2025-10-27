-- sdk/core/extrinsic_builder.lua
-- High-level extrinsic builder with automatic call index resolution

local extrinsic = require("sdk.extrinsic")
local metadata = require("sdk.metadata")

local ExtrinsicBuilder = {}

-- Create a new extrinsic builder
function ExtrinsicBuilder.new(rpc)
    local self = setmetatable({}, {__index = ExtrinsicBuilder})
    self.rpc = rpc
    self.runtime_version = nil
    return self
end

-- Get runtime version (cached)
function ExtrinsicBuilder:get_runtime_version()
    if not self.runtime_version then
        self.runtime_version = self.rpc:state_getRuntimeVersion()
    end
    return self.runtime_version
end

-- Helper function to extract spec_name from runtime version
function ExtrinsicBuilder:get_spec_name()
    local runtime = self:get_runtime_version()
    return runtime.spec_name or runtime.specName or runtime.spec or "substrate"
end

-- Create System.remark_with_event extrinsic
function ExtrinsicBuilder:system_remark(message)
    local spec_name = self:get_spec_name()
    local call_index = metadata.get_system_remark_index(spec_name, self.rpc)
    
    -- Convert message to hex
    local message_hex = "0x"
    for i = 1, #message do
        message_hex = message_hex .. string.format("%02x", string.byte(message, i))
    end
    
    return extrinsic.new(call_index, message_hex)
end

-- Create Balances.transferAllowDeath extrinsic (what Polkadot.js Apps uses)
function ExtrinsicBuilder:balances_transfer(recipient_address, amount_units)
    local spec_name = self:get_spec_name()
    local call_index = metadata.get_balances_transfer_index(spec_name, self.rpc)
    
    -- Get recipient's AccountId32 (public key) from SS58 address
    local ffi_module = require('sdk.polkadot_ffi')
    local ffi = ffi_module.ffi
    local lib = ffi_module.lib
    
    local recipient_result = lib.decode_ss58_address(recipient_address)
    if not recipient_result.success then
        local error_msg = ffi.string(recipient_result.error)
        lib.free_string(recipient_result.error)
        error("Failed to decode recipient address: " .. error_msg)
    end
    
    local recipient_account_id = ffi.string(recipient_result.data)
    lib.free_string(recipient_result.data)
    
    -- Encode compact integer for balance (proper SCALE encoding)
    local function encode_compact_u128(value)
        if value < 64 then
            -- Single byte mode: value << 2
            return string.format("%02x", value * 4)
        elseif value < 16384 then
            -- Two byte mode: (value << 2) | 0x01
            local encoded = (value * 4) + 1
            return string.format("%02x%02x", encoded % 256, math.floor(encoded / 256))
        elseif value < 1073741824 then
            -- Four byte mode: (value << 2) | 0x02
            local encoded = (value * 4) + 2
            local bytes = {}
            for i = 1, 4 do
                table.insert(bytes, string.format("%02x", encoded % 256))
                encoded = math.floor(encoded / 256)
            end
            return table.concat(bytes)
        else
            -- Big integer mode - for large values
            local temp_value = value
            local byte_count = 0
            while temp_value > 0 do
                temp_value = math.floor(temp_value / 256)
                byte_count = byte_count + 1
            end
            
            -- Encode length in first byte: ((byte_count - 4) << 2) | 0x03
            local length_byte = ((byte_count - 4) * 4) + 3
            local result = string.format("%02x", length_byte)
            
            -- Encode the value in little-endian
            local temp_value = value
            for i = 1, byte_count do
                result = result .. string.format("%02x", temp_value % 256)
                temp_value = math.floor(temp_value / 256)
            end
            
            return result
        end
    end
    
    -- Build the transfer call data: MultiAddress::Id(0x00) + AccountId32 + Compact<Balance>
    local transfer_data = "0x00" .. recipient_account_id .. encode_compact_u128(amount_units)
    
    return extrinsic.new(call_index, transfer_data)
end

-- Create custom extrinsic with automatic call index resolution
function ExtrinsicBuilder:custom(pallet_name, call_name, call_data)
    local spec_name = self:get_spec_name()
    local call_index = metadata.get_call_index(spec_name, pallet_name, call_name, self.rpc)
    
    return extrinsic.new(call_index, call_data)
end

return ExtrinsicBuilder 