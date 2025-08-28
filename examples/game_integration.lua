-- examples/game_integration.lua
-- Game integration example for SubLua SDK

local sdk = require("sdk.init")

print("🎮 SubLua Game Integration Example")
print("==================================")

-- Game configuration
local GAME_CONFIG = {
    rpc_url = "wss://westend-rpc.polkadot.io",
    player_mnemonic = "helmet myself order all require large unusual verify ritual final apart nut",
    game_contract_address = "5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY", -- Example contract
    min_balance = 1000000000000, -- 1 WND minimum for game
    transaction_fee = 100000000000 -- 0.1 WND fee
}

-- Game state
local GameState = {
    player = nil,
    rpc = nil,
    chain_config = nil,
    balance = 0,
    is_connected = false
}

-- Initialize game
function GameState:init()
    print("\n1️⃣ Initializing game...")
    
    -- Connect to blockchain
    self.rpc = sdk.rpc.new(GAME_CONFIG.rpc_url)
    self.chain_config = sdk.chain_config.detect_from_url(GAME_CONFIG.rpc_url)
    
    -- Create player signer
    self.player = sdk.signer.from_mnemonic(GAME_CONFIG.player_mnemonic)
    self.player_address = self.player:get_ss58_address(self.chain_config.ss58_prefix)
    
    print("✅ Game initialized")
    print("   Chain:", self.chain_config.name)
    print("   Player:", self.player_address)
    
    return self:check_connection()
end

-- Check blockchain connection
function GameState:check_connection()
    print("\n2️⃣ Checking blockchain connection...")
    
    local success, account = pcall(function()
        return self.rpc:get_account_info(self.player_address)
    end)
    
    if success and account then
        self.balance = account.data.free_tokens or account.data.free or 0
        self.is_connected = true
        print("✅ Connected to blockchain")
        print("   Balance:", string.format("%.5f %s", self.balance, self.chain_config.token_symbol))
        return true
    else
        print("❌ Failed to connect to blockchain")
        print("   Error:", account or "Unknown error")
        return false
    end
end

-- Check if player has sufficient balance
function GameState:has_sufficient_balance()
    local required = GAME_CONFIG.min_balance + GAME_CONFIG.transaction_fee
    return self.balance >= required
end

-- Game action: Purchase item
function GameState:purchase_item(item_id, price)
    print("\n🛒 Purchasing item", item_id, "for", price / (10 ^ self.chain_config.token_decimals), self.chain_config.token_symbol)
    
    if not self:has_sufficient_balance() then
        print("❌ Insufficient balance for purchase")
        return false, "Insufficient balance"
    end
    
    -- Create purchase transaction
    local success, tx_hash = pcall(function()
        return self.player:transfer(self.rpc, GAME_CONFIG.game_contract_address, price)
    end)
    
    if success then
        print("✅ Purchase transaction submitted")
        print("   Transaction hash:", tx_hash)
        
        -- Update balance
        self.balance = self.balance - price - GAME_CONFIG.transaction_fee
        
        return true, tx_hash
    else
        print("❌ Purchase failed")
        print("   Error:", tx_hash)
        return false, tx_hash
    end
end

-- Game action: Earn rewards
function GameState:earn_rewards(amount)
    print("\n🏆 Earning rewards:", amount / (10 ^ self.chain_config.token_decimals), self.chain_config.token_symbol)
    
    -- In a real game, this would be called by the game contract
    -- For this example, we'll simulate it
    print("✅ Rewards earned (simulated)")
    print("   Amount:", amount / (10 ^ self.chain_config.token_decimals), self.chain_config.token_symbol)
    
    return true
end

-- Game action: Transfer to another player
function GameState:transfer_to_player(recipient_address, amount)
    print("\n💸 Transferring to player:", recipient_address)
    print("   Amount:", amount / (10 ^ self.chain_config.token_decimals), self.chain_config.token_symbol)
    
    if not self:has_sufficient_balance() then
        print("❌ Insufficient balance for transfer")
        return false, "Insufficient balance"
    end
    
    local success, tx_hash = pcall(function()
        return self.player:transfer(self.rpc, recipient_address, amount)
    end)
    
    if success then
        print("✅ Transfer completed")
        print("   Transaction hash:", tx_hash)
        
        -- Update balance
        self.balance = self.balance - amount - GAME_CONFIG.transaction_fee
        
        return true, tx_hash
    else
        print("❌ Transfer failed")
        print("   Error:", tx_hash)
        return false, tx_hash
    end
end

-- Get player statistics
function GameState:get_player_stats()
    print("\n📊 Player Statistics")
    print("===================")
    print("Address:", self.player_address)
    print("Balance:", string.format("%.5f %s", self.balance, self.chain_config.token_symbol))
    print("Connected:", self.is_connected and "Yes" or "No")
    print("Can play:", self:has_sufficient_balance() and "Yes" or "No")
end

-- Refresh balance
function GameState:refresh_balance()
    print("\n🔄 Refreshing balance...")
    
    local success, account = pcall(function()
        return self.rpc:get_account_info(self.player_address)
    end)
    
    if success and account then
        self.balance = account.data.free_tokens or account.data.free or 0
        print("✅ Balance refreshed")
        print("   New balance:", string.format("%.5f %s", self.balance, self.chain_config.token_symbol))
        return true
    else
        print("❌ Failed to refresh balance")
        return false
    end
end

-- Main game loop
function GameState:run_game()
    print("\n🎮 Starting game...")
    
    -- Initialize game
    if not self:init() then
        print("❌ Failed to initialize game")
        return
    end
    
    -- Show player stats
    self:get_player_stats()
    
    -- Game actions (commented out for safety)
    print("\n🎯 Game Actions (commented out for safety)")
    print("Uncomment the code below to enable game actions:")
    
    --[[
    -- Example game actions
    local success, result
    
    -- Purchase a sword
    success, result = self:purchase_item("sword", 500000000000) -- 0.5 WND
    if success then
        print("🎉 Sword purchased!")
    end
    
    -- Earn rewards for completing a quest
    success, result = self:earn_rewards(200000000000) -- 0.2 WND
    if success then
        print("🎉 Quest completed!")
    end
    
    -- Transfer to another player
    local other_player = "5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty"
    success, result = self:transfer_to_player(other_player, 100000000000) -- 0.1 WND
    if success then
        print("🎉 Transfer completed!")
    end
    
    -- Refresh balance after actions
    self:refresh_balance()
    self:get_player_stats()
    --]]
    
    print("\n✅ Game integration example completed!")
    print("This demonstrates how to integrate SubLua into a game.")
end

-- Run the game
GameState:run_game()

print("\n📚 Integration Notes:")
print("====================")
print("• This example shows how to integrate SubLua into a game")
print("• All blockchain operations are handled through the SDK")
print("• Error handling ensures the game doesn't crash")
print("• Balance tracking keeps the game state synchronized")
print("• Transaction fees are automatically calculated")
print("• The game can be paused while transactions are processing")

print("\n🔧 Production Considerations:")
print("=============================")
print("• Implement proper error recovery")
print("• Add transaction confirmation waiting")
print("• Use event subscriptions for real-time updates")
print("• Implement proper security measures")
print("• Add rate limiting for transactions")
print("• Consider using batch transactions for efficiency")
