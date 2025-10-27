#!/usr/bin/env lua

-- test_installation.lua
-- Simple script to test SubLua installation

local function test_installation()
    print("🧪 Testing SubLua installation...")
    print("")
    
    local tests = {
        {
            name = "SDK Loading",
            test = function()
                local sdk = require("sublua")
                return sdk ~= nil
            end
        },
        {
            name = "FFI Library Loading",
            test = function()
                local ffi = require("sublua.polkadot_ffi")
                return ffi ~= nil and ffi.lib ~= nil
            end
        },
        {
            name = "RPC Module",
            test = function()
                local rpc = require("sublua.rpc")
                return rpc ~= nil
            end
        },
        {
            name = "Signer Module",
            test = function()
                local signer = require("sublua.signer")
                return signer ~= nil
            end
        },
        {
            name = "Chain Config Module",
            test = function()
                local config = require("sublua.chain_config")
                return config ~= nil
            end
        }
    }
    
    local passed = 0
    local total = #tests
    
    for _, test in ipairs(tests) do
        local success, result = pcall(test.test)
        if success and result then
            print("✅ " .. test.name .. " - PASSED")
            passed = passed + 1
        else
            print("❌ " .. test.name .. " - FAILED")
            if not success then
                print("   Error: " .. tostring(result))
            end
        end
    end
    
    print("")
    print("📊 Test Results: " .. passed .. "/" .. total .. " tests passed")
    
    if passed == total then
        print("🎉 All tests passed! SubLua is properly installed.")
        return true
    else
        print("⚠️  Some tests failed. Check the installation.")
        return false
    end
end

-- Run tests
local success = test_installation()

-- Exit with appropriate code
os.exit(success and 0 or 1)
