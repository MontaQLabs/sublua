# SubLua API Reference

## Table of Contents

- [Core SDK](#core-sdk)
- [RPC Client](#rpc-client)
- [Signer Management](#signer-management)
- [Chain Configuration](#chain-configuration)
- [Extrinsic Builder](#extrinsic-builder)
- [FFI Functions](#ffi-functions)
- [Error Handling](#error-handling)

## Core SDK

### `require("sdk.init")`

Loads the SubLua SDK and returns the main SDK object.

```lua
local sdk = require("sdk.init")
```

**Returns:**
- `table` - SDK object containing all modules

**Available modules:**
- `sdk.rpc` - RPC client functionality
- `sdk.signer` - Cryptographic operations
- `sdk.chain_config` - Chain configuration
- `sdk.extrinsic_builder` - Transaction building

## RPC Client

### `sdk.rpc.new(url, config?)`

Creates a new RPC client connection to a Substrate node.

```lua
local rpc = sdk.rpc.new("wss://westend-rpc.polkadot.io")
```

**Parameters:**
- `url` (string) - WebSocket URL of the Substrate node
- `config` (table, optional) - Chain configuration

**Returns:**
- `table` - RPC client object

**Example:**
```lua
local rpc = sdk.rpc.new("wss://westend-rpc.polkadot.io", {
    name = "Westend",
    token_symbol = "WND",
    token_decimals = 12,
    ss58_prefix = 42
})
```

### `rpc:get_account_info(address)`

Fetches account information including balance and nonce.

```lua
local account = rpc:get_account_info("5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY")
```

**Parameters:**
- `address` (string) - SS58 encoded account address

**Returns:**
- `table|nil` - Account information or nil if account doesn't exist

**Account structure:**
```lua
{
    data = {
        free = 9997224699029,           -- Free balance in units
        free_tokens = 9.997224699029,   -- Free balance in tokens
        reserved = 0,                   -- Reserved balance in units
        reserved_tokens = 0,            -- Reserved balance in tokens
        frozen = 0,                     -- Frozen balance in units
        frozen_tokens = 0,              -- Frozen balance in tokens
        token_symbol = "WND",           -- Token symbol
        token_decimals = 12,            -- Token decimals
        flags = 0                       -- Account flags
    },
    nonce = 0                          -- Account nonce
}
```

### `rpc:author_submitExtrinsic(extrinsic)`

Submits a signed extrinsic to the network.

```lua
local tx_hash = rpc:author_submitExtrinsic(signed_extrinsic)
```

**Parameters:**
- `extrinsic` (string) - Hex-encoded signed extrinsic

**Returns:**
- `string` - Transaction hash

## Signer Management

### `sdk.signer.from_mnemonic(mnemonic)`

Creates a signer from a mnemonic phrase.

```lua
local signer = sdk.signer.from_mnemonic("your twelve word mnemonic phrase here")
```

**Parameters:**
- `mnemonic` (string) - BIP39 mnemonic phrase

**Returns:**
- `table` - Signer object

### `signer:get_ss58_address(prefix)`

Generates an SS58 address for the specified network prefix.

```lua
local address = signer:get_ss58_address(42)  -- Westend
```

**Parameters:**
- `prefix` (number) - SS58 network prefix

**Returns:**
- `string` - SS58 encoded address

**Common prefixes:**
- `0` - Polkadot
- `2` - Kusama
- `42` - Westend
- `1` - Rococo

### `signer:transfer(rpc, destination, amount)`

Submits a balance transfer transaction.

```lua
local tx_hash = signer:transfer(rpc, "5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY", 1000000000000)
```

**Parameters:**
- `rpc` (table) - RPC client object
- `destination` (string) - Recipient SS58 address
- `amount` (number) - Transfer amount in units (not tokens)

**Returns:**
- `string` - Transaction hash

## Chain Configuration

### `sdk.chain_config.detect_from_url(url)`

Automatically detects chain configuration from RPC URL.

```lua
local config = sdk.chain_config.detect_from_url("wss://westend-rpc.polkadot.io")
```

**Parameters:**
- `url` (string) - RPC URL

**Returns:**
- `table` - Chain configuration

**Configuration structure:**
```lua
{
    name = "Westend Testnet",           -- Chain name
    token_symbol = "WND",              -- Token symbol
    token_decimals = 12,               -- Token decimals
    ss58_prefix = 42,                  -- SS58 network prefix
    existential_deposit = 1000000000000 -- Minimum balance required
}
```

## Extrinsic Builder

### `sdk.extrinsic_builder.new(rpc)`

Creates a new extrinsic builder for constructing transactions.

```lua
local builder = sdk.extrinsic_builder.new(rpc)
```

**Parameters:**
- `rpc` (table) - RPC client object

**Returns:**
- `table` - Extrinsic builder object

### `builder:balances_transfer(destination, amount)`

Creates a balance transfer extrinsic.

```lua
local extrinsic = builder:balances_transfer("5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY", 1000000000000)
```

**Parameters:**
- `destination` (string) - Recipient SS58 address
- `amount` (number) - Transfer amount in units

**Returns:**
- `table` - Extrinsic object

### `extrinsic:set_nonce(nonce)`

Sets the nonce for the extrinsic.

```lua
extrinsic:set_nonce(5)
```

**Parameters:**
- `nonce` (number) - Account nonce

### `extrinsic:set_tip(tip)`

Sets the tip (priority fee) for the extrinsic.

```lua
extrinsic:set_tip(1000000000)  -- 1 WND tip
```

**Parameters:**
- `tip` (number) - Tip amount in units

### `extrinsic:set_era_immortal()`

Sets the extrinsic to be immortal (no expiration).

```lua
extrinsic:set_era_immortal()
```

### `extrinsic:encode_unsigned()`

Encodes the extrinsic without signature.

```lua
local unsigned = extrinsic:encode_unsigned()
```

**Returns:**
- `string` - Hex-encoded unsigned extrinsic

### `extrinsic:encode_signed(signature, public_key)`

Encodes the extrinsic with signature.

```lua
local signed = extrinsic:encode_signed(signature, public_key)
```

**Parameters:**
- `signature` (string) - Hex-encoded signature
- `public_key` (string) - Hex-encoded public key

**Returns:**
- `string` - Hex-encoded signed extrinsic

## FFI Functions

The SDK includes FFI bindings to Rust libraries for cryptographic operations.

### Loading the FFI Library

```lua
local ffi = require("ffi")

-- Define FFI structures
ffi.cdef[[
    typedef struct {
        bool success;
        char* data;
        char* error;
    } ExtrinsicResult;

    typedef struct {
        bool success;
        char* tx_hash;
        char* error;
    } TransferResult;

    ExtrinsicResult derive_sr25519_from_mnemonic(const char* mnemonic);
    ExtrinsicResult derive_sr25519_public_key(const char* seed_hex);
    ExtrinsicResult compute_ss58_address(const char* public_key_hex, uint16_t network_prefix);
    ExtrinsicResult decode_ss58_address(const char* ss58_address);
    ExtrinsicResult sign_extrinsic(const char* seed_hex, const char* extrinsic_hex);
    ExtrinsicResult blake2_128_hash(const char* data);
    TransferResult submit_balance_transfer_subxt(const char* node_url, const char* mnemonic, const char* dest_address, uint64_t amount);
    void free_string(char* ptr);
]]

-- Load the library
local lib = ffi.load("./polkadot-ffi-subxt/target/release/libpolkadot_ffi_subxt.dylib")
```

### `derive_sr25519_from_mnemonic(mnemonic)`

Derives an Sr25519 keypair from a mnemonic phrase.

```lua
local c_mnemonic = ffi.new("char[?]", #mnemonic + 1)
ffi.copy(c_mnemonic, mnemonic)
local result = lib.derive_sr25519_from_mnemonic(c_mnemonic)

if result.success then
    local json_str = ffi.string(result.data)
    lib.free_string(result.data)
    -- Parse JSON to get seed and public key
end
```

**Returns:**
- `ExtrinsicResult` - Contains JSON with seed and public key

### `compute_ss58_address(public_key_hex, network_prefix)`

Computes SS58 address from public key.

```lua
local c_public = ffi.new("char[?]", #public_key + 1)
ffi.copy(c_public, public_key)
local result = lib.compute_ss58_address(c_public, 42)

if result.success then
    local address = ffi.string(result.data)
    lib.free_string(result.data)
end
```

### `submit_balance_transfer_subxt(node_url, mnemonic, dest_address, amount)`

Submits a balance transfer using subxt.

```lua
local c_node_url = ffi.new("char[?]", #node_url + 1)
local c_mnemonic = ffi.new("char[?]", #mnemonic + 1)
local c_dest = ffi.new("char[?]", #dest_address + 1)

ffi.copy(c_node_url, node_url)
ffi.copy(c_mnemonic, mnemonic)
ffi.copy(c_dest, dest_address)

local result = lib.submit_balance_transfer_subxt(c_node_url, c_mnemonic, c_dest, amount)

if result.success then
    local tx_hash = ffi.string(result.tx_hash)
    lib.free_string(result.tx_hash)
end
```

## Error Handling

The SDK provides comprehensive error handling for all operations.

### Common Error Patterns

```lua
-- RPC errors
local success, result = pcall(function()
    return rpc:get_account_info(address)
end)

if not success then
    print("RPC error:", result)
end

-- Signer errors
local success, signer = pcall(function()
    return sdk.signer.from_mnemonic(mnemonic)
end)

if not success then
    print("Signer error:", signer)
end

-- FFI errors
local result = lib.some_function(params)
if not result.success then
    local error_msg = ffi.string(result.error)
    lib.free_string(result.error)
    print("FFI error:", error_msg)
end
```

### Error Types

- **RPC Errors**: Network connectivity, node issues
- **Validation Errors**: Invalid parameters, insufficient funds
- **Cryptographic Errors**: Invalid mnemonic, signing failures
- **FFI Errors**: Library loading, memory allocation

### Best Practices

1. Always check return values and error conditions
2. Free FFI string pointers to prevent memory leaks
3. Use pcall for operations that may fail
4. Provide meaningful error messages to users
5. Implement retry logic for network operations
