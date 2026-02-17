-- check_assethub_meta.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
package.cpath = "./sublua/?.so;" .. package.cpath

local polkadot = require("sublua.init")
local Metadata = require("sublua.metadata")

local url = "https://westend-asset-hub-rpc.polkadot.io"
local api = polkadot.connect(url)

print("Fetching AssetHub Metadata...")
local hex = api:state_getMetadata()
print("Metadata Hex Length: " .. #hex)

-- Allow parsing to fail, we just want to see if we get that far
local status, meta = pcall(Metadata.parse, hex)

if status then
    print("\nMetadata Version: " .. meta.version)
    if meta.pallets["Balances"] then
        print("Balances Index: " .. meta.pallets["Balances"].index)
        local calls = meta.pallets["Balances"].calls
        if calls then
            print("Balances Calls:")
            for name, idx in pairs(calls) do
                print("  " .. name .. ": " .. idx)
            end
        end
    else
        print("Balances pallet NOT FOUND")
    end
else
    print("\nMetadata Parse Failed: " .. tostring(meta))
    -- Try to dump first few pallets if possible from partial print?
    -- No, standard parser failed.
end
