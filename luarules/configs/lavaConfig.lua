local mapName = Game.mapName:lower()
Spring.Echo("Lava Mapname", mapName)
lavaMap = false
--[[ 
    
addTideRhym(HeightLevel, Speed, Delay for next TideRhym in seconds)

if string.find(mapName, "quicksilver") then
    lavaMap = true
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




