-- examples/multisig_example.lua
-- Demonstrates multi-signature account usage with SubLua

package.path = package.path .. ";./?.lua;./?/init.lua"
local sublua = require("sublua")

print("🔐 SubLua Multi-Signature Account Example")
print("=" .. string.rep("=", 70))

-- Load FFI
sublua.ffi()
print("✅ FFI loaded\n")

-- Configuration
local RPC_URL = "wss://westend-rpc.polkadot.io"

-- Create two signers (Alice and Bob)
local ALICE_MNEMONIC = "bottom drive obey lake curtain smoke basket hold race lonely fit walk"
local BOB_MNEMONIC = "helmet myself order all require large unusual verify ritual final apart nut"

print("1️⃣  Creating signers...")
local signer_mod = sublua.signer()
local alice = signer_mod.from_mnemonic(ALICE_MNEMONIC)
local bob = signer_mod.from_mnemonic(BOB_MNEMONIC)

local alice_addr = alice:get_ss58_address(42)  -- Westend prefix
local bob_addr = bob:get_ss58_address(42)

print("   Alice: " .. alice_addr)
print("   Bob:   " .. bob_addr)

-- Create a 2-of-2 multisig account
print("\n2️⃣  Creating 2-of-2 multisig account...")
local multisig_mod = sublua.multisig()

local multisig_info, err = multisig_mod.create_address(
    {alice_addr, bob_addr},
    2  -- Both signatures required
)

if not multisig_info then
    print("❌ Error creating multisig: " .. tostring(err))
    os.exit(1)
end

print("   ✅ Multisig address created!")
print("   Address:  " .. multisig_info.multisig_address)
print("   Threshold: " .. multisig_info.threshold)
print("   Signatories:")
for i, addr in ipairs(multisig_info.signatories) do
    print("      " .. i .. ". " .. addr)
end

-- Demonstrate deterministic address generation
print("\n3️⃣  Verifying deterministic address generation...")
local multisig_addr2, _ = multisig_mod.get_address({alice_addr, bob_addr}, 2)
if multisig_addr2 == multisig_info.multisig_address then
    print("   ✅ Same signatories produce same address")
else
    print("   ❌ Address mismatch!")
end

-- Show different threshold produces different address
print("\n4️⃣  Comparing different thresholds...")
local multisig_1of2, _ = multisig_mod.get_address({alice_addr, bob_addr}, 1)
local multisig_2of2, _ = multisig_mod.get_address({alice_addr, bob_addr}, 2)

print("   1-of-2 multisig: " .. multisig_1of2)
print("   2-of-2 multisig: " .. multisig_2of2)

if multisig_1of2 ~= multisig_2of2 then
    print("   ✅ Different thresholds produce different addresses")
end

-- Example: 3-of-5 multisig (treasury scenario)
print("\n5️⃣  Creating 3-of-5 treasury multisig...")
local council_members = {
    alice_addr,
    bob_addr,
    "5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY",
    "5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty",
    "5FLSigC9HGRKVhB9FiEo4Y3koPsNmBmLJbpXg2mp1hXcS59Y"
}

local treasury_multisig, err = multisig_mod.create_address(council_members, 3)

if treasury_multisig then
    print("   ✅ Treasury multisig created!")
    print("   Address: " .. treasury_multisig.multisig_address)
    print("   Requires 3 out of 5 signatures")
end

-- Parameter validation examples
print("\n6️⃣  Demonstrating parameter validation...")

-- Invalid: threshold too high
local valid, err = multisig_mod.validate_params({"addr1", "addr2"}, 3)
if not valid then
    print("   ✅ Rejects threshold > signatories: " .. err)
end

-- Invalid: too few signatories
valid, err = multisig_mod.validate_params({"addr1"}, 1)
if not valid then
    print("   ✅ Rejects < 2 signatories: " .. err)
end

-- Valid parameters
valid, err = multisig_mod.validate_params({"addr1", "addr2", "addr3"}, 2)
if valid then
    print("   ✅ Accepts valid 2-of-3 configuration")
end

print("\n" .. string.rep("=", 70))
print("📚 Usage Notes:")
print("   • Multisig addresses are deterministically derived from signatories")
print("   • Order of signatories doesn't matter (automatically sorted)")
print("   • Different thresholds create different multisig addresses")
print("   • Threshold must be between 1 and number of signatories")
print("   • Minimum 2 signatories required")
print("\n💡 Next Steps:")
print("   • Fund the multisig address with tokens")
print("   • Use multisig.approve_as_multi() to approve transactions")
print("   • Use multisig.as_multi() to execute with threshold signatures")
print("\n✅ Example completed!")

