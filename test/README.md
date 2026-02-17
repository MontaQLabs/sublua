# SubLua Test Suite

This directory contains comprehensive tests for all SubLua components, following the architecture defined in `architecture.md`.

## Test Structure

- **test_crypto.lua** - Tests for the C crypto module (Blake2b, Twox, Ed25519, SS58)
- **test_scale.lua** - Tests for SCALE codec (compact integers, u8/u16/u32/u64/u128, option, vector)
- **test_keyring.lua** - Tests for keyring module (seed derivation, SS58 encoding, signing)
- **test_transaction.lua** - Tests for transaction builder (signing, encoding, edge cases)
- **test_rpc.lua** - Unit tests for RPC client (method signatures, parameter handling)
- **test_integration.lua** - Integration tests (end-to-end workflows, network tests)
- **test_core.lua** - Basic core functionality tests

## Running Tests

### Run All Tests

```bash
make test
```

### Run Individual Test Suites

```bash
make test-crypto      # Crypto module tests
make test-scale       # SCALE codec tests
make test-keyring     # Keyring tests
make test-transaction # Transaction builder tests
make test-rpc         # RPC client tests
make test-integration # Integration tests (requires network)
make test-core        # Core functionality tests
```

### Run Tests Manually

```bash
cd test
lua test_crypto.lua
lua test_scale.lua
# ... etc
```

### Skip Network Tests

Integration tests that require network access can be skipped:

```bash
SKIP_NETWORK_TESTS=1 make test-integration
```

## Test Coverage

### Crypto Module (26 tests)
- ✅ Blake2b hashing (empty, basic, different lengths, long input, error handling)
- ✅ Twox128/Twox64 hashing (deterministic, storage keys)
- ✅ Ed25519 (keypair generation, signing, verification, error cases)
- ✅ SS58 encoding/decoding (roundtrip, different versions, error handling)

### SCALE Codec (25 tests)
- ✅ Compact integers (single byte, two bytes, four bytes, bigint mode)
- ✅ Fixed-size integers (u8, u16, u32, u64, u128)
- ✅ Option type (None, Some)
- ✅ Vector type (empty, single, multiple elements)
- ✅ Real-world patterns (account nonce, balance, call index)

### Keyring (17 tests)
- ✅ Seed handling (hex with/without 0x, raw bytes)
- ✅ Deterministic key generation
- ✅ SS58 address generation
- ✅ Message signing and verification
- ✅ URI parsing (//Alice)
- ✅ Edge cases (all zeros, all 0xFF)

### Transaction Builder (17 tests)
- ✅ Transaction creation and signing
- ✅ Nonce handling
- ✅ Different calls/signers produce different signatures
- ✅ Extrinsic structure (V4)
- ✅ Immortal era encoding
- ✅ Payload hashing for long calls
- ✅ Deterministic signing
- ✅ Chain state dependencies (genesis hash, block hash)

### RPC Client (18 tests)
- ✅ Client creation (HTTP/HTTPS/WSS/WS)
- ✅ Chain properties
- ✅ Storage key construction
- ✅ Method signatures
- ✅ Parameter handling

### Integration Tests (varies)
- ✅ Module loading
- ✅ Keyring -> Address -> SS58 roundtrip
- ✅ Keyring -> Sign -> Verify
- ✅ SCALE encode -> Transaction -> Sign
- ✅ Storage key construction
- ✅ Network tests (RPC calls, account queries, transaction flow)

## Test Philosophy

Tests follow the architecture principles:
1. **Pure C & Lua**: Tests verify C module and Lua layer separately
2. **Standard Lua Support**: Tests work with standard Lua (5.1-5.4)
3. **Hybrid Implementation**: Tests cover both C module and Lua layer
4. **Zero FFI**: Tests use standard Lua C API

## Adding New Tests

When adding new functionality:

1. Add tests to the appropriate test file
2. Follow the existing test structure:
   ```lua
   test("Test name", function()
       -- Test code
       assert(condition)
   end)
   ```
3. Run the test suite to ensure all tests pass
4. Update this README if adding new test categories

## Continuous Integration

Tests are designed to be run in CI/CD pipelines:
- Unit tests run without network access
- Integration tests can be skipped with `SKIP_NETWORK_TESTS=1`
- All tests return exit codes (0 = success, 1 = failure)
