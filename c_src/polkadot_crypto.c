/*
  Minimal Pure C Crypto Module for Polkadot/Substrate
  Uses Monocypher (Ed25519, Blake2b) and xxHash (Twox)
*/

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>

#include "vendor/monocypher.h"
#include "vendor/tweetnacl.h"
#define XXH_INLINE_ALL
#include "vendor/xxhash.h"

/* From tweetnacl.c — seed-based Ed25519 keypair */
extern void tweetnacl_keypair_from_seed(unsigned char *pk, unsigned char *sk, const unsigned char *seed);

/* --- Helper Macros --- */
#if LUA_VERSION_NUM < 502
#define luaL_newlib(L,l) (lua_newtable(L), luaL_register(L,NULL,l))
#endif

/* --- Blake2b --- */
static int l_blake2b(lua_State *L) {
    size_t len;
    const char *data = luaL_checklstring(L, 1, &len);
    int output_len = luaL_optinteger(L, 2, 32); /* Default 32 bytes */
    
    if (output_len < 1 || output_len > 64) {
        return luaL_error(L, "Output length must be between 1 and 64");
    }
    
    uint8_t hash[64];
    crypto_blake2b(hash, output_len, (const uint8_t*)data, len);
    
    lua_pushlstring(L, (const char*)hash, output_len);
    return 1;
}

/* --- Twox (xxHash) --- */
static int l_twox128(lua_State *L) {
    size_t len;
    const char *data = luaL_checklstring(L, 1, &len);
    
    // Substrate twox_128 is NOT XXH128.
    // It is XXH64(seed=0) concatenated with XXH64(seed=1).
    
    uint64_t h0 = XXH64(data, len, 0);
    uint64_t h1 = XXH64(data, len, 1);
    
    uint8_t out[16];
    // Little endian output for each 64-bit hash
    for(int i=0; i<8; i++) out[i] = (h0 >> (i*8)) & 0xFF;
    for(int i=0; i<8; i++) out[8+i] = (h1 >> (i*8)) & 0xFF;
    
    lua_pushlstring(L, (const char*)out, 16);
    return 1;
}

static int l_twox64(lua_State *L) {
    size_t len;
    const char *data = luaL_checklstring(L, 1, &len);
    
    uint64_t hash = XXH64(data, len, 0);
    
    uint8_t out[8];
    for(int i=0; i<8; i++) out[i] = (hash >> (i*8)) & 0xFF;
    
    lua_pushlstring(L, (const char*)out, 8);
    return 1;
}

/* --- Ed25519 (TweetNaCl — standard SHA-512, RFC 8032) --- */

static int l_ed25519_keypair_from_seed(lua_State *L) {
    size_t seed_len;
    const char *seed = luaL_checklstring(L, 1, &seed_len);
    
    if (seed_len != 32) {
        return luaL_error(L, "Seed must be 32 bytes");
    }
    
    unsigned char pub[32];
    unsigned char sk[64];
    tweetnacl_keypair_from_seed(pub, sk, (const unsigned char*)seed);
    
    memset(sk, 0, 64);
    lua_pushlstring(L, (const char*)pub, 32);
    return 1;
}

static int l_ed25519_sign(lua_State *L) {
    size_t seed_len, msg_len;
    const char *seed = luaL_checklstring(L, 1, &seed_len);
    const char *msg = luaL_checklstring(L, 2, &msg_len);
    
    if (seed_len != 32) return luaL_error(L, "Seed must be 32 bytes");
    
    /* Build TweetNaCl secret key: seed(32) || pubkey(32) */
    unsigned char pub[32];
    unsigned char sk[64];
    tweetnacl_keypair_from_seed(pub, sk, (const unsigned char*)seed);
    
    /* crypto_sign outputs signature(64) || message */
    unsigned long long smlen;
    unsigned char *sm = (unsigned char*)malloc(msg_len + 64);
    if (!sm) return luaL_error(L, "out of memory");
    
    crypto_sign(sm, &smlen, (const unsigned char*)msg, msg_len, sk);
    
    /* First 64 bytes of sm are the signature */
    lua_pushlstring(L, (const char*)sm, 64);
    
    free(sm);
    memset(sk, 0, 64);
    return 1;
}

static int l_ed25519_verify(lua_State *L) {
    size_t pub_len, msg_len, sig_len;
    const char *pub = luaL_checklstring(L, 1, &pub_len);
    const char *msg = luaL_checklstring(L, 2, &msg_len);
    const char *sig = luaL_checklstring(L, 3, &sig_len);
    
    if (pub_len != 32) return luaL_error(L, "Public key must be 32 bytes");
    if (sig_len != 64) return luaL_error(L, "Signature must be 64 bytes");
    
    /* crypto_sign_open expects sm = signature(64) || message */
    unsigned char *sm = (unsigned char*)malloc(msg_len + 64);
    unsigned char *m  = (unsigned char*)malloc(msg_len + 64);
    if (!sm || !m) { free(sm); free(m); return luaL_error(L, "out of memory"); }
    
    memcpy(sm, sig, 64);
    memcpy(sm + 64, msg, msg_len);
    
    unsigned long long mlen;
    int valid = crypto_sign_open(m, &mlen, sm, msg_len + 64, (const unsigned char*)pub);
    
    free(sm);
    free(m);
    
    lua_pushboolean(L, valid == 0);
    return 1;
}


/* --- SS58 Encode/Decode (Minimal C Implementation) --- */

// Base58 Alphabet
static const char *ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
static int8_t B58_MAP[256];
static int MAP_INIT = 0;

static void init_map() {
    if (MAP_INIT) return;
    memset(B58_MAP, -1, 256);
    for (int i = 0; i < 58; i++) {
        B58_MAP[(uint8_t)ALPHABET[i]] = i;
    }
    MAP_INIT = 1;
}

// Simple Base58 Encode (byte array -> string)
static void base58_encode(const uint8_t *in, size_t in_len, char *out) {
    size_t zeros = 0;
    while (zeros < in_len && in[zeros] == 0) zeros++;
    
    // ~1.37 * length
    size_t b58_len = in_len * 137 / 100 + 10;
    uint8_t *b58 = (uint8_t*)calloc(b58_len, 1);
    
    size_t len = 0;
    for (size_t i = zeros; i < in_len; i++) {
        int carry = in[i];
        for (size_t j = 0; j < len; j++) {
            int x = b58[j] * 256 + carry;
            b58[j] = x % 58;
            carry = x / 58;
        }
        while (carry) {
            b58[len++] = carry % 58;
            carry /= 58;
        }
    }
    
    // Output
    size_t out_idx = 0;
    for (size_t i = 0; i < zeros; i++) out[out_idx++] = '1';
    for (size_t i = 0; i < len; i++) out[out_idx++] = ALPHABET[b58[len - 1 - i]];
    out[out_idx] = 0;
    
    free(b58);
}

// Simple Base58 Decode (string -> byte array)
static int base58_decode(const char *in, size_t in_len, uint8_t *out, size_t out_max, size_t *out_len) {
    init_map();
    size_t zeros = 0;
    while (zeros < in_len && in[zeros] == '1') zeros++;
    
    // ~0.73 * length
    size_t bytes_len = in_len * 732 / 1000 + 10;
    uint8_t *bytes = (uint8_t*)calloc(bytes_len, 1);
    
    size_t len = 0;
    for (size_t i = zeros; i < in_len; i++) {
        int val = B58_MAP[(uint8_t)in[i]];
        if (val == -1) { free(bytes); return -1; } // Invalid char
        
        int carry = val;
        for (size_t j = 0; j < len; j++) {
            int x = bytes[j] * 58 + carry;
            bytes[j] = x % 256;
            carry = x / 256;
        }
        while (carry) {
            bytes[len++] = carry % 256;
            carry /= 256;
        }
    }
    
    if (len + zeros > out_max) { free(bytes); return -2; }
    
    memset(out, 0, zeros);
    for (size_t i = 0; i < len; i++) {
        out[zeros + i] = bytes[len - 1 - i];
    }
    *out_len = zeros + len;
    
    free(bytes);
    return 0;
}

static int l_ss58_encode(lua_State *L) {
    size_t pub_len;
    const char *pub = luaL_checklstring(L, 1, &pub_len);
    int version = luaL_checkinteger(L, 2);
    
    if (pub_len != 32) return luaL_error(L, "Public key must be 32 bytes");
    
    // Using simple SS58 (1 byte prefix)
    uint8_t data[35]; // 1 prefix + 32 pub + 2 check
    data[0] = (uint8_t)version; 
    memcpy(data + 1, pub, 32);
    
    // Compute Checksum: Blake2b-512("SS58PRE" ++ data[0..33])[0..2]
    uint8_t prefix[] = {'S','S','5','8','P','R','E'};
    uint8_t ctx[40]; // 7 + 33 = 40
    memcpy(ctx, prefix, 7);
    memcpy(ctx + 7, data, 33);
    
    uint8_t hash[64];
    crypto_blake2b(hash, 64, ctx, 40);
    
    data[33] = hash[0];
    data[34] = hash[1];
    
    char out[128];
    base58_encode(data, 35, out);
    
    lua_pushstring(L, out);
    return 1;
}

static int l_ss58_decode(lua_State *L) {
    size_t len;
    const char *str = luaL_checklstring(L, 1, &len);
    
    uint8_t data[64]; // Max buffer
    size_t data_len = 0;
    
    if (base58_decode(str, len, data, 64, &data_len) != 0) {
        return luaL_error(L, "Base58 decode failed");
    }
    
    if (data_len < 3) return luaL_error(L, "SS58 address too short");
    
    // Verify checksum
    // Last 2 bytes are checksum
    size_t payload_len = data_len - 2;
    uint8_t claimed_sum[2];
    claimed_sum[0] = data[payload_len];
    claimed_sum[1] = data[payload_len + 1];
    
    // Recompute checksum
    uint8_t prefix[] = {'S','S','5','8','P','R','E'};
    // Context size = 7 + payload_len
    uint8_t *ctx = (uint8_t*)malloc(7 + payload_len);
    memcpy(ctx, prefix, 7);
    memcpy(ctx + 7, data, payload_len);
    
    uint8_t hash[64];
    crypto_blake2b(hash, 64, ctx, 7 + payload_len);
    free(ctx);
    
    if (hash[0] != claimed_sum[0] || hash[1] != claimed_sum[1]) {
        return luaL_error(L, "Invalid SS58 checksum");
    }
    
    // Parse version and pubkey
    // Assume simple 1-byte version for now
    uint8_t version = data[0];
    uint8_t pub[32];
    if (payload_len == 33) { // 1 byte version + 32 byte pubkey
        memcpy(pub, data + 1, 32);
        lua_pushlstring(L, (const char*)pub, 32);
        lua_pushinteger(L, version);
        return 2;
    } else {
        return luaL_error(L, "Unsupported SS58 format length");
    }
}


static const struct luaL_Reg polkadot_crypto [] = {
    {"blake2b", l_blake2b},
    {"twox128", l_twox128},
    {"twox64", l_twox64},
    {"ed25519_keypair_from_seed", l_ed25519_keypair_from_seed},
    {"ed25519_sign", l_ed25519_sign},
    {"ed25519_verify", l_ed25519_verify},
    {"ss58_encode", l_ss58_encode},
    {"ss58_decode", l_ss58_decode},
    {NULL, NULL}
};

static int polkadot_crypto_init(lua_State *L) {
    // Add pure-C implementation notice
    lua_pushstring(L, "Pure C (Monocypher + TweetNaCl + xxHash)");
    lua_setglobal(L, "_POLKADOT_CRYPTO_IMPL");
    
    #if LUA_VERSION_NUM >= 502
        luaL_newlib(L, polkadot_crypto);
    #else
        luaL_register(L, "polkadot_crypto", polkadot_crypto);
    #endif
    return 1;
}

// Entry point for: require("polkadot_crypto")
int luaopen_polkadot_crypto(lua_State *L) {
    return polkadot_crypto_init(L);
}

// Entry point for: require("sublua.polkadot_crypto") (LuaRocks install)
int luaopen_sublua_polkadot_crypto(lua_State *L) {
    return polkadot_crypto_init(L);
}
