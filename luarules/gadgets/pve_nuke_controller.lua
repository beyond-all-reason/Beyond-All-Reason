local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Raptor Defense Nuke Controller",
		desc = "Gives targets to raptor nuke launchers",
		author = "Damgam",
		date = "2023",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local difficulty = "normal"

if Spring.Utilities.Gametype.IsRaptors() then
	Spring.Log(gadget:GetInfo().name, LOG.INFO, "Raptor Defense Spawner Activated!")
	difficulty = Spring.GetModOptions().raptor_difficulty
elseif Spring.Utilities.Gametype.IsScavengers() then
	Spring.Log(gadget:GetInfo().name, LOG.INFO, "Scav Defense Spawner Activated!")
	difficulty = Spring.GetModOptions().scav_difficulty
else
	Spring.Log(gadget:GetInfo().name, LOG.INFO, "Defense Spawner Deactivated!")
	return false
end

local pveTeamID = Spring.Utilities.GetScavTeamID() or Spring.Utilities.GetRaptorTeamID()
local GetGameSeconds = Spring.GetGameSeconds
local GetAllUnits = Spring.GetAllUnits
local GetUnitDefID = Spring.GetUnitDefID
local GetUnitTeam = Spring.GetUnitTeam
local GetUnitPosition = Spring.GetUnitPosition
local GetGroundHeight = Spring.GetGroundHeight
local GiveOrderToUnit = Spring.GiveOrderToUnit

local nukeDefs = {}
for unitDefID, def in ipairs(UnitDefs) do
	if def.weapons then
		for i = 1, #def.weapons do
			local wDef = WeaponDefs[def.weapons[i].weaponDef]
			if wDef.targetable == 1 or wDef.customParams.pvenukecontroller then
				nukeDefs[unitDefID] = wDef.reload
				--nukeDefs[unitDefID] = true
				break
			end
		end
	end
end

local aliveNukeLaunchers = {}
local targetUnits = {}
local targetUnitIndex = {}
local attackCmdParams = { 0, 0, 0 }

local function AddTargetUnit(unitID)
	if not targetUnitIndex[unitID] then
		targetUnits[#targetUnits + 1] = unitID
		targetUnitIndex[unitID] = #targetUnits
	end
end

local function RemoveTargetUnit(unitID)
	local index = targetUnitIndex[unitID]
	if not index then
		return
	end

	local lastIndex = #targetUnits
	local lastUnitID = targetUnits[lastIndex]
	targetUnits[index] = lastUnitID
	targetUnitIndex[lastUnitID] = index
	targetUnits[lastIndex] = nil
	targetUnitIndex[unitID] = nil
end

local function UpdateTrackedUnit(unitID, unitDefID, unitTeam)
	if nukeDefs[unitDefID] and unitTeam == pveTeamID then
		aliveNukeLaunchers[unitID] = GetGameSeconds() + math.random(5, 10)
		RemoveTargetUnit(unitID)
		return
	end

	aliveNukeLaunchers[unitID] = nil
	if unitTeam ~= pveTeamID then
		AddTargetUnit(unitID)
	else
		RemoveTargetUnit(unitID)
	end
end

function gadget:Initialize()
	local allUnits = GetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		UpdateTrackedUnit(unitID, GetUnitDefID(unitID), GetUnitTeam(unitID))
	end
end

function gadget:UnitGiven(unitID, unitDefID, unitTeam)
	UpdateTrackedUnit(unitID, unitDefID, unitTeam)
end

function gadget:UnitTaken(unitID, unitDefID, unitTeam)
	UpdateTrackedUnit(unitID, unitDefID, unitTeam)
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	UpdateTrackedUnit(unitID, unitDefID, unitTeam)
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID)
	aliveNukeLaunchers[unitID] = nil
	RemoveTargetUnit(unitID)
end

local difficulties = {
	veryeasy = 1500,
	easy = 1000,
	normal = 800,
	hard = 700,
	veryhard = 600,
	epic = 500,
}

local gridSize = difficulties[difficulty]
local mapSizeX = Game.mapSizeX
local mapSizeZ = Game.mapSizeZ
local targetGridCells = {}
local numOfCellsX = math.ceil(mapSizeX / gridSize)
local numOfCellsZ = math.ceil(mapSizeZ / gridSize)

for cellX = 1, numOfCellsX do
	for cellZ = 1, numOfCellsZ do
		if not targetGridCells[cellX] then
			targetGridCells[cellX] = {}
		end
		targetGridCells[cellX][cellZ] = {
			-- xmin = (cellX-1)*gridSize,
			-- zmin = (cellZ-1)*gridSize,
			-- xmax = cellX*gridSize,
			-- zmax = cellZ*gridSize,
			locked = 0,
		}
	end
end

local function checkTargetCell(posx, posz, now)
	local cellX = math.ceil(posx / gridSize)
	local cellZ = math.ceil(posz / gridSize)
	local cellData = targetGridCells[cellX][cellZ]
	if cellData.locked < now then
		cellData.locked = now + math.random(180, 300)
		return true
	end
	return false
end

function gadget:GameFrame(frame)
	if frame % 30 ~= 17 then
		return
	end

	local now = GetGameSeconds()
	local targetCount = #targetUnits
	if targetCount == 0 then
		return
	end

	for nukeID, cooldown in pairs(aliveNukeLaunchers) do
		if cooldown <= now then
			local targetID = targetUnits[math.random(1, targetCount)]
			if targetID and GetUnitTeam(targetID) ~= GetUnitTeam(nukeID) then
				local x, y, z = GetUnitPosition(targetID)
				if x and z then
					x = x + math.random(-1024, 1024)
					z = z + math.random(-1024, 1024)
					if x > 0 and x < mapSizeX and z > 0 and z < mapSizeZ and checkTargetCell(x, z, now) then
						y = math.max(GetGroundHeight(x, z), 0)
						attackCmdParams[1] = x
						attackCmdParams[2] = y
						attackCmdParams[3] = z
						GiveOrderToUnit(nukeID, CMD.ATTACK, attackCmdParams, 0)
						aliveNukeLaunchers[nukeID] = now + (nukeDefs[Spring.GetUnitDefID(nukeID)] * 0.75)
					end
				end
			end
		end
	end
end
