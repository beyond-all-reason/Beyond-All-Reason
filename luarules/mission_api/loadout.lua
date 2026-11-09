---
--- Loadout spawning logic used in :GamePreload() and the SpawnUnits and CreateFeatures actions.
---

local tracking = GG["MissionAPI"].Modules.Tracking

local trackedUnitIDs = GG["MissionAPI"].trackedUnitIDs
local trackedFeatureIDs = GG["MissionAPI"].trackedFeatureIDs

--- Orientation of unit and feature entries

-- A point closer than this is on the entry itself, as in RotateUnits.
local MIN_DIRECTION_DISTANCE = 0.001

local function compassAngleToHeading(angle)
	-- TODO: refactor to call CompassAngleToHeading when it is merged
	return math.floor((angle % 360 - 180) / 360 * -65536)
end

local function directionToHeading(entry, direction)
	if direction.angle then
		return compassAngleToHeading(direction.angle)
	end

	local dx, dz = direction.x - entry.position.x, direction.z - entry.position.z
	if math.abs(dx) < MIN_DIRECTION_DISTANCE and math.abs(dz) < MIN_DIRECTION_DISTANCE then
		return BAR.Utilities.FacingToHeading(0)
	end
	-- Not Spring.GetHeadingFromVector: before RecoilEngine #3240 it swaps east and west for dz just above zero.
	return compassAngleToHeading(math.deg(math.atan2(dx, -dz)))
end

local function orientationOf(entry)
	local orientation = entry.orientation
	if type(orientation) == "table" then
		local heading = directionToHeading(entry, orientation)
		return heading, BAR.Utilities.HeadingToFacing(heading)
	end
	local facing = orientation or 0
	return BAR.Utilities.FacingToHeading(facing), facing
end

--- Units

local BUILD_GRID_SIZE = Game.squareSize * Game.footprintScale

local function generateGridPositions(centerX, centerY, centerZ, quantity, xSpacing, zSpacing)
	local positions = {}
	if quantity <= 0 then
		return positions
	end

	-- Rows of the nearest square, and only the columns the quantity fills, centered on the point.
	local rows = math.ceil(math.sqrt(quantity))
	local columns = math.ceil(quantity / rows)
	-- From the first unit to the last, one spacing fewer than the units in a row or column.
	local xSpan = (columns - 1) * xSpacing
	local zSpan = (rows - 1) * zSpacing
	local left = centerX - math.floor(xSpan / 2)
	local top = centerZ - math.floor(zSpan / 2)
	local count = 0

	for x = left, left + xSpan, xSpacing do
		for z = top, top + zSpan, zSpacing do
			if count >= quantity then
				return positions
			end
			table.insert(positions, { x = x, y = centerY or Spring.GetGroundHeight(x, z), z = z })
			count = count + 1
		end
	end
	return positions
end

local function spawnUnit(unit, pos, facing, heading)
	-- Make unitName available to MetaUnitAdded call-in which gets triggered by Spring.CreateUnit
	-- A trigger there can spawn units inside this CreateUnit, so the outer values are put back after it
	local inProgressSpawnName = GG["MissionAPI"].nameOfUnitBeingSpawned
	local inProgressSpawnIsBeingBuilt = GG["MissionAPI"].spawnedUnitIsBeingBuilt
	GG["MissionAPI"].nameOfUnitBeingSpawned = unit.unitName
	GG["MissionAPI"].spawnedUnitIsBeingBuilt = unit.construction
	local unitID = Spring.CreateUnit(unit.unitDefName, pos.x, pos.y, pos.z, facing, unit.teamName, unit.construction)
	GG["MissionAPI"].nameOfUnitBeingSpawned = inProgressSpawnName
	GG["MissionAPI"].spawnedUnitIsBeingBuilt = inProgressSpawnIsBeingBuilt

	if unitID and heading then
		-- Keep the slope the unit was created standing on.
		local _, upDir = Spring.GetUnitVectors(unitID)
		Spring.SetUnitHeadingAndUpDir(unitID, heading, upDir[1], upDir[2], upDir[3])
	end

	if unitID and unit.neutral then
		Spring.SetUnitNeutral(unitID, true)
	end

	tracking.TrackUnit(unit.unitName, unitID)

	return unitID
end

local function convertOrdersTargetingNames(orders)
	local commandsAcceptingName = {
		[CMD.GUARD] = true,
		[CMD.REPAIR] = true,
		[CMD.CAPTURE] = true,
		[CMD.ATTACK] = true,
		[CMD.LOAD_UNITS] = true,
		[CMD.RECLAIM] = true,
		[CMD.RESURRECT] = true,
	}

	-- Replace name param with unitIDs or featureIDs, duplicating order for each unitID.
	-- A name with nothing behind it gives no order, and the orders around it stay as written.
	local newOrders = {}
	for _, order in ipairs(orders or {}) do
		local commandID = order[1]
		local params = order[2] or {}

		if commandsAcceptingName[commandID] and type(params) == "table" and (params.unitName or params.featureName) then
			local thingIDs
			local offset = 0
			if params.featureName then
				thingIDs = trackedFeatureIDs[params.featureName]
				if not Engine.FeatureSupport.noOffsetForFeatureID then
					offset = Game.maxUnits
				end
			elseif params.unitName then
				thingIDs = trackedUnitIDs[params.unitName]
			end

			-- Copies, so the mission's own options table is never handed on or changed.
			local options = table.copy(order[3] or {})
			local queuedOptions = table.copy(options)
			if not table.contains(queuedOptions, "shift") then
				queuedOptions[#queuedOptions + 1] = "shift"
			end
			local targetOptions = options
			for thingID in pairs(thingIDs or {}) do
				newOrders[#newOrders + 1] = { commandID, thingID + offset, targetOptions }
				targetOptions = queuedOptions
			end
		else
			newOrders[#newOrders + 1] = order
		end
	end

	return newOrders
end

local function spawnUnitLoadout(unitLoadout)
	for _, unit in ipairs(unitLoadout or {}) do
		local spacing = unit.spacing or 0
		---@type table
		local unitDef = UnitDefNames[unit.unitDefName]
		local xsize = unitDef.xsize * Game.squareSize + spacing
		local zsize = unitDef.zsize * Game.squareSize + spacing

		-- Buildings keep the nearest of the four facings.
		local heading, facing = orientationOf(unit)
		local turnTo = nil
		if type(unit.orientation) == "table" and not unitDef.isImmobile then
			turnTo = heading
		end

		-- adjust for facing of non-square units
		if BAR.Utilities.IsFacingEW(facing) then
			xsize, zsize = zsize, xsize
		end

		local snapToBuildGrid = unitDef.isImmobile
		local buildFacing
		if snapToBuildGrid then
			-- Round up to whole grid cells so snapping keeps the buildings evenly spaced.
			xsize = math.ceil(xsize / BUILD_GRID_SIZE) * BUILD_GRID_SIZE
			zsize = math.ceil(zsize / BUILD_GRID_SIZE) * BUILD_GRID_SIZE
			buildFacing = BAR.Utilities.FacingToNumber(facing)
		end

		local center = unit.position
		local positions = generateGridPositions(center.x, center.y, center.z, unit.quantity or 1, xsize, zsize)
		for _, pos in ipairs(positions) do
			if snapToBuildGrid then
				pos.x, pos.y, pos.z = Spring.Pos2BuildPos(unitDef.id, pos.x, pos.y, pos.z, buildFacing)
			end
			local unitID = spawnUnit(unit, pos, facing, turnTo)
			-- Fence around mission-issued orders for UnitOrdered triggers using `ignoreMissionActions`.
			GG["MissionAPI"].issuingOrders = true
			Spring.GiveOrderArrayToUnit(unitID, convertOrdersTargetingNames(unit.orders))
			GG["MissionAPI"].issuingOrders = nil
		end
	end
end

--- Features

local gaiaTeamID = Spring.GetGaiaTeamID()

local corpseToUnitDefName = {}
for _, unitDef in pairs(UnitDefs) do
	if unitDef.corpse and FeatureDefNames[unitDef.corpse] then
		corpseToUnitDefName[unitDef.corpse] = unitDef.name
	end
end

local function spawnFeature(featureDefName, x, y, z, heading, facing, featureName)
	local featureID = Spring.CreateFeature(featureDefName, x, y, z, heading, gaiaTeamID)
	local unitDefName = corpseToUnitDefName[featureDefName]

	if featureID and unitDefName then
		Spring.SetFeatureResurrect(featureID, unitDefName, facing)
	end
	tracking.TrackFeature(featureName, featureID)
end

local function spawnFeatureLoadout(featureLoadout)
	for _, feature in ipairs(featureLoadout or {}) do
		local x, y, z = feature.position.x, feature.position.y, feature.position.z
		y = y or Spring.GetGroundHeight(x, z)
		local heading, facing = orientationOf(feature)
		spawnFeature(feature.featureDefName, x, y, z, heading, facing, feature.featureName)
	end
end

return {
	ConvertOrdersTargetingNames = convertOrdersTargetingNames,
	SpawnUnitLoadout = spawnUnitLoadout,
	SpawnFeatureLoadout = spawnFeatureLoadout,
}
