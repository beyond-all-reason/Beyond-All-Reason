if not gadgetHandler:IsSyncedCode() then
	return false
end

function gadget:GetInfo()
    return {
      name      = "Neutral Unit Spawner",
      desc      = "Spawns neutral units on the map in predefined locations",
      author    = "Damgam",
      date      = "2024",
	  license   = "GNU GPL, v2 or later",
      layer     = -100,
      enabled   = true,
    }
end

local SpawnGroups = {
    [1] = {
        units = { -- list of units in this pack
            "armpw",
            "armpw",
            "armpw",
            "armpw",
            "armpw",
        },
        spawnpos = {3100, 3570},
        role = "guardian", -- doesn't matter for now, will allow different behaviours when that's coded in
        spread = 900, -- range of spawn and orders
    },
    [2] = {
        units = { -- list of units in this pack
            "armpw",
            "armpw",
            "armpw",
        },
        spawnpos = {657, 4000},
        role = "guardian", -- doesn't matter for now, will allow different behaviours when that's coded in
        spread = 100, -- range of spawn and orders
    },
    [3] = {
        units = { -- list of units in this pack
            "armpw",
            "armpw",
            "armpw",
        },
        spawnpos = {5450, 3140},
        role = "guardian", -- doesn't matter for now, will allow different behaviours when that's coded in
        spread = 100, -- range of spawn and orders
    },
}

for index, content in pairs(SpawnGroups) do
    for i = 1,#content.units do
        local posx = content.spawnpos[1] + math.random(-content.spread, content.spread)
        local posz = content.spawnpos[2] + math.random(-content.spread, content.spread)
        local posy = Spring.GetGroundHeight(posx, posz)
        local createdUnit = Spring.CreateUnit(content.units[i], posx, posy, posz, math.random(0,3), Spring.GetGaiaTeamID())
        if createdUnit then
            for _ = 1,5 do
                Spring.GiveOrderToUnit(createdUnit, CMD.PATROL, {content.spawnpos[1] + math.random(-content.spread, content.spread), posy, content.spawnpos[2] + math.random(-content.spread, content.spread)}, {"shift"})
            end
        end
    end
end