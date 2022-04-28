local spawnpadSpawnEnabled = false
local PvEEnabled = Spring.Utilities.Gametype.IsPvE()
if Spring.GetModOptions().commanderbuildersenabled == "enabled" or (Spring.GetModOptions().commanderbuildersenabled == "pve_only" and PvEEnabled) then
	spawnpadSpawnEnabled = true
end

local UDN = UnitDefNames

function gadget:GetInfo()
    return {
      name      = "commander builder spawn",
      desc      = "123",
      author    = "Damgam",
      date      = "2021",
      layer     = -100,
      enabled   = spawnpadSpawnEnabled,
    }
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local spawnpads = {
    [UDN.armcom.id] = "armrespawn",
    [UDN.corcom.id] = "correspawn",
	[UDN.legcomdef.id] = "correspawn",
}

function SpawnAssistDrones(unitID, unitDefID, unitTeam)
	local posx, posy, posz = Spring.GetUnitPosition(unitID)
    local spawnpadunit = spawnpads[unitDefID]
    local spawnpadID = Spring.CreateUnit(spawnpadunit, posx, posy, posz, 0, unitTeam)
    --Spring.SpawnCEG("scav-spawnexplo", posx, posy+10, posz,0,0,0)
    Spring.GiveOrderToUnit(spawnpadID, CMD.GUARD, unitID, {})
    Spring.SetUnitBlocking(spawnpadID, false)
end

local commandersList = {}
function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
    if spawnpads[unitDefID] and not builderID then
        commandersList[unitID] = true
    end
end

function gadget:GameFrame(n)
    if n == 90 then
        local units = Spring.GetAllUnits()
        for i = 1,#units do
            if commandersList[units[i]] then
                local unitID = units[i]
                local unitDefID = Spring.GetUnitDefID(unitID)
                local unitTeam = Spring.GetUnitTeam(unitID)
                SpawnAssistDrones(unitID, unitDefID, unitTeam)
            end
        end
    end
end