-- sdk/ffi.lua
-- Centralised FFI binding for the Polkadot SDK
-- Tries several strategies to locate and load the compiled Rust shared object.

local ffi = require("ffi")

-- C definitions shared by multiple modules
ffi.cdef[[
    typedef struct {
        bool success;
        char* data;   // allocated C string (hex encoded)
        char* error;  // allocated C string on failure
    } ExtrinsicResult;

    /* Signing */
    ExtrinsicResult sign_extrinsic(const char* seed_hex, const char* extrinsic_hex);
    ExtrinsicResult derive_sr25519_public_key(const char* seed_hex);
    ExtrinsicResult compute_ss58_address(const char* public_key_hex, uint16_t network_prefix);
    ExtrinsicResult decode_ss58_address(const char* ss58_address);
    ExtrinsicResult derive_sr25519_from_mnemonic(const char* mnemonic);
    ExtrinsicResult blake2_128_hash(const char* data);
    void            free_string(char* ptr);

    /* SCALE / Extrinsics */
    int encode_unsigned_extrinsic(
        uint8_t module_index,
        uint8_t function_index,
        const uint8_t* arguments_ptr,
        size_t arguments_len,
        uint8_t** out_ptr,
        size_t* out_len);

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
        size_t* out_len);

    void free_encoded_extrinsic(uint8_t* ptr, size_t len);
]]

-- Helper to attempt loading the library from multiple candidate paths
local function try_load(paths)
    for _, p in ipairs(paths) do
        local ok, lib = pcall(ffi.load, p)
        if ok then return lib end
    end
    return nil, "Unable to locate libpolkadot_ffi.so – tried: " .. table.concat(paths, ", ")
end

-- Form candidate paths (relative to this file as well as CWD)
local this_dir = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"
local candidates = {
    "polkadot_ffi",                       -- in LD_LIBRARY_PATH / system path
    "libpolkadot_ffi.so",                 -- likewise
    this_dir .. "../polkadot-ffi/target/release/libpolkadot_ffi.so",
    this_dir .. "../../polkadot-ffi/target/release/libpolkadot_ffi.so", -- when this file ends up in sdk/core/
}

local lib, err = try_load(candidates)
if not lib then
    error(err)
end

return {
    ffi = ffi,
    lib = lib,
} 