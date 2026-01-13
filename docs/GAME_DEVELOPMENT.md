# 🎮 Building Blockchain Games with SubLua

A comprehensive guide to creating production-ready blockchain games using SubLua and Love2D.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Architecture Overview](#architecture-overview)
4. [Step-by-Step Tutorial](#step-by-step-tutorial)
5. [Blockchain Integration](#blockchain-integration)
6. [Token Economics Design](#token-economics-design)
7. [Player Management](#player-management)
8. [Building & Distribution](#building--distribution)
9. [Best Practices](#best-practices)
10. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools

```bash
# Install Love2D game engine
brew install love  # macOS
# or download from: https://love2d.org

# Install LuaJIT
brew install luajit

# Install SubLua SDK
curl -sSL https://raw.githubusercontent.com/MontaQLabs/sublua/main/install_sublua.sh | bash
```

### Knowledge Requirements

- Basic Lua programming
- Game development fundamentals
- Blockchain concepts (wallets, transactions)
- Understanding of token economics

---

## Quick Start

### 1. Create Game Structure

```bash
mkdir my-blockchain-game
cd my-blockchain-game

# Create game files
touch main.lua
touch conf.lua

# Create SubLua integration
mkdir blockchain
touch blockchain/init.lua
```

### 2. Basic Game Template

**conf.lua** - Game configuration:

```lua
function love.conf(t)
    t.title = "My Blockchain Game"
    t.version = "11.5"
    t.window.width = 1024
    t.window.height = 768
    t.window.resizable = false
end
```

**main.lua** - Basic game loop:

```lua
-- Load SubLua
local sublua = require("sublua")
sublua.ffi()

-- Game state
local gameState = {
    player = {
        address = nil,
        balance = 0
    },
    score = 0
}

function love.load()
    -- Initialize blockchain
    local signer = sublua.signer().from_mnemonic(
        "your twelve word mnemonic phrase here"
    )
    gameState.player.address = signer:get_ss58_address(42) -- Westend
    
    print("Player address:", gameState.player.address)
end

function love.update(dt)
    -- Game logic
end

function love.draw()
    love.graphics.print("Player: " .. gameState.player.address, 10, 10)
    love.graphics.print("Score: " .. gameState.score, 10, 30)
end
```

---

## Architecture Overview

### Recommended Structure

```
my-blockchain-game/
├── main.lua              # Game entry point
├── conf.lua              # Love2D configuration
├── blockchain/
│   ├── init.lua          # Blockchain initialization
│   ├── wallet.lua        # Player wallet management
│   ├── rewards.lua       # Reward distribution
│   └── treasury.lua      # Treasury management
├── game/
│   ├── player.lua        # Player mechanics
│   ├── world.lua         # Game world
│   └── ui.lua            # User interface
├── assets/
│   ├── images/
│   └── sounds/
└── sublua/               # Bundled SubLua SDK
```

### Component Responsibilities

| Component | Responsibility |
|-----------|---------------|
| **main.lua** | Game loop, state management |
| **blockchain/** | All blockchain interactions |
| **game/** | Core game mechanics |
| **assets/** | Graphics and sounds |
| **sublua/** | Bundled SDK (for distribution) |

---

## Step-by-Step Tutorial

### Step 1: Initialize Blockchain Module

**blockchain/init.lua**:

```lua
local Blockchain = {}
local sublua = nil
local ffi = nil
local ffi_lib = nil

function Blockchain.init()
    -- Load SubLua SDK
    local ok, mod = pcall(require, "sublua")
    if not ok then
        error("SubLua not found. Install with: luarocks install sublua")
    end
    
    sublua = mod
    
    -- Load FFI
    sublua.ffi()
    
    local polkadot_ffi = require("sublua.polkadot_ffi")
    ffi = polkadot_ffi.ffi
    ffi_lib = polkadot_ffi.get_lib()
    
    print("✓ Blockchain initialized")
end

function Blockchain.createWallet(mnemonic)
    local signer = sublua.signer().from_mnemonic(mnemonic)
    return {
        signer = signer,
        address = signer:get_ss58_address(42), -- Westend
        mnemonic = mnemonic
    }
end

function Blockchain.getBalance(address)
    local url = "wss://westend-rpc.polkadot.io"
    local url_c = ffi.new("char[?]", #url + 1)
    ffi.copy(url_c, url)
    
    local addr_c = ffi.new("char[?]", #address + 1)
    ffi.copy(addr_c, address)
    
    local result = ffi_lib.query_balance(url_c, addr_c)
    
    if result.success then
        local data = ffi.string(result.data)
        ffi_lib.free_string(result.data)
        
        local balance = data:match('U128%((%d+)%)') or "0"
        return tonumber(balance) / 1e12 -- Convert to WND
    end
    
    return 0
end

function Blockchain.sendReward(fromMnemonic, toAddress, amountWND)
    local url = "wss://westend-rpc.polkadot.io"
    local amount = math.floor(amountWND * 1e12) -- Convert to smallest unit
    
    local url_c = ffi.new("char[?]", #url + 1)
    ffi.copy(url_c, url)
    
    local mnemonic_c = ffi.new("char[?]", #fromMnemonic + 1)
    ffi.copy(mnemonic_c, fromMnemonic)
    
    local dest_c = ffi.new("char[?]", #toAddress + 1)
    ffi.copy(dest_c, toAddress)
    
    local result = ffi_lib.submit_balance_transfer_subxt(
        url_c, mnemonic_c, dest_c, amount
    )
    
    if result.success then
        local tx_hash = ffi.string(result.tx_hash)
        ffi_lib.free_string(result.tx_hash)
        return true, tx_hash
    else
        local err = ffi.string(result.error)
        ffi_lib.free_string(result.error)
        return false, err
    end
end

return Blockchain
```

### Step 2: Implement Player Wallet

**blockchain/wallet.lua**:

```lua
local Wallet = {}

function Wallet.generate()
    -- In production, prompt user for their mnemonic
    -- For demo, generate a random one
    local words = {
        "abandon", "ability", "able", "about", "above", "absent",
        "absorb", "abstract", "absurd", "abuse", "access", "accident"
    }
    
    local mnemonic = table.concat(words, " ")
    return mnemonic
end

function Wallet.save(mnemonic)
    -- SECURITY WARNING: Never store mnemonics unencrypted in production!
    -- This is for demo purposes only
    love.filesystem.write("wallet.txt", mnemonic)
end

function Wallet.load()
    local content = love.filesystem.read("wallet.txt")
    return content
end

function Wallet.exists()
    return love.filesystem.getInfo("wallet.txt") ~= nil
end

return Wallet
```

### Step 3: Design Token Economics

**blockchain/rewards.lua**:

```lua
local Rewards = {}

-- Treasury account (holds game's funds)
local TREASURY_MNEMONIC = "your treasury mnemonic here"
local TREASURY_ADDRESS = "5GH4vb..." -- Derive from mnemonic

-- Reward structure
local REWARD_TABLE = {
    kill_enemy = 0.001,      -- 0.001 WND per enemy
    collect_item = 0.002,    -- 0.002 WND per item
    complete_level = 0.01,   -- 0.01 WND per level
    win_game = 0.05,         -- 0.05 WND for winning
}

function Rewards.calculate(achievements)
    local total = 0
    
    for achievement, count in pairs(achievements) do
        local reward = REWARD_TABLE[achievement] or 0
        total = total + (reward * count)
    end
    
    return total
end

function Rewards.send(playerAddress, amountWND, blockchain)
    -- Send from treasury to player
    local success, txHash = blockchain.sendReward(
        TREASURY_MNEMONIC,
        playerAddress,
        amountWND
    )
    
    if success then
        print("✓ Reward sent:", amountWND, "WND")
        print("  TX:", txHash)
        return true
    else
        print("✗ Reward failed:", txHash)
        return false
    end
end

function Rewards.estimate(gameState)
    -- Preview potential rewards
    local achievements = {
        kill_enemy = gameState.enemiesKilled,
        collect_item = gameState.itemsCollected,
        complete_level = gameState.levelsCompleted
    }
    
    return Rewards.calculate(achievements)
end

return Rewards
```

### Step 4: Build the Game

**main.lua** - Complete example:

```lua
local Blockchain = require("blockchain.init")
local Wallet = require("blockchain.wallet")
local Rewards = require("blockchain.rewards")

local GameState = {
    screen = "menu",  -- menu, playing, gameover
    
    player = {
        x = 400,
        y = 300,
        wallet = nil,
        balance = 0,
        address = nil
    },
    
    game = {
        score = 0,
        enemiesKilled = 0,
        itemsCollected = 0,
        time = 0
    },
    
    blockchain = {
        ready = false,
        lastReward = nil
    }
}

function love.load()
    -- Initialize blockchain
    Blockchain.init()
    
    -- Load or create wallet
    local mnemonic
    if Wallet.exists() then
        mnemonic = Wallet.load()
    else
        mnemonic = Wallet.generate()
        Wallet.save(mnemonic)
    end
    
    GameState.player.wallet = Blockchain.createWallet(mnemonic)
    GameState.player.address = GameState.player.wallet.address
    GameState.blockchain.ready = true
    
    -- Load balance
    GameState.player.balance = Blockchain.getBalance(GameState.player.address)
    
    print("Game loaded!")
    print("Player:", GameState.player.address)
    print("Balance:", GameState.player.balance, "WND")
end

function love.update(dt)
    if GameState.screen == "playing" then
        GameState.game.time = GameState.game.time + dt
        
        -- Game logic here
        -- When player achieves something:
        -- GameState.game.enemiesKilled = GameState.game.enemiesKilled + 1
    end
end

function love.draw()
    if GameState.screen == "menu" then
        love.graphics.print("Press SPACE to start", 400, 300)
        love.graphics.print("Player: " .. GameState.player.address, 10, 10)
        love.graphics.print(string.format("Balance: %.4f WND", 
            GameState.player.balance), 10, 30)
    elseif GameState.screen == "playing" then
        -- Draw game
        love.graphics.circle("fill", GameState.player.x, GameState.player.y, 20)
        love.graphics.print("Score: " .. GameState.game.score, 10, 10)
        
        -- Show potential reward
        local estimatedReward = Rewards.estimate(GameState.game)
        love.graphics.print(string.format("Potential Reward: %.4f WND", 
            estimatedReward), 10, 30)
    elseif GameState.screen == "gameover" then
        love.graphics.print("Game Over!", 400, 300)
        love.graphics.print("Final Score: " .. GameState.game.score, 400, 330)
        
        if GameState.blockchain.lastReward then
            love.graphics.print("Reward Sent: " .. GameState.blockchain.lastReward .. " WND", 
                400, 360)
        end
    end
end

function love.keypressed(key)
    if key == "space" and GameState.screen == "menu" then
        GameState.screen = "playing"
    elseif key == "escape" then
        love.event.quit()
    end
end

function sendFinalReward()
    local achievements = {
        kill_enemy = GameState.game.enemiesKilled,
        collect_item = GameState.game.itemsCollected
    }
    
    local rewardAmount = Rewards.calculate(achievements)
    
    if rewardAmount > 0 then
        local success, txHash = Rewards.send(
            GameState.player.address,
            rewardAmount,
            Blockchain
        )
        
        if success then
            GameState.blockchain.lastReward = rewardAmount
            GameState.player.balance = GameState.player.balance + rewardAmount
        end
    end
    
    GameState.screen = "gameover"
end
```

---

## Blockchain Integration

### Querying Balances

```lua
function queryBalance(address)
    local polkadot_ffi = require("sublua.polkadot_ffi")
    local ffi = polkadot_ffi.ffi
    local lib = polkadot_ffi.get_lib()
    
    local url = "wss://westend-rpc.polkadot.io"
    local url_c = ffi.new("char[?]", #url + 1)
    ffi.copy(url_c, url)
    
    local addr_c = ffi.new("char[?]", #address + 1)
    ffi.copy(addr_c, address)
    
    local result = lib.query_balance(url_c, addr_c)
    
    if result.success then
        local data = ffi.string(result.data)
        lib.free_string(result.data)
        
        local balance = data:match('U128%((%d+)%)')
        return tonumber(balance) / 1e12
    end
    
    return 0
end
```

### Sending Transactions

```lua
function sendTransaction(fromMnemonic, toAddress, amountWND)
    local polkadot_ffi = require("sublua.polkadot_ffi")
    local ffi = polkadot_ffi.ffi
    local lib = polkadot_ffi.get_lib()
    
    local url = "wss://westend-rpc.polkadot.io"
    local amount = math.floor(amountWND * 1e12)
    
    -- Prepare C strings
    local url_c = ffi.new("char[?]", #url + 1)
    ffi.copy(url_c, url)
    
    local mnemonic_c = ffi.new("char[?]", #fromMnemonic + 1)
    ffi.copy(mnemonic_c, fromMnemonic)
    
    local dest_c = ffi.new("char[?]", #toAddress + 1)
    ffi.copy(dest_c, toAddress)
    
    -- Submit transaction
    local result = lib.submit_balance_transfer_subxt(
        url_c, mnemonic_c, dest_c, amount
    )
    
    if result.success then
        local tx_hash = ffi.string(result.tx_hash)
        lib.free_string(result.tx_hash)
        return true, tx_hash
    else
        local err = ffi.string(result.error)
        lib.free_string(result.error)
        return false, err
    end
end
```

### Real-time Balance Updates

```lua
function createBalanceTracker()
    local tracker = {
        lastBalance = 0,
        checkInterval = 5, -- seconds
        timeSinceCheck = 0
    }
    
    function tracker:update(dt, address)
        self.timeSinceCheck = self.timeSinceCheck + dt
        
        if self.timeSinceCheck >= self.checkInterval then
            self.timeSinceCheck = 0
            
            local newBalance = queryBalance(address)
            
            if newBalance ~= self.lastBalance then
                local diff = newBalance - self.lastBalance
                self.lastBalance = newBalance
                
                -- Trigger notification
                return true, diff
            end
        end
        
        return false, 0
    end
    
    return tracker
end
```

---

## Token Economics Design

### Basic Reward Model

```lua
local TokenEconomics = {
    -- Entry
    entry_fee = 0,  -- Free to play
    
    -- Rewards
    per_action = 0.001,  -- Small actions
    per_milestone = 0.01, -- Achievements
    per_win = 0.1,        -- Game completion
    
    -- Limits
    max_per_game = 0.5,   -- Cap per session
    daily_limit = 2.0,    -- Anti-farming
    
    -- Treasury
    treasury_mnemonic = "...",
    min_treasury_balance = 10.0  -- WND
}
```

### Anti-Farming Measures

```lua
function shouldAwardReward(playerAddress, amount)
    -- Check daily limit
    local todayTotal = getPlayerDailyTotal(playerAddress)
    if todayTotal + amount > TokenEconomics.daily_limit then
        return false, "Daily limit reached"
    end
    
    -- Check treasury balance
    local treasuryBalance = queryBalance(TREASURY_ADDRESS)
    if treasuryBalance < TokenEconomics.min_treasury_balance then
        return false, "Treasury insufficient"
    end
    
    -- Check time between rewards (prevent spam)
    local lastReward = getLastRewardTime(playerAddress)
    if os.time() - lastReward < 60 then  -- 1 minute cooldown
        return false, "Cooldown active"
    end
    
    return true, "OK"
end
```

### Progressive Rewards

```lua
function calculateReward(level, performance)
    local baseReward = 0.01
    local levelMultiplier = 1 + (level * 0.1)
    local performanceBonus = performance / 100  -- 0-1
    
    local total = baseReward * levelMultiplier * (1 + performanceBonus)
    
    -- Cap maximum
    return math.min(total, TokenEconomics.max_per_game)
end
```

---

## Player Management

### Secure Wallet Storage

```lua
-- ⚠️ SECURITY WARNING: This is a simplified example
-- In production, use proper encryption!

local PlayerData = {}

function PlayerData.save(data)
    local json = love.data.encode("string", "json", data)
    love.filesystem.write("player.json", json)
end

function PlayerData.load()
    if love.filesystem.getInfo("player.json") then
        local json = love.filesystem.read("player.json")
        return love.data.decode("string", "json", json)
    end
    return nil
end

-- Better approach: Prompt for mnemonic each session
function PlayerData.promptMnemonic()
    -- Use Love2D text input
    -- Never store unencrypted mnemonics!
end
```

### Leaderboard System

```lua
local Leaderboard = {
    entries = {}
}

function Leaderboard.add(address, score, reward)
    table.insert(self.entries, {
        address = address,
        score = score,
        reward = reward,
        timestamp = os.time()
    })
    
    -- Sort by score
    table.sort(self.entries, function(a, b)
        return a.score > b.score
    end)
    
    -- Keep top 10
    while #self.entries > 10 do
        table.remove(self.entries)
    end
    
    -- Save to file
    love.filesystem.write("leaderboard.json", 
        love.data.encode("string", "json", self.entries))
end

function Leaderboard.draw(x, y)
    love.graphics.print("🏆 TOP PLAYERS", x, y)
    
    for i, entry in ipairs(self.entries) do
        local shortAddr = entry.address:sub(1, 8) .. "..."
        love.graphics.print(
            string.format("%d. %s - %d pts (%.4f WND)", 
                i, shortAddr, entry.score, entry.reward),
            x, y + (i * 20) + 20
        )
    end
end
```

---

## Building & Distribution

### Step 1: Bundle SubLua

```bash
# Copy SubLua SDK into your game
mkdir -p my-game/sublua
cp -r ~/.luarocks/share/lua/5.1/sublua/* my-game/sublua/

# Copy FFI library
mkdir -p my-game/precompiled/macos-aarch64
cp ~/.sublua/lib/libpolkadot_ffi.dylib my-game/precompiled/macos-aarch64/
```

### Step 2: Create .love File

```bash
cd my-game
zip -r ../MyGame.love .
```

### Step 3: Test

```bash
love MyGame.love
```

### Step 4: Create Standalone App (macOS)

```bash
# Copy Love2D app
cp -r /Applications/love.app MyGame.app

# Rename executable
mv MyGame.app/Contents/MacOS/love MyGame.app/Contents/MacOS/MyGame

# Update Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleName MyGame" MyGame.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable MyGame" MyGame.app/Contents/Info.plist

# Copy .love and FFI
cp MyGame.love MyGame.app/Contents/Resources/
cp precompiled/macos-aarch64/libpolkadot_ffi.dylib MyGame.app/Contents/Frameworks/

# Sign
codesign --force --deep --sign - MyGame.app
```

### Step 5: Distribute

```bash
# Create distributable zip
zip -r MyGame-macOS.zip MyGame.app

# Users can now double-click MyGame.app - no installation needed!
```

---

## Best Practices

### Security

1. **Never hardcode private keys or mnemonics**
   ```lua
   -- ❌ BAD
   local mnemonic = "expose all my tokens please"
   
   -- ✅ GOOD
   local mnemonic = promptUserForMnemonic()
   ```

2. **Use testnet for development**
   ```lua
   local RPC_URL = "wss://westend-rpc.polkadot.io"  -- Testnet
   -- NOT: "wss://rpc.polkadot.io"  -- Mainnet
   ```

3. **Validate all inputs**
   ```lua
   function isValidAddress(addr)
       return addr and #addr == 48 and addr:match("^5[A-Za-z0-9]+$")
   end
   ```

### Performance

1. **Cache blockchain queries**
   ```lua
   local balanceCache = {
       value = 0,
       lastUpdate = 0,
       ttl = 30  -- seconds
   }
   ```

2. **Use async patterns**
   ```lua
   -- Don't block game loop for blockchain calls
   function asyncQuery(callback)
       -- Use coroutines or threading
   end
   ```

3. **Batch operations**
   ```lua
   -- Instead of sending multiple small rewards,
   -- accumulate and send one larger reward
   ```

### User Experience

1. **Show transaction status**
   ```lua
   function showNotification(message, duration)
       -- Visual feedback for blockchain operations
   end
   ```

2. **Handle failures gracefully**
   ```lua
   if not success then
       -- Fall back to demo mode or retry
       showNotification("Network error. Retrying...")
   end
   ```

3. **Provide clear instructions**
   ```lua
   function drawHelp()
       love.graphics.print("Get testnet tokens: https://faucet.polkadot.io/westend")
   end
   ```

---

## Troubleshooting

### Common Issues

**Issue**: "FFI library not found"
```lua
-- Solution: Check package.path
print(package.path)

-- Add paths manually if needed
package.path = package.path .. ";./sublua/?.lua"
```

**Issue**: "Transaction failed: Insufficient balance"
```lua
-- Solution: Check treasury balance
local balance = queryBalance(TREASURY_ADDRESS)
print("Treasury:", balance, "WND")

-- Fund via faucet if needed
```

**Issue**: "Module 'sublua' not found"
```lua
-- Solution: Ensure SubLua is bundled
local info = love.filesystem.getInfo("sublua")
if not info then
    error("SubLua not bundled. Copy sublua/ directory to your game.")
end
```

---

## Example Games

### Full Examples in Repository

1. **Treasure Hunter** (`examples/treasure_hunter_game.lua`)
   - Complete grid-based game
   - Token rewards per treasure
   - Real-time blockchain integration

2. **Terminal Game** (`examples/game_integration.lua`)
   - Command-line game example
   - Purchase items with tokens
   - Reward distribution

### Community Games

See: https://github.com/MontaQLabs/sublua/discussions/games

---

## Resources

- **SubLua Documentation**: https://github.com/MontaQLabs/sublua
- **Love2D Wiki**: https://love2d.org/wiki/
- **Polkadot Docs**: https://wiki.polkadot.network/
- **Westend Faucet**: https://faucet.polkadot.io/westend

---

## Support

- GitHub Issues: https://github.com/MontaQLabs/sublua/issues
- Discussions: https://github.com/MontaQLabs/sublua/discussions

---

**Happy Game Development! 🎮⛓️**

Built with ❤️ using SubLua - The Lua SDK for Substrate Blockchains
