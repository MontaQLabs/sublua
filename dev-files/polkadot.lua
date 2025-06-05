local ffi = require("ffi")

-- Load the Rust library
local polkadot = ffi.load("./polkadot-ffi/target/release/libpolkadot_ffi.so")

-- Define C types and functions
ffi.cdef[[
    typedef struct {
        bool success;
        char* data;
        char* error;
    } ExtrinsicResult;

    ExtrinsicResult sign_extrinsic(const char* seed_hex, const char* extrinsic_hex);
    void free_string(char* ptr);
]]

local function sign_extrinsic(seed_hex, extrinsic_hex)
    local result = polkadot.sign_extrinsic(seed_hex, extrinsic_hex)
    
    local response = {
        success = result.success,
        data = nil,
        error = nil
    }
    
    if result.success then
        if result.data ~= nil then
            response.data = ffi.string(result.data)
            polkadot.free_string(result.data)
        end
    else
        if result.error ~= nil then
            response.error = ffi.string(result.error)
            polkadot.free_string(result.error)
        end
    end
    
    return response
end

return {
    sign_extrinsic = sign_extrinsic
} 