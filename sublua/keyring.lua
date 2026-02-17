-- polkadot/keyring.lua
-- Simplified Keypair management (Ed25519) in Pure Lua (using crypto bindings)

local crypto = require("polkadot_crypto")
-- local ss58 = require("polkadot.ss58") -- Removed, using crypto module direct

local Keyring = {}

function Keyring.from_seed(seed_hex)
    local seed
    if seed_hex:match("^0x") then
        seed = (seed_hex:gsub("^0x", ""):gsub("..", function(cc) return string.char(tonumber(cc, 16)) end))
    else
        seed = seed_hex
    end
    
    if #seed ~= 32 then
        error("Seed must be 32 bytes")
    end
    
    local pubkey = crypto.ed25519_keypair_from_seed(seed)
    
    return {
        seed = seed,
        pubkey = pubkey,
        address = crypto.ss58_encode(pubkey, 42), -- Default Substrate 42
        sign = function(self, msg)
            return crypto.ed25519_sign(self.seed, msg)
        end
    }
end

function Keyring.from_uri(uri)
    if uri == "//Alice" then
        return Keyring.from_seed(string.rep("a", 32)) -- Mock Ed25519 "Alice"
    elseif uri == "//Bob" then
        return Keyring.from_seed(string.rep("b", 32)) -- Mock Ed25519 "Bob"
    elseif uri == "//Charlie" then
        return Keyring.from_seed(string.rep("c", 32)) -- Mock Ed25519 "Charlie"
    end
    error("Keyring URI parsing not fully implemented in Pure Lua (requires BIP39/PBKDF2)")
end

return Keyring
