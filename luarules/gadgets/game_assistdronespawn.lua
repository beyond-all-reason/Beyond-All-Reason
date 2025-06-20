if not (Spring.GetModOptions().assistdronesenabled == "enabled" or (Spring.GetModOptions().assistdronesenabled == "pve_only" and Spring.Utilities.Gametype.IsPvE())) then
	return
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
      name      = "assistdrone spawn",
      desc      = "123",
      author    = "Damgam",
      date      = "2021",
	  license   = "GNU GPL, v2 or later",
      layer     = -100,
      enabled   = true,
    }
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local droneCount = Spring.GetModOptions().assistdronescount
local teamIDDroneList = {}

local teamsList = Spring.GetTeamList()

function CountItemsInArray(array)
    local count = 0
    for k in pairs(array) do
        count = count + 1
    end
    return count
end

local drones = {}
--local UDN = UnitDefNames
if Spring.GetModOptions().assistdronesair == true then
	--drones = {
	--	[UDN.armcom.id] = "armassistdrone",
	--	[UDN.corcom.id] = "corassistdrone",
	--	[UDN.legcom.id] = "legassistdrone",
	--}
	for unitDefID, unitDef in pairs(UnitDefs) do
		if unitDef.customParams.iscommander then
			drones[unitDefID] = string.sub(unitDef.name, 1, 3).."assistdrone"
		end
	end
else
	--drones = {
	--	[UDN.armcom.id] = "armassistdrone_land",
	--	[UDN.corcom.id] = "corassistdrone_land",
	--	[UDN.legcom.id] = "legassistdrone_land",
	--}
	for unitDefID, unitDef in pairs(UnitDefs) do
		if unitDef.customParams.iscommander then
			drones[unitDefID] = string.sub(unitDef.name, 1, 3).."assistdrone_land"
		end
	end
end


function SpawnAssistDrone(unitID, unitDefID, unitTeam)
    if not teamIDDroneList[unitTeam] then teamIDDroneList[unitTeam] = {} end
    local droneunit = drones[unitDefID]
    if CountItemsInArray(teamIDDroneList[unitTeam]) < droneCount then
        local posx, posy, posz = Spring.GetUnitPosition(unitID)
        local droneID = Spring.CreateUnit(droneunit, posx, posy+100, posz, 0, unitTeam)
        if droneID then
            GG.ScavengersSpawnEffectUnitID(droneID)
            Spring.GiveOrderToUnit(droneID, CMD.GUARD, unitID, {})
            teamIDDroneList[unitTeam][droneID] = true
            Spring.SetUnitCosts(droneID, {buildTime = 500, metalCost = 1, energyCost = 1})
        end
    end
end

local commandersList = {}
function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
    if drones[unitDefID] and not builderID then
        commandersList[unitID] = true
    end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
    if commandersList[unitID] then
        commandersList[unitID] = nil
    end
    for _, teamID in pairs(teamsList) do
        if teamIDDroneList[teamID] and teamIDDroneList[teamID][unitID] then
            teamIDDroneList[teamID][unitID] = nil
            break
        end
    end
end

function gadget:GameFrame(n)
    if n == 150 or n > 150 and n%1800 == 0 then -- Drone respawn
        for comID, _ in pairs(commandersList) do
            local comDefID = Spring.GetUnitDefID(comID)
            local comTeam = Spring.GetUnitTeam(comID)
            SpawnAssistDrone(comID, comDefID, comTeam)
        end
    end
end
