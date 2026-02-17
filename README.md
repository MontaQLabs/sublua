# SubLua

SubLua is a lightweight, high-performance Polkadot/Substrate SDK for Lua (5.1-5.4). It is built with **Pure C** and **Pure Lua**, requiring no Rust or complex toolchains.

## Features

-   **Native Crypto**: Ed25519, Blake2b, and xxHash implemented in optimized C.
-   **SS58 Support**: Full address encoding/decoding with checksums.
-   **SCALE Codec**: Pure Lua implementation of the SCALE serialization format.
-   **RPC Client**: Easy-to-use HTTP/HTTPS client for interacting with any Substrate node.
-   **Transactions**: Build, sign, and submit extrinsics (V4) from Lua.
-   **Zero Rust**: Works without the massive Rust dependency tree.

## Installation

### Prerequisites

-   A C compiler (`gcc` or `clang`)
-   Lua 5.1, 5.2, 5.3, 5.4 or LuaJIT
-   `luasocket` and `lua-cjson` (for RPC)

### Build from Source

```bash
# Clone the repository
git clone https://github.com/MontaQLabs/sublua.git
cd sublua

# Build the C module
make
```

This will produce `c_src/polkadot_crypto.so`.

## Quick Start

```lua
local polkadot = require("polkadot")
local keyring = require("polkadot.keyring")

-- Connect to Westend
local api = polkadot.connect("https://westend-rpc.polkadot.io")

-- Generate a keyring from a 32-byte seed
local alice = keyring.from_seed("0x...")

-- Query account balance
local info = api:system_account(alice.address)
print("Balance:", info.data.free_formated)
```

## Testing

SubLua includes a comprehensive test suite covering all components:

```bash
# Run all tests
make test

# Run specific test suites
make test-crypto      # Crypto module tests
make test-scale       # SCALE codec tests
make test-keyring     # Keyring tests
make test-transaction # Transaction builder tests
make test-rpc         # RPC client tests
make test-integration # Integration tests
```

See [test/README.md](test/README.md) for detailed testing documentation.

## Architecture

See [architecture.md](architecture.md) for a detailed breakdown of the technical components and design decisions.

## License

MIT
