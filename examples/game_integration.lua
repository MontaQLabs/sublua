-- examples/game_integration.lua
-- Game integration example for SubLua SDK

-- Add local path for development
package.path = package.path .. ";./?.lua;./?/init.lua;./sublua/?.lua"

local sublua = require("sublua")

print("🎮 SubLua Game Integration Example")
print("==================================")
print("Version:", sublua.version)

-- Load FFI
print("\nLoading FFI library...")
sublua.ffi()

-- Game configuration
local GAME_CONFIG = {
    rpc_url = "wss://westend-rpc.polkadot.io",
    player_mnemonic = "helmet myself order all require large unusual verify ritual final apart nut",
    game_contract_address = "5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY",
    min_balance = 1000000000000, -- 1 WND minimum for game
    transaction_fee = 100000000000, -- 0.1 WND fee
    westend_prefix = 42,
    token_symbol = "WND",
    token_decimals = 12
}

-- Game state
local GameState = {
    player = nil,
    player_address = nil,
    balance = 0,
    is_connected = false,
    ffi = nil,
    ffi_lib = nil
}

-- Initialize game
function GameState:init()
    print("\n1️⃣ Initializing game...")
    
    -- Set up FFI
    local polkadot_ffi = require("sublua.polkadot_ffi")
    self.ffi = polkadot_ffi.ffi
    self.ffi_lib = polkadot_ffi.get_lib()
    
    -- Create player signer
    local signer_module = sublua.signer()
    self.player = signer_module.from_mnemonic(GAME_CONFIG.player_mnemonic)
    self.player_address = self.player:get_ss58_address(GAME_CONFIG.westend_prefix)
    
    print("✅ Game initialized")
    print("   Chain: Westend")
    print("   Player:", self.player_address)
    
    return self:check_connection()
end

-- Check blockchain connection
function GameState:check_connection()
    print("\n2️⃣ Checking blockchain connection...")
    
    local url_cstr = self.ffi.new("char[?]", #GAME_CONFIG.rpc_url + 1)
    self.ffi.copy(url_cstr, GAME_CONFIG.rpc_url)
    
    local addr_cstr = self.ffi.new("char[?]", #self.player_address + 1)
    self.ffi.copy(addr_cstr, self.player_address)
    
    local result = self.ffi_lib.query_balance(url_cstr, addr_cstr)
    
    if result.success then
        local data_str = self.ffi.string(result.data)
        self.ffi_lib.free_string(result.data)
        
        local free_match = data_str:match('U128%((%d+)%)')
        if free_match then
            self.balance = tonumber(free_match)
            self.is_connected = true
            local balance_tokens = self.balance / (10 ^ GAME_CONFIG.token_decimals)
            print("✅ Connected to blockchain")
            print(string.format("   Balance: %.5f %s", balance_tokens, GAME_CONFIG.token_symbol))
            return true
        end
    end
    
    print("❌ Failed to connect to blockchain")
    return false
end

-- Check if player has sufficient balance
function GameState:has_sufficient_balance()
    local required = GAME_CONFIG.min_balance + GAME_CONFIG.transaction_fee
    return self.balance >= required
end

-- Game action: Purchase item
function GameState:purchase_item(item_id, price)
    local price_tokens = price / (10 ^ GAME_CONFIG.token_decimals)
    print(string.format("\n🛒 Purchasing item %s for %.4f %s", item_id, price_tokens, GAME_CONFIG.token_symbol))
    
    if not self:has_sufficient_balance() then
        print("❌ Insufficient balance for purchase")
        return false, "Insufficient balance"
    end
    
    -- Prepare FFI call
    local url_cstr = self.ffi.new("char[?]", #GAME_CONFIG.rpc_url + 1)
    self.ffi.copy(url_cstr, GAME_CONFIG.rpc_url)
    
    local mnemonic_cstr = self.ffi.new("char[?]", #GAME_CONFIG.player_mnemonic + 1)
    self.ffi.copy(mnemonic_cstr, GAME_CONFIG.player_mnemonic)
    
    local dest_cstr = self.ffi.new("char[?]", #GAME_CONFIG.game_contract_address + 1)
    self.ffi.copy(dest_cstr, GAME_CONFIG.game_contract_address)
    
    local result = self.ffi_lib.submit_balance_transfer_subxt(url_cstr, mnemonic_cstr, dest_cstr, price)
    
    if result.success then
        local tx_hash = self.ffi.string(result.tx_hash)
        self.ffi_lib.free_string(result.tx_hash)
        print("✅ Purchase transaction submitted")
        print("   Transaction hash:", tx_hash)
        self.balance = self.balance - price - GAME_CONFIG.transaction_fee
        return true, tx_hash
    else
        local err_str = self.ffi.string(result.error)
        self.ffi_lib.free_string(result.error)
        print("❌ Purchase failed:", err_str)
        return false, err_str
    end
end

-- Game action: Earn rewards
function GameState:earn_rewards(amount)
    local amount_tokens = amount / (10 ^ GAME_CONFIG.token_decimals)
    print(string.format("\n🏆 Earning rewards: %.4f %s", amount_tokens, GAME_CONFIG.token_symbol))
    print("✅ Rewards earned (simulated)")
    return true
end

-- Game action: Transfer to another player
function GameState:transfer_to_player(recipient_address, amount)
    local amount_tokens = amount / (10 ^ GAME_CONFIG.token_decimals)
    print("\n💸 Transferring to player:", recipient_address)
    print(string.format("   Amount: %.4f %s", amount_tokens, GAME_CONFIG.token_symbol))
    
    if not self:has_sufficient_balance() then
        print("❌ Insufficient balance for transfer")
        return false, "Insufficient balance"
    end
    
    local url_cstr = self.ffi.new("char[?]", #GAME_CONFIG.rpc_url + 1)
    self.ffi.copy(url_cstr, GAME_CONFIG.rpc_url)
    
    local mnemonic_cstr = self.ffi.new("char[?]", #GAME_CONFIG.player_mnemonic + 1)
    self.ffi.copy(mnemonic_cstr, GAME_CONFIG.player_mnemonic)
    
    local dest_cstr = self.ffi.new("char[?]", #recipient_address + 1)
    self.ffi.copy(dest_cstr, recipient_address)
    
    local result = self.ffi_lib.submit_balance_transfer_subxt(url_cstr, mnemonic_cstr, dest_cstr, amount)
    
    if result.success then
        local tx_hash = self.ffi.string(result.tx_hash)
        self.ffi_lib.free_string(result.tx_hash)
        print("✅ Transfer completed")
        print("   Transaction hash:", tx_hash)
        self.balance = self.balance - amount - GAME_CONFIG.transaction_fee
        return true, tx_hash
    else
        local err_str = self.ffi.string(result.error)
        self.ffi_lib.free_string(result.error)
        print("❌ Transfer failed:", err_str)
        return false, err_str
    end
end

-- Get player statistics
function GameState:get_player_stats()
    print("\n📊 Player Statistics")
    print("===================")
    print("Address:", self.player_address)
    local balance_tokens = self.balance / (10 ^ GAME_CONFIG.token_decimals)
    print(string.format("Balance: %.5f %s", balance_tokens, GAME_CONFIG.token_symbol))
    print("Connected:", self.is_connected and "Yes" or "No")
    print("Can play:", self:has_sufficient_balance() and "Yes" or "No")
end

-- Refresh balance
function GameState:refresh_balance()
    print("\n🔄 Refreshing balance...")
    return self:check_connection()
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
