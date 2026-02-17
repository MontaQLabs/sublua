-- test/run_tests.lua
-- Test runner for all SubLua tests

package.cpath = "./sublua/?.so;" .. package.cpath
package.path = "./?.lua;./?/init.lua;" .. package.path

local tests = {
    {name = "Crypto Module", file = "test_crypto.lua"},
    {name = "SCALE Codec", file = "test_scale.lua"},
    {name = "Keyring", file = "test_keyring.lua"},
    {name = "Transaction Builder", file = "test_transaction.lua"},
    {name = "RPC Client", file = "test_rpc.lua"},
    {name = "XCM", file = "test_xcm.lua"},
    {name = "Integration", file = "test_integration.lua"},
}

local function run_test(test_file)
    local test_path = debug.getinfo(1).source:match("@?(.*/)")
    local full_path = test_path .. test_file
    
    -- Change to test directory
    local original_dir = os.getenv("PWD") or "."
    os.execute("cd " .. test_path .. " 2>/dev/null")
    
    local result = os.execute("lua " .. full_path)
    os.execute("cd " .. original_dir .. " 2>/dev/null")
    
    return result == true or result == 0
end

print("=" .. string.rep("=", 60))
print("SubLua Test Suite")
print("=" .. string.rep("=", 60))
print()

local total_passed = 0
local total_failed = 0
local failed_tests = {}

for _, test in ipairs(tests) do
    print("\n" .. string.rep("-", 60))
    print("Running: " .. test.name)
    print(string.rep("-", 60))
    
    local ok = run_test(test.file)
    if ok then
        total_passed = total_passed + 1
    else
        total_failed = total_failed + 1
        table.insert(failed_tests, test.name)
    end
end

print("\n" .. string.rep("=", 60))
print("Test Summary")
print(string.rep("=", 60))
print("Total Tests: " .. #tests)
print("Passed: " .. total_passed)
print("Failed: " .. total_failed)

if #failed_tests > 0 then
    print("\nFailed Tests:")
    for _, name in ipairs(failed_tests) do
        print("  - " .. name)
    end
end

if total_failed == 0 then
    print("\n🎉 All tests passed!")
    os.exit(0)
else
    print("\n❌ Some tests failed")
    os.exit(1)
end
