local spawnpadSpawnEnabled = false
local PvEEnabled = Spring.Utilities.Gametype.IsPvE()
if SpringShared.GetModOptions().commanderbuildersenabled == "enabled" or (SpringShared.GetModOptions().commanderbuildersenabled == "pve_only" and PvEEnabled) then
	spawnpadSpawnEnabled = true
end

if not UnitDefNames.armrespawn then
	spawnpadSpawnEnabled = false
end

if not spawnpadSpawnEnabled then
	return
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
      name      = "commander builder spawn",
      desc      = "123",
      author    = "Damgam",
      date      = "2021",
	  license   = "GNU GPL, v2 or later",
      layer     = -100,
      enabled   = spawnpadSpawnEnabled,
    }
end

local UDN = UnitDefNames

if not gadgetHandler:IsSyncedCode() then
	return false
end

local positionCheckLibrary = VFS.Include("luarules/utilities/damgam_lib/position_checks.lua")

local spawnpads = {
    [UDN.armcom.id] = "armrespawn",
    [UDN.corcom.id] = "correspawn",
}
if SpringShared.GetModOptions().experimentallegionfaction then
	spawnpads[UDN.legcom.id] = "legnanotcbase"
end

local spawnFrame = Game.spawnWarpInFrame + Game.gameSpeed * 2 -- add time to deconflict initial build orders

function SpawnAssistTurret(unitID, unitDefID, unitTeam)
	local posx, posy, posz = SpringShared.GetUnitPosition(unitID)
    local spawnpadunit = spawnpads[unitDefID]
    local spawnpadID
    for k = 1,10000 do
        posx = math.ceil((posx + math.random(-k-64, k+64))/16)*16
        posz = math.ceil((posz + math.random(-k-64, k+64))/16)*16
        posy = SpringShared.GetGroundHeight(posx, posz)
        local canSpawnTurret = positionCheckLibrary.FlatAreaCheck(posx, posy, posz, 96)
        if canSpawnTurret then
            canSpawnTurret = positionCheckLibrary.OccupancyCheck(posx, posy, posz, 96)
        end
        if canSpawnTurret then
            canSpawnTurret = positionCheckLibrary.ResourceCheck(posx, posz, 96)
        end
        if canSpawnTurret then
            spawnpadID = SpringSynced.CreateUnit(spawnpadunit, posx, posy, posz, 0, unitTeam)
            break
        end
    end
	if spawnpadID then
        GG.ScavengersSpawnEffectUnitID(spawnpadID)
		SpringSynced.GiveOrderToUnit(spawnpadID, CMD.GUARD, unitID, {})
        SpringSynced.SetUnitCosts(spawnpadID, {buildTime = 20000, metalCost = 100, energyCost = 1000})
		--Spring.SetUnitBlocking(spawnpadID, false)
	end
end

local commandersList = {}
function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
    if spawnpads[unitDefID] and not builderID then
        commandersList[unitID] = true
    end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
    if commandersList[unitID] then
        commandersList[unitID] = nil
    end
end

function gadget:GameFrame(n)
    if n == spawnFrame then
        for comID, _ in pairs(commandersList) do
            local comDefID = SpringShared.GetUnitDefID(comID)
            local comTeam = SpringShared.GetUnitTeam(comID)
            SpawnAssistTurret(comID, comDefID, comTeam)
        end
    end
end
