# SubLua Security Best Practices

This document provides comprehensive security guidelines for building production applications with SubLua.

## Table of Contents

1. [Key Storage Security](#key-storage-security)
2. [Mnemonic Phrase Management](#mnemonic-phrase-management)
3. [Network Security](#network-security)
4. [Proxy Account Security](#proxy-account-security)
5. [Multisig Security](#multisig-security)
6. [Production Deployment](#production-deployment)

---

## Key Storage Security

### ⚠️ Never Store Private Keys in Code

**BAD:**
```lua
-- ❌ NEVER DO THIS
local PRIVATE_KEY = "0x1234567890abcdef..."
local MNEMONIC = "word word word..."  -- Exposed in source code
```

**GOOD:**
```lua
-- ✅ Use environment variables
local mnemonic = os.getenv("ACCOUNT_MNEMONIC")
if not mnemonic then
    error("ACCOUNT_MNEMONIC environment variable not set")
end
```

### Environment Variables

Store sensitive credentials in environment variables:

```bash
# .env file (add to .gitignore!)
export ACCOUNT_MNEMONIC="your twelve word mnemonic phrase here"
export RPC_URL="wss://rpc.polkadot.io"
```

Load them in your application:

```lua
local function load_env_file(filename)
    local file = io.open(filename, "r")
    if not file then return end
    
    for line in file:lines() do
        local key, value = line:match("^%s*export%s+([^=]+)%s*=%s*\"([^\"]*)\"")
        if key and value then
            -- Note: Lua doesn't have built-in setenv, use shell wrapper
            print("Loaded: " .. key)
        end
    end
    file:close()
end

-- Usage
load_env_file(".env")
local mnemonic = os.getenv("ACCOUNT_MNEMONIC")
```

### Encrypted Storage

For production applications, encrypt sensitive data at rest:

```lua
-- Example using external encryption tool
local function load_encrypted_mnemonic(key_file, password)
    -- Use system's encryption (e.g., openssl, gpg)
    local handle = io.popen(string.format(
        "openssl enc -aes-256-cbc -d -in %s -pass pass:%s",
        key_file,
        password
    ))
    local mnemonic = handle:read("*a")
    handle:close()
    
    -- Validate mnemonic format
    if not mnemonic or #mnemonic < 32 then
        error("Invalid encrypted mnemonic")
    end
    
    return mnemonic:gsub("%s+$", "")  -- trim whitespace
end

-- Usage
local password = os.getenv("ENCRYPTION_PASSWORD")
local mnemonic = load_encrypted_mnemonic("account.enc", password)
```

Create encrypted key file:

```bash
# Encrypt your mnemonic
echo "your mnemonic phrase here" | openssl enc -aes-256-cbc -out account.enc

# Decrypt when needed
openssl enc -aes-256-cbc -d -in account.enc
```

### Hardware Security Modules (HSM)

For enterprise deployments, use HSM or key management systems:

```lua
-- Example: AWS KMS integration
local function get_mnemonic_from_kms()
    local handle = io.popen("aws kms decrypt --key-id alias/substrate-key --ciphertext-blob file://encrypted.txt --output text --query Plaintext")
    local encrypted = handle:read("*a")
    handle:close()
    
    -- Decode base64
    local base64_decoded = ... -- Use base64 library
    return base64_decoded
end
```

---

## Mnemonic Phrase Management

### Generation

Generate secure mnemonic phrases offline:

```bash
# Using subkey (official Substrate tool)
subkey generate

# Or using BIP39 tools
# NEVER use online generators for production keys!
```

### Validation

Always validate mnemonics before use:

```lua
local function validate_mnemonic(mnemonic)
    -- Check word count
    local words = {}
    for word in mnemonic:gmatch("%S+") do
        table.insert(words, word)
    end
    
    if #words ~= 12 and #words ~= 24 then
        return false, "Mnemonic must be 12 or 24 words"
    end
    
    -- Test derivation
    local signer_mod = require("sublua.signer")
    local success, result = pcall(function()
        return signer_mod.from_mnemonic(mnemonic)
    end)
    
    if not success then
        return false, "Invalid mnemonic: " .. tostring(result)
    end
    
    return true, nil
end

-- Usage
local mnemonic = os.getenv("ACCOUNT_MNEMONIC")
local valid, err = validate_mnemonic(mnemonic)
if not valid then
    error("Mnemonic validation failed: " .. err)
end
```

### Backup Procedures

1. **Write down mnemonic on paper** - Never store digitally unless encrypted
2. **Store in multiple secure locations** - Fireproof safe, safety deposit box
3. **Use metal backup plates** - For long-term storage
4. **Test recovery process** - Verify you can restore from backup

### Recovery Testing

```lua
-- Test mnemonic recovery
local function test_mnemonic_recovery(mnemonic, expected_address)
    local signer = require("sublua.signer")().from_mnemonic(mnemonic)
    local address = signer:get_ss58_address(0)  -- Polkadot
    
    if address ~= expected_address then
        error("Mnemonic does not match expected address!")
    end
    
    print("✅ Mnemonic recovery test passed")
end
```

---

## Network Security

### Always Use WSS (WebSocket Secure)

**BAD:**
```lua
local RPC_URL = "ws://rpc.polkadot.io"  -- ❌ Unencrypted
```

**GOOD:**
```lua
local RPC_URL = "wss://rpc.polkadot.io"  -- ✅ Encrypted
```

### Validate RPC Endpoints

```lua
local TRUSTED_RPC_ENDPOINTS = {
    polkadot = {
        "wss://rpc.polkadot.io",
        "wss://polkadot-rpc.dwellir.com",
        "wss://polkadot.api.onfinality.io/public-ws",
    },
    westend = {
        "wss://westend-rpc.polkadot.io",
    },
}

local function validate_rpc_url(url, chain)
    local allowed = TRUSTED_RPC_ENDPOINTS[chain]
    if not allowed then
        error("Unknown chain: " .. chain)
    end
    
    for _, trusted_url in ipairs(allowed) do
        if url == trusted_url then
            return true
        end
    end
    
    error("Untrusted RPC endpoint: " .. url)
end
```

### Rate Limiting

Implement rate limiting to avoid DoS:

```lua
local rate_limiter = {
    last_call = 0,
    min_interval = 0.1,  -- 100ms between calls
}

local function rate_limited_call(fn, ...)
    local now = os.clock()
    local elapsed = now - rate_limiter.last_call
    
    if elapsed < rate_limiter.min_interval then
        local sleep_time = rate_limiter.min_interval - elapsed
        os.execute("sleep " .. tostring(sleep_time))
    end
    
    rate_limiter.last_call = os.clock()
    return fn(...)
end

-- Usage
local result = rate_limited_call(function()
    return rpc:get_account_info(address)
end)
```

---

## Proxy Account Security

### Cold Wallet Pattern

Use proxy accounts to keep main account offline:

```lua
-- Main account (cold storage - offline)
local MAIN_ACCOUNT = "keep this offline"

-- Proxy account (hot wallet - online)
local PROXY_MNEMONIC = os.getenv("PROXY_MNEMONIC")

-- Setup proxy
local proxy_mod = require("sublua.proxy")()

-- Add limited proxy
local tx_hash = proxy_mod.add(
    RPC_URL,
    MAIN_ACCOUNT_MNEMONIC,  -- Sign once, then go offline
    proxy_address,
    proxy_mod.TYPES.NON_TRANSFER,  -- ✅ Limit permissions
    0
)

-- From now on, use proxy for day-to-day operations
-- Main account stays in cold storage
```

### Proxy Type Selection

Choose the most restrictive proxy type for your use case:

| Proxy Type | Use Case | Risk Level |
|------------|----------|------------|
| `NonTransfer` | Governance voting only | ⭐ Low |
| `Staking` | Staking operations only | ⭐⭐ Medium |
| `Governance` | Governance only | ⭐ Low |
| `Any` | Full control | ⭐⭐⭐⭐⭐ **Very High** |

```lua
-- ✅ GOOD: Restrictive proxy for specific use case
proxy_mod.add(RPC_URL, main_mnemonic, delegate, proxy_mod.TYPES.GOVERNANCE, 0)

-- ❌ BAD: 'Any' proxy grants full control
proxy_mod.add(RPC_URL, main_mnemonic, delegate, proxy_mod.TYPES.ANY, 0)
```

### Proxy Delay

Use time-delayed proxies for high-value accounts:

```lua
-- Add proxy with 2-day delay (172800 blocks / 6s)
local DELAY_BLOCKS = math.floor((2 * 24 * 60 * 60) / 6)  -- 2 days

proxy_mod.add(
    RPC_URL,
    main_mnemonic,
    proxy_address,
    proxy_mod.TYPES.ANY,
    DELAY_BLOCKS  -- ✅ 2-day delay gives time to cancel malicious actions
)
```

### Regular Audit

Regularly check your proxy accounts:

```lua
local function audit_proxies(rpc_url, account)
    local proxy_mod = require("sublua.proxy")()
    local proxies, err = proxy_mod.query(rpc_url, account)
    
    if not proxies then
        print("Error querying proxies: " .. tostring(err))
        return
    end
    
    print("🔍 Proxy Audit for " .. account)
    print("Proxies: " .. proxies)
    
    -- Alert if unexpected proxies found
    -- (In production, parse JSON and validate against whitelist)
end

-- Run monthly
audit_proxies(RPC_URL, main_address)
```

---

## Multisig Security

### Key Distribution

**Never store all multisig keys in one location:**

```
✅ GOOD: Distributed key storage
- Key 1: Hardware wallet (offline)
- Key 2: Team member A's secure device
- Key 3: Team member B's secure device
- Key 4: Cold storage backup
- Key 5: Legal custodian

❌ BAD: All keys on same server/computer
```

### Threshold Selection

Choose appropriate thresholds:

| Use Case | Signatories | Recommended Threshold |
|----------|-------------|----------------------|
| Personal backup | 2 | 2-of-2 |
| Small team treasury | 3 | 2-of-3 |
| Organization treasury | 5 | 3-of-5 |
| Large DAO | 7-9 | 5-of-7 or 6-of-9 |

```lua
-- ✅ Treasury with redundancy
local council = {addr1, addr2, addr3, addr4, addr5}
local multisig = require("sublua.multisig")().create_address(council, 3)

-- Even if 2 members lose keys, treasury is still accessible
-- But requires 3 members to approve transactions
```

### Signing Ceremony

Implement formal signing procedures:

```lua
local function secure_multisig_signing()
    print("📋 Multisig Signing Ceremony")
    print("1. Verify transaction details")
    print("2. Each signer reviews independently")
    print("3. Signers approve in sequence")
    print("4. Final signer executes transaction")
    
    -- Log all actions
    local log_file = io.open("multisig_log.txt", "a")
    log_file:write(string.format(
        "[%s] Signing ceremony initiated by %s\n",
        os.date("%Y-%m-%d %H:%M:%S"),
        current_signer
    ))
    log_file:close()
end
```

---

## Production Deployment

### Security Checklist

Before deploying to production:

- [ ] All private keys stored encrypted
- [ ] Environment variables used for secrets
- [ ] `.env` files added to `.gitignore`
- [ ] RPC endpoints validated and whitelisted
- [ ] Rate limiting implemented
- [ ] Error handling doesn't leak sensitive data
- [ ] Logging doesn't include private keys
- [ ] Backup and recovery procedures tested
- [ ] Multisig thresholds reviewed
- [ ] Proxy permissions minimized
- [ ] Security audit completed

### Error Handling

Never log sensitive information:

```lua
-- ❌ BAD
local success, err = pcall(function()
    return signer.from_mnemonic(mnemonic)
end)
if not success then
    print("Error with mnemonic: " .. mnemonic)  -- ❌ Logs mnemonic!
end

-- ✅ GOOD
local success, err = pcall(function()
    return signer.from_mnemonic(mnemonic)
end)
if not success then
    print("Error: Failed to create signer")  -- ✅ Generic error
    -- Log details to secure logging system, not stdout
end
```

### Secure Logging

```lua
local function secure_log(level, message)
    -- Sanitize message - remove any potential secrets
    message = message:gsub("0x[a-fA-F0-9]{64}", "[REDACTED-SEED]")
    message = message:gsub("%w+%s+%w+%s+%w+%s+%w+%s+%w+", "[REDACTED-MNEMONIC]")
    
    -- Log to secure location
    local log = io.open("/var/log/sublua/app.log", "a")
    log:write(string.format("[%s] %s: %s\n", os.date("%Y-%m-%d %H:%M:%S"), level, message))
    log:close()
end
```

### Monitoring and Alerts

Set up monitoring for suspicious activity:

```lua
local function monitor_account(rpc_url, address)
    local last_nonce = 0
    
    while true do
        local account = rpc:get_account_info(address)
        
        -- Alert on unexpected transactions
        if account.nonce > last_nonce + 1 then
            alert("⚠️ Multiple transactions detected!")
        end
        
        last_nonce = account.nonce
        os.execute("sleep 30")  -- Check every 30 seconds
    end
end
```

---

## Incident Response

### Compromised Key Procedure

If you suspect a key compromise:

1. **Immediately transfer funds** to a new account
2. **Revoke all proxies** linked to the compromised account
3. **Update multisig members** if a multisig key is compromised
4. **Document the incident** for post-mortem analysis
5. **Review security practices** to prevent recurrence

```lua
-- Emergency fund transfer
local function emergency_transfer(compromised_mnemonic, safe_address)
    print("🚨 EMERGENCY TRANSFER INITIATED")
    
    local signer = require("sublua.signer")().from_mnemonic(compromised_mnemonic)
    local rpc = require("sublua.rpc")().new(RPC_URL)
    
    -- Get balance
    local account = rpc:get_account_info(signer:get_ss58_address(0))
    local balance = account.data.free
    
    -- Transfer all funds (minus fee)
    local tx_hash = signer:transfer(rpc, safe_address, balance - 1000000000)
    
    print("✅ Emergency transfer complete: " .. tx_hash)
end
```

---

## Additional Resources

- [Substrate Security Best Practices](https://docs.substrate.io/learn/accounts-addresses-keys/)
- [Polkadot Key Management](https://wiki.polkadot.network/docs/learn-account-generation)
- [Web3 Foundation Security Guidelines](https://github.com/w3f/General-Grants-Program/blob/master/grants/grant_guidelines_per_category.md#security)

---

## Contact

For security issues or vulnerabilities, please contact:
- **Email**: security@montaq.io
- **GitHub**: [Security Advisory](https://github.com/MontaQLabs/sublua/security/advisories/new)

**Do not disclose security vulnerabilities publicly until they are patched.**

