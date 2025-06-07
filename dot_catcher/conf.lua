function love.conf(t)
    t.title = "Cosmic Guardian: Stellar Harvest"
    t.version = "11.4"
    t.window.width = 800
    t.window.height = 600
    t.window.resizable = false
    t.window.vsync = 1
    
    -- Enhanced graphics settings
    t.window.msaa = 4  -- Anti-aliasing
    t.window.depth = 16
    
    -- For debugging
    t.console = true
    
    -- Game identity
    t.identity = "cosmic_guardian"
end 