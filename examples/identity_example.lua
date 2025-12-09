-- examples/identity_example.lua
-- Demonstrates on-chain identity management with SubLua

package.path = package.path .. ";./?.lua;./?/init.lua"
local sublua = require("sublua")

print("👤 SubLua On-Chain Identity Example")
print("=" .. string.rep("=", 70))

-- Load FFI
sublua.ffi()
print("✅ FFI loaded\n")

-- Configuration
local RPC_URL = "wss://westend-rpc.polkadot.io"
local TEST_MNEMONIC = "bottom drive obey lake curtain smoke basket hold race lonely fit walk"

print("1️⃣  Creating account...")
local signer_mod = sublua.signer()
local account = signer_mod.from_mnemonic(TEST_MNEMONIC)
local address = account:get_ss58_address(42)  -- Westend

print("   Address: " .. address)

-- Identity module
local identity_mod = sublua.identity()

-- Create identity information
print("\n2️⃣  Creating identity information...")
local identity_info = identity_mod.create_info()

-- Fill in identity details
identity_info.display_name = "Alice Wonderland"
identity_info.legal_name = "Alice W. Smith"
identity_info.web = "https://alice.example.com"
identity_info.email = "alice@example.com"
identity_info.twitter = "@alicewonderland"

print("   Display Name: " .. identity_info.display_name)
print("   Legal Name:   " .. identity_info.legal_name)
print("   Website:      " .. identity_info.web)
print("   Email:        " .. identity_info.email)
print("   Twitter:      " .. identity_info.twitter)

-- Validate identity information
print("\n3️⃣  Validating identity information...")
local valid, err = identity_mod.validate(identity_info)

if valid then
    print("   ✅ Identity information is valid")
else
    print("   ❌ Validation failed: " .. tostring(err))
end

-- Test validation with invalid data
print("\n4️⃣  Testing validation with invalid data...")

-- Invalid email
local invalid_info = {
    display_name = "Bob",
    email = "not-an-email"
}
valid, err = identity_mod.validate(invalid_info)
if not valid then
    print("   ✅ Rejects invalid email: " .. err)
end

-- Invalid URL
invalid_info = {
    display_name = "Bob",
    web = "not-a-valid-url"
}
valid, err = identity_mod.validate(invalid_info)
if not valid then
    print("   ✅ Rejects invalid URL: " .. err)
end

-- Field too long
invalid_info = {
    display_name = string.rep("a", 100)  -- Max is 32 bytes
}
valid, err = identity_mod.validate(invalid_info)
if not valid then
    print("   ✅ Rejects too long display_name: " .. err)
end

-- Setting identity (Example - commented out to avoid actual transactions)
print("\n5️⃣  Setting On-Chain Identity (Example)")
print("   Code:")
print([[
   local tx_hash, err = identity_mod.set(
       RPC_URL,
       TEST_MNEMONIC,
       {
           display_name = "Alice Wonderland",
           web = "https://alice.example.com",
           email = "alice@example.com",
           twitter = "@alicewonderland"
       }
   )
   
   if tx_hash then
       print("✅ Identity set! TX Hash: " .. tx_hash)
   end
]])
print("   ℹ️  Commented out to avoid actual transactions")
print("   💰 Note: Setting identity requires a deposit (~20 WND on Westend)")

-- Querying identity
print("\n6️⃣  Querying Identity (Example)")
print("   Code:")
print([[
   local identity_data, err = identity_mod.query(RPC_URL, address)
   
   if identity_data and identity_data ~= "null" then
       print("Identity found:", identity_data)
   else
       print("No identity set for this account")
   end
]])

-- Clearing identity
print("\n7️⃣  Clearing Identity (Example)")
print("   Code:")
print([[
   local tx_hash, err = identity_mod.clear(RPC_URL, TEST_MNEMONIC)
   
   if tx_hash then
       print("✅ Identity cleared! TX Hash: " .. tx_hash)
       print("💰 Deposit refunded to account")
   end
]])
print("   ℹ️  Commented out to avoid actual transactions")
print("   💰 Note: Clearing identity refunds the deposit")

-- Field length limits
print("\n8️⃣  Identity Field Limits:")
print("   • display_name:  32 bytes")
print("   • legal_name:    32 bytes")
print("   • web:           100 bytes")
print("   • email:         100 bytes")
print("   • twitter:       32 bytes")

-- Use cases
print("\n" .. string.rep("=", 70))
print("💡 Common Use Cases:")

print("\n   1. Personal Branding:")
print("      • Display your name and website on-chain")
print("      • Link social media accounts")
print("      • Build reputation in the ecosystem")

print("\n   2. Validator Identity:")
print("      • Validators show identity to nominators")
print("      • Increases trust and transparency")
print("      • Helps distinguish legitimate validators")

print("\n   3. Treasury Proposal Authors:")
print("      • Proposers can show their identity")
print("      • Increases accountability")
print("      • Builds trust with token holders")

print("\n   4. Collator/Parachain Teams:")
print("      • Teams can verify their on-chain presence")
print("      • Link to official communication channels")
print("      • Demonstrate legitimacy")

-- Identity Judgements
print("\n" .. string.rep("=", 70))
print("🏛️  Identity Judgements:")
print("   After setting your identity, you can request judgement from registrars:")
print("   • Registrars verify your identity information")
print("   • Provides social proof and trust")
print("   • Usually requires KYC process")
print("   • Judgement levels: Unknown, Reasonable, KnownGood, OutOfDate, LowQuality")

-- Best practices
print("\n" .. string.rep("=", 70))
print("📚 Best Practices:")
print("   • Use real, verifiable information")
print("   • Link to domains/accounts you control")
print("   • Keep information up to date")
print("   • Consider getting registrar judgement")
print("   • Remember: information is public and permanent")

print("\n⚠️  Security Notes:")
print("   • All identity information is publicly visible on-chain")
print("   • Never include sensitive information (passwords, private keys)")
print("   • Email and social handles are visible to everyone")
print("   • Consider privacy implications before setting identity")

print("\n💰 Cost Information (Westend Testnet):")
print("   • Setting identity: ~20 WND deposit")
print("   • Deposit is refundable when clearing identity")
print("   • Requesting judgement: Varies by registrar")

print("\n✅ Example completed!")

