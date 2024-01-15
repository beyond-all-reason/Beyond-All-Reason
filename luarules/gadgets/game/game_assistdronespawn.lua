local droneSpawnEnabled = false
local PvEEnabled = Spring.Utilities.Gametype.IsPvE()
if Spring.GetModOptions().assistdronesenabled == "enabled" or (Spring.GetModOptions().assistdronesenabled == "pve_only" and PvEEnabled) then
	droneSpawnEnabled = true
end
local droneCount = Spring.GetModOptions().assistdronescount
local teamIDDroneList = {}

local UDN = UnitDefNames
local teamsList = Spring.GetTeamList()

function gadget:GetInfo()
    return {
      name      = "assistdrone spawn",
      desc      = "123",
      author    = "Damgam",
      date      = "2021",
	  license   = "GNU GPL, v2 or later",
      layer     = -100,
      enabled   = droneSpawnEnabled,
    }
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

function CountItemsInArray(array)
    local count = 0
    for k in pairs(array) do
        count = count + 1
    end
    return count
end

local drones = {}
if Spring.GetModOptions().assistdronesair == true then
    drones = {
        [UDN.armcom.id] = "armassistdrone",
        [UDN.corcom.id] = "corassistdrone",
        [UDN.legcom.id] = "legassistdrone",
    }
else
    drones = {
        [UDN.armcom.id] = "armassistdrone_land",
        [UDN.corcom.id] = "corassistdrone_land",
        [UDN.legcom.id] = "legassistdrone_land",
    }
end


function SpawnAssistDrone(unitID, unitDefID, unitTeam)
    if not teamIDDroneList[unitTeam] then teamIDDroneList[unitTeam] = {} end
    local droneunit = drones[unitDefID]
    if CountItemsInArray(teamIDDroneList[unitTeam]) < droneCount then
        local posx, posy, posz = Spring.GetUnitPosition(unitID)
        local droneID = Spring.CreateUnit(droneunit, posx, posy+100, posz, 0, unitTeam)
        if droneID then
            Spring.SpawnCEG("scav-spawnexplo", posx, posy+100, posz,0,0,0)
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

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam) 
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
