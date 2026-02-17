-- polkadot/init.lua
local Polkadot = {}

-- Load C module (it must be in package.cpath)
-- Users might need to set package.cpath or use a loader
local status, crypto = pcall(require, "polkadot_crypto")
if not status then
    -- Try to load from relative path for dev/testing
    local path = debug.getinfo(1).source:match("@?(.*/)")
    if path then
        package.cpath = package.cpath .. ";" .. path .. "../../c_src/?.so"
        status, crypto = pcall(require, "polkadot_crypto")
    end
    
    if not status then
        error("Failed to load polkadot_crypto C module: " .. tostring(crypto))
    end
end

Polkadot.crypto = crypto
Polkadot.rpc = require("polkadot.rpc")
-- Polkadot.ss58 is now available via crypto.ss58_encode/decode

-- Convenience
function Polkadot.connect(url)
    return Polkadot.rpc.new(url)
end

return Polkadot
