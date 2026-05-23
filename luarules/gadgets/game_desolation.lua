local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Desolation",
		desc = "Cheat command to wipe a team down to a power quota",
		author = "SethDGamre",
		date = "2026-05-21",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then return false end

local DESOLATION_QUOTA_RATIO = 0.2
local REDEEMABLE_CHANCE = 0.5
local TURRET_GAIA_CHANCE = 0.75
local DESOLATION_SECONDS = 10
local DESOLATION_STAGGER_FRAMES = DESOLATION_SECONDS * Game.gameSpeed
local POWERFUL_TURRET_BIAS = 3
local TURRET_HOTSPOT_COUNT = 5
local MAP_SIZE_X = Game.mapSizeX
local MAP_SIZE_Z = Game.mapSizeZ
local HALF_MAP_DISTANCE_SQUARED = (math.min(MAP_SIZE_X, MAP_SIZE_Z) ^ 2)
local DESOLATE_GAIA = 0
local DESOLATE_CORPSE = 1
local DESOLATE_HEAP = 2
local DESOLATE_ERASE = 3

local CAN_MOVE_PENALTY_MULTIPLIER = 4

local TO_HEAP_DAMAGE_RATIO = 0.5

local spSpawnExplosion = Spring.SpawnExplosion
local spCreateFeature = Spring.CreateFeature
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitPosition = Spring.GetUnitPosition
local spDestroyUnit = Spring.DestroyUnit
local spGetTeamUnits = Spring.GetTeamUnits
local spAddUnitDamage = Spring.AddUnitDamage
local spTransferUnit = Spring.TransferUnit
local spValidUnitID = Spring.ValidUnitID
local spGetUnitsInSphere = Spring.GetUnitsInSphere
local mathRandom = math.random
local mathMax = math.max
local mathFloor = math.floor
local mathDistance2dSquared = math.distance2dSquared
local cascadeOrigins = {x = 0, z = 0}

local gaiaTeam = Spring.GetGaiaTeamID()

local defData = {}
local commanderDefs = {}
local actionFrames = {}
local desolatedTeams = {}

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

	local corpseDefName = unitDef.corpse
	if FeatureDefNames[corpseDefName] then
		local corpseDefID = FeatureDefNames[corpseDefName].id
		data.heap = FeatureDefs[corpseDefID].deathFeatureID
	end

	local deathExplosionName = unitDef.deathExplosion
	local explosionDefID = WeaponDefNames[deathExplosionName].id
	data.explosionDefID = explosionDefID

	if isTurretDef(unitDef) then
		data.isTurret = true
	end
	if unitDef.customParams and unitDef.customParams.iscommander then
		data.isCommander = true
	end
	if unitDef.canMove then
		data.canMove = true
	end
	defData[unitDefID] = data
end

local function chooseFate(unitID)
	local fate = DESOLATE_HEAP

	if math.random() <= REDEEMABLE_CHANCE then
		if defData[spGetUnitDefID(unitID)].isTurret then
			if math.random() <= TURRET_GAIA_CHANCE then
				fate = DESOLATE_GAIA
			else
				fate = DESOLATE_CORPSE
			end
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
		local health, maxHealth = spGetUnitHealth(unitID)
		spTransferUnit(unitID, gaiaTeam, false)
		spAddUnitDamage(unitID, maxHealth * 1.5, 1)
		return
	end

	local unitDefID = spGetUnitDefID(unitID)
	local data = defData[unitDefID]
	local x, y, z = spGetUnitPosition(unitID)

	if fate == DESOLATE_CORPSE then
		spDestroyUnit(unitID, false, false, -1)
		return
	end	
	
	if fate == DESOLATE_HEAP or fate == DESOLATE_ERASE then
		spDestroyUnit(unitID, false, true, -1)
		spSpawnExplosion(x, y, z, 0, 0, 0, {weaponDef = data.explosionDefID, owner = unitID})
	end
	if fate == DESOLATE_HEAP then
		spCreateFeature(data.heap, x, y, z)
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

-- Ease-out explosion timing: returns frame index (integer) for myPosition relative to origin
-- Use HALF_MAP_DISTANCE_SQUARED already defined in your file
local function getEaseOutFrames(positionX, positionZ)
    local dx = positionX - cascadeOrigins.x
    local dz = positionZ - cascadeOrigins.z
    local dist2 = dx * dx + dz * dz

    -- Guard: if max squared distance is zero or negative, fallback to instant or max
    if HALF_MAP_DISTANCE_SQUARED <= 0 then
        if dist2 <= 0 then
            return 0
        else
            return math.floor(DESOLATION_STAGGER_FRAMES + 0.5)
        end
    end

    if dist2 <= 0 then
        return 0
    end

    if dist2 >= HALF_MAP_DISTANCE_SQUARED then
        return math.floor(DESOLATION_STAGGER_FRAMES + 0.5)
    end

    -- Use squared fraction to avoid sqrt
    local t = dist2 / HALF_MAP_DISTANCE_SQUARED
    -- Cubic ease-out applied to the squared fraction
    local eased = 1 - math.pow(1 - t, 3)
    local frames = math.floor(eased * DESOLATION_STAGGER_FRAMES + 0.5)
	Spring.Echo(frames)
    return frames
end


local function queueDesolationAction(unitID, fate, baseFrame)
	local positionX, _, positionZ = spGetUnitPosition(unitID)
	local frame = baseFrame + getEaseOutFrames(positionX, positionZ)
	local frameActions = actionFrames[frame]
	if not frameActions then
		frameActions = {}
		actionFrames[frame] = frameActions
	end
	frameActions[#frameActions + 1] = { unitID = unitID, fate = fate }
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
	Spring.Echo("Team Desolated!", teamID)
	desolatedTeams[teamID] = true
	local teamUnits = spGetTeamUnits(teamID)
	local turrets = {}
	local hotspots = {}
	local currentFrame = Spring.GetGameFrame()
	local currentPower = 0

	--got turrets?
	for unitIndex = 1, #teamUnits do
		local unitID = teamUnits[unitIndex]
		local unitDefID = spGetUnitDefID(unitID)
		local unitDefEntry = defData[unitDefID]
		if unitDefEntry and unitDefEntry.isTurret then
			turrets[#turrets + 1] = unitID
		end
		currentPower = currentPower + unitDefEntry.power
	end
	turrets = sortUnitsByPower(turrets)

	--pick some turrets to preserve and positions
	for hotspotIndex = 1, math.min(TURRET_HOTSPOT_COUNT, #turrets) do
		local randomSelection = dndStyleDisadvantageBias(#turrets, POWERFUL_TURRET_BIAS)
		local unitID = turrets[randomSelection]
		local x, y, z = spGetUnitPosition(unitID)
		table.insert(hotspots, { x = x, z = z })
		desolateUnit(unitID, DESOLATE_GAIA) --set to neutral immediately to ensure they exist later
		table.remove(turrets, randomSelection) --remove so no duplicates
	end

	--sort by desirability
	teamUnits = spGetTeamUnits(teamID) --refresh to exclude turrets
	teamUnits = sortUnitsByDesirabilityAndDistance(teamUnits, hotspots)

	local erasurePowerTargetThreshold = currentPower * DESOLATION_QUOTA_RATIO

	--erase units until we get below the threshold
	for eraseIndex = 1, #teamUnits do
		if currentPower <= erasurePowerTargetThreshold or #teamUnits == 0 then
			break
		end
		local randomSelection = dndStyleDisadvantageBias(#teamUnits, 2)
		local unitID = teamUnits[randomSelection]
		local unitDefID = spGetUnitDefID(unitID)
		local unitPower = defData[unitDefID].power or 0
		queueDesolationAction(unitID, DESOLATE_ERASE, currentFrame)
		currentPower = currentPower - unitPower
		table.remove(teamUnits, randomSelection)
	end

	--choose to gaia, corpse, or heap remainders


	for unitIndex = 1, #teamUnits do
		local unitID = teamUnits[unitIndex]
		local fate = chooseFate(unitID)
		queueDesolationAction(unitID, fate, currentFrame)
	end
end

local function desolateCommand(cmd, line, words, playerID)
	if not Spring.IsCheatingEnabled() then
		return
	end
	local teamID = tonumber(words[1])
	if not teamID then
		Spring.Echo("Desolate: usage /luarules desolate <teamID>")
		return
	end
	if not Spring.GetTeamInfo(teamID) then
		Spring.Echo("Desolate: invalid team ID " .. tostring(teamID))
		return
	end
	desolateTeam(teamID)
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	if defData[unitDefID].isCommander then
		cascadeOrigins.x, _, cascadeOrigins.z = spGetUnitPosition(unitID)
	end
end

function gadget:GameFrame(gameFrame)
	local frameActions = actionFrames[gameFrame]
	if not frameActions then
		return
	end
	actionFrames[gameFrame] = nil
	for actionIndex = 1, #frameActions do
		local action = frameActions[actionIndex]
		desolateUnit(action.unitID, action.fate)
	end
end

function gadget:Initialize()
	gadgetHandler:AddChatAction("desolate", desolateCommand, "Wipes a team to 20% of highest player peak power. Usage: /luarules desolate <teamID>. Requires /cheat")
	GG.Desolation = {}
	GG.Desolation['DesolateTeam'] = desolateTeam
end

function gadget:Shutdown()
	gadgetHandler:RemoveChatAction("desolate")
end