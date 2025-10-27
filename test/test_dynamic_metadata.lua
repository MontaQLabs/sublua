#!/usr/bin/env luajit
-- Test dynamic metadata functionality

package.path = package.path .. ";./?.lua;./?/init.lua"

local sublua = require("sublua")
local metadata_mod = sublua.metadata()

print("🧪 Testing Dynamic Metadata with Subxt")
print("=" .. string.rep("=", 70))

-- Load FFI
sublua.ffi()
print("✅ FFI loaded\n")

-- Test chains
local test_chains = {
    {name = "Westend", url = "wss://westend-rpc.polkadot.io"},
    {name = "Polkadot", url = "wss://rpc.polkadot.io"},
}

for _, chain in ipairs(test_chains) do
    print("📡 Testing " .. chain.name .. " (" .. chain.url .. ")")
    print(string.rep("-", 70))
    
    -- 1. Fetch metadata
    print("\n1️⃣  Fetching chain metadata...")
    local metadata, err = metadata_mod.fetch_metadata(chain.url)
    if metadata then
        print("   ✅ Spec Version: " .. (metadata.spec_version or "unknown"))
        print("   ✅ Transaction Version: " .. (metadata.transaction_version or "unknown"))
        print("   ✅ Pallet Count: " .. (metadata.pallet_count or "unknown"))
    else
        print("   ❌ Error: " .. (err or "unknown"))
    end
    
    -- 2. Get all pallets
    print("\n2️⃣  Discovering pallets...")
    local pallets, err = metadata_mod.get_pallets(chain.url)
    if pallets then
        print("   ✅ Found " .. #pallets .. " pallets")
        print("   📋 First 10 pallets:")
        for i = 1, math.min(10, #pallets) do
            print("      - " .. pallets[i])
        end
    else
        print("   ❌ Error: " .. (err or "unknown"))
    end
    
    -- 3. Get call index for Balances::transfer_keep_alive
    print("\n3️⃣  Looking up Balances::transfer_keep_alive call index...")
    local indices, err = metadata_mod.get_dynamic_call_index(chain.url, "Balances", "transfer_keep_alive")
    if indices then
        print("   ✅ Call Index: [" .. indices[1] .. ", " .. indices[2] .. "]")
    else
        print("   ❌ Error: " .. (err or "unknown"))
    end
    
    -- 4. Get all calls for Balances pallet
    print("\n4️⃣  Getting all Balances pallet calls...")
    local calls, err = metadata_mod.get_pallet_calls_list(chain.url, "Balances")
    if calls then
        print("   ✅ Pallet calls retrieved successfully")
        print("   📋 (Call list parsing requires full JSON parser)")
    else
        print("   ❌ Error: " .. (err or "unknown"))
    end
    
    -- 5. Check runtime compatibility
    print("\n5️⃣  Checking runtime compatibility...")
    local compatible, message = metadata_mod.check_compatibility(chain.url, 1000000)  -- Intentionally wrong version
    print("   Compatible: " .. tostring(compatible))
    print("   Message: " .. (message or "N/A"))
    
    print("\n" .. string.rep("=", 70) .. "\n")
end

print("🎉 Dynamic Metadata Tests Complete!")
print("\n💡 Key Features:")
print("   ✅ Automatic pallet discovery from runtime")
print("   ✅ Dynamic call index lookup (no hardcoding needed)")
print("   ✅ Runtime version compatibility checking")
print("   ✅ Full metadata parsing via subxt SCALE codec")

