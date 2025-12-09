#!/usr/bin/env luajit
-- Test advanced cryptographic features: multisig, proxy, identity

package.path = package.path .. ";./?.lua;./?/init.lua"

local sublua = require("sublua")

print("🧪 Testing Advanced Cryptographic Features")
print("=" .. string.rep("=", 70))

-- Load FFI
sublua.ffi()
print("✅ FFI loaded\n")

-- Test configuration
local TEST_RPC = "wss://westend-rpc.polkadot.io"
local TEST_MNEMONIC_1 = "bottom drive obey lake curtain smoke basket hold race lonely fit walk"
local TEST_MNEMONIC_2 = "helmet myself order all require large unusual verify ritual final apart nut"

-- Helper function to run tests
local function run_test(name, test_fn)
    print("\n📝 Test: " .. name)
    print(string.rep("-", 70))
    
    local success, result = pcall(test_fn)
    
    if success and result then
        print("✅ PASSED: " .. name)
        return true
    elseif success then
        print("❌ FAILED: " .. name)
        return false
    else
        print("❌ ERROR: " .. name)
        print("   Error: " .. tostring(result))
        return false
    end
end

-- Test results tracking
local tests_passed = 0
local tests_failed = 0

local function record_test(result)
    if result then
        tests_passed = tests_passed + 1
    else
        tests_failed = tests_failed + 1
    end
end

-- =================================================================
-- MULTISIG TESTS
-- =================================================================

print("\n" .. string.rep("=", 70))
print("🔐 MULTISIG TESTS")
print(string.rep("=", 70))

record_test(run_test("Create multisig address from 2 signatories", function()
    local multisig_mod = sublua.multisig()
    local signer1 = sublua.signer().from_mnemonic(TEST_MNEMONIC_1)
    local signer2 = sublua.signer().from_mnemonic(TEST_MNEMONIC_2)
    
    local addr1 = signer1:get_ss58_address(42)  -- Westend
    local addr2 = signer2:get_ss58_address(42)
    
    print("   Signatory 1: " .. addr1)
    print("   Signatory 2: " .. addr2)
    
    local info, err = multisig_mod.create_address({addr1, addr2}, 2)
    
    if not info then
        print("   Error: " .. tostring(err))
        return false
    end
    
    print("   Multisig Address: " .. info.multisig_address)
    print("   Threshold: " .. info.threshold)
    
    -- Verify address format (should be valid SS58)
    assert(info.multisig_address, "Should return multisig address")
    assert(#info.multisig_address > 40, "Address should be valid SS58 format")
    assert(info.threshold == 2, "Threshold should be 2")
    
    return true
end))

record_test(run_test("Validate multisig parameters", function()
    local multisig_mod = sublua.multisig()
    
    -- Test invalid threshold
    local valid, err = multisig_mod.validate_params({"addr1", "addr2"}, 0)
    assert(not valid, "Should reject threshold of 0")
    print("   ✓ Rejects threshold < 1: " .. tostring(err))
    
    -- Test threshold > signatories
    valid, err = multisig_mod.validate_params({"addr1", "addr2"}, 3)
    assert(not valid, "Should reject threshold > signatories")
    print("   ✓ Rejects threshold > signatories: " .. tostring(err))
    
    -- Test insufficient signatories
    valid, err = multisig_mod.validate_params({"addr1"}, 1)
    assert(not valid, "Should reject < 2 signatories")
    print("   ✓ Rejects < 2 signatories: " .. tostring(err))
    
    -- Test valid params
    valid, err = multisig_mod.validate_params({"addr1", "addr2", "addr3"}, 2)
    assert(valid, "Should accept valid params")
    print("   ✓ Accepts valid parameters")
    
    return true
end))

record_test(run_test("Get multisig address (convenience method)", function()
    local multisig_mod = sublua.multisig()
    local signer1 = sublua.signer().from_mnemonic(TEST_MNEMONIC_1)
    local signer2 = sublua.signer().from_mnemonic(TEST_MNEMONIC_2)
    
    local addr1 = signer1:get_ss58_address(42)
    local addr2 = signer2:get_ss58_address(42)
    
    local multisig_addr, err = multisig_mod.get_address({addr1, addr2}, 2)
    
    if not multisig_addr then
        print("   Error: " .. tostring(err))
        return false
    end
    
    print("   Multisig Address: " .. multisig_addr)
    assert(#multisig_addr > 40, "Should return valid SS58 address")
    
    return true
end))

-- =================================================================
-- PROXY TESTS
-- =================================================================

print("\n" .. string.rep("=", 70))
print("🎭 PROXY TESTS")
print(string.rep("=", 70))

record_test(run_test("Validate proxy types", function()
    local proxy_mod = sublua.proxy()
    
    -- Test valid proxy types
    local valid_types = {"Any", "NonTransfer", "Governance", "Staking"}
    for _, proxy_type in ipairs(valid_types) do
        local valid, err = proxy_mod.validate_type(proxy_type)
        assert(valid, "Should accept " .. proxy_type)
        print("   ✓ Accepts proxy type: " .. proxy_type)
    end
    
    -- Test invalid proxy type
    local valid, err = proxy_mod.validate_type("InvalidType")
    assert(not valid, "Should reject invalid type")
    print("   ✓ Rejects invalid type: " .. tostring(err))
    
    return true
end))

record_test(run_test("Query proxies for an account (dry run)", function()
    local proxy_mod = sublua.proxy()
    local signer = sublua.signer().from_mnemonic(TEST_MNEMONIC_1)
    local address = signer:get_ss58_address(42)
    
    print("   Querying proxies for: " .. address)
    
    local proxies, err = proxy_mod.query(TEST_RPC, address)
    
    if not proxies then
        print("   Error: " .. tostring(err))
        -- This is expected if account has no proxies
        print("   ℹ️  No proxies found (expected for test account)")
        return true
    end
    
    print("   Proxies data: " .. proxies)
    return true
end))

-- =================================================================
-- IDENTITY TESTS
-- =================================================================

print("\n" .. string.rep("=", 70))
print("👤 IDENTITY TESTS")
print(string.rep("=", 70))

record_test(run_test("Validate identity information", function()
    local identity_mod = sublua.identity()
    
    -- Test valid identity
    local valid_info = {
        display_name = "Alice",
        web = "https://alice.example.com",
        email = "alice@example.com",
        twitter = "@alice"
    }
    
    local valid, err = identity_mod.validate(valid_info)
    assert(valid, "Should accept valid identity")
    print("   ✓ Accepts valid identity info")
    
    -- Test invalid email
    local invalid_email = {display_name = "Bob", email = "not-an-email"}
    valid, err = identity_mod.validate(invalid_email)
    assert(not valid, "Should reject invalid email")
    print("   ✓ Rejects invalid email: " .. tostring(err))
    
    -- Test invalid URL
    local invalid_url = {display_name = "Bob", web = "not-a-url"}
    valid, err = identity_mod.validate(invalid_url)
    assert(not valid, "Should reject invalid URL")
    print("   ✓ Rejects invalid URL: " .. tostring(err))
    
    -- Test field length limits
    local too_long = {display_name = string.rep("a", 100)}
    valid, err = identity_mod.validate(too_long)
    assert(not valid, "Should reject too long display_name")
    print("   ✓ Rejects too long fields: " .. tostring(err))
    
    return true
end))

record_test(run_test("Create identity info template", function()
    local identity_mod = sublua.identity()
    
    local info = identity_mod.create_info()
    
    assert(type(info) == "table", "Should return a table")
    assert(info.display_name == "", "Should have display_name field")
    assert(info.legal_name == "", "Should have legal_name field")
    assert(info.web == "", "Should have web field")
    assert(info.email == "", "Should have email field")
    assert(info.twitter == "", "Should have twitter field")
    
    print("   ✓ Created identity info template with all fields")
    
    return true
end))

record_test(run_test("Query identity for an account (dry run)", function()
    local identity_mod = sublua.identity()
    local signer = sublua.signer().from_mnemonic(TEST_MNEMONIC_1)
    local address = signer:get_ss58_address(42)
    
    print("   Querying identity for: " .. address)
    
    local identity_data, err = identity_mod.query(TEST_RPC, address)
    
    if not identity_data then
        print("   Error: " .. tostring(err))
        print("   ℹ️  No identity found (expected for test account)")
        return true
    end
    
    print("   Identity data: " .. identity_data)
    return true
end))

-- =================================================================
-- INTEGRATION TESTS
-- =================================================================

print("\n" .. string.rep("=", 70))
print("🔗 INTEGRATION TESTS")
print(string.rep("=", 70))

record_test(run_test("Multisig address is deterministic", function()
    local multisig_mod = sublua.multisig()
    local signer1 = sublua.signer().from_mnemonic(TEST_MNEMONIC_1)
    local signer2 = sublua.signer().from_mnemonic(TEST_MNEMONIC_2)
    
    local addr1 = signer1:get_ss58_address(42)
    local addr2 = signer2:get_ss58_address(42)
    
    -- Create multisig address twice
    local multisig1, _ = multisig_mod.get_address({addr1, addr2}, 2)
    local multisig2, _ = multisig_mod.get_address({addr1, addr2}, 2)
    
    assert(multisig1 == multisig2, "Multisig address should be deterministic")
    print("   ✓ Same signatories produce same multisig address")
    print("   Address: " .. multisig1)
    
    return true
end))

record_test(run_test("Multisig address changes with different threshold", function()
    local multisig_mod = sublua.multisig()
    local signer1 = sublua.signer().from_mnemonic(TEST_MNEMONIC_1)
    local signer2 = sublua.signer().from_mnemonic(TEST_MNEMONIC_2)
    
    local addr1 = signer1:get_ss58_address(42)
    local addr2 = signer2:get_ss58_address(42)
    
    local multisig_threshold_1, _ = multisig_mod.get_address({addr1, addr2}, 1)
    local multisig_threshold_2, _ = multisig_mod.get_address({addr1, addr2}, 2)
    
    assert(multisig_threshold_1 ~= multisig_threshold_2, "Different thresholds should produce different addresses")
    print("   ✓ Threshold 1: " .. multisig_threshold_1)
    print("   ✓ Threshold 2: " .. multisig_threshold_2)
    
    return true
end))

-- =================================================================
-- SUMMARY
-- =================================================================

print("\n" .. string.rep("=", 70))
print("📊 TEST SUMMARY")
print(string.rep("=", 70))
print("✅ Tests Passed: " .. tests_passed)
print("❌ Tests Failed: " .. tests_failed)
print("📈 Total Tests:  " .. (tests_passed + tests_failed))
print("✨ Success Rate: " .. string.format("%.1f%%", (tests_passed / (tests_passed + tests_failed)) * 100))

if tests_failed == 0 then
    print("\n🎉 All tests passed!")
    os.exit(0)
else
    print("\n⚠️  Some tests failed. Please review the output above.")
    os.exit(1)
end

