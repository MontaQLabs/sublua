-- sublua/init.lua
-- SubLua: Lightweight Polkadot/Substrate SDK for Lua
local SubLua = {}

-- Load C module: try LuaRocks path first, then bare name, then dev path
local status, crypto = pcall(require, "sublua.polkadot_crypto")
if not status then
    status, crypto = pcall(require, "polkadot_crypto")
end
if not status then
    local path = debug.getinfo(1).source:match("@?(.*/)")
    if path then
        package.cpath = package.cpath .. ";" .. path .. "?.so;" .. path .. "?.dll"
        status, crypto = pcall(require, "polkadot_crypto")
    end
    if not status then
        error("Failed to load polkadot_crypto C module: " .. tostring(crypto))
    end
end

-- Preload under both names so submodules find it regardless of install method
package.preload["polkadot_crypto"] = package.preload["polkadot_crypto"] or function() return crypto end
package.preload["sublua.polkadot_crypto"] = package.preload["sublua.polkadot_crypto"] or function() return crypto end
package.loaded["polkadot_crypto"] = package.loaded["polkadot_crypto"] or crypto
package.loaded["sublua.polkadot_crypto"] = package.loaded["sublua.polkadot_crypto"] or crypto

SubLua.crypto = crypto
SubLua.keyring = require("sublua.keyring")
SubLua.transaction = require("sublua.transaction")
SubLua.scale = require("sublua.scale")
SubLua.call = require("sublua.call")
SubLua.rpc = require("sublua.rpc")
SubLua.metadata = require("sublua.metadata")
SubLua.xcm = require("sublua.xcm")

-- Convenience
function SubLua.connect(url)
    return SubLua.rpc.new(url)
end

return SubLua
