---
--- Loadout spawning logic used in :GamePreload() and the SpawnUnits and CreateFeatures actions.
---

local tracking = VFS.Include('luarules/mission_api/tracking.lua')

local trackedUnitIDs = GG['MissionAPI'].trackedUnitIDs
local trackedFeatureIDs = GG['MissionAPI'].trackedFeatureIDs

--- Units

local function generateGridPositions(centerX, centerZ, quantity, xSpacing, zSpacing)
	local positions = {}
	local xGridSize = math.ceil(math.sqrt(quantity)) * xSpacing
	local zGridSize = math.ceil(math.sqrt(quantity)) * zSpacing
	local left = centerX - math.floor(xGridSize / 2)
	local top = centerZ - math.floor(zGridSize / 2)
	local count = 0

	for x = left, left + xGridSize - xSpacing, xSpacing do
		for z = top, top + zGridSize - zSpacing, zSpacing do
			if count >= quantity then return positions end
			table.insert(positions, { x = x, y = Spring.GetGroundHeight(x, z), z = z })
			count = count + 1
		end
	end
	return positions
end

local function spawnUnit(unit, pos)
	local unitID = Spring.CreateUnit(unit.unitDefName, pos.x, pos.y, pos.z, unit.facing or 's', unit.team, unit.construction)
	if unitID and unit.neutral then
		Spring.SetUnitNeutral(unitID, true)
	end

	tracking.TrackUnit(unit.unitName, unitID)

	return unitID
end

local function convertOrdersTargetingNames(orders)
	local commandsAcceptingName = { [CMD.GUARD] = true, [CMD.REPAIR] = true, [CMD.CAPTURE] = true, [CMD.ATTACK] = true,
									[CMD.LOAD_UNITS] = true, [CMD.RECLAIM] = true, [CMD.RESURRECT] = true }

	-- Replace name param with unitIDs or featureIDs, duplicating order for each unitID
	local newOrders = {}
	for _, order in pairs(orders or {}) do
		local commandID = order[1]
		local params = order[2] or {}
		local options = order[3] or {}

		if commandsAcceptingName[commandID] and type(params) == 'table' and (params.unitName or params.featureName) then
			local thingIDs = {}
			local offset = 0
			if params.featureName then
				thingIDs = trackedFeatureIDs[params.featureName]
				if not Engine.FeatureSupport.noOffsetForFeatureID then
					offset = Game.maxUnits
				end
			elseif params.unitName then
				thingIDs = trackedUnitIDs[params.unitName]
			end

			local isFirstUnitID = true
			for thingID in pairs(thingIDs) do
				newOrders[#newOrders + 1] = { commandID, thingID + offset, table.copy(options) }
				if isFirstUnitID then
					table.insert(options, 'shift')
					isFirstUnitID = false
				end
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
		local unitDef = UnitDefNames[unit.unitDefName]
		local xsize = unitDef.xsize * Game.squareSize + spacing
		local zsize = unitDef.zsize * Game.squareSize + spacing

		-- adjust for facing of non-square units
		if Spring.Utilities.IsFacingEW(unit.facing) then
			xsize, zsize = zsize, xsize
		end

		local positions = generateGridPositions(unit.x, unit.z, unit.quantity or 1, xsize, zsize)
		for _, pos in pairs(positions) do
			local unitID = spawnUnit(unit, pos)
			Spring.GiveOrderArrayToUnit(unitID,  convertOrdersTargetingNames(unit.orders))
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

local function spawnFeature(featureDefName, position, facing, featureName)
	local heading = Spring.Utilities.FacingToHeading(facing or 0)
	local featureID = Spring.CreateFeature(featureDefName, position.x, position.y, position.z, heading, gaiaTeamID)
	local unitDefName = corpseToUnitDefName[featureDefName]

	if featureID and unitDefName then
		Spring.SetFeatureResurrect(featureID, unitDefName, facing)
	end
	tracking.TrackFeature(featureName, featureID)
end

local function spawnFeatureLoadout(featureLoadout)
	for _, feature in ipairs(featureLoadout or {}) do
		feature.y = Spring.GetGroundHeight(feature.x, feature.z)
		spawnFeature(feature.featureDefName, feature, feature.facing, feature.featureName)
	end
end

return {
	ConvertOrdersTargetingNames = convertOrdersTargetingNames,
	SpawnUnitLoadout = spawnUnitLoadout,
	SpawnFeatureLoadout = spawnFeatureLoadout,
}
