-- sdk/core/chain_config.lua
-- Chain configuration for popular Substrate networks

local ChainConfig = {}

-- Predefined chain configurations
ChainConfig.CHAINS = {
    POLKADOT = {
        name = "Polkadot",
        rpc_urls = {
            "wss://rpc.polkadot.io",
            "wss://polkadot.api.onfinality.io/public-ws"
        },
        ss58_prefix = 0,
        token_symbol = "DOT",
        token_decimals = 10,
        existential_deposit = 10000000000  -- 1 DOT
    },
    
    KUSAMA = {
        name = "Kusama",
        rpc_urls = {
            "wss://kusama-rpc.polkadot.io",
            "wss://kusama.api.onfinality.io/public-ws"
        },
        ss58_prefix = 2,
        token_symbol = "KSM",
        token_decimals = 12,
        existential_deposit = 333333333  -- ~0.000333 KSM
    },
    
    WESTEND = {
        name = "Westend Testnet",
        rpc_urls = {
            "wss://westend-rpc.polkadot.io",
            "wss://rpc.ibp.network/westend"
        },
        ss58_prefix = 42,
        token_symbol = "WND",
        token_decimals = 12,
        existential_deposit = 10000000000  -- 0.01 WND
    },
    
    PASEO = {
        name = "Paseo Testnet",
        rpc_urls = {
            "wss://paseo.rpc.amforc.com",
            "wss://paseo.dotters.network",
            "wss://rpc.ibp.network/paseo"
        },
        ss58_prefix = 0,
        token_symbol = "PAS",
        token_decimals = 10,
        existential_deposit = 10000000000  -- 1 PAS
    },
    
    ROCOCO = {
        name = "Rococo Testnet",
        rpc_urls = {
            "wss://rococo-rpc.polkadot.io"
        },
        ss58_prefix = 42,
        token_symbol = "ROC",
        token_decimals = 12,
        existential_deposit = 33333333  -- ~0.000033 ROC
    },
    
    -- Generic Substrate chain (fallback)
    SUBSTRATE = {
        name = "Substrate",
        rpc_urls = {},
        ss58_prefix = 42,
        token_symbol = "UNIT",
        token_decimals = 12,
        existential_deposit = 1000000000000  -- 1 UNIT
    }
}

-- Get chain configuration by name
function ChainConfig.get(chain_name)
    local chain = ChainConfig.CHAINS[string.upper(chain_name)]
    if not chain then
        print("Warning: Unknown chain '" .. chain_name .. "', using Substrate defaults")
        return ChainConfig.CHAINS.SUBSTRATE
    end
    return chain
end

-- Auto-detect chain from RPC URL
function ChainConfig.detect_from_url(rpc_url)
    local url_lower = string.lower(rpc_url)
    
    if url_lower:match("polkadot") then
        return ChainConfig.CHAINS.POLKADOT
    elseif url_lower:match("kusama") then
        return ChainConfig.CHAINS.KUSAMA
    elseif url_lower:match("westend") then
        return ChainConfig.CHAINS.WESTEND
    elseif url_lower:match("paseo") then
        return ChainConfig.CHAINS.PASEO
    elseif url_lower:match("rococo") then
        return ChainConfig.CHAINS.ROCOCO
    else
        return ChainConfig.CHAINS.SUBSTRATE
    end
end

-- Create a custom chain configuration
function ChainConfig.custom(config)
    return {
        name = config.name or "Custom Chain",
        rpc_urls = config.rpc_urls or {},
        ss58_prefix = config.ss58_prefix or 42,
        token_symbol = config.token_symbol or "UNIT",
        token_decimals = config.token_decimals or 12,
        existential_deposit = config.existential_deposit or 1000000000000
    }
end

return ChainConfig 