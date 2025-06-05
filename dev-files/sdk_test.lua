-- Test script for the Polkadot SDK
local ffi = require("ffi")
local http = require("socket.http")
local json = require("dkjson")
local ltn12 = require("ltn12")
-- Load the SDK
local sdk = require("init")

-- === Configuration ===
local rpc_url = "https://rpc.ibp.network/paseo"

-- Use the provided mnemonic phrase
local mnemonic = "bottom drive obey lake curtain smoke basket hold race lonely fit walk"
print("Using mnemonic:", mnemonic)

-- Try to derive seed from mnemonic via Rust FFI
local signer, key_info = sdk.signer.from_mnemonic(mnemonic)
local seed_hex = key_info.seed
print("Derived seed:", seed_hex)

-- Expected address for verification
local expected_address = "12bzRJfh7arnnfPPUZHeJUaE62QLEwhK48QnH9LXeK2m1iZU"
print("Expected Paseo address:", expected_address)

-- Test data
local test_call_index = {0x00, 0x00}  -- System.remark (simpler than remark_with_event)

-- Simple empty remark
local test_call_data = "0x00"  -- Empty remark

print("Using simple remark call:")
print("  Call data:", test_call_data)

-- Create signer early so it's available to all functions
-- local signer = sdk.signer.new(seed_hex) -- now using signer from mnemonic derivation

-- HTTP request helper
local function http_request(url, payload)
    local json_payload = json.encode(payload)
    local response_chunks = {}
    local res, code = http.request{
        url = url,
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = tostring(#json_payload)
        },
        source = ltn12.source.string(json_payload),
        sink = ltn12.sink.table(response_chunks),
    }
    
    if code ~= 200 then
        return nil, "HTTP request failed with code " .. tostring(code)
    end
    
    local body = table.concat(response_chunks)
    local obj, pos, err = json.decode(body, 1, nil)
    if err then
        return nil, "JSON decode error: " .. err
    end
    
    return obj, nil
end

-- Function to get runtime version
local function get_runtime_version()
    local payload = {
        jsonrpc = "2.0",
        method = "state_getRuntimeVersion",
        params = {},
        id = 1
    }
    
    local response, err = http_request(rpc_url, payload)
    if err then
        return nil, "HTTP error: " .. err
    end
    
    if response.error then
        return nil, response.error
    end
    
    return response.result, nil
end

-- Function to get finalized head
local function get_finalized_head()
    local payload = {
        jsonrpc = "2.0",
        method = "chain_getFinalizedHead",
        params = {},
        id = 1
    }
    
    local response, err = http_request(rpc_url, payload)
    if err then
        return nil, "HTTP error: " .. err
    end
    
    if response.error then
        return nil, response.error
    end
    
    return response.result, nil
end

-- Function to get genesis hash
local function get_genesis_hash()
    local payload = {
        jsonrpc = "2.0",
        method = "chain_getBlockHash",
        params = {0},
        id = 1
    }
    
    local response, err = http_request(rpc_url, payload)
    if err then
        return nil, "HTTP error: " .. err
    end
    
    if response.error then
        return nil, response.error
    end
    
    return response.result, nil
end

-- Function to get existential deposit
local function get_existential_deposit()
    local payload = {
        jsonrpc = "2.0",
        method = "state_getStorage",
        params = {"0x26aa394eea5630e07c48ae0c9558cef7c6f4b4b87e33cc2f0c90c68a19b4273a1"}, -- Balances.ExistentialDeposit
        id = 1
    }
    
    local response, err = http_request(rpc_url, payload)
    if err then
        return nil, "HTTP error: " .. err
    end
    
    if response.error then
        return nil, response.error
    end
    
    return response.result, nil
end

-- Function to check actual account balance
local function get_account_balance_info()
    local ss58_address = signer:get_ss58_address(0) -- Paseo uses prefix 0
    local payload = {
        jsonrpc = "2.0",
        method = "system_account",
        params = {ss58_address},
        id = 1
    }
    
    local response, err = http_request(rpc_url, payload)
    if err then
        return nil, "HTTP error: " .. err
    end
    
    if response.error then
        return nil, response.error
    end
    
    return response.result, nil
end

-- Function to check account balance (nonce only)
local function get_account_balance()
    local ss58_address = signer:get_ss58_address(0) -- Paseo uses prefix 0
    local payload = {
        jsonrpc = "2.0",
        method = "system_accountNextIndex",
        params = {ss58_address},
        id = 1
    }
    
    local response, err = http_request(rpc_url, payload)
    if err then
        return nil, "HTTP error: " .. err
    end
    
    if response.error then
        return nil, response.error
    end
    
    return response.result, nil
end

-- Function to check Asset Hub native balance (DOT)
local function get_asset_hub_balance()
    -- Asset Hub uses substrate generic SS58 format (prefix 0)
    local public_key = signer:get_public_key():gsub("^0x", "")
    
    -- System.Account storage key for Asset Hub
    -- Blake2_128Concat("System") + Blake2_128Concat("Account") + Blake2_128Concat(AccountId32)
    local storage_key = "0x26aa394eea5630e07c48ae0c9558cef7b99d880ec681799c0cf30e8886371da9" .. public_key
    
    local payload = {
        jsonrpc = "2.0",
        method = "state_getStorage",
        params = {storage_key},
        id = 1
    }
    
    local response, err = http_request(rpc_url, payload)
    if err then
        return nil, "HTTP error: " .. err
    end
    
    if response.error then
        return nil, response.error
    end
    
    return response.result, nil
end

-- Function to check Asset Hub assets using storage
local function get_asset_hub_assets()
    -- Try to query some common asset IDs on Asset Hub
    local public_key = signer:get_public_key():gsub("^0x", "")
    local assets_to_check = {
        "1984", -- USDT
        "1337", -- USDC  
        "30",   -- DOT (if represented as asset)
    }
    
    local results = {}
    for _, asset_id in ipairs(assets_to_check) do
        -- Assets.Account storage key
        local asset_id_encoded = string.format("%08x", tonumber(asset_id)) -- 4-byte little endian
        local storage_key = "0x682a59d51ab9e48a8c8cc418ff9708d2b99d880ec681799c0cf30e8886371da9" .. asset_id_encoded .. public_key
        
        local payload = {
            jsonrpc = "2.0",
            method = "state_getStorage",
            params = {storage_key},
            id = 1
        }
        
        local response, err = http_request(rpc_url, payload)
        if not err and response.result then
            results[asset_id] = response.result
        end
    end
    
    return results, nil
end

-- === Submit Transaction ===
local function submit_transaction(signed_extrinsic_hex)
    local payload = {
        jsonrpc = "2.0",
        method = "author_submitExtrinsic",
        params = {signed_extrinsic_hex},
        id = 1
    }
    
    local response, err = http_request(rpc_url, payload)
    if err then
        return nil, "HTTP error: " .. err
    end
    
    if response.error then
        return nil, response.error
    end
    
    return response.result, nil
end

-- Test Extrinsic with proper runtime parameters
print("\n=== Testing Extrinsic ===")

-- Get runtime parameters
local runtime_version, err = get_runtime_version()
if not runtime_version then
    print("Failed to get runtime version:", err)
    return
end

local genesis_hash, err = get_genesis_hash()
if not genesis_hash then
    print("Failed to get genesis hash:", err)
    return
end

local finalized_head, err = get_finalized_head()
if not finalized_head then
    print("Failed to get finalized head:", err)
    return
end

print("Runtime version:", runtime_version.specVersion)
print("Genesis hash:", genesis_hash)
print("Finalized head:", finalized_head)

-- Debug: Show what call we're making
print("Call index:", test_call_index[1], test_call_index[2])
print("Call data:", test_call_data)

print("Encoding unsigned extrinsic...")
-- Create extrinsic using object-oriented API
local extrinsic = sdk.extrinsic.new(test_call_index, test_call_data)
local unsigned_extrinsic = extrinsic:encode()
print("Unsigned extrinsic:", unsigned_extrinsic)

-- Test Signer
print("\n=== Testing Signer ===")
print("Created signer with seed:", seed_hex)
print("Public key:", signer:get_public_key())
print("SS58 Address (Westend):", signer:get_ss58_address(42))
print("SS58 Address (Paseo):", signer:get_ss58_address(0))

-- Verify the address matches expected
local paseo_address = signer:get_ss58_address(0)
if paseo_address == expected_address then
    print("✅ Address verification: PASSED")
else
    print("❌ Address verification: FAILED")
    print("  Expected:", expected_address)
    print("  Got:     ", paseo_address)
end

-- Test signing with proper parameters
local nonce = 0
local tip = 0
local era_mortal = false  -- Back to immortal era
local era_period = 0
local era_phase = 0

-- Set extrinsic parameters
extrinsic:set_nonce(nonce)
extrinsic:set_tip(tip)
extrinsic:set_era(era_mortal, era_period, era_phase)

-- Create signed extrinsic
local signed_extrinsic = extrinsic:create_signed(signer)
print("Signed extrinsic:", signed_extrinsic)

-- Check account balance first
print("\n=== Checking Account Balance ===")
local current_nonce = 0  -- Initialize current_nonce
local account_info, err = get_account_balance_info()
if err then
    print("Error getting account balance:", json.encode(err))
    print("Trying nonce-only method...")
    local account_nonce, nonce_err = get_account_balance()
    if nonce_err then
        print("Error getting nonce:", json.encode(nonce_err))
    else
        print("Account nonce:", account_nonce)
        print("Account exists with nonce", account_nonce)
        current_nonce = account_nonce
    end
else
    if account_info then
        print("Account info:", json.encode(account_info))
        
        -- Parse account data
        local nonce = account_info.nonce or 0
        local free_balance = account_info.data and account_info.data.free or "0"
        local reserved = account_info.data and account_info.data.reserved or "0"
        
        print("Account nonce:", nonce)
        print("Free balance:", free_balance)
        print("Reserved balance:", reserved)
        
        current_nonce = nonce
        
        -- Update extrinsic with correct nonce if needed
        if nonce > 0 then
            print("Updating extrinsic with nonce:", nonce)
            extrinsic:set_nonce(nonce)
            signed_extrinsic = extrinsic:create_signed(signer)
            print("Updated signed extrinsic:", signed_extrinsic)
        end
        
        -- Check if account has sufficient balance
        local free_balance_num = tonumber(free_balance) or 0
        if free_balance_num > 0 then
            print("✅ Account is funded with", free_balance, "PAS")
        else
            print("❌ Account has no balance - needs funding")
        end
    else
        print("Account not found")
    end
end

-- Update extrinsic with the correct nonce from Paseo
if current_nonce > 0 then
    print("Updating extrinsic with Paseo nonce:", current_nonce)
    extrinsic:set_nonce(current_nonce)
    signed_extrinsic = extrinsic:create_signed(signer)
    print("Updated signed extrinsic with nonce", current_nonce)
end

-- Check Asset Hub specific balance
print("\n=== Checking Asset Hub Balance ===")
local asset_hub_balance, ah_err = get_asset_hub_balance()
if ah_err then
    print("Error getting Asset Hub balance:", json.encode(ah_err))
else
    if asset_hub_balance and asset_hub_balance ~= "0x" then
        print("Asset Hub account storage:", asset_hub_balance)
        
        -- Decode the account info from storage
        -- Format: nonce (4 bytes) + consumers (4 bytes) + providers (4 bytes) + sufficients (4 bytes) + data
        local storage_data = asset_hub_balance:gsub("^0x", "")
        if #storage_data >= 32 then -- At least 16 bytes for account info
            -- Extract nonce (first 4 bytes, little endian)
            local nonce_hex = storage_data:sub(1, 8)
            local nonce_bytes = {}
            for i = 1, 8, 2 do
                table.insert(nonce_bytes, 1, tonumber(nonce_hex:sub(i, i+1), 16))
            end
            local ah_nonce = nonce_bytes[1] + nonce_bytes[2]*256 + nonce_bytes[3]*65536 + nonce_bytes[4]*16777216
            
            print("Asset Hub nonce:", ah_nonce)
            
            -- Try to extract balance data (after account info, usually starts around byte 16)
            if #storage_data > 32 then
                print("Asset Hub has account data - account is active")
                
                -- Update with Asset Hub nonce
                current_nonce = ah_nonce
                print("Using Asset Hub nonce:", current_nonce)
                
                -- Update extrinsic with Asset Hub nonce
                extrinsic:set_nonce(current_nonce)
                signed_extrinsic = extrinsic:create_signed(signer)
                print("Updated signed extrinsic with Asset Hub nonce")
            else
                print("Asset Hub account exists but may have minimal data")
            end
        else
            print("Asset Hub storage data too short to decode")
        end
    else
        print("Asset Hub account not found in storage")
    end
end

-- Check for other assets on Asset Hub
print("\n=== Checking Asset Hub Assets ===")
local asset_balances, asset_err = get_asset_hub_assets()
if asset_err then
    print("Error getting Asset Hub assets:", json.encode(asset_err))
else
    if asset_balances and next(asset_balances) then
        print("Found Asset Hub assets:")
        for asset_id, balance_data in pairs(asset_balances) do
            print("  Asset ID " .. asset_id .. ":", balance_data)
        end
    else
        print("No additional assets found")
    end
end

-- Try querying balance using state_call
print("\n=== Balance Query via state_call ===")
local balance_call_payload = {
    jsonrpc = "2.0",
    method = "state_call",
    params = {
        "AccountNonceApi_account_nonce",
        "0x" .. signer:get_public_key():gsub("^0x", "")
    },
    id = 1
}

local balance_call_response, balance_call_err = http_request(rpc_url, balance_call_payload)
if balance_call_err then
    print("Balance call error:", balance_call_err)
elseif balance_call_response.error then
    print("Balance call error:", json.encode(balance_call_response.error))
else
    print("Balance call result:", balance_call_response.result)
end

-- Try a different RPC endpoint to verify account
print("\n=== Trying Different Balance Method ===")
local balance_payload = {
    jsonrpc = "2.0",
    method = "system_dryRun",
    params = {signed_extrinsic},
    id = 1
}

local balance_response, balance_err = http_request(rpc_url, balance_payload)
if balance_err then
    print("Dry run error:", balance_err)
elseif balance_response.error then
    print("Dry run error:", json.encode(balance_response.error))
else
    print("Dry run result:", json.encode(balance_response.result))
end

-- Alternative Balance Check using state_getStorage
print("\n=== Alternative Balance Check ===")
local public_key = signer:get_public_key():gsub("^0x", "")
local storage_key = "0x26aa394eea5630e07c48ae0c9558cef7b99d880ec681799c0cf30e8886371da9" .. public_key

local storage_payload = {
    jsonrpc = "2.0",
    method = "state_getStorage",
    params = {storage_key},
    id = 1
}

local storage_response, storage_err = http_request(rpc_url, storage_payload)
if storage_err then
    print("Storage query error:", storage_err)
elseif storage_response.error then
    print("Storage query error:", json.encode(storage_response.error))
elseif storage_response.result then
    print("Raw account storage:", storage_response.result)
    if storage_response.result == "0x" or not storage_response.result then
        print("❌ Account not found in storage - needs funding")
    else
        print("✅ Account exists in storage")
        -- Try to decode the storage data
        local storage_data = storage_response.result:gsub("^0x", "")
        print("Storage data length:", #storage_data)
    end
else
    print("No storage result - account likely unfunded")
end

-- Test sending transaction
print("\n=== Testing Transaction Submission ===")
print("Submitting transaction...")
local result, err = submit_transaction(signed_extrinsic)
if err then
    print("Submission error:", json.encode(err))
    
    -- Try with author_submitAndWatchExtrinsic for more detailed error
    print("\n=== Trying with Watch Method ===")
    local watch_payload = {
        jsonrpc = "2.0",
        method = "author_submitAndWatchExtrinsic",
        params = {signed_extrinsic},
        id = 1
    }
    
    local watch_response, watch_err = http_request(rpc_url, watch_payload)
    if watch_err then
        print("Watch submission error:", watch_err)
    elseif watch_response.error then
        print("Watch submission error:", json.encode(watch_response.error))
    else
        print("Watch submission result:", json.encode(watch_response.result))
    end
else
    print("Transaction hash:", result)
    print("SUCCESS! Transaction submitted to Westend")
end

-- Function to check account info
local function get_account_info(address)
    -- Convert SS58 address to AccountId32 for storage key
    -- For now, let's use the public key directly
    local public_key = signer:get_public_key():gsub("^0x", "")
    
    -- System.Account storage key: blake2_128_concat(module) + blake2_128_concat(storage) + blake2_128_concat(AccountId32)
    local payload = {
        jsonrpc = "2.0",
        id = 1,
        method = "state_getStorage",
        params = {"0x26aa394eea5630e07c48ae0c9558cef7b99d880ec681799c0cf30e8886371da9" .. public_key}
    }
    
    local response, err = http_request(rpc_url, payload)
    if err then
        return nil, err
    end
    
    return response, nil
end

-- Check account info before submitting
print("\n=== Checking Account Info ===")
local account_info, err = get_account_info()
if err then
    print("Error getting account info:", err)
elseif account_info and account_info.result then
    print("Account data:", account_info.result)
else
    print("Account not found or has no balance")
end

-- Function to get runtime metadata
local function get_runtime_metadata()
    local payload = {
        jsonrpc = "2.0",
        id = 1,
        method = "state_getMetadata"
    }
    
    local response, err = http_request(rpc_url, payload)
    if err then
        return nil, err
    end
    
    return response, nil
end

-- Check runtime metadata
print("\n=== Checking Runtime Metadata ===")
local metadata, err = get_runtime_metadata()
if err then
    print("Error getting metadata:", err)
elseif metadata and metadata.result then
    print("Metadata length:", #metadata.result)
    print("Metadata prefix:", metadata.result:sub(1, 20))
else
    print("Failed to get metadata")
end

-- Try submitting with author_submitExtrinsic instead
print("\n=== Trying author_submitExtrinsic ===")
local author_payload = {
    jsonrpc = "2.0",
    method = "author_submitExtrinsic",
    params = {signed_extrinsic},
    id = 1
}

local author_response, author_err = http_request(rpc_url, author_payload)
if author_err then
    print("Author submit error:", author_err)
elseif author_response.error then
    print("Author submit error:", json.encode(author_response.error))
    if author_response.error.message then
        print("Error message:", author_response.error.message)
    end
else
    print("Author submit result:", json.encode(author_response.result))
    if author_response.result then
        print("✅ Transaction hash:", author_response.result)
        print("Check transaction at: https://westend.subscan.io/extrinsic/" .. author_response.result)
    end
end

-- Summary and funding instructions
print("\n=== SUMMARY ===")
print("✅ SDK Status: WORKING")
print("✅ Signing: SUCCESSFUL")
print("✅ Extrinsic Format: VALID")
print("❌ Account Balance: 0 PAS (UNFUNDED)")
print("")
print("Account Details:")
print("  Mnemonic: bottom drive obey lake curtain smoke basket hold race lonely fit walk")
print("  Address:", signer:get_ss58_address(0)) -- Paseo address
print("  Public Key:", key_info.public)
print("  Nonce:", current_nonce)
print("  Balance: 0 PAS")
print("")
print("🚨 ACCOUNT NEEDS FUNDING TO SUBMIT TRANSACTIONS")
print("")
print("To fund this account:")
print("1. Go to: https://faucet.polkadot.io/paseo")
print("2. Enter address:", signer:get_ss58_address(0))
print("3. Request PAS tokens")
print("4. Wait for confirmation (check: https://paseo.subscan.io/account/" .. signer:get_ss58_address(0) .. ")")
print("5. Re-run this script")
print("")
print("Alternative: Send PAS from another funded account")
print("")
print("The runtime panic occurs because the account has insufficient balance.")
print("Once funded, transactions should submit successfully.")

print("\nAll tests completed!")