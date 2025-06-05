local ffi = require("ffi")

-- Load the Rust library
local lib = ffi.load("./polkadot-ffi/target/release/libpolkadot_ffi.so")

-- Define C types
ffi.cdef[[
    typedef struct {
        bool success;
        char* data;
        char* error;
    } ExtrinsicResult;

    ExtrinsicResult sign_extrinsic(const char* seed_hex, const char* extrinsic_hex);
    void free_string(char* ptr);
    int encode_unsigned_extrinsic(
        uint8_t module_index,
        uint8_t function_index,
        const uint8_t* arguments_ptr,
        size_t arguments_len,
        uint8_t** out_ptr,
        size_t* out_len
    );
    int encode_signed_extrinsic(
        uint8_t module_index,
        uint8_t function_index,
        const uint8_t* arguments_ptr,
        size_t arguments_len,
        const uint8_t* signer_ptr,
        const uint8_t* signature_ptr,
        uint32_t nonce,
        uint64_t tip_low,
        uint64_t tip_high,
        bool era_mortal,
        uint8_t era_period,
        uint8_t era_phase,
        uint8_t** out_ptr,
        size_t* out_len
    );
    void free_encoded_extrinsic(uint8_t* ptr, size_t len);
]]

-- Export SDK modules
local sdk = {
    extrinsic = require("extrinsic"),
    signer = require("signer")
}

-- Add FFI functions to the SDK
sdk.ffi = {
    sign_extrinsic = function(seed_hex, extrinsic_hex)
        local result = lib.sign_extrinsic(seed_hex, extrinsic_hex)
        if result.success then
            local data = ffi.string(result.data)
            lib.free_string(result.data)
            return { success = true, data = data }
        else
            local error = ffi.string(result.error)
            lib.free_string(result.error)
            return { success = false, error = error }
        end
    end,
    
    encode_unsigned_extrinsic = function(module_index, function_index, arguments)
        local out_ptr = ffi.new("uint8_t*[1]")
        local out_len = ffi.new("size_t[1]")
        
        local result = lib.encode_unsigned_extrinsic(
            module_index,
            function_index,
            arguments,
            #arguments,
            out_ptr,
            out_len
        )
        
        if result == 0 then
            local data = ffi.string(out_ptr[0], out_len[0])
            lib.free_encoded_extrinsic(out_ptr[0], out_len[0])
            return { success = true, data = data }
        else
            return { success = false, error = "Failed to encode extrinsic" }
        end
    end,
    
    encode_signed_extrinsic = function(module_index, function_index, arguments, signer, signature, nonce, tip, era)
        local out_ptr = ffi.new("uint8_t*[1]")
        local out_len = ffi.new("size_t[1]")
        
        local tip_low = tip % (2^64)
        local tip_high = math.floor(tip / (2^64))
        
        local result = lib.encode_signed_extrinsic(
            module_index,
            function_index,
            arguments,
            #arguments,
            signer,
            signature,
            nonce,
            tip_low,
            tip_high,
            era.mortal,
            era.period,
            era.phase,
            out_ptr,
            out_len
        )
        
        if result == 0 then
            local data = ffi.string(out_ptr[0], out_len[0])
            lib.free_encoded_extrinsic(out_ptr[0], out_len[0])
            return { success = true, data = data }
        else
            return { success = false, error = "Failed to encode extrinsic" }
        end
    end
}

return sdk 