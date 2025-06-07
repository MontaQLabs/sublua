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

-- Blockchain: fetch balance
local function fetchBalance()
    if not blockchain.connected or not blockchain.address then return end
    blockchain.balanceLoading = true
    local success, res = pcall(function()
        local account_info = blockchain.rpc:get_account_info(blockchain.address)
        if account_info and account_info.data then
            blockchain.balance = account_info.data.free
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
    love.window.setTitle("Cosmic Guardian: Stellar Harvest")
    love.graphics.setBackgroundColor(0.02, 0.02, 0.08)
    highScore = 0
    
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
    if blockchain.connected and (love.timer.getTime() - blockchain.lastBalanceFetch > 5) then
        fetchBalance()
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
    if crystalSpawnTimer >= (1.2 - difficulty * 0.1) then
        spawnStellarCrystal()
        crystalSpawnTimer = 0
    end
    
    powerSpawnTimer = powerSpawnTimer + dt
    if powerSpawnTimer >= 8 then
        spawnPowerCore()
        powerSpawnTimer = 0
    end
    
    darkMatterSpawnTimer = darkMatterSpawnTimer + dt
    if darkMatterSpawnTimer >= (3 - difficulty * 0.2) then
        spawnDarkMatter()
        darkMatterSpawnTimer = 0
    end
    
    -- Update stellar crystals
    for i = #stellarCrystals, 1, -1 do
        local crystal = stellarCrystals[i]
        crystal.y = crystal.y + crystal.speed * dt
        crystal.glow = crystal.glow + dt * 5
        crystal.rotation = crystal.rotation + dt * 2
        
        -- Magnet effect
        if player.powerups.magnet > 0 then
            local dx = player.x - crystal.x
            local dy = player.y - crystal.y
            local dist = math.sqrt(dx*dx + dy*dy)
            if dist < 100 then
                crystal.x = crystal.x + (dx / dist) * 150 * dt
                crystal.y = crystal.y + (dy / dist) * 150 * dt
            end
        end
        
        -- Check collision with player
        if checkCollision(player, crystal) then
            table.remove(stellarCrystals, i)
            local points = crystal.points
            if player.powerups.doublePoints > 0 then
                points = points * 2
            end
            score = score + points
            player.energy = player.energy + points
            
            -- Combo system
            local currentTime = love.timer.getTime()
            if currentTime - lastCatchTime < COMBO_TIMEOUT then
                combo = combo + 1
                maxCombo = math.max(maxCombo, combo)
                points = points + combo
                score = score + combo
            else
                combo = 1
            end
            lastCatchTime = currentTime
            
            table.insert(scorePopups, {
                x = crystal.x, y = crystal.y, 
                points = points, t = 0, 
                color = crystal.color
            })
            
            createParticles(crystal.x, crystal.y, crystal.color, 8, 150)
            flashEffect = 0.1
            
        elseif crystal.y > WINDOW_HEIGHT + crystal.radius then
            table.remove(stellarCrystals, i)
        end
    end
    
    -- Update power cores
    for i = #powerCores, 1, -1 do
        local core = powerCores[i]
        core.y = core.y + core.speed * dt
        core.glow = core.glow + dt * 4
        core.rotation = core.rotation + dt * 3
        
        if checkCollision(player, core) then
            table.remove(powerCores, i)
            player.powerups[core.type] = 10 -- 10 seconds
            
            if core.type == "shield" then
                player.shield = player.maxShield
            end
            
            createExplosion(core.x, core.y, core.color)
            
        elseif core.y > WINDOW_HEIGHT + core.radius then
            table.remove(powerCores, i)
        end
    end
    
    -- Update dark matter
    for i = #darkMatter, 1, -1 do
        local matter = darkMatter[i]
        matter.y = matter.y + matter.speed * dt
        matter.glow = matter.glow + dt * 6
        matter.rotation = matter.rotation + dt * 4
        
        if checkCollision(player, matter) and player.invulnerable <= 0 then
            table.remove(darkMatter, i)
            
            if player.shield > 0 then
                player.shield = math.max(0, player.shield - matter.damage)
            else
                player.health = math.max(0, player.health - matter.damage)
                player.invulnerable = 1
            end
            
            createExplosion(matter.x, matter.y, matter.color)
            
            if player.health <= 0 then
                gameState = "gameover"
                if score > highScore then highScore = score end
            end
            
        elseif matter.y > WINDOW_HEIGHT + matter.radius then
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
        e.radius = e.radius + e.maxRadius * dt * 3
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
    
    -- Check win condition
    if player.energy >= 1000 then
        gameState = "victory"
        if score > highScore then highScore = score end
    end
end

-- Draw game elements
function love.draw()
    -- Apply screen shake
    if screenShake > 0 then
        love.graphics.push()
        love.graphics.translate(
            (math.random() - 0.5) * screenShake * 10,
            (math.random() - 0.5) * screenShake * 10
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
        local alpha = 0.5 + 0.5 * math.sin(star.twinkle)
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.circle("fill", star.x, star.y, star.size)
    end
    
    -- Flash effect
    if flashEffect > 0 then
        love.graphics.setColor(1, 1, 1, flashEffect)
        love.graphics.rectangle("fill", 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)
    end
    
    -- Story/Intro screen
    if gameState == "intro" then
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)
        
        local story = storyText[storyPhase]
        if story then
            -- Background panel for better readability
            love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
            love.graphics.rectangle("fill", 50, 100, WINDOW_WIDTH - 100, WINDOW_HEIGHT - 200, 20, 20)
            
            -- Title
            love.graphics.setColor(0.3, 0.8, 1)
            love.graphics.printf(story.title, 0, 130, WINDOW_WIDTH, "center", 0, 1.8)
            
            -- Story text
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(story.text, 70, 180, WINDOW_WIDTH - 140, "center", 0, 1)
            
            -- Continue prompt
            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.printf("Press SPACE to continue...", 70, WINDOW_HEIGHT - 150, WINDOW_WIDTH - 140, "center", 0, 1)
        end
        
        if screenShake > 0 then love.graphics.pop() end
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
        love.graphics.setColor(e.color[1], e.color[2], e.color[3], e.life * 0.3)
        love.graphics.circle("line", e.x, e.y, e.radius)
        love.graphics.setColor(e.color[1], e.color[2], e.color[3], e.life * 0.1)
        love.graphics.circle("fill", e.x, e.y, e.radius)
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
    for _, crystal in ipairs(stellarCrystals) do
        -- Glow effect
        love.graphics.setColor(crystal.color[1], crystal.color[2], crystal.color[3], 0.3)
        love.graphics.circle("fill", crystal.x, crystal.y, crystal.radius + 5 + 3 * math.sin(crystal.glow))
        
        -- Crystal body
        love.graphics.setColor(crystal.color)
        love.graphics.push()
        love.graphics.translate(crystal.x, crystal.y)
        love.graphics.rotate(crystal.rotation)
        love.graphics.polygon("fill", 
            -crystal.radius, 0,
            0, -crystal.radius,
            crystal.radius, 0,
            0, crystal.radius
        )
        love.graphics.pop()
        
        -- Crystal core
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.circle("fill", crystal.x, crystal.y, crystal.radius * 0.4)
    end
    
    -- Draw power cores
    for _, core in ipairs(powerCores) do
        -- Glow effect
        love.graphics.setColor(core.color[1], core.color[2], core.color[3], 0.4)
        love.graphics.circle("fill", core.x, core.y, core.radius + 8 + 4 * math.sin(core.glow))
        
        -- Core body
        love.graphics.setColor(core.color)
        love.graphics.push()
        love.graphics.translate(core.x, core.y)
        love.graphics.rotate(core.rotation)
        love.graphics.rectangle("fill", -core.radius, -core.radius, core.radius * 2, core.radius * 2)
        love.graphics.pop()
        
        -- Core center
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("fill", core.x, core.y, core.radius * 0.5)
    end
    
    -- Draw dark matter
    for _, matter in ipairs(darkMatter) do
        -- Menacing glow
        love.graphics.setColor(matter.color[1], matter.color[2], matter.color[3], 0.5)
        love.graphics.circle("fill", matter.x, matter.y, matter.radius + 6 + 3 * math.sin(matter.glow))
        
        -- Dark matter body
        love.graphics.setColor(matter.color)
        love.graphics.push()
        love.graphics.translate(matter.x, matter.y)
        love.graphics.rotate(matter.rotation)
        
        -- Spiky appearance
        local spikes = 8
        local points = {}
        for i = 1, spikes do
            local angle = (i - 1) * (math.pi * 2 / spikes)
            local radius = matter.radius * (0.7 + 0.3 * math.sin(matter.glow + i))
            table.insert(points, math.cos(angle) * radius)
            table.insert(points, math.sin(angle) * radius)
        end
        love.graphics.polygon("fill", points)
        love.graphics.pop()
    end
    
    -- Draw score popups
    for _, p in ipairs(scorePopups) do
        local alpha = 1 - (p.t / 1.5)
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
        love.graphics.printf("+" .. p.points, p.x - 30, p.y - 20, 60, "center", 0, 1.5 + p.t)
        
        if combo > 1 then
            love.graphics.setColor(1, 1, 0, alpha)
            love.graphics.printf("x" .. combo, p.x - 30, p.y + 10, 60, "center", 0, 1.2)
        end
    end
    
    -- UI Background panels
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 10, 10, 250, 120, 10, 10) -- Stats panel
    love.graphics.rectangle("fill", WINDOW_WIDTH - 310, 10, 300, 120, 10, 10) -- Blockchain panel
    
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
    love.graphics.print("Wave: " .. wave, 20, 115)
    
    -- Combo display
    if combo > 1 then
        love.graphics.setColor(1, 1, 0)
        love.graphics.print("COMBO x" .. combo, 140, 75, 0, 1.5)
    end
    
    -- Active powerups
    local powerY = 140
    for k, v in pairs(player.powerups) do
        if v > 0 then
            love.graphics.setColor(1, 1, 1, 0.8)
            love.graphics.print(k:upper() .. ": " .. string.format("%.1f", v), 20, powerY)
            powerY = powerY + 20
        end
    end
    
    -- Blockchain UI
    love.graphics.setColor(1, 1, 1)
    local addr = blockchain.address and (blockchain.address:sub(1, 8) .. "..." .. blockchain.address:sub(-4)) or "-"
    local bal = blockchain.balanceLoading and "..." or (blockchain.balance and string.format("%.5f PSA", blockchain.balance / (10^12)) or "0 PSA")
    local chain = blockchain.chain_config and blockchain.chain_config.name or "?"
    
    love.graphics.printf("Wallet: " .. addr, WINDOW_WIDTH - 300, 20, 280, "right")
    love.graphics.printf("Balance: " .. bal, WINDOW_WIDTH - 300, 44, 280, "right")
    love.graphics.printf("Chain: " .. chain, WINDOW_WIDTH - 300, 68, 280, "right")
    
    if blockchain.connected then
        love.graphics.setColor(0.2, 1, 0.4)
        love.graphics.printf("CONNECTED", WINDOW_WIDTH - 300, 92, 280, "right")
    end
    
    -- Game over screen
    if gameState == "gameover" then
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)
        
        love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
        love.graphics.rectangle("fill", 50, 80, WINDOW_WIDTH - 100, WINDOW_HEIGHT - 160, 20, 20)
        
        love.graphics.setColor(1, 0.2, 0.2)
        love.graphics.printf("MISSION FAILED", 0, 110, WINDOW_WIDTH, "center", 0, 2)
        
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("The Dark Matter consumed the galaxy...", 70, 160, WINDOW_WIDTH - 140, "center", 0, 1.2)
        love.graphics.printf("Final Score: " .. score, 70, 200, WINDOW_WIDTH - 140, "center", 0, 1.5)
        love.graphics.printf("Energy Collected: " .. player.energy .. "/1000", 70, 240, WINDOW_WIDTH - 140, "center", 0, 1.2)
        love.graphics.printf("Max Combo: " .. maxCombo .. "x", 70, 280, WINDOW_WIDTH - 140, "center", 0, 1.2)
        love.graphics.printf("Survival Time: " .. string.format("%.1f", gameTime) .. "s", 70, 320, WINDOW_WIDTH - 140, "center", 0, 1.2)
        
        love.graphics.setColor(0.3, 0.8, 1)
        love.graphics.printf("Press SPACE to try again", 70, 380, WINDOW_WIDTH - 140, "center", 0, 1.5)
    end
    
    -- Victory screen
    if gameState == "victory" then
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)
        
        love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
        love.graphics.rectangle("fill", 50, 80, WINDOW_WIDTH - 100, WINDOW_HEIGHT - 160, 20, 20)
        
        love.graphics.setColor(0.2, 1, 0.2)
        love.graphics.printf("MISSION ACCOMPLISHED!", 0, 110, WINDOW_WIDTH, "center", 0, 2)
        
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("You saved the galaxy, Guardian!", 70, 160, WINDOW_WIDTH - 140, "center", 0, 1.2)
        love.graphics.printf("The Defense Grid is now online!", 70, 190, WINDOW_WIDTH - 140, "center", 0, 1)
        love.graphics.printf("Final Score: " .. score, 70, 230, WINDOW_WIDTH - 140, "center", 0, 1.5)
        love.graphics.printf("Max Combo: " .. maxCombo .. "x", 70, 270, WINDOW_WIDTH - 140, "center", 0, 1.2)
        love.graphics.printf("Mission Time: " .. string.format("%.1f", gameTime) .. "s", 70, 310, WINDOW_WIDTH - 140, "center", 0, 1.2)
        
        love.graphics.setColor(0.3, 0.8, 1)
        love.graphics.printf("Press SPACE to play again", 70, 380, WINDOW_WIDTH - 140, "center", 0, 1.5)
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

-- Blockchain functions
function sendScoreToBlockchain()
    if not blockchain.connected or not blockchain.signer or blockchain.scoreSent then return end
    
    local success, err = pcall(function()
        local extrinsic = sdk.extrinsic.new({
            module = "System",
            call = "remark",
            args = { "COSMIC_GUARDIAN_SCORE:" .. score .. ":ENERGY:" .. player.energy .. ":COMBO:" .. maxCombo }
        })
        
        local account_info = blockchain.rpc:get_account_info(blockchain.address)
        local nonce = account_info and account_info.nonce or 0
        
        extrinsic:set_nonce(nonce)
        extrinsic:set_tip(0)
        extrinsic:set_era_immortal()
        
        local unsigned_hex = extrinsic:encode_unsigned()
        local signature = blockchain.signer:sign(unsigned_hex)
        local signed_hex = extrinsic:encode_signed(signature, blockchain.signer:get_public_key())
        
        local result = blockchain.rpc:author_submitExtrinsic(signed_hex)
        blockchain.scoreSent = true
        print("Score sent to blockchain:", score)
        print("Energy collected:", player.energy)
        print("Max combo:", maxCombo)
        print("Transaction hash:", result)
    end)
    
    if not success then
        print("Failed to send score:", err)
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
    
    blockchain.scoreSent = false
    screenShake = 0
    flashEffect = 0
end 