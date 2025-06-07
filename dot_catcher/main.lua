-- Game constants
local PLAYER_SPEED = 400
local TOKEN_SPEED = 300
local TOKEN_SPAWN_RATE = 0.8 -- seconds
local WINDOW_WIDTH = 800
local WINDOW_HEIGHT = 600
local GRAVITY = 500
local JUMP_FORCE = -400
local MAX_TOKENS = 5
local TOKEN_POINTS = {1, 2, 3} -- Different point values for tokens
local TOKEN_COLORS = {
    {1, 0.8, 0},    -- Gold
    {0, 0.8, 1},    -- Blue
    {1, 0.4, 0.8}   -- Purple
}

-- Fix module search path for SDK
package.path = "./?.lua;./?/init.lua;./sdk/?.lua;./sdk/?/init.lua;" .. package.path

-- Blockchain integration
local sdk = require("sdk.init")
local ALICE_MNEMONIC = "bottom drive obey lake curtain smoke basket hold race lonely fit walk"
local RPC_URL = "wss://paseo.dotters.network"

local blockchain = {
    connected = false,
    address = nil,
    scoreSent = false,
    mnemonic = ALICE_MNEMONIC,
    showMnemonicInput = false,
    rpc = nil,
    chain_config = nil,
    signer = nil,
    highScore = 0,
    error = nil,
    balance = nil,
    balanceLoading = false,
    lastBalanceFetch = 0
}

-- Game state
local player = {
    x = WINDOW_WIDTH / 2,
    y = WINDOW_HEIGHT - 80,
    radius = 28,
    speed = PLAYER_SPEED,
    velocityY = 0,
    isJumping = false,
    color = {0.2, 0.8, 1},
    trail = {} -- For visual effects
}

local tokens = {}
local score = 0
local gameOver = false
local lastTokenSpawn = 0
local combo = 0
local maxCombo = 0
local lastCatchTime = 0
local COMBO_TIMEOUT = 1.0 -- seconds
local gameTime = 0
local difficulty = 1
local highScore = 0
local paused = false
local gameState = "start" -- start, playing, gameover, paused
local scorePopups = {}

-- Animated background dots
local bgDots = {}
for i = 1, 40 do
    table.insert(bgDots, {
        x = math.random() * WINDOW_WIDTH,
        y = math.random() * WINDOW_HEIGHT,
        r = math.random(8, 18),
        speed = math.random(10, 30),
        alpha = math.random() * 0.2 + 0.1
    })
end

-- Helper: format balance
local function format_balance(balance, decimals)
    if not balance then return "..." end
    decimals = decimals or 12
    local b = tonumber(balance) or 0
    return string.format("%.4f", b / (10^decimals))
end

-- Blockchain: fetch balance
local function fetchBalance()
    if not blockchain.connected or not blockchain.address then return end
    blockchain.balanceLoading = true
    local success, res = pcall(function()
        local account_info = blockchain.rpc:get_account_info(blockchain.address)
        if account_info and account_info.data then
            blockchain.balance = account_info.data.free
            -- Format balance with proper decimals
            local free_tokens = account_info.data.free_tokens
            local token_symbol = account_info.data.token_symbol or "PSA"
            return string.format("%.5f %s", free_tokens, token_symbol)
        end
        return "0 PSA"
    end)
    blockchain.balanceLoading = false
    blockchain.lastBalanceFetch = love.timer.getTime()
    if not success then
        blockchain.balance = nil
        print("Failed to fetch balance:", res)
    end
end

-- Initialize the game
function love.load()
    love.window.setMode(WINDOW_WIDTH, WINDOW_HEIGHT)
    love.window.setTitle("DOT Catcher")
    love.graphics.setBackgroundColor(0.08, 0.09, 0.13)
    highScore = 0
    
    -- Blockchain connection
    local success, err = pcall(function()
        -- Create RPC connection first
        blockchain.rpc = sdk.rpc.new(RPC_URL)
        if not blockchain.rpc then
            error("Failed to create RPC connection")
        end
        
        -- Get runtime version to verify connection
        local runtime = blockchain.rpc:state_getRuntimeVersion()
        if not runtime then
            error("Failed to get runtime version")
        end
        
        -- Auto-detect chain configuration from URL
        blockchain.chain_config = sdk.chain_config.detect_from_url(RPC_URL)
        if not blockchain.chain_config then
            error("Failed to detect chain configuration")
        end
        
        print("🔗 Chain: " .. blockchain.chain_config.name)
        print("💰 Token: " .. blockchain.chain_config.token_symbol)
        
        -- Create signer from mnemonic
        blockchain.signer = sdk.signer.from_mnemonic(blockchain.mnemonic)
        if not blockchain.signer then
            error("Failed to create signer")
        end
        
        blockchain.address = blockchain.signer:get_ss58_address(blockchain.chain_config.ss58_prefix)
        blockchain.connected = true
        
        print("Wallet connected:")
        print("  Address:", blockchain.address)
        
        -- Initial balance fetch
        fetchBalance()
    end)
    
    if not success then
        print("❌ Blockchain initialization failed:", err)
        blockchain.connected = false
        blockchain.error = err
    end
end

-- Update game state
function love.update(dt)
    if blockchain.connected and (love.timer.getTime() - blockchain.lastBalanceFetch > 5) then
        fetchBalance()
    end
    -- Animated background dots
    for _, dot in ipairs(bgDots) do
        dot.y = dot.y + dot.speed * dt
        if dot.y > WINDOW_HEIGHT + dot.r then
            dot.y = -dot.r
            dot.x = math.random() * WINDOW_WIDTH
        end
    end
    if gameState == "start" or gameState == "paused" then return end
    if gameOver then
        if not blockchain.scoreSent and blockchain.connected then
            sendScoreToBlockchain()
        end
        return
    end
    gameTime = gameTime + dt
    difficulty = 1 + math.floor(gameTime / 30) -- Increase difficulty every 30 seconds

    -- Update player trail
    table.insert(player.trail, {x = player.x, y = player.y})
    if #player.trail > 10 then
        table.remove(player.trail, 1)
    end

    -- Player movement
    if love.keyboard.isDown('left') then
        player.x = math.max(player.radius, player.x - player.speed * dt)
    end
    if love.keyboard.isDown('right') then
        player.x = math.min(WINDOW_WIDTH - player.radius, player.x + player.speed * dt)
    end
    
    -- Player jumping
    if love.keyboard.isDown('space') and not player.isJumping then
        player.velocityY = JUMP_FORCE
        player.isJumping = true
    end
    
    -- Apply gravity
    player.velocityY = player.velocityY + GRAVITY * dt
    player.y = player.y + player.velocityY * dt
    
    -- Ground collision
    if player.y > WINDOW_HEIGHT - player.radius then
        player.y = WINDOW_HEIGHT - player.radius
        player.velocityY = 0
        player.isJumping = false
    end

    -- Spawn tokens
    lastTokenSpawn = lastTokenSpawn + dt
    if lastTokenSpawn >= TOKEN_SPAWN_RATE / difficulty and #tokens < MAX_TOKENS then
        spawnToken()
        lastTokenSpawn = 0
    end

    -- Update tokens
    for i = #tokens, 1, -1 do
        local token = tokens[i]
        token.y = token.y + TOKEN_SPEED * difficulty * dt
        
        -- Add some horizontal movement
        token.x = token.x + math.sin(token.y * 0.01) * 50 * dt

        -- Check collision with player
        if checkCollision(player, token) then
            table.remove(tokens, i)
            score = score + token.points
            table.insert(scorePopups, {x = token.x, y = token.y, points = token.points, t = 0, color = token.color})
            
            -- Handle combo system
            local currentTime = love.timer.getTime()
            if currentTime - lastCatchTime < COMBO_TIMEOUT then
                combo = combo + 1
                maxCombo = math.max(maxCombo, combo)
                -- Visual feedback for combo
                player.color = {1, 0.8, 0}
            else
                combo = 1
                player.color = {0.2, 0.8, 1}
            end
            lastCatchTime = currentTime
            
        -- Remove tokens that fall off screen
        elseif token.y > WINDOW_HEIGHT + token.radius then
            table.remove(tokens, i)
            gameOver = true
            gameState = "gameover"
            if score > highScore then highScore = score end
        end
    end
    
    -- Reset player color
    if love.timer.getTime() - lastCatchTime > 0.2 then
        player.color = {0.2, 0.8, 1}
    end

    for i = #scorePopups, 1, -1 do
        local p = scorePopups[i]
        p.t = p.t + dt
        p.y = p.y - 30 * dt
        if p.t > 0.8 then table.remove(scorePopups, i) end
    end
end

-- Draw game elements
function love.draw()
    -- Animated background gradient
    local r, g, b = 0.08, 0.09, 0.13
    for i = 1, 10 do
        love.graphics.setColor(r, g, b, 0.08)
        love.graphics.rectangle("fill", 0, (i-1)*WINDOW_HEIGHT/10, WINDOW_WIDTH, WINDOW_HEIGHT/10)
        r = r + 0.01; g = g + 0.01; b = b + 0.01
    end
    -- Animated background dots
    for _, dot in ipairs(bgDots) do
        love.graphics.setColor(1, 1, 1, dot.alpha)
        love.graphics.circle("fill", dot.x, dot.y, dot.r)
    end
    -- UI: Wallet info (with background for better visibility)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", WINDOW_WIDTH - 300, 10, 290, 100, 10, 10)
    
    love.graphics.setColor(1, 1, 1)
    local addr = blockchain.address and (blockchain.address:sub(1, 8) .. "..." .. blockchain.address:sub(-4)) or "-"
    local bal = blockchain.balanceLoading and "..." or (blockchain.balance and string.format("%.5f PSA", blockchain.balance / (10^12)) or "0 PSA")
    local chain = blockchain.chain_config and blockchain.chain_config.name or "?"
    
    love.graphics.printf("Wallet: " .. addr, WINDOW_WIDTH - 290, 20, 270, "right")
    love.graphics.printf("Balance: " .. bal, WINDOW_WIDTH - 290, 44, 270, "right")
    love.graphics.printf("Chain: " .. chain, WINDOW_WIDTH - 290, 68, 270, "right")
    
    if blockchain.error then
        love.graphics.setColor(1, 0, 0)
        love.graphics.printf("Error: " .. blockchain.error, WINDOW_WIDTH - 290, 92, 270, "right")
    end
    -- UI: Connected badge
    if blockchain.connected then
        love.graphics.setColor(0.2, 1, 0.4, 0.8)
        love.graphics.rectangle("fill", WINDOW_WIDTH - 120, 120, 110, 28, 12, 12)
        love.graphics.setColor(0, 0.2, 0.1)
        love.graphics.printf("Connected", WINDOW_WIDTH - 120, 124, 110, "center")
    end
    -- Game states
    if gameState == "start" then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)
        
        -- Start screen panel
        love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
        love.graphics.rectangle("fill", WINDOW_WIDTH/2 - 200, WINDOW_HEIGHT/2 - 200, 400, 400, 20, 20)
        
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("DOT Catcher", WINDOW_WIDTH/2 - 200, WINDOW_HEIGHT/2 - 180, 400, "center", 0, 3)
        love.graphics.setColor(0.2, 1, 0.4)
        love.graphics.printf("Press SPACE to Start", WINDOW_WIDTH/2 - 200, WINDOW_HEIGHT/2 - 100, 400, "center", 0, 2)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Move: ← →   Jump: SPACE   Pause: P   Quit: ESC", WINDOW_WIDTH/2 - 200, WINDOW_HEIGHT/2 - 40, 400, "center", 0, 1.2)
        return
    end
    if gameState == "paused" then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)
        
        -- Pause screen panel
        love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
        love.graphics.rectangle("fill", WINDOW_WIDTH/2 - 200, WINDOW_HEIGHT/2 - 150, 400, 300, 20, 20)
        
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Paused", WINDOW_WIDTH/2 - 200, WINDOW_HEIGHT/2 - 130, 400, "center", 0, 3)
        love.graphics.setColor(0.2, 1, 0.4)
        love.graphics.printf("Press P to Resume", WINDOW_WIDTH/2 - 200, WINDOW_HEIGHT/2 - 50, 400, "center", 0, 2)
        return
    end
    -- Player trail
    for i, pos in ipairs(player.trail) do
        local alpha = i / #player.trail
        love.graphics.setColor(0.2, 0.8, 1, alpha * 0.3)
        love.graphics.circle("fill", pos.x, pos.y, player.radius)
    end
    -- Player (rounded, shadow)
    love.graphics.setColor(0, 0, 0, 0.25)
    love.graphics.circle("fill", player.x+4, player.y+8, player.radius+2)
    love.graphics.setColor(player.color)
    love.graphics.circle("fill", player.x, player.y, player.radius)
    -- Tokens (rounded, shadow, color)
    for _, token in ipairs(tokens) do
        love.graphics.setColor(0, 0, 0, 0.18)
        love.graphics.circle("fill", token.x+3, token.y+6, token.radius+2)
        love.graphics.setColor(token.color)
        love.graphics.circle("fill", token.x, token.y, token.radius)
        love.graphics.setColor(token.color[1], token.color[2], token.color[3], 0.3)
        love.graphics.circle("fill", token.x, token.y, token.radius * 1.5)
    end
    -- Score popups
    for _, p in ipairs(scorePopups) do
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], 1-p.t)
        love.graphics.printf("+"..p.points, p.x-20, p.y-20, 40, "center", 0, 1.5)
    end
    -- Score, combo, high score (with background for better visibility)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 10, 10, 200, 90, 10, 10)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Score: " .. score, 20, 20, 0, 2)
    love.graphics.print("High Score: " .. highScore, 20, 54, 0, 1.3)
    
    if combo > 1 then
        love.graphics.setColor(1, 0.8, 0)
        love.graphics.print("Combo: " .. combo .. "x", 20, 88, 0, 1.7)
    end
    -- Game over overlay
    if gameState == "gameover" then
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)
        
        -- Game over panel
        love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
        love.graphics.rectangle("fill", WINDOW_WIDTH/2 - 200, WINDOW_HEIGHT/2 - 200, 400, 400, 20, 20)
        
        love.graphics.setColor(1, 0, 0)
        love.graphics.printf("Game Over!", WINDOW_WIDTH/2 - 200, WINDOW_HEIGHT/2 - 180, 400, "center", 0, 3)
        
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Final Score: " .. score, WINDOW_WIDTH/2 - 200, WINDOW_HEIGHT/2 - 100, 400, "center", 0, 2)
        love.graphics.printf("Max Combo: " .. maxCombo .. "x", WINDOW_WIDTH/2 - 200, WINDOW_HEIGHT/2 - 40, 400, "center", 0, 2)
        love.graphics.printf("Time: " .. string.format("%.1f", gameTime) .. "s", WINDOW_WIDTH/2 - 200, WINDOW_HEIGHT/2 + 20, 400, "center", 0, 2)
        
        if blockchain.scoreSent then
            love.graphics.setColor(0.2, 1, 0.4)
            love.graphics.printf("Score sent to blockchain!", WINDOW_WIDTH/2 - 200, WINDOW_HEIGHT/2 + 80, 400, "center", 0, 2)
        end
        
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Press SPACE to Restart", WINDOW_WIDTH/2 - 200, WINDOW_HEIGHT/2 + 140, 400, "center", 0, 2)
    end
end

-- Handle key presses
function love.keypressed(key)
    if key == "escape" then
        if blockchain.showMnemonicInput then
            blockchain.showMnemonicInput = false
            blockchain.mnemonic = ALICE_MNEMONIC
        else
            love.event.quit()
        end
    elseif key == "space" then
        if gameState == "start" then
            resetGame()
            gameState = "playing"
        elseif gameState == "gameover" then
            resetGame()
            gameState = "playing"
        end
    elseif key == "p" then
        if gameState == "playing" then
            gameState = "paused"
        elseif gameState == "paused" then
            gameState = "playing"
        end
    elseif key == "c" and not blockchain.connected then
        blockchain.showMnemonicInput = true
    elseif key == "return" and blockchain.showMnemonicInput then
        connectWallet()
    end
end

-- Handle text input
function love.textinput(t)
    if blockchain.showMnemonicInput then
        blockchain.mnemonic = blockchain.mnemonic .. t
    end
end

-- Blockchain functions
function connectWallet()
    if blockchain.mnemonic == "" then return end
    
    local success, err = pcall(function()
        -- Create signer from mnemonic
        blockchain.signer = sdk.signer.from_mnemonic(blockchain.mnemonic)
        blockchain.address = blockchain.signer:get_ss58_address(blockchain.chain_config.ss58_prefix)
        blockchain.connected = true
        blockchain.showMnemonicInput = false
        print("Wallet connected:")
        print("  Address:", blockchain.address)
    end)
    
    if not success then
        print("Failed to connect wallet:", err)
        blockchain.connected = false
    end
end

function sendScoreToBlockchain()
    if not blockchain.connected or not blockchain.signer then return end
    
    local success, err = pcall(function()
        -- Create extrinsic for System.remark
        local extrinsic = sdk.extrinsic.new({
            module = "System",
            call = "remark",
            args = { "DOT_CATCHER_SCORE:" .. score .. ":COMBO:" .. maxCombo }
        })
        
        -- Get current nonce
        local account_info = blockchain.rpc:get_account_info(blockchain.address)
        local nonce = account_info and account_info.nonce or 0
        
        -- Set transaction parameters
        extrinsic:set_nonce(nonce)
        extrinsic:set_tip(0)
        extrinsic:set_era_immortal()
        
        -- Sign and submit
        local unsigned_hex = extrinsic:encode_unsigned()
        local signature = blockchain.signer:sign(unsigned_hex)
        local signed_hex = extrinsic:encode_signed(signature, blockchain.signer:get_public_key())
        
        -- Submit transaction
        local result = blockchain.rpc:author_submitExtrinsic(signed_hex)
        blockchain.scoreSent = true
        print("Score sent to blockchain:", score)
        print("Max combo:", maxCombo)
        print("Transaction hash:", result)
    end)
    
    if not success then
        print("Failed to send score:", err)
    end
end

-- Helper functions
function spawnToken()
    local tokenType = math.random(1, #TOKEN_POINTS)
    local token = {
        x = math.random(40, WINDOW_WIDTH - 40),
        y = -20,
        radius = 18,
        speed = TOKEN_SPEED * (0.8 + math.random() * 0.4), -- Random speed variation
        points = TOKEN_POINTS[tokenType],
        color = TOKEN_COLORS[tokenType]
    }
    table.insert(tokens, token)
end

function checkCollision(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dist = math.sqrt(dx*dx + dy*dy)
    return dist < (a.radius + b.radius)
end

function resetGame()
    tokens = {}
    score = 0
    combo = 0
    maxCombo = 0
    gameOver = false
    lastTokenSpawn = 0
    gameTime = 0
    difficulty = 1
    player.x = WINDOW_WIDTH / 2
    player.y = WINDOW_HEIGHT - 80
    player.velocityY = 0
    player.isJumping = false
    player.color = {0.2, 0.8, 1}
    player.trail = {}
    blockchain.scoreSent = false
    scorePopups = {}
end 