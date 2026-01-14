local trackedUnitIDsByName = GG['MissionAPI'].TrackedUnitIDsByName
local trackedUnitNamesByID = GG['MissionAPI'].TrackedUnitNamesByID
local triggers = GG['MissionAPI'].Triggers


----------------------------------------------------------------
--- Utility Functions:
----------------------------------------------------------------

local function isNameUntracked(name)
	return not trackedUnitIDsByName[name] or not next(trackedUnitIDsByName[name])
end

local function trackUnit(name, unitID)
	if not name or not unitID then
		return
	end

	if not trackedUnitIDsByName[name] then
		trackedUnitIDsByName[name] = {}
	end
	if not trackedUnitNamesByID[unitID] then
		trackedUnitNamesByID[unitID] = {}
	end

	trackedUnitIDsByName[name][#trackedUnitIDsByName[name] + 1] = unitID
	trackedUnitNamesByID[unitID][#trackedUnitNamesByID[unitID] + 1] = name
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

	Spring.GiveOrderArrayToUnitArray(trackedUnitIDsByName[name], orders)
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

	for _, unitID in pairs(trackedUnitIDsByName[name]) do
		Spring.DestroyUnit(unitID, selfDestruct, reclaimed)
	end
end

----------------------------------------------------------------

local function transferUnits(name, newTeam, given)
	if isNameUntracked(name) then return end

	for _, unitID in pairs(trackedUnitIDsByName[name]) do
		Spring.TransferUnit(unitID, newTeam, given)
	end
end

local function nameUnits(name, teamID, unitDefName, rectangle, circle)

	if not teamID and not unitDefName and not rectangle and not circle then
		-- TODO: move this to prevalidation step?
		Spring.Log('actions.lua', LOG.ERROR, "[Mission API] A NameUnits action is missing required parameter. At least one of teamID, unitDefName, rectangle, and circle is required.")
		return
	end

	local hasFilterOtherThanTeamID = unitDefName or rectangle or circle

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

	local unitsInRectangle = {}
	if rectangle then
		unitsInRectangle = Spring.GetUnitsInRectangle(rectangle.x1, rectangle.z1, rectangle.x2, rectangle.z2, teamID)
	end

	local unitsInCircle = {}
	if circle then
		unitsInCircle = Spring.GetUnitsInCylinder(circle.x, circle.z, circle.radius, teamID)
	end

	local unitsToName = {}
	if hasFilterOtherThanTeamID then
		unitsToName = table.intersection(true, unitsFromDef, unitsInRectangle, unitsInCircle)
	else
		unitsToName = allUnitsOfTeam
	end

	for _, unitID in pairs(unitsToName) do
		trackUnit(name, unitID)
	end
end

local function unnameUnits(name)
	if isNameUntracked(name) then return end

	for _, unitID in pairs(trackedUnitIDsByName[name]) do
		table.removeAll(trackedUnitNamesByID[unitID], name)
		if not next(trackedUnitNamesByID[unitID]) then
			trackedUnitNamesByID[unitID] = nil
		end
	end
	trackedUnitIDsByName[name] = nil
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
