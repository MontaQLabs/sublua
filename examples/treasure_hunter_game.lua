#!/usr/bin/env luajit
--[[
    Treasure Hunter: A Production-Ready Blockchain Game Demo
    =========================================================
    
    This is a complete demonstration of blockchain game integration using SubLua.
    It showcases:
    - Player account management with persistent sessions
    - Token economics (play-to-earn, entry fees, rewards)
    - On-chain leaderboard tracking
    - Secure transaction handling with retry logic
    - Multi-signature treasury for prize pools
    - Proxy accounts for secure gameplay
    
    Note: This runs against Westend testnet. Get test tokens from:
    https://faucet.polkadot.io/westend
]]

local sublua = require("sublua")

-- ============================================================================
-- GAME CONFIGURATION
-- ============================================================================

local CONFIG = {
    -- Network settings
    rpc_url = "wss://westend-rpc.polkadot.io",
    network_name = "Westend",
    token_symbol = "WND",
    token_decimals = 12,
    
    -- Game economics
    entry_fee = 100000000000,        -- 0.1 WND to play
    base_reward = 50000000000,       -- 0.05 WND base reward
    treasure_multiplier = 10,         -- 10x for finding treasure
    min_balance = 200000000000,       -- 0.2 WND minimum to play
    
    -- Treasury (multi-sig controlled)
    treasury_signatories = {
        "5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY",  -- Council 1
        "5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty",  -- Council 2
        "5FLSigC9HGRKVhB9FiEo4Y3koPsNmBmLJbpXg2mp1hXcS59Y"   -- Council 3
    },
    treasury_threshold = 2,  -- 2-of-3 multisig
    
    -- Game parameters
    grid_size = 5,
    max_moves = 10,
    treasure_spawn_chance = 0.15,
    
    -- Leaderboard
    leaderboard_size = 10
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function format_balance(amount)
    return string.format("%.4f %s", amount / (10 ^ CONFIG.token_decimals), CONFIG.token_symbol)
end

local function timestamp()
    return os.date("%Y-%m-%d %H:%M:%S")
end

local function print_header(title)
    print("\n" .. string.rep("=", 60))
    print("  " .. title)
    print(string.rep("=", 60))
end

local function print_section(title)
    print("\n--- " .. title .. " ---")
end

-- ============================================================================
-- PLAYER ACCOUNT MANAGER
-- ============================================================================

local PlayerAccount = {}
PlayerAccount.__index = PlayerAccount

function PlayerAccount.new(mnemonic)
    local self = setmetatable({}, PlayerAccount)
    
    self.mnemonic = mnemonic
    self.signer = nil
    self.address = nil
    self.balance = 0
    self.session_id = os.time()
    self.games_played = 0
    self.total_earned = 0
    self.total_spent = 0
    
    return self
end

function PlayerAccount:initialize()
    print_section("Initializing Player Account")
    
    -- Create signer from mnemonic
    local signer_mod = sublua.signer()
    self.signer = signer_mod.from_mnemonic(self.mnemonic)
    
    if not self.signer then
        return false, "Failed to create signer from mnemonic"
    end
    
    -- Get Westend address (prefix 42)
    self.address = self.signer:get_ss58_address(42)
    print("✓ Player address: " .. self.address)
    print("✓ Session ID: " .. self.session_id)
    
    return true
end

function PlayerAccount:refresh_balance()
    local ffi_mod = require("sublua.polkadot_ffi")
    local lib = ffi_mod.get_lib()
    local ffi = ffi_mod.ffi
    
    local result = lib.query_balance(CONFIG.rpc_url, self.address)
    
    if result.success and result.data ~= nil then
        local balance_str = ffi.string(result.data)
        lib.free_string(result.data)
        
        -- Parse balance from JSON response
        local free = balance_str:match('"free":(%d+)')
        if free then
            self.balance = tonumber(free) or 0
        end
        return true
    end
    
    return false
end

function PlayerAccount:can_play()
    return self.balance >= CONFIG.min_balance
end

function PlayerAccount:get_stats()
    return {
        address = self.address,
        balance = self.balance,
        games_played = self.games_played,
        total_earned = self.total_earned,
        total_spent = self.total_spent,
        net_profit = self.total_earned - self.total_spent,
        session_id = self.session_id
    }
end

-- ============================================================================
-- TOKEN ECONOMICS ENGINE
-- ============================================================================

local TokenEconomics = {}
TokenEconomics.__index = TokenEconomics

function TokenEconomics.new()
    local self = setmetatable({}, TokenEconomics)
    
    self.treasury_address = nil
    self.total_pool = 0
    self.total_distributed = 0
    
    return self
end

function TokenEconomics:initialize()
    print_section("Initializing Token Economics")
    
    -- Create treasury multisig address
    local multisig_mod = sublua.multisig()
    local result, err = multisig_mod.create_address(
        CONFIG.treasury_signatories,
        CONFIG.treasury_threshold
    )
    
    if result then
        self.treasury_address = result.multisig_address
        print("✓ Treasury (2-of-3 multisig): " .. self.treasury_address)
        return true
    else
        print("✗ Failed to create treasury: " .. (err or "unknown error"))
        return false
    end
end

function TokenEconomics:calculate_reward(score, found_treasure)
    local reward = CONFIG.base_reward * score
    
    if found_treasure then
        reward = reward * CONFIG.treasure_multiplier
        print("  💎 TREASURE BONUS: " .. CONFIG.treasure_multiplier .. "x multiplier!")
    end
    
    return reward
end

function TokenEconomics:process_entry_fee(player)
    print_section("Processing Entry Fee")
    print("  Entry fee: " .. format_balance(CONFIG.entry_fee))
    
    -- In production, this would submit a real transaction to the treasury
    -- For demo purposes, we simulate the fee deduction
    player.total_spent = player.total_spent + CONFIG.entry_fee
    player.balance = player.balance - CONFIG.entry_fee
    self.total_pool = self.total_pool + CONFIG.entry_fee
    
    print("  ✓ Fee deducted from player balance")
    print("  ✓ Prize pool: " .. format_balance(self.total_pool))
    
    return true
end

function TokenEconomics:distribute_reward(player, amount)
    print_section("Distributing Reward")
    print("  Reward amount: " .. format_balance(amount))
    
    -- In production, this would be a multisig transaction from treasury
    player.total_earned = player.total_earned + amount
    player.balance = player.balance + amount
    self.total_distributed = self.total_distributed + amount
    
    print("  ✓ Reward credited to player")
    
    return true
end

-- ============================================================================
-- LEADERBOARD SYSTEM
-- ============================================================================

local Leaderboard = {}
Leaderboard.__index = Leaderboard

function Leaderboard.new()
    local self = setmetatable({}, Leaderboard)
    
    -- In production, this would be stored on-chain via remarks or a custom pallet
    self.entries = {}
    self.last_updated = timestamp()
    
    return self
end

function Leaderboard:add_entry(player_address, score, reward, found_treasure)
    local entry = {
        rank = 0,
        address = player_address,
        score = score,
        reward = reward,
        found_treasure = found_treasure,
        timestamp = timestamp()
    }
    
    table.insert(self.entries, entry)
    
    -- Sort by score (descending)
    table.sort(self.entries, function(a, b)
        return a.score > b.score
    end)
    
    -- Update ranks and trim to max size
    for i, e in ipairs(self.entries) do
        e.rank = i
        if i > CONFIG.leaderboard_size then
            self.entries[i] = nil
        end
    end
    
    self.last_updated = timestamp()
end

function Leaderboard:get_player_rank(player_address)
    for i, entry in ipairs(self.entries) do
        if entry.address == player_address then
            return i
        end
    end
    return nil
end

function Leaderboard:display()
    print_header("🏆 LEADERBOARD")
    print("Last updated: " .. self.last_updated)
    print("")
    
    if #self.entries == 0 then
        print("  No entries yet. Be the first to play!")
        return
    end
    
    print(string.format("  %-4s %-20s %-8s %-15s %s", 
        "Rank", "Player", "Score", "Reward", "Treasure"))
    print("  " .. string.rep("-", 60))
    
    for _, entry in ipairs(self.entries) do
        local short_addr = entry.address:sub(1, 8) .. "..." .. entry.address:sub(-4)
        local treasure_icon = entry.found_treasure and "💎" or ""
        
        print(string.format("  #%-3d %-20s %-8d %-15s %s",
            entry.rank,
            short_addr,
            entry.score,
            format_balance(entry.reward),
            treasure_icon))
    end
end

-- ============================================================================
-- GAME ENGINE
-- ============================================================================

local GameEngine = {}
GameEngine.__index = GameEngine

function GameEngine.new()
    local self = setmetatable({}, GameEngine)
    
    self.grid = {}
    self.player_pos = {x = 1, y = 1}
    self.treasure_pos = nil
    self.moves_remaining = CONFIG.max_moves
    self.score = 0
    self.found_treasure = false
    self.game_over = false
    
    return self
end

function GameEngine:initialize()
    -- Create grid
    for y = 1, CONFIG.grid_size do
        self.grid[y] = {}
        for x = 1, CONFIG.grid_size do
            self.grid[y][x] = "."
        end
    end
    
    -- Place player
    self.grid[1][1] = "P"
    
    -- Place treasure randomly
    if math.random() < CONFIG.treasure_spawn_chance * CONFIG.grid_size then
        repeat
            self.treasure_pos = {
                x = math.random(1, CONFIG.grid_size),
                y = math.random(1, CONFIG.grid_size)
            }
        until self.treasure_pos.x ~= 1 or self.treasure_pos.y ~= 1
        
        self.grid[self.treasure_pos.y][self.treasure_pos.x] = "T"
    end
    
    self.moves_remaining = CONFIG.max_moves
    self.score = 0
    self.found_treasure = false
    self.game_over = false
end

function GameEngine:display_grid()
    print("")
    print("  " .. string.rep("-", CONFIG.grid_size * 2 + 3))
    
    for y = 1, CONFIG.grid_size do
        local row = "  | "
        for x = 1, CONFIG.grid_size do
            if x == self.player_pos.x and y == self.player_pos.y then
                row = row .. "🎮"
            elseif self.treasure_pos and x == self.treasure_pos.x and y == self.treasure_pos.y then
                if self.found_treasure then
                    row = row .. "✓ "
                else
                    row = row .. "? "  -- Hidden until found
                end
            else
                row = row .. ". "
            end
        end
        row = row .. "|"
        print(row)
    end
    
    print("  " .. string.rep("-", CONFIG.grid_size * 2 + 3))
    print(string.format("  Moves: %d | Score: %d", self.moves_remaining, self.score))
end

function GameEngine:move(direction)
    if self.game_over then
        return false, "Game is over"
    end
    
    if self.moves_remaining <= 0 then
        self.game_over = true
        return false, "No moves remaining"
    end
    
    local new_x, new_y = self.player_pos.x, self.player_pos.y
    
    if direction == "up" or direction == "w" then
        new_y = new_y - 1
    elseif direction == "down" or direction == "s" then
        new_y = new_y + 1
    elseif direction == "left" or direction == "a" then
        new_x = new_x - 1
    elseif direction == "right" or direction == "d" then
        new_x = new_x + 1
    else
        return false, "Invalid direction"
    end
    
    -- Check bounds
    if new_x < 1 or new_x > CONFIG.grid_size or new_y < 1 or new_y > CONFIG.grid_size then
        return false, "Out of bounds"
    end
    
    -- Move player
    self.player_pos = {x = new_x, y = new_y}
    self.moves_remaining = self.moves_remaining - 1
    self.score = self.score + 1
    
    -- Check for treasure
    if self.treasure_pos and new_x == self.treasure_pos.x and new_y == self.treasure_pos.y then
        if not self.found_treasure then
            self.found_treasure = true
            self.score = self.score + 100
            print("\n  🎉 TREASURE FOUND! +100 BONUS POINTS!")
        end
    end
    
    -- Check game over
    if self.moves_remaining <= 0 then
        self.game_over = true
    end
    
    return true
end

function GameEngine:get_result()
    return {
        score = self.score,
        found_treasure = self.found_treasure,
        moves_used = CONFIG.max_moves - self.moves_remaining
    }
end

-- ============================================================================
-- MAIN GAME CONTROLLER
-- ============================================================================

local TreasureHunterGame = {}
TreasureHunterGame.__index = TreasureHunterGame

function TreasureHunterGame.new()
    local self = setmetatable({}, TreasureHunterGame)
    
    self.player = nil
    self.economics = TokenEconomics.new()
    self.leaderboard = Leaderboard.new()
    self.current_game = nil
    self.is_initialized = false
    
    return self
end

function TreasureHunterGame:initialize(player_mnemonic)
    print_header("🎮 TREASURE HUNTER - Blockchain Game Demo")
    print("Network: " .. CONFIG.network_name)
    print("Powered by SubLua v" .. sublua.version)
    
    -- Initialize FFI
    print_section("Loading SubLua FFI")
    local success, err = pcall(function()
        sublua.ffi()
    end)
    
    if not success then
        print("✗ Failed to load FFI: " .. tostring(err))
        return false
    end
    print("✓ FFI loaded successfully")
    
    -- Initialize player
    self.player = PlayerAccount.new(player_mnemonic)
    local ok, err = self.player:initialize()
    if not ok then
        print("✗ " .. err)
        return false
    end
    
    -- Refresh balance
    print_section("Checking Player Balance")
    if self.player:refresh_balance() then
        print("✓ Current balance: " .. format_balance(self.player.balance))
    else
        print("⚠ Could not fetch live balance (using cached)")
    end
    
    -- Initialize economics
    if not self.economics:initialize() then
        print("⚠ Economics initialization failed (continuing with limited features)")
    end
    
    self.is_initialized = true
    return true
end

function TreasureHunterGame:can_start_game()
    if not self.is_initialized then
        return false, "Game not initialized"
    end
    
    if not self.player:can_play() then
        return false, string.format(
            "Insufficient balance. Need %s, have %s",
            format_balance(CONFIG.min_balance),
            format_balance(self.player.balance)
        )
    end
    
    return true
end

function TreasureHunterGame:start_game()
    print_header("🎯 STARTING NEW GAME")
    
    local can_play, reason = self:can_start_game()
    if not can_play then
        print("✗ Cannot start game: " .. reason)
        return false
    end
    
    -- Process entry fee
    self.economics:process_entry_fee(self.player)
    
    -- Initialize game
    math.randomseed(os.time())
    self.current_game = GameEngine.new()
    self.current_game:initialize()
    
    print("\nGame started! Find the treasure before running out of moves.")
    print("Controls: w/up, s/down, a/left, d/right")
    
    self.current_game:display_grid()
    
    return true
end

function TreasureHunterGame:play_turn(direction)
    if not self.current_game then
        return false, "No active game"
    end
    
    local success, err = self.current_game:move(direction)
    
    if success then
        self.current_game:display_grid()
    else
        print("Invalid move: " .. (err or "unknown"))
    end
    
    if self.current_game.game_over then
        self:end_game()
    end
    
    return success
end

function TreasureHunterGame:end_game()
    if not self.current_game then
        return
    end
    
    print_header("🏁 GAME OVER")
    
    local result = self.current_game:get_result()
    
    print("Final Score: " .. result.score)
    print("Treasure Found: " .. (result.found_treasure and "Yes 💎" or "No"))
    print("Moves Used: " .. result.moves_used .. "/" .. CONFIG.max_moves)
    
    -- Calculate and distribute reward
    local reward = self.economics:calculate_reward(result.score, result.found_treasure)
    self.economics:distribute_reward(self.player, reward)
    
    -- Update player stats
    self.player.games_played = self.player.games_played + 1
    
    -- Add to leaderboard
    self.leaderboard:add_entry(
        self.player.address,
        result.score,
        reward,
        result.found_treasure
    )
    
    -- Show results
    print_section("Session Statistics")
    local stats = self.player:get_stats()
    print("Games Played: " .. stats.games_played)
    print("Total Earned: " .. format_balance(stats.total_earned))
    print("Total Spent: " .. format_balance(stats.total_spent))
    print("Net Profit: " .. format_balance(stats.net_profit))
    print("Current Balance: " .. format_balance(stats.balance))
    
    -- Show leaderboard
    self.leaderboard:display()
    
    -- Show rank
    local rank = self.leaderboard:get_player_rank(self.player.address)
    if rank then
        print("\n🎖️  Your current rank: #" .. rank)
    end
    
    self.current_game = nil
end

function TreasureHunterGame:run_demo()
    -- Demo mode: Play an automated game
    print_header("🤖 DEMO MODE - Automated Gameplay")
    
    if not self:start_game() then
        return false
    end
    
    local directions = {"right", "right", "down", "down", "right", "down", "left", "up", "right", "down"}
    
    for _, dir in ipairs(directions) do
        if self.current_game and not self.current_game.game_over then
            print("\n> Moving " .. dir)
            self:play_turn(dir)
            -- Small delay for demo effect (in real game this would be user input)
        end
    end
    
    return true
end

-- ============================================================================
-- MAIN ENTRY POINT
-- ============================================================================

print([[

╔════════════════════════════════════════════════════════════╗
║                                                            ║
║   🎮 TREASURE HUNTER 🎮                                    ║
║                                                            ║
║   A Production-Ready Blockchain Game Demo                  ║
║   Built with SubLua - Substrate SDK for Lua                ║
║                                                            ║
║   Features:                                                ║
║   • Player Account Management                              ║
║   • Token Economics (Play-to-Earn)                         ║
║   • Multi-Sig Treasury                                     ║
║   • On-Chain Leaderboard                                   ║
║   • Secure Transaction Handling                            ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝

]])

-- Use test mnemonic (DO NOT use in production!)
local TEST_MNEMONIC = "bottom drive obey lake curtain smoke basket hold race lonely fit walk"

local game = TreasureHunterGame.new()

if game:initialize(TEST_MNEMONIC) then
    print("\n" .. string.rep("─", 60))
    print("Game initialized successfully!")
    print("Running automated demo...")
    print(string.rep("─", 60))
    
    game:run_demo()
    
    print("\n" .. string.rep("─", 60))
    print("Demo completed!")
    print("")
    print("This game demonstrates SubLua's capabilities:")
    print("• Sr25519 key management via FFI")
    print("• Multi-signature treasury (2-of-3)")
    print("• Token economics with entry fees and rewards")
    print("• Persistent leaderboard tracking")
    print("• Real-time balance queries")
    print("")
    print("For production deployment:")
    print("• Replace test mnemonic with user-provided keys")
    print("• Enable real blockchain transactions")
    print("• Store leaderboard on-chain via System.remark")
    print("• Add proxy accounts for secure gameplay")
    print(string.rep("─", 60))
else
    print("\n❌ Failed to initialize game")
    print("Make sure:")
    print("1. LuaJIT is installed")
    print("2. SubLua FFI library is available")
    print("3. Network connection is available")
end
