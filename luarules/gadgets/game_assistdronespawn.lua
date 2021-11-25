local droneSpawnEnabled = false
local scavengersAIEnabled = Spring.Utilities.Gametype.IsScavengers()
if Spring.GetModOptions().assistdronesenabled == "enabled" or (Spring.GetModOptions().assistdronesenabled == "scav_only" and scavengersAIEnabled) then
	droneSpawnEnabled = true
end
local droneCount = Spring.GetModOptions().assistdronescount

local UDN = UnitDefNames

function gadget:GetInfo()
    return {
      name      = "assistdrone spawn",
      desc      = "123",
      author    = "Damgam",
      date      = "2021",
      layer     = -100,
      enabled   = droneSpawnEnabled,
    }
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local drones = {
    [UDN.armcom.id] = "armassistdrone",
    [UDN.corcom.id] = "corassistdrone",
}

function SpawnAssistDrones(unitID, unitDefID, unitTeam)
	local posx, posy, posz = Spring.GetUnitPosition(unitID)
    local droneunit = drones[unitDefID]
	for i = 1,droneCount do
		local posx = posx+math.random(-32*droneCount,32*droneCount)
		local posz = posz+math.random(-32*droneCount,32*droneCount)
		local droneID = Spring.CreateUnit(droneunit, posx, posy+10, posz, 0, unitTeam)
		Spring.SpawnCEG("scav-spawnexplo", posx, posy+10, posz,0,0,0)
		Spring.GiveOrderToUnit(droneID, CMD.GUARD, unitID, {})
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
    if drones[unitDefID] and not builderID then
        SpawnAssistDrones(unitID, unitDefID, unitTeam)
    end
end
