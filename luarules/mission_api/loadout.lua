---
--- Loadout spawning logic used in :GamePreload() and the SpawnUnits and CreateFeatures actions.
---

local tracking = GG["MissionAPI"].Modules.Tracking
local missionOrders = GG["MissionAPI"].Modules.Orders

local trackedFeatureIDs = GG["MissionAPI"].trackedFeatureIDs

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

local function spawnUnit(unit, pos)
	-- Make unitName available to MetaUnitAdded call-in which gets triggered by Spring.CreateUnit
	-- A trigger there can spawn units inside this CreateUnit, so the outer values are put back after it
	local inProgressSpawnName = GG["MissionAPI"].nameOfUnitBeingSpawned
	local inProgressSpawnIsBeingBuilt = GG["MissionAPI"].spawnedUnitIsBeingBuilt
	GG["MissionAPI"].nameOfUnitBeingSpawned = unit.unitName
	GG["MissionAPI"].spawnedUnitIsBeingBuilt = unit.construction
	local unitID =
		Spring.CreateUnit(unit.unitDefName, pos.x, pos.y, pos.z, unit.facing or "s", unit.teamName, unit.construction)
	GG["MissionAPI"].nameOfUnitBeingSpawned = inProgressSpawnName
	GG["MissionAPI"].spawnedUnitIsBeingBuilt = inProgressSpawnIsBeingBuilt

	if unitID and unit.neutral then
		Spring.SetUnitNeutral(unitID, true)
	end

	tracking.TrackUnit(unit.unitName, unitID)

	return unitID
end

local function spawnUnitLoadout(unitLoadout)
	for _, unit in ipairs(unitLoadout or {}) do
		local spacing = unit.spacing or 0
		---@type table
		local unitDef = UnitDefNames[unit.unitDefName]
		local xsize = unitDef.xsize * Game.squareSize + spacing
		local zsize = unitDef.zsize * Game.squareSize + spacing

		-- adjust for facing of non-square units
		if BAR.Utilities.IsFacingEW(unit.facing) then
			xsize, zsize = zsize, xsize
		end

		local snapToBuildGrid = unitDef.isImmobile
		local buildFacing
		if snapToBuildGrid then
			-- Round up to whole grid cells so snapping keeps the buildings evenly spaced.
			xsize = math.ceil(xsize / BUILD_GRID_SIZE) * BUILD_GRID_SIZE
			zsize = math.ceil(zsize / BUILD_GRID_SIZE) * BUILD_GRID_SIZE
			buildFacing = BAR.Utilities.FacingToNumber(unit.facing)
		end

		local center = unit.position
		local positions = generateGridPositions(center.x, center.y, center.z, unit.quantity or 1, xsize, zsize)
		local spawnedUnitIDs = {}
		for _, pos in ipairs(positions) do
			if snapToBuildGrid then
				pos.x, pos.y, pos.z = Spring.Pos2BuildPos(unitDef.id, pos.x, pos.y, pos.z, buildFacing)
			end
			spawnedUnitIDs[spawnUnit(unit, pos)] = true
		end

		missionOrders.GiveOrders(spawnedUnitIDs, unit.orders)
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

local function spawnFeature(featureDefName, x, y, z, facing, featureName)
	local heading = BAR.Utilities.FacingToHeading(facing or 0)
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
		spawnFeature(feature.featureDefName, x, y, z, feature.facing, feature.featureName)
	end
end

return {
	SpawnUnitLoadout = spawnUnitLoadout,
	SpawnFeatureLoadout = spawnFeatureLoadout,
}
