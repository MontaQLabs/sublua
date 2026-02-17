-- examples/xcm_teleport.lua
-- Teleport WND from Westend relay chain to AssetHub (parachain 1000)
--
-- Usage: lua examples/xcm_teleport.lua
-- Requires: Bob (//Bob) dev account funded on Westend relay chain

package.cpath = "./sublua/?.so;" .. package.cpath
package.path = "./?.lua;./?/init.lua;" .. package.path

local RPC = require("sublua.rpc")
local XCM = require("sublua.xcm")
local Keyring = require("sublua.keyring")

local function to_hex(s)
    return (s:gsub(".", function(c) return string.format("%02x", string.byte(c)) end))
end

-- Connect to Westend relay chain
local api = RPC.new("https://westend-rpc.polkadot.io")
local bob = Keyring.from_uri("//Bob")
local account = api:system_account(bob.address)

print("=== XCM Teleport: Westend -> AssetHub ===")
print("Sender:  " .. bob.address)
print("Balance: " .. string.format("%.4f WND", account.data.free / 1e12))
print("Nonce:   " .. account.nonce)

-- Teleport 1 WND to Bob on AssetHub
local amount = 1000000000000 -- 1 WND (12 decimals)
print("\nTeleporting " .. string.format("%.4f WND", amount / 1e12) .. " to AssetHub (para 1000)")
print("Beneficiary: Bob on AssetHub")

local signed, info = XCM.teleport_to_parachain(api, bob, bob.pubkey, amount, {
    para_id = 1000 -- Westend AssetHub
})

-- Submit
local http = require("socket.http")
local ltn12 = require("ltn12")
local json = require("cjson")

local body = json.encode({jsonrpc="2.0", method="author_submitExtrinsic", params={signed}, id=1})
local resp_body = {}
http.request{
    url = "https://westend-rpc.polkadot.io",
    method = "POST",
    headers = {["Content-Type"]="application/json", ["Content-Length"]=tostring(#body)},
    source = ltn12.source.string(body),
    sink = ltn12.sink.table(resp_body),
    redirect = true
}

local resp = json.decode(table.concat(resp_body))
if resp.result then
    print("\n✅ XCM Teleport submitted!")
    print("TX Hash: " .. resp.result)
    print("Explorer: https://westend.subscan.io/extrinsic/" .. resp.result)
elseif resp.error then
    print("\n❌ Error: " .. tostring(resp.error.message) .. " - " .. tostring(resp.error.data))
end
