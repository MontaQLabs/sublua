# SubLua Architecture

SubLua is a lightweight Polkadot/Substrate client library for Lua, designed for portability, simplicity, and zero heavy dependencies.

## Core Philosophy

1.  **Pure C & Lua**: No Rust toolchain required. No dependency on complex C++ libraries.
2.  **Standard Lua Support**: Works with standard Lua (5.1-5.4) and LuaJIT.
3.  **Hybrid Implementation**: 
    - **C Module**: Handles performance-critical and complex cryptographic primitives.
    - **Lua Layer**: Handles high-level logic, RPC, SCALE encoding, and transaction building.
4.  **Zero FFI**: Uses the standard Lua C API instead of LuaJIT FFI for maximum compatibility across Lua implementations.

---

## Technical Stack

### 1. Crypto Layer (C Module: `polkadot_crypto`)
The heart of the library is a small C module that abstracts away the cryptographic requirements of Substrate.

-   **Dependencies**: 
    -   **Monocypher**: Used for Ed25519 signatures and Blake2b hashing (128/256/512).
    -   **xxHash**: Used for Twox64 and Twox128 hashes (required for storage keys).
-   **SS58 Codec**: A custom C implementation of Base58 with Blake2b checksums, ensuring correct address handling without external bignum libraries.
-   **Distribution**: Shipped as source with a simple Makefile; produces a single `polkadot_crypto.so` file.

### 2. Communication Layer (Lua: `rpc.lua`)
A pure Lua JSON-RPC client.

-   **Transport**: HTTP/HTTPS via `luasocket`.
-   **Serialization**: JSON via `lua-cjson`.
-   **Capabilities**:
    -   State queries (`state_getStorage`).
    -   Chain metadata/properties retrieval.
    -   Extrinsic submission.
    -   Block and Header retrieval.

### 3. Data Layer (Lua: `scale.lua`)
A pure Lua implementation of the **SCALE Codec**, the standard serialization format for Substrate.

-   **Supported Types**: 
    -   Compact Integers (handling standard Lua number limits).
    -   Fixed-size integers (U8, U16, U32, U128).
    -   Option and Vector types.
    -   Struct/Result pattern support.

### 4. Transaction Layer (Lua: `transaction.lua`)
Constructs and signs Substrate Extrinsics (V4).

-   **Logic**:
    -   Payload construction (Call + Extra + Additional).
    -   Hashing and Signing (Ed25519).
    -   V4 Envelope encoding.
-   **Keyring**: Managed via `keyring.lua` for deterministic key derivation from seeds.

---

## Directory Structure

```text
sublua/
├── c_src/                  # C Module Source
│   ├── vendor/             # Monocypher and xxHash
│   ├── polkadot_crypto.c    # Lua C Bindings
│   └── Makefile            # Build System
├── lua/
│   └── polkadot/           # Core Lua Library
│       ├── init.lua        # Entry Point
│       ├── rpc.lua         # JSON-RPC Client
│       ├── scale.lua       # SCALE Codec
│       ├── keyring.lua     # Key Management
│       └── transaction.lua # Transaction Logic
├── examples/               # Usage examples
└── test/                   # Unit and Integration tests
```

## Security Assumptions
-   **Ed25519**: While Polkadot defaults to Sr25519 (Schnorrkel), Ed25519 is natively supported by the Substrate `MultiSignature` type and provides a much smaller foot-print for C implementations.
-   **Immortal Eras**: Currently defaults to Immortal transactions for simplicity; Mortal Eras (mortal transactions) can be implemented via the SCALE codec logic.
