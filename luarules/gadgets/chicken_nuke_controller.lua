function gadget:GetInfo()
	return {
		name = "Chicken Defense Nuke Controller",
		desc = "Gives targets to chicken nuke launchers",
		author = "Damgam",
		date = "2023",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
    return
end

if Spring.Utilities.Gametype.IsChickens() then
	Spring.Log(gadget:GetInfo().name, LOG.INFO, "Chicken Defense Spawner Activated!")
else
	Spring.Log(gadget:GetInfo().name, LOG.INFO, "Chicken Defense Spawner Deactivated!")
	return false
end
local nukeDefs = {
    [UnitDefNames["chicken_turretxl_meteor"].id] = true,
}
local aliveNukeLaunchers = {}

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
    if nukeDefs[unitDefID] then
        aliveNukeLaunchers[unitID] = Spring.GetGameSeconds() + math.random(5,15)
    end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID)
    if aliveNukeLaunchers[unitID] then
        aliveNukeLaunchers[unitID] = nil
    end
end

function gadget:GameFrame(frame)
    if frame%30 == 17 then
        local allUnits = Spring.GetAllUnits()
        for nukeID, cooldown in pairs(aliveNukeLaunchers) do
            if cooldown <= Spring.GetGameSeconds() then
                local targetID = allUnits[math.random(1,#allUnits)]
                if Spring.GetUnitTeam(targetID) ~= Spring.GetUnitTeam(nukeID) then
                    local x,y,z = Spring.GetUnitPosition(targetID)
                    x = x + math.random(-1024,1024)
                    z = z + math.random(-1024,1024)
                    y = math.max(Spring.GetGroundHeight(x,z), 0)
                    if x and z and x > 0 and x < Game.mapSizeX and z > 0 and z < Game.mapSizeZ then
                        Spring.GiveOrderToUnit(nukeID, CMD.ATTACK, {x, y, z}, {"shift"})
                        aliveNukeLaunchers[nukeID] = Spring.GetGameSeconds() + math.random(5,45)
                    end
                end
            end
        end
    end
end