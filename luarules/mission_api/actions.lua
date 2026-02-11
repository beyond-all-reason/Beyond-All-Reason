local trackedUnitIDs = GG['MissionAPI'].trackedUnitIDs
local trackedUnitNames = GG['MissionAPI'].trackedUnitNames
local triggers = GG['MissionAPI'].Triggers


----------------------------------------------------------------
--- Utility Functions:
----------------------------------------------------------------

local function isNameUntracked(name)
	return table.isNilOrEmpty(trackedUnitIDs[name])
end

local function trackUnit(name, unitID)
	if not name or not unitID then
		return
	end

	if not trackedUnitIDs[name] then
		trackedUnitIDs[name] = {}
	end
	if not trackedUnitNames[unitID] then
		trackedUnitNames[unitID] = {}
	end

	trackedUnitIDs[name][#trackedUnitIDs[name] + 1] = unitID
	trackedUnitNames[unitID][#trackedUnitNames[unitID] + 1] = name
end

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

local function issueOrders(name, orders)
    if isNameUntracked(name) then return end

	Spring.GiveOrderArrayToUnitArray(trackedUnitIDs[name], orders)
end

local function spawnUnits(name, unitDefName, teamID, position, quantity, facing, construction)

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
		trackUnit(name, unitID)
	end
end

----------------------------------------------------------------

local function despawnUnits(name, selfDestruct, reclaimed)
	if isNameUntracked(name) then return end

	-- Copying table as UnitKilled trigger with SpawnUnits with the same name could cause infinite loop.
	for _, unitID in pairs(table.copy(trackedUnitIDs[name])) do
		if Spring.GetUnitIsDead(unitID) == false then
			Spring.DestroyUnit(unitIDs[i], selfDestruct, reclaimed)
		end
	end
end

----------------------------------------------------------------

local function transferUnits(name, newTeam, given)
	if isNameUntracked(name) then return end

	-- Copying table as UnitExists trigger with TransferUnits with the same name could cause infinite loop.
	for _, unitID in pairs(table.copy(trackedUnitIDs[name])) do
		Spring.TransferUnit(unitID, newTeam, given)
	end
end

local function nameUnits(name, teamID, unitDefName, area)

	if not teamID and not unitDefName and not area then
		-- TODO: move this to prevalidation step?
		Spring.Log('actions.lua', LOG.ERROR, "[Mission API] A NameUnits action is missing required parameter. At least one of teamID, unitDefName, and area is required.")
		return
	end

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
		trackUnit(name, unitID)
	end
end

local function unnameUnits(name)
	if isNameUntracked(name) then return end

	for _, unitID in pairs(trackedUnitIDs[name]) do
		table.removeAll(trackedUnitNames[unitID], name)
		if table.isEmpty(trackedUnitNames[unitID]) then
			trackedUnitNames[unitID] = nil
		end
	end
	trackedUnitIDs[name] = nil
end

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
