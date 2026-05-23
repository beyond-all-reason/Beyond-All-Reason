local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Desolation",
		desc = "Cheat command to wipe team 0 down to a power quota",
		author = "SethDGamre",
		date = "2026-05-21",
		layer = 0,
		enabled = true,
	}
end

local DESOLATION_QUOTA_RATIO = 0.2
local REDEEMABLE_CHANCE = 0.5
local TURRET_GAIA_CHANCE = 0.75
local TURRET_RADIUS = 200
local TURRET_RADIUS_SQR = TURRET_RADIUS * TURRET_RADIUS
local HEAP_OVERKILL_MULTIPLIER = 3
local STAGGER_MAX_SECONDS = 5
local EXTREME_DAMAGE = 999999999999
local POWERFUL_TURRET_BIAS = 3
local TURRET_HOTSPOT_COUNT = 5

local DESOLATE_GAIA = 0
local DESOLATE_CORPSE = 1
local DESOLATE_HEAP = 2
local DESOLATE_ERASE = 3

local CAN_MOVE_PENALTY_MULTIPLIER = 4


local TO_HEAP_DAMAGE_RATIO = 0.5

local clusteredStructures = {}
local unclusteredStructures = {}
local mobileUnits = {}

local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitPosition = Spring.GetUnitPosition
local spGetTeamUnits = Spring.GetTeamUnits
local spAddUnitDamage = Spring.AddUnitDamage
local spTransferUnit = Spring.TransferUnit
local spValidUnitID = Spring.ValidUnitID
local spGetUnitsInSphere = Spring.GetUnitsInSphere
local mathRandom = math.random
local mathMax = math.max
local mathFloor = math.floor
local mathDistance2dSquared = math.distance2dSquared

local gaiaTeam = Spring.GetGaiaTeamID()

local defData = {}
local commanderDefs = {}

--populate def types
local function isTurretDef(unitDef)
	if unitDef.canMove then
		return false
	end
	if not unitDef.weapons or #unitDef.weapons == 0 then
		return false
	end
	if unitDef.buildOptions and #unitDef.buildOptions > 0 then
		return false
	end
	return true
end

for unitDefID, unitDef in ipairs(UnitDefs) do
	local data = {}
	
	data.power = unitDef.power
	if isTurretDef(unitDef) then
		data.isTurret = true
	end
	if unitDef.customParams.iscommander then
		data.isCommander = true
	end
	if unitDef.canMove then
		data.canMove = true
	end
	defData[unitDefID] = data
end

local function chooseFate(unitID)
	local fate = DESOLATE_HEAP

	if math.random <= REDEEMABLE_CHANCE then
		if defData[spGetUnitDefID(unitID)].isTurret then
			fate = DESOLATE_GAIA and math.random <= TURRET_GAIA_CHANCE or DESOLATE_CORPSE
		else
			fate = DESOLATE_CORPSE
		end
	end
	return fate
end

local function desolateUnit(unitID, fate)
	if not spValidUnitID(unitID) then
		return
	end
	if fate == DESOLATE_GAIA then
		spTransferUnit(unitID, gaiaTeam, false)
		return
	end
	if fate == DESOLATE_ERASE then
		spAddUnitDamage(unitID, EXTREME_DAMAGE, 0, nil, -1)
		return
	end
	local health, maxHealth = spGetUnitHealth(unitID)
	if not health or health <= 0 then
		return
	end
	if fate == DESOLATE_CORPSE then
		spAddUnitDamage(unitID, health, 0, nil, -1)
	elseif fate == DESOLATE_HEAP then
		local heapDamage = health
		if maxHealth and maxHealth > 0 then
			heapDamage = mathMax(maxHealth * TO_HEAP_DAMAGE_RATIO, health)
		end
		spAddUnitDamage(unitID, heapDamage, 0, nil, -1)
	end
end

local function dndStyleDisadvantageBias(rangeCount, degree)
	local selection
	for rollIndex = 1, degree do
		local randomWholeNumber = math.random(1, rangeCount)
		if not selection or randomWholeNumber < selection then
			selection = randomWholeNumber
		end
	end
	return selection
end

local function sortUnitsByPower(unitTable)
	local sortedUnits = {}
	for unitIndex = 1, #unitTable do
		sortedUnits[unitIndex] = unitTable[unitIndex]
	end
	table.sort(sortedUnits, function(unitA, unitB)
		local powerA = defData[spGetUnitDefID(unitA)].power or 0
		local powerB = defData[spGetUnitDefID(unitB)].power or 0
		return powerA > powerB
	end)
	return sortedUnits
end

local function sortUnitsByDesirabilityAndDistance(unitsTable, positionTable)
	local sortedUnits = {}
	local closestDistanceByUnit = {}

	for unitIndex = 1, #unitsTable do
		local unitID = unitsTable[unitIndex]
		sortedUnits[unitIndex] = unitID
		local unitX, unitY, unitZ = spGetUnitPosition(unitID)
		local closestDistance = math.huge
		if unitX then
			for positionIndex = 1, #positionTable do
				local position = positionTable[positionIndex]
				local distance = mathDistance2dSquared(position.x, position.z, unitX, unitZ)
				closestDistance = math.min(distance, closestDistance)
			end
		end

		local canMove = defData[spGetUnitDefID(unitID)].canMove
		closestDistanceByUnit[unitID] = canMove and closestDistance * CAN_MOVE_PENALTY_MULTIPLIER or closestDistance
	end

	table.sort(sortedUnits, function(unitA, unitB)
		return closestDistanceByUnit[unitA] > closestDistanceByUnit[unitB] --longer distances first
	end)

	return sortedUnits
end

local function desolateTeam(teamID)
	local teamUnits = spGetTeamUnits(teamID)
	local turrets = {}
	local hotspots = {}

	--got turrets?
	for unitIndex = 1, #teamUnits do
		local unitID = teamUnits[unitIndex]
		local unitDefID = spGetUnitDefID(unitID)
		local defData = defData[unitDefID]
		if defData.isTurret then
			turrets[unitID] = true
		end
	end
	turrets = sortUnitsByPower(turrets)

	--pick some turrets to preserve and positions
	for i, TURRET_HOTSPOT_COUNT do
		randomSelection = dndStyleDisadvantageBias(#turrets, 3) --zzz need to make all units gaia before destruction?
		local unitID = turrets[randomSelection]
		local x, y, z = spGetUnitPosition(unitID)
		table.insert(hotspots, {x, z})
		desolateUnit(unitID, DESOLATE_GAIA) --set to neutral immediately to ensure they exist later
		table.remove(turrets, randomSelection) --remove so no duplicates
	end

	--sort by desirability
	teamUnits = spGetTeamUnits(teamID) --refresh to exclude turrets
	teamUnits = sortUnitsByDesirabilityAndDistance(teamUnits, hotspots)

	local erasurePowerTargetThreshold = GG.PowerLib.HighestPlayerPeakPower() * DESOLATION_QUOTA_RATIO
	local currentPower = GG.PowerLib.TeamPower(teamID)

	--erase units until we get below the threshold
	for eraseIndex = 1, #teamUnits do
		if currentPower <= erasurePowerTargetThreshold or #teamUnits == 0 then
			break
		end
		local randomSelection = dndStyleDisadvantageBias(#teamUnits, 2)
		local unitID = teamUnits[randomSelection]
		local unitDefID = spGetUnitDefID(unitID)
		local unitPower = defData[unitDefID].power or 0
		desolateUnit(unitID, DESOLATE_ERASE)
		currentPower = currentPower - unitPower
		table.remove(teamUnits, randomSelection)
	end

	--choose to gaia, corpse, or heap remainders
	
	--chooseFate(unitID)



	-- now we cull the undesirables
	teamUnits = spGetTeamUnits(teamID)


end