local mapName = Game.mapName:lower()
Spring.Echo("Lava Mapname", mapName)
lavaMap = false
--[[ EXAMPLE
    
addTideRhym(HeightLevel, Speed, Delay for next TideRhym in seconds)

if string.find(mapName, "quicksilver") then
    lavaMap = true
    lavaMinHeight = 137 -- minheight of map smf - otherwise will use 0
    if (gadgetHandler:IsSyncedCode()) then
        lavaLevel = 220
        lavaGrow = 0.25
        lavaDamage = 100
        
        addTideRhym (-21, 0.25, 5*10)
        addTideRhym (150, 0.25, 3)
        addTideRhym (-20, 0.25, 5*10)
        addTideRhym (150, 0.25, 5)
        addTideRhym (-20, 1, 5*60)
        addTideRhym (180, 0.5, 60)
        addTideRhym (240, 0.2, 10)
    end
end

]]

-- For testing purposes
-- if string.find(mapName, "quicksilver") then
--     lavaMap = true
--     lavaMinHeight = 137 -- minheight of map smf - otherwise will use 0
--     if (gadgetHandler:IsSyncedCode()) then
--         lavaLevel = 220
--         lavaGrow = 0.25
--         lavaDamage = 100
        
--         addTideRhym (-21, 0.25, 5*10)
--         addTideRhym (150, 0.25, 3)
--         addTideRhym (-20, 0.25, 5*10)
--         addTideRhym (150, 0.25, 5)
--         addTideRhym (-20, 1, 5*60)
--         addTideRhym (180, 0.5, 60)
--         addTideRhym (240, 0.2, 10)
--     end
-- end

if string.find(mapName, "incandescence") then
    lavaMap = true
    lavaMinHeight = 137 -- minheight of map smf - otherwise will use 0

    if (gadgetHandler:IsSyncedCode()) then
        lavaLevel = 210 -- pre-game lava level
        lavaGrow = 0.25
        lavaDamage = 150 -- damage per second

        addTideRhym (209, 0.25, 5*6000) -- needs to be -1 than pre-game lava level
    end
end

if string.find(mapName, "hotstepper") then
    lavaMap = true
    lavaLevel = 100 -- pre-game lava level
    lavaGrow = 0.25
    lavaDamage = 150 -- damage per second
    if (gadgetHandler:IsSyncedCode()) then
        addTideRhym (99, 0.25, 5*60) -- needs to be -1 than pre-game lava level
        addTideRhym (236, 0.10, 5)
        addTideRhym (100, 0.25, 5*60)
        addTideRhym (236, 0.10, 5)
        addTideRhym (100, 0.25, 5*60)
        addTideRhym (300, 0.20, 1)
        addTideRhym (355, 0.10, 30)
        addTideRhym (395, 0.07, 9)
    end




elseif Game.waterDamage > 0 then -- Waterdamagemaps - keep at the very bottom
    lavaMap = true
    lavaLevel = 1 -- pre-game lava level
    lavaGrow = 0.25
    lavaDamage = 100 -- damage per second
    if (gadgetHandler:IsSyncedCode()) then
        addTideRhym (1, 0.25, 9999)
        addTideRhym (1, 0.25, 9999)
    end
end


