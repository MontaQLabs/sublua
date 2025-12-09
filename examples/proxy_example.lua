-- examples/proxy_example.lua
-- Demonstrates proxy account usage with SubLua

package.path = package.path .. ";./?.lua;./?/init.lua"
local sublua = require("sublua")

print("🎭 SubLua Proxy Account Example")
print("=" .. string.rep("=", 70))

-- Load FFI
sublua.ffi()
print("✅ FFI loaded\n")

-- Configuration
local RPC_URL = "wss://westend-rpc.polkadot.io"

-- Create accounts
local MAIN_ACCOUNT_MNEMONIC = "bottom drive obey lake curtain smoke basket hold race lonely fit walk"
local PROXY_ACCOUNT_MNEMONIC = "helmet myself order all require large unusual verify ritual final apart nut"

print("1️⃣  Setting up accounts...")
local signer_mod = sublua.signer()
local main_account = signer_mod.from_mnemonic(MAIN_ACCOUNT_MNEMONIC)
local proxy_account = signer_mod.from_mnemonic(PROXY_ACCOUNT_MNEMONIC)

local main_addr = main_account:get_ss58_address(42)  -- Westend
local proxy_addr = proxy_account:get_ss58_address(42)

print("   Main Account:  " .. main_addr)
print("   Proxy Account: " .. proxy_addr)

-- Proxy module
local proxy_mod = sublua.proxy()

-- Show available proxy types
print("\n2️⃣  Available Proxy Types:")
print("   • Any              - Allow all calls")
print("   • NonTransfer      - All calls except balance transfers")
print("   • Governance       - Only governance calls")
print("   • Staking          - Only staking calls")
print("   • IdentityJudgement - Only identity judgement")
print("   • CancelProxy      - Only cancel proxy calls")

-- Validate proxy type
print("\n3️⃣  Validating proxy types...")
local valid, err = proxy_mod.validate_type(proxy_mod.TYPES.ANY)
if valid then
    print("   ✅ 'Any' is a valid proxy type")
end

valid, err = proxy_mod.validate_type("InvalidType")
if not valid then
    print("   ✅ Rejects invalid type: " .. err)
end

-- Example: Adding a proxy (commented out to avoid actual on-chain transactions)
print("\n4️⃣  Adding a Proxy (Example)")
print("   Code:")
print([[
   local tx_hash, err = proxy_mod.add(
       RPC_URL,
       MAIN_ACCOUNT_MNEMONIC,
       proxy_addr,
       proxy_mod.TYPES.ANY,  -- Proxy type
       0                      -- No delay
   )
]])
print("   ℹ️  Commented out to avoid actual transactions")

-- Example: Removing a proxy
print("\n5️⃣  Removing a Proxy (Example)")
print("   Code:")
print([[
   local tx_hash, err = proxy_mod.remove(
       RPC_URL,
       MAIN_ACCOUNT_MNEMONIC,
       proxy_addr,
       proxy_mod.TYPES.ANY,  -- Must match type when added
       0                      -- Must match delay when added
   )
]])
print("   ℹ️  Commented out to avoid actual transactions")

-- Example: Executing a call through a proxy
print("\n6️⃣  Executing Transfer Through Proxy (Example)")
print("   Code:")
print([[
   local tx_hash, err = proxy_mod.transfer(
       RPC_URL,
       PROXY_ACCOUNT_MNEMONIC,  -- Proxy signs
       main_addr,                -- On behalf of main account
       "5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty",  -- Recipient
       1000000000000  -- 1 WND (12 decimals)
   )
]])
print("   ℹ️  Commented out to avoid actual transactions")

-- Example: Custom proxy call
print("\n7️⃣  Custom Proxy Call (Example)")
print("   Code:")
print([[
   local tx_hash, err = proxy_mod.call(
       RPC_URL,
       PROXY_ACCOUNT_MNEMONIC,
       main_addr,
       "Balances",              -- Pallet
       "transfer_keep_alive",   -- Call
       {                         -- Arguments
           dest = "5FHneW46...",
           amount = 1000000000000
       }
   )
]])
print("   ℹ️  Currently supports Balances::transfer_keep_alive")

-- Query existing proxies
print("\n8️⃣  Querying Proxies (Example)")
print("   Code:")
print([[
   local proxies, err = proxy_mod.query(RPC_URL, main_addr)
   if proxies then
       print("Proxies:", proxies)
   end
]])

-- Use cases
print("\n" .. string.rep("=", 70))
print("💡 Common Use Cases:")
print("\n   1. Cold Wallet Security:")
print("      • Keep main account offline (cold storage)")
print("      • Use hot wallet as proxy for day-to-day transactions")
print("      • Limit proxy permissions (e.g., NonTransfer for governance only)")

print("\n   2. Bot Automation:")
print("      • Main account holds funds")
print("      • Bot account acts as proxy")
print("      • Revoke proxy access anytime")

print("\n   3. Multi-Device Access:")
print("      • Main account on hardware wallet")
print("      • Mobile device as proxy for convenience")
print("      • Desktop as another proxy")

print("\n   4. Delegation:")
print("      • Delegate governance voting to trusted party")
print("      • Keep token control in main account")

print("\n" .. string.rep("=", 70))
print("📚 Important Notes:")
print("   • Proxy types must match exactly when removing")
print("   • Delay parameter must also match when removing")
print("   • 'Any' proxy type grants full control - use with caution")
print("   • Proxies can be revoked at any time by main account")
print("   • Proxy account pays transaction fees, not main account")

print("\n✅ Example completed!")

