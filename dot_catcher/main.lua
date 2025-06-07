-- ===== COSMIC GUARDIAN: STELLAR HARVEST =====
-- An epic space adventure where you play as a Cosmic Guardian protecting the galaxy
-- by collecting stellar energy while battling dark matter entities!

-- Game constants
local PLAYER_SPEED = 350
local TOKEN_SPEED = 300
local TOKEN_SPAWN_RATE = 0.8 -- seconds
local WINDOW_WIDTH = 800
local WINDOW_HEIGHT = 600
local GRAVITY = 400
local JUMP_FORCE = -350
local MAX_TOKENS = 5
local TOKEN_POINTS = {1, 2, 3} -- Different point values for tokens
local TOKEN_COLORS = {
    {1, 0.8, 0},    -- Gold
    {0, 0.8, 1},    -- Blue
    {1, 0.4, 0.8}   -- Purple
}

-- Fonts
local fonts = {}

-- Fix module search path for SDK
package.path = "./?.lua;./?/init.lua;./sdk/?.lua;./sdk/?/init.lua;" .. package.path

-- Blockchain integration with WASM trap fix
local sdk = require("sdk.init")
local ALICE_MNEMONIC = "bottom drive obey lake curtain smoke basket hold race lonely fit walk"
local RPC_URL = "wss://paseo.dotters.network"

local blockchain = {
    connected = false,
    address = nil,
    mnemonic = ALICE_MNEMONIC,
    rpc = nil,
    chain_config = nil,
    signer = nil,
    error = nil,
    balance = nil,
    balanceLoading = false,
    lastBalanceFetch = 0,
    nonce = 0,
    transactionQueue = {},
    lastTransactionTime = 0,
    transactionCooldown = 3.0 -- 3 seconds between transactions
}

-- Game state and story
local gameState = "intro" -- intro, playing, gameover, paused, story
local storyPhase = 1
local storyText = {
    [1] = {
        title = "THE COSMIC GUARDIAN",
        text = "In the year 2157, you are humanity's last hope...\n\nThe galaxy is under attack by Dark Matter Entities\nthat consume stellar energy, leaving worlds in darkness.\n\nAs a Cosmic Guardian, you must collect Stellar Crystals\nto power the Ancient Defense Grid and save civilization!",
        duration = 8
    },
    [2] = {
        title = "MISSION BRIEFING",
        text = "Your ship is equipped with:\n• Quantum Jump Thrusters (SPACE)\n• Stellar Energy Collector\n• Emergency Shield Generator\n\nCollect blue Stellar Crystals for energy\nGrab golden Power Cores for special abilities\nAvoid red Dark Matter - it's deadly!",
        duration = 6
    },
    [3] = {
        title = "THE BATTLE BEGINS",
        text = "The Dark Matter swarm approaches!\n\nYour mission: Collect 1000 Stellar Energy units\nto activate the Defense Grid.\n\nThe fate of the galaxy rests in your hands, Guardian!",
        duration = 4
    }
}

-- Enhanced player with abilities
local player = {
    x = WINDOW_WIDTH / 2,
    y = WINDOW_HEIGHT - 80,
    radius = 25,
    speed = PLAYER_SPEED,
    velocityY = 0,
    isJumping = false,
    health = 100,
    maxHealth = 100,
    shield = 0,
    maxShield = 50,
    energy = 0,
    color = {0.3, 0.8, 1},
    trail = {},
    particles = {},
    invulnerable = 0,
    powerups = {
        shield = 0,
        speed = 0,
        magnet = 0,
        doublePoints = 0
    }
}

-- Game objects
local stellarCrystals = {}
local powerCores = {}
local darkMatter = {}
local particles = {}
local explosions = {}
local scorePopups = {}

-- Game stats
local score = 0
local gameTime = 0
local wave = 1
local difficulty = 1
local highScore = 0
local combo = 0
local maxCombo = 0
local lastCatchTime = 0
local COMBO_TIMEOUT = 2.0

-- Spawn timers
local crystalSpawnTimer = 0
local powerSpawnTimer = 0
local darkMatterSpawnTimer = 0

-- Visual effects
local stars = {}
local nebula = {}
local screenShake = 0
local flashEffect = 0

-- Initialize stars and nebula
for i = 1, 100 do
    table.insert(stars, {
        x = math.random() * WINDOW_WIDTH,
        y = math.random() * WINDOW_HEIGHT,
        size = math.random() * 2 + 0.5,
        speed = math.random() * 30 + 10,
        twinkle = math.random() * math.pi * 2
    })
end

for i = 1, 20 do
    table.insert(nebula, {
        x = math.random() * WINDOW_WIDTH,
        y = math.random() * WINDOW_HEIGHT,
        size = math.random() * 100 + 50,
        speed = math.random() * 5 + 2,
        color = {
            math.random() * 0.3 + 0.1,
            math.random() * 0.3 + 0.2,
            math.random() * 0.5 + 0.3,
            0.1
        }
    })
end

-- Helper: format balance
local function format_balance(balance, decimals)
    if not balance then return "..." end
    decimals = decimals or 12
    local b = tonumber(balance) or 0
    return string.format("%.4f", b / (10^decimals))
end

-- Blockchain: fetch balance and nonce
local function fetchBalance()
    if not blockchain.connected or not blockchain.address then return end
    blockchain.balanceLoading = true
    local success, res = pcall(function()
        local account_info = blockchain.rpc:get_account_info(blockchain.address)
        if account_info and account_info.data then
            blockchain.balance = account_info.data.free
            blockchain.nonce = account_info.nonce or 0
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

-- Enhanced blockchain transaction system
local function queueTransaction(message, priority)
    priority = priority or 1
    table.insert(blockchain.transactionQueue, {
        message = message,
        priority = priority,
        timestamp = love.timer.getTime()
    })
    
    -- Sort by priority (higher priority first)
    table.sort(blockchain.transactionQueue, function(a, b)
        return a.priority > b.priority
    end)
end

local function sendNextTransaction()
    if not blockchain.connected or not blockchain.signer then return end
    if #blockchain.transactionQueue == 0 then return end
    if love.timer.getTime() - blockchain.lastTransactionTime < blockchain.transactionCooldown then return end
    
    local txData = table.remove(blockchain.transactionQueue, 1)
    
    local success, err = pcall(function()
        -- Create System.remark transaction with WASM trap fix
        local extrinsic = sdk.extrinsic.new({0, 1}, "0x" .. string.gsub(txData.message, ".", function(c)
            return string.format("%02x", string.byte(c))
        end))
        
        extrinsic:set_nonce(blockchain.nonce)
        extrinsic:set_era_immortal()
        extrinsic:set_tip(0)
        
        -- Create signing payload and sign
        local unsigned_payload = extrinsic:encode_unsigned()
        local signature = blockchain.signer:sign(unsigned_payload)
        
        -- CRITICAL: Use transaction version 4 to avoid WASM traps!
        local signed_hex = extrinsic:encode_signed(signature, blockchain.signer:get_public_key(), 4)
        
        local result = blockchain.rpc:author_submitExtrinsic(signed_hex)
        blockchain.nonce = blockchain.nonce + 1
        blockchain.lastTransactionTime = love.timer.getTime()
        
        print("✅ Game result recorded on blockchain!")
        print("📋 Transaction Hash:", result)
        print("🎮 Final Score:", score)
        print("⚡ Energy Collected:", player.energy)
    end)
    
    if not success then
        print("❌ Transaction failed:", err)
        -- Re-queue with lower priority if it failed
        if not string.find(tostring(err), "temporarily banned") then
            txData.priority = math.max(1, txData.priority - 1)
            table.insert(blockchain.transactionQueue, txData)
        end
    end
end

-- Game event blockchain logging - only for final results
local function logGameEnd(victory)
    local status = victory and "VICTORY" or "DEFEAT"
    local timestamp = os.date("%Y%m%d_%H%M%S")
    local message = string.format("COSMIC_GUARDIAN_%s:SCORE_%d:ENERGY_%d:COMBO_%d:TIME_%.1fs:WAVE_%d:%s", 
        status, score, player.energy, maxCombo, gameTime, wave, timestamp)
    queueTransaction(message, 5) -- High priority for game end
    print("🎮 Queuing final game result for blockchain...")
end

-- Initialize the game
function love.load()
    love.window.setMode(WINDOW_WIDTH, WINDOW_HEIGHT)
    love.window.setTitle("Cosmic Guardian: Stellar Harvest")
    love.graphics.setBackgroundColor(0.02, 0.02, 0.08)
    highScore = 0
    
    -- Initialize fonts
    fonts.small = love.graphics.newFont(12)
    fonts.medium = love.graphics.newFont(16)
    fonts.large = love.graphics.newFont(24)
    
    -- Blockchain connection
    local success, err = pcall(function()
        blockchain.rpc = sdk.rpc.new(RPC_URL)
        if not blockchain.rpc then
            error("Failed to create RPC connection")
        end
        
        local runtime = blockchain.rpc:state_getRuntimeVersion()
        if not runtime then
            error("Failed to get runtime version")
        end
        
        blockchain.chain_config = sdk.chain_config.detect_from_url(RPC_URL)
        if not blockchain.chain_config then
            error("Failed to detect chain configuration")
        end
        
        print("🔗 Chain: " .. blockchain.chain_config.name)
        print("💰 Token: " .. blockchain.chain_config.token_symbol)
        
        blockchain.signer = sdk.signer.from_mnemonic(blockchain.mnemonic)
        if not blockchain.signer then
            error("Failed to create signer")
        end
        
        blockchain.address = blockchain.signer:get_ss58_address(blockchain.chain_config.ss58_prefix)
        blockchain.connected = true
        
        print("Wallet connected:")
        print("  Address:", blockchain.address)
        
        fetchBalance()
    end)
    
    if not success then
        print("❌ Blockchain initialization failed:", err)
        blockchain.connected = false
        blockchain.error = err
    end
end

-- Create particle effect
function createParticles(x, y, color, count, speed)
    for i = 1, count do
        table.insert(particles, {
            x = x,
            y = y,
            vx = (math.random() - 0.5) * speed,
            vy = (math.random() - 0.5) * speed,
            color = color,
            life = 1,
            maxLife = 1,
            size = math.random() * 3 + 1
        })
    end
end

-- Create explosion effect
function createExplosion(x, y, color)
    table.insert(explosions, {
        x = x,
        y = y,
        radius = 0,
        maxRadius = 50,
        color = color,
        life = 1
    })
    screenShake = 0.3
    createParticles(x, y, color, 15, 200)
end

-- Spawn stellar crystal
function spawnStellarCrystal()
    table.insert(stellarCrystals, {
        x = math.random(30, WINDOW_WIDTH - 30),
        y = -20,
        radius = 12,
        speed = math.random(80, 120) + difficulty * 10,
        points = math.random(5, 15),
        color = {0.2, 0.8, 1},
        glow = 0,
        rotation = 0
    })
end

-- Spawn power core
function spawnPowerCore()
    local powerTypes = {"shield", "speed", "magnet", "doublePoints"}
    local powerType = powerTypes[math.random(#powerTypes)]
    local colors = {
        shield = {0.2, 1, 0.2},
        speed = {1, 1, 0.2},
        magnet = {1, 0.2, 1},
        doublePoints = {1, 0.8, 0.2}
    }
    
    table.insert(powerCores, {
        x = math.random(30, WINDOW_WIDTH - 30),
        y = -20,
        radius = 15,
        speed = math.random(60, 100),
        type = powerType,
        color = colors[powerType],
        glow = 0,
        rotation = 0
    })
end

-- Spawn dark matter
function spawnDarkMatter()
    table.insert(darkMatter, {
        x = math.random(30, WINDOW_WIDTH - 30),
        y = -20,
        radius = math.random(15, 25),
        speed = math.random(100, 150) + difficulty * 15,
        color = {0.8, 0.1, 0.1},
        glow = 0,
        rotation = 0,
        damage = 20
    })
end

-- Check collision
function checkCollision(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dist = math.sqrt(dx*dx + dy*dy)
    return dist < (a.radius + b.radius)
end

-- Update game state
function love.update(dt)
    -- Blockchain updates
    if blockchain.connected then
        if love.timer.getTime() - blockchain.lastBalanceFetch > 10 then
            fetchBalance()
        end
        sendNextTransaction()
    end
    
    -- Update visual effects
    for i = #stars, 1, -1 do
        local star = stars[i]
        star.y = star.y + star.speed * dt
        star.twinkle = star.twinkle + dt * 3
        if star.y > WINDOW_HEIGHT + 10 then
            star.y = -10
            star.x = math.random() * WINDOW_WIDTH
        end
    end
    
    for i = #nebula, 1, -1 do
        local n = nebula[i]
        n.y = n.y + n.speed * dt
        if n.y > WINDOW_HEIGHT + n.size then
            n.y = -n.size
            n.x = math.random() * WINDOW_WIDTH
        end
    end
    
    -- Update screen effects
    if screenShake > 0 then
        screenShake = screenShake - dt * 2
    end
    if flashEffect > 0 then
        flashEffect = flashEffect - dt * 3
    end
    
    -- Story mode
    if gameState == "intro" then
        return
    end
    
    if gameState ~= "playing" then return end
    
    gameTime = gameTime + dt
    difficulty = 1 + math.floor(gameTime / 45)
    wave = math.floor(gameTime / 30) + 1
    
    -- Update player
    player.invulnerable = math.max(0, player.invulnerable - dt)
    
    -- Update powerups
    for k, v in pairs(player.powerups) do
        if v > 0 then
            player.powerups[k] = v - dt
        end
    end
    
    -- Player movement
    local moveSpeed = player.speed
    if player.powerups.speed > 0 then
        moveSpeed = moveSpeed * 1.5
    end
    
    if love.keyboard.isDown('left') or love.keyboard.isDown('a') then
        player.x = math.max(player.radius, player.x - moveSpeed * dt)
    end
    if love.keyboard.isDown('right') or love.keyboard.isDown('d') then
        player.x = math.min(WINDOW_WIDTH - player.radius, player.x + moveSpeed * dt)
    end
    
    -- Player jumping
    if (love.keyboard.isDown('space') or love.keyboard.isDown('up') or love.keyboard.isDown('w')) and not player.isJumping then
        player.velocityY = JUMP_FORCE
        player.isJumping = true
        createParticles(player.x, player.y + player.radius, {0.3, 0.8, 1}, 5, 100)
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
    
    -- Update player trail
    table.insert(player.trail, {x = player.x, y = player.y, life = 1})
    for i = #player.trail, 1, -1 do
        player.trail[i].life = player.trail[i].life - dt * 3
        if player.trail[i].life <= 0 then
            table.remove(player.trail, i)
        end
    end
    
    -- Spawn objects
    crystalSpawnTimer = crystalSpawnTimer + dt
    if crystalSpawnTimer > TOKEN_SPAWN_RATE / difficulty then
        spawnStellarCrystal()
        crystalSpawnTimer = 0
    end
    
    powerSpawnTimer = powerSpawnTimer + dt
    if powerSpawnTimer > 8 / difficulty then
        spawnPowerCore()
        powerSpawnTimer = 0
    end
    
    darkMatterSpawnTimer = darkMatterSpawnTimer + dt
    if darkMatterSpawnTimer > 3 / difficulty then
        spawnDarkMatter()
        darkMatterSpawnTimer = 0
    end
    
    -- Update stellar crystals
    for i = #stellarCrystals, 1, -1 do
        local crystal = stellarCrystals[i]
        crystal.y = crystal.y + crystal.speed * dt
        crystal.glow = crystal.glow + dt * 5
        crystal.rotation = crystal.rotation + dt * 2
        
        if crystal.y > WINDOW_HEIGHT + 50 then
            table.remove(stellarCrystals, i)
        elseif checkCollision(player, crystal) then
            score = score + crystal.points
            player.energy = player.energy + crystal.points
            combo = combo + 1
            maxCombo = math.max(maxCombo, combo)
            lastCatchTime = gameTime
            
            table.insert(scorePopups, {
                x = crystal.x,
                y = crystal.y,
                points = crystal.points,
                color = crystal.color,
                t = 0
            })
            
            createParticles(crystal.x, crystal.y, crystal.color, 8, 150)
            flashEffect = 0.2
            table.remove(stellarCrystals, i)
        end
    end
    
    -- Update power cores
    for i = #powerCores, 1, -1 do
        local core = powerCores[i]
        core.y = core.y + core.speed * dt
        core.glow = core.glow + dt * 4
        core.rotation = core.rotation + dt * 3
        
        if core.y > WINDOW_HEIGHT + 50 then
            table.remove(powerCores, i)
        elseif checkCollision(player, core) then
            player.powerups[core.type] = 10
            createParticles(core.x, core.y, core.color, 12, 200)
            flashEffect = 0.3
            table.remove(powerCores, i)
        end
    end
    
    -- Update dark matter
    for i = #darkMatter, 1, -1 do
        local matter = darkMatter[i]
        matter.y = matter.y + matter.speed * dt
        matter.glow = matter.glow + dt * 6
        matter.rotation = matter.rotation + dt * 4
        
        if matter.y > WINDOW_HEIGHT + 50 then
            table.remove(darkMatter, i)
        elseif checkCollision(player, matter) and player.invulnerable <= 0 then
            if player.shield > 0 then
                player.shield = math.max(0, player.shield - matter.damage)
            else
                player.health = math.max(0, player.health - matter.damage)
            end
            player.invulnerable = 1.5
            combo = 0
            createExplosion(matter.x, matter.y, matter.color)
            table.remove(darkMatter, i)
        end
    end
    
    -- Update particles
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.life = p.life - dt / p.maxLife
        if p.life <= 0 then
            table.remove(particles, i)
        end
    end
    
    -- Update explosions
    for i = #explosions, 1, -1 do
        local e = explosions[i]
        e.radius = e.radius + 100 * dt
        e.life = e.life - dt * 2
        if e.life <= 0 then
            table.remove(explosions, i)
        end
    end
    
    -- Update score popups
    for i = #scorePopups, 1, -1 do
        local p = scorePopups[i]
        p.t = p.t + dt
        p.y = p.y - 50 * dt
        if p.t > 1.5 then
            table.remove(scorePopups, i)
        end
    end
    
    -- Reset combo if too much time passed
    if gameTime - lastCatchTime > COMBO_TIMEOUT then
        combo = 0
    end
    
    -- Check victory condition
    if player.energy >= 1000 and gameState == "playing" then
        gameState = "victory"
        logGameEnd(true)
    end
    
    -- Check game over
    if player.health <= 0 and gameState == "playing" then
        gameState = "gameover"
        logGameEnd(false)
    end
end

-- Draw game elements
function love.draw()
    -- Apply screen shake
    if screenShake > 0 then
        love.graphics.push()
        love.graphics.translate(
            (math.random() - 0.5) * screenShake * 20,
            (math.random() - 0.5) * screenShake * 20
        )
    end
    
    -- Draw space background
    love.graphics.setColor(0.02, 0.02, 0.08)
    love.graphics.rectangle("fill", 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)
    
    -- Draw nebula
    for _, n in ipairs(nebula) do
        love.graphics.setColor(n.color)
        love.graphics.circle("fill", n.x, n.y, n.size)
    end
    
    -- Draw stars
    for _, star in ipairs(stars) do
        local twinkle = 0.5 + 0.5 * math.sin(star.twinkle)
        love.graphics.setColor(1, 1, 1, twinkle)
        love.graphics.circle("fill", star.x, star.y, star.size)
    end
    
    -- Flash effect
    if flashEffect > 0 then
        love.graphics.setColor(1, 1, 1, flashEffect * 0.3)
        love.graphics.rectangle("fill", 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)
    end
    
    -- Story/Intro screen
    if gameState == "intro" then
        love.graphics.setColor(0, 0, 0, 0.9)
        love.graphics.rectangle("fill", 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)
        
        local story = storyText[storyPhase]
        if story then
            -- Fixed title positioning to stay within screen bounds
            love.graphics.setColor(0.3, 0.8, 1)
            love.graphics.printf(story.title, 50, 80, WINDOW_WIDTH - 100, "center", 0, 1.8)
            
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(story.text, 80, 150, WINDOW_WIDTH - 160, "center", 0, 1.2)
            
            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.printf("Press SPACE to continue", 50, WINDOW_HEIGHT - 80, WINDOW_WIDTH - 100, "center", 0, 1.3)
        end
        
        if screenShake > 0 then
            love.graphics.pop()
        end
        return
    end
    
    if gameState ~= "playing" and gameState ~= "gameover" and gameState ~= "victory" then
        if screenShake > 0 then love.graphics.pop() end
        return
    end
    
    -- Draw particles
    for _, p in ipairs(particles) do
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], p.life)
        love.graphics.circle("fill", p.x, p.y, p.size * p.life)
    end
    
    -- Draw explosions
    for _, e in ipairs(explosions) do
        local alpha = e.life * 0.5
        love.graphics.setColor(e.color[1], e.color[2], e.color[3], alpha)
        love.graphics.circle("line", e.x, e.y, e.radius)
        love.graphics.setColor(e.color[1], e.color[2], e.color[3], alpha * 0.3)
        love.graphics.circle("fill", e.x, e.y, e.radius * 0.5)
    end
    
    -- Draw player trail
    for i, pos in ipairs(player.trail) do
        local alpha = pos.life * 0.4
        love.graphics.setColor(0.3, 0.8, 1, alpha)
        love.graphics.circle("fill", pos.x, pos.y, player.radius * pos.life)
    end
    
    -- Draw player
    if player.invulnerable > 0 and math.floor(player.invulnerable * 10) % 2 == 0 then
        -- Flashing when invulnerable
    else
        -- Player glow
        love.graphics.setColor(0.3, 0.8, 1, 0.3)
        love.graphics.circle("fill", player.x, player.y, player.radius + 8)
        
        -- Player body
        love.graphics.setColor(player.color)
        love.graphics.circle("fill", player.x, player.y, player.radius)
        
        -- Player core
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.circle("fill", player.x, player.y, player.radius * 0.6)
        
        -- Shield effect
        if player.shield > 0 then
            love.graphics.setColor(0.2, 1, 0.2, 0.5)
            love.graphics.circle("line", player.x, player.y, player.radius + 15)
            love.graphics.circle("line", player.x, player.y, player.radius + 12)
        end
    end
    
    -- Draw stellar crystals
    drawStellarCrystals()
    
    -- Draw power cores
    drawPowerCores()
    
    -- Draw dark matter
    drawDarkMatter()
    
    -- Draw score popups
    drawScorePopups()
    
    -- UI Background panels
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 10, 10, 280, 140, 10, 10) -- Stats panel
    love.graphics.rectangle("fill", WINDOW_WIDTH - 320, 10, 310, 160, 10, 10) -- Blockchain panel
    
    -- Health and shield bars
    love.graphics.setColor(0.8, 0.2, 0.2)
    love.graphics.rectangle("fill", 20, 20, 200, 15, 5, 5)
    love.graphics.setColor(0.2, 0.8, 0.2)
    love.graphics.rectangle("fill", 20, 20, 200 * (player.health / player.maxHealth), 15, 5, 5)
    
    if player.shield > 0 then
        love.graphics.setColor(0.2, 0.2, 0.8)
        love.graphics.rectangle("fill", 20, 40, 200, 10, 5, 5)
        love.graphics.setColor(0.2, 0.8, 1)
        love.graphics.rectangle("fill", 20, 40, 200 * (player.shield / player.maxShield), 10, 5, 5)
    end
    
    -- Game stats
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Health: " .. player.health .. "/" .. player.maxHealth, 20, 55)
    love.graphics.print("Score: " .. score, 20, 75)
    love.graphics.print("Energy: " .. player.energy .. "/1000", 20, 95)
    love.graphics.print("Wave: " .. wave .. " | Time: " .. string.format("%.1f", gameTime) .. "s", 20, 115)
    
    -- Combo display
    if combo > 1 then
        love.graphics.setColor(1, 1, 0)
        love.graphics.print("COMBO x" .. combo, 20, 135, 0, 1.5)
    end
    
    -- Enhanced Blockchain UI
    love.graphics.setColor(1, 1, 1)
    local addr = blockchain.address and (blockchain.address:sub(1, 8) .. "..." .. blockchain.address:sub(-4)) or "Not Connected"
    local bal = blockchain.balanceLoading and "Loading..." or (blockchain.balance and string.format("%.4f PSA", blockchain.balance / (10^12)) or "0 PSA")
    local chain = blockchain.chain_config and blockchain.chain_config.name or "Unknown"
    
    love.graphics.print("🔗 BLOCKCHAIN STATUS", WINDOW_WIDTH - 310, 20)
    love.graphics.print("Wallet: " .. addr, WINDOW_WIDTH - 310, 40)
    love.graphics.print("Balance: " .. bal, WINDOW_WIDTH - 310, 60)
    love.graphics.print("Chain: " .. chain, WINDOW_WIDTH - 310, 80)
    love.graphics.print("Nonce: " .. blockchain.nonce, WINDOW_WIDTH - 310, 100)
    love.graphics.print("Queue: " .. #blockchain.transactionQueue .. " pending", WINDOW_WIDTH - 310, 120)
    
    if blockchain.connected then
        love.graphics.setColor(0.2, 1, 0.4)
        love.graphics.print("● CONNECTED", WINDOW_WIDTH - 310, 140)
    else
        love.graphics.setColor(1, 0.4, 0.2)
        love.graphics.print("● DISCONNECTED", WINDOW_WIDTH - 310, 140)
    end
    
    -- Game over screen with fixed positioning
    if gameState == "gameover" then
        love.graphics.setColor(0, 0, 0, 0.9)
        love.graphics.rectangle("fill", 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)
        
        love.graphics.setColor(0.1, 0.1, 0.1, 0.95)
        love.graphics.rectangle("fill", 60, 100, WINDOW_WIDTH - 120, WINDOW_HEIGHT - 200, 20, 20)
        
        love.graphics.setColor(1, 0.2, 0.2)
        love.graphics.printf("MISSION FAILED", 80, 130, WINDOW_WIDTH - 160, "center", 0, 1.8)
        
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("The Dark Matter consumed the galaxy...", 100, 180, WINDOW_WIDTH - 200, "center", 0, 1.1)
        love.graphics.printf("Final Score: " .. score, 100, 210, WINDOW_WIDTH - 200, "center", 0, 1.3)
        love.graphics.printf("Energy Collected: " .. player.energy .. "/1000", 100, 240, WINDOW_WIDTH - 200, "center", 0, 1.1)
        love.graphics.printf("Max Combo: " .. maxCombo .. "x", 100, 270, WINDOW_WIDTH - 200, "center", 0, 1.1)
        love.graphics.printf("Survival Time: " .. string.format("%.1f", gameTime) .. "s", 100, 300, WINDOW_WIDTH - 200, "center", 0, 1.1)
        
        if blockchain.connected then
            love.graphics.setColor(0.3, 0.8, 1)
            love.graphics.printf("Game data recorded on blockchain!", 100, 340, WINDOW_WIDTH - 200, "center", 0, 1.0)
        end
        
        love.graphics.setColor(0.3, 0.8, 1)
        love.graphics.printf("Press SPACE to try again", 100, 380, WINDOW_WIDTH - 200, "center", 0, 1.4)
    end
    
    -- Victory screen with fixed positioning
    if gameState == "victory" then
        love.graphics.setColor(0, 0, 0, 0.9)
        love.graphics.rectangle("fill", 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)
        
        love.graphics.setColor(0.1, 0.1, 0.1, 0.95)
        love.graphics.rectangle("fill", 60, 100, WINDOW_WIDTH - 120, WINDOW_HEIGHT - 200, 20, 20)
        
        love.graphics.setColor(0.2, 1, 0.2)
        love.graphics.printf("MISSION ACCOMPLISHED!", 80, 130, WINDOW_WIDTH - 160, "center", 0, 1.6)
        
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("You saved the galaxy, Guardian!", 100, 180, WINDOW_WIDTH - 200, "center", 0, 1.1)
        love.graphics.printf("The Defense Grid is now online!", 100, 210, WINDOW_WIDTH - 200, "center", 0, 1.0)
        love.graphics.printf("Final Score: " .. score, 100, 240, WINDOW_WIDTH - 200, "center", 0, 1.3)
        love.graphics.printf("Max Combo: " .. maxCombo .. "x", 100, 270, WINDOW_WIDTH - 200, "center", 0, 1.1)
        love.graphics.printf("Mission Time: " .. string.format("%.1f", gameTime) .. "s", 100, 300, WINDOW_WIDTH - 200, "center", 0, 1.1)
        
        if blockchain.connected then
            love.graphics.setColor(0.2, 1, 0.2)
            love.graphics.printf("Victory recorded on blockchain!", 100, 340, WINDOW_WIDTH - 200, "center", 0, 1.0)
        end
        
        love.graphics.setColor(0.3, 0.8, 1)
        love.graphics.printf("Press SPACE to play again", 100, 380, WINDOW_WIDTH - 200, "center", 0, 1.4)
    end
    
    if screenShake > 0 then
        love.graphics.pop()
    end
end

-- Handle key presses
function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "space" then
        if gameState == "intro" then
            storyPhase = storyPhase + 1
            if storyPhase > #storyText then
                gameState = "playing"
                resetGame()
            end
        elseif gameState == "gameover" or gameState == "victory" then
            gameState = "intro"
            storyPhase = 1
        end
    elseif key == "p" then
        if gameState == "playing" then
            gameState = "paused"
        elseif gameState == "paused" then
            gameState = "playing"
        end
    end
end

-- Reset game
function resetGame()
    stellarCrystals = {}
    powerCores = {}
    darkMatter = {}
    particles = {}
    explosions = {}
    scorePopups = {}
    
    score = 0
    combo = 0
    maxCombo = 0
    gameTime = 0
    difficulty = 1
    wave = 1
    
    crystalSpawnTimer = 0
    powerSpawnTimer = 0
    darkMatterSpawnTimer = 0
    
    player.x = WINDOW_WIDTH / 2
    player.y = WINDOW_HEIGHT - 80
    player.velocityY = 0
    player.isJumping = false
    player.health = player.maxHealth
    player.shield = 0
    player.energy = 0
    player.color = {0.3, 0.8, 1}
    player.trail = {}
    player.invulnerable = 0
    
    for k, _ in pairs(player.powerups) do
        player.powerups[k] = 0
    end
    
    screenShake = 0
    flashEffect = 0
    
    -- Refresh nonce for new game
    if blockchain.connected then
        fetchBalance()
    end
end

-- Draw stellar crystals
function drawStellarCrystals()
    for _, crystal in ipairs(stellarCrystals) do
        love.graphics.push()
        love.graphics.translate(crystal.x, crystal.y)
        love.graphics.rotate(crystal.rotation)
        
        -- Glow effect
        local glowAlpha = 0.3 + 0.2 * math.sin(crystal.glow)
        love.graphics.setColor(crystal.color[1], crystal.color[2], crystal.color[3], glowAlpha)
        love.graphics.circle("fill", 0, 0, crystal.radius * 1.5)
        
        -- Main crystal
        love.graphics.setColor(crystal.color)
        love.graphics.circle("fill", 0, 0, crystal.radius)
        
        -- Inner shine
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.circle("fill", -crystal.radius * 0.3, -crystal.radius * 0.3, crystal.radius * 0.4)
        
        love.graphics.pop()
    end
end

-- Draw power cores
function drawPowerCores()
    for _, core in ipairs(powerCores) do
        love.graphics.push()
        love.graphics.translate(core.x, core.y)
        love.graphics.rotate(core.rotation)
        
        -- Outer glow
        local glowAlpha = 0.4 + 0.3 * math.sin(core.glow)
        love.graphics.setColor(core.color[1], core.color[2], core.color[3], glowAlpha)
        love.graphics.circle("fill", 0, 0, core.radius * 2)
        
        -- Main core
        love.graphics.setColor(core.color)
        love.graphics.circle("fill", 0, 0, core.radius)
        
        -- Core pattern
        love.graphics.setColor(1, 1, 1, 0.9)
        for i = 1, 6 do
            local angle = (i / 6) * math.pi * 2
            local x = math.cos(angle) * core.radius * 0.6
            local y = math.sin(angle) * core.radius * 0.6
            love.graphics.circle("fill", x, y, 2)
        end
        
        love.graphics.pop()
    end
end

-- Draw dark matter
function drawDarkMatter()
    for _, matter in ipairs(darkMatter) do
        love.graphics.push()
        love.graphics.translate(matter.x, matter.y)
        love.graphics.rotate(matter.rotation)
        
        -- Dark aura
        local glowAlpha = 0.5 + 0.3 * math.sin(matter.glow)
        love.graphics.setColor(matter.color[1], matter.color[2], matter.color[3], glowAlpha)
        love.graphics.circle("fill", 0, 0, matter.radius * 1.8)
        
        -- Main matter
        love.graphics.setColor(matter.color)
        love.graphics.circle("fill", 0, 0, matter.radius)
        
        -- Dark core
        love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
        love.graphics.circle("fill", 0, 0, matter.radius * 0.5)
        
        -- Energy crackling
        love.graphics.setColor(0.8, 0.2, 0.2, 0.6)
        for i = 1, 4 do
            local angle = (i / 4) * math.pi * 2 + matter.rotation * 2
            local x1 = math.cos(angle) * matter.radius * 0.3
            local y1 = math.sin(angle) * matter.radius * 0.3
            local x2 = math.cos(angle) * matter.radius * 0.8
            local y2 = math.sin(angle) * matter.radius * 0.8
            love.graphics.line(x1, y1, x2, y2)
        end
        
        love.graphics.pop()
    end
end

-- Draw particles
function drawParticles()
    for _, p in ipairs(particles) do
        local alpha = p.life
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
        love.graphics.circle("fill", p.x, p.y, p.size * p.life)
    end
end

-- Draw explosions
function drawExplosions()
    for _, e in ipairs(explosions) do
        local alpha = e.life * 0.5
        love.graphics.setColor(e.color[1], e.color[2], e.color[3], alpha)
        love.graphics.circle("line", e.x, e.y, e.radius)
        love.graphics.setColor(e.color[1], e.color[2], e.color[3], alpha * 0.3)
        love.graphics.circle("fill", e.x, e.y, e.radius * 0.5)
    end
end

-- Draw score popups
function drawScorePopups()
    for _, p in ipairs(scorePopups) do
        local alpha = 1 - (p.t / 1.5)
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
        love.graphics.printf("+" .. p.points, p.x - 50, p.y, 100, "center")
    end
end 