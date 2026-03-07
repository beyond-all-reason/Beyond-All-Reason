local tracking = VFS.Include('luarules/mission_api/tracking.lua')
local initializeTracking     = tracking.InitializeTracking
local trackUnit              = tracking.TrackUnit
local isUnitNameUntracked    = tracking.IsUnitNameUntracked
local untrackUnitName        = tracking.UntrackUnitName
local trackFeature           = tracking.TrackFeature
local isFeatureNameUntracked = tracking.IsFeatureNameUntracked

local trackedUnitIDs    = GG['MissionAPI'].trackedUnitIDs
local trackedFeatureIDs = GG['MissionAPI'].trackedFeatureIDs
local triggers = GG['MissionAPI'].Triggers

initializeTracking()


----------------------------------------------------------------
--- Utility Functions:
----------------------------------------------------------------

local function generateGridPositions(center, quantity, xSpacing, zSpacing)
	local positions = {}
	local xGridSize = math.ceil(math.sqrt(quantity)) * xSpacing
	local zGridSize = math.ceil(math.sqrt(quantity)) * zSpacing
	local left = center.x - math.floor(xGridSize / 2)
	local top = center.z - math.floor(zGridSize / 2)
	local count = 0

	for x = left, left + xGridSize - xSpacing, xSpacing do
		for z = top, top + zGridSize - zSpacing, zSpacing do
			if count >= quantity then return positions end
			table.insert(positions, {x = x, z = z})
			count = count + 1
		end
	end
	return positions
end


----------------------------------------------------------------
--- Action Functions:
----------------------------------------------------------------

local function enableTrigger(triggerID)
	triggers[triggerID].settings.active = true
end

local function disableTrigger(triggerID)
	triggers[triggerID].settings.active = false
end

local function issueOrders(unitName, orders)
    if isUnitNameUntracked(unitName) then return end

	Spring.GiveOrderArrayToUnitArray(trackedUnitIDs[unitName], orders)
end

local function spawnUnits(unitName, unitDefName, teamID, position, quantity, facing, construction)

	if not UnitDefNames[unitDefName] then return end

	local unitDef = UnitDefs[UnitDefNames[unitDefName].id]
	local xsize = unitDef.xsize * Game.squareSize
	local zsize = unitDef.zsize * Game.squareSize

	-- adjust for facing of non-square units
	if facing == 'e' or facing == 'w' then
		xsize, zsize = zsize, xsize
	end

	local positions = generateGridPositions(position, quantity or 1, xsize, zsize)

	for _, pos in pairs(positions) do
		pos.y = Spring.GetGroundHeight(pos.x, pos.z)
		local unitID = Spring.CreateUnit(unitDefName, pos.x, pos.y, pos.z, facing or 's', teamID, construction)
		trackUnit(unitName, unitID)
	end
end

----------------------------------------------------------------

local function despawnUnits(unitName, selfDestruct, reclaimed)
	if isUnitNameUntracked(unitName) then return end

	-- Copying table as UnitKilled trigger with SpawnUnits with the same name could cause infinite loop.
	for _, unitID in pairs(table.copy(trackedUnitIDs[unitName])) do
		if Spring.GetUnitIsDead(unitID) == false then
			Spring.DestroyUnit(unitID, selfDestruct, reclaimed)
		end
	end
end

----------------------------------------------------------------

local function transferUnits(unitName, newTeam, given)
	if isUnitNameUntracked(unitName) then return end

	-- Copying table as UnitExists trigger with TransferUnits with the same name could cause infinite loop.
	for _, unitID in pairs(table.copy(trackedUnitIDs[unitName])) do
		Spring.TransferUnit(unitID, newTeam, given)
	end
end

local function nameUnits(unitName, teamID, unitDefName, area)
	local hasFilterOtherThanTeamID = unitDefName or area

	local allUnitsOfTeam = {}
	if not hasFilterOtherThanTeamID then
		allUnitsOfTeam = Spring.GetTeamUnits(teamID)
	end

	local unitsFromDef = {}
	if unitDefName then
		if UnitDefNames[unitDefName] then
			local unitDefID = UnitDefNames[unitDefName].id
			if teamID then
				unitsFromDef = Spring.GetTeamUnitsByDefs(teamID, unitDefID)
			else
				for _, allyTeamID in pairs(Spring.GetAllyTeamList()) do
					for _, teamIDForAllyTeam in pairs(Spring.GetTeamList(allyTeamID)) do
						table.append(unitsFromDef, Spring.GetTeamUnitsByDefs(teamIDForAllyTeam, unitDefID))
					end
				end
			end
		end
	end

	local unitsInArea = {}
	if area.x1 and area.z1 and area.x2 and area.z2 then
		unitsInArea = Spring.GetUnitsInRectangle(area.x1, area.z1, area.x2, area.z2, teamID)
	elseif area.x and area.z and area.radius then
		unitsInArea = Spring.GetUnitsInCylinder(area.x, area.z, area.radius, teamID)
	end

	local unitsToName = {}
	if hasFilterOtherThanTeamID then
		unitsToName = table.valueIntersection(
			unpack(table.filterArray({ unitsFromDef, unitsInArea},
				function(tbl) return not table.isEmpty(tbl) end)))
	else
		unitsToName = allUnitsOfTeam
	end

	for _, unitID in pairs(unitsToName) do
		trackUnit(unitName, unitID)
	end
end

local function unnameUnits(unitName)
	untrackUnitName(unitName)
end

----------------------------------------------------------------

local function createFeature(featureDefName, position, featureName, facing)
	if not FeatureDefNames[featureDefName] then return end

	-- Convert named facing to a heading integer (Spring uses 0-65535 headings)
	local facingToHeading = { s = 0, n = 32768, e = 16384, w = 49152,
		south = 0, north = 32768, east = 16384, west = 49152,
		[0] = 0, [1] = 32768, [2] = 16384, [3] = 49152 }
	local heading = facing and (facingToHeading[facing] or 0) or 0

	local featureID = Spring.CreateFeature(featureDefName, position.x, position.y, position.z, heading)
	if featureID and featureName then
		trackFeature(featureName, featureID)
	end
end

local function destroyFeature(featureName)
	if isFeatureNameUntracked(featureName) then return end

	-- Copy table to avoid mutation while iterating
	for _, featureID in pairs(table.copy(trackedFeatureIDs[featureName])) do
		if Spring.ValidFeatureID(featureID) then
			Spring.DestroyFeature(featureID)
		end
	end
end

----------------------------------------------------------------

local function spawnExplosion(position, direction, params)
	spawnExplosion(position[1], position[2], position[3], direction[1], direction[2], direction[3], params)
end

local function sendMessage(message)
	Spring.Echo(message)
end

local function victory(winningAllyTeamIDs)
	Spring.GameOver({ unpack(winningAllyTeamIDs) })
end

local function defeat(losingAllyTeamIDs)
	local allAllyTeamIDs = Spring.GetAllyTeamList()
	local winningAllyTeamIDs = { }
	for _, allyTeamID in pairs(allAllyTeamIDs) do
		if not table.contains(losingAllyTeamIDs, allyTeamID) then
			table.insert(winningAllyTeamIDs, allyTeamID)
		end
	end
	Spring.GameOver({ unpack(winningAllyTeamIDs) })
end

local function custom(func)
	func()
end

return {
	-- Triggers
	EnableTrigger = enableTrigger,
	DisableTrigger = disableTrigger,

	-- Orders
	IssueOrders = issueOrders,

	-- Build Options

	-- Units
	SpawnUnits = spawnUnits,
	DespawnUnits = despawnUnits,
	TransferUnits = transferUnits,
	NameUnits = nameUnits,
	UnnameUnits = unnameUnits,

	-- Features
	CreateFeature = createFeature,
	DestroyFeature = destroyFeature,

	-- SFX
	SpawnExplosion = spawnExplosion,

	-- Map

	-- Media
	SendMessage = sendMessage,

	-- Win Condition
	Victory = victory,
	Defeat = defeat,

	-- Custom
	Custom = custom,
}
