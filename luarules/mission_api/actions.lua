local trackedUnits = GG['MissionAPI'].TrackedUnits
local triggers = GG['MissionAPI'].Triggers


----------------------------------------------------------------
--- Utility Functions:
----------------------------------------------------------------

local function isNameUntracked(name)
	return not trackedUnits[name] or #trackedUnits[name] == 0
end

local function trackUnit(name, unitID)
	if not name or not unitID then return end

	if not trackedUnits[name] then trackedUnits[name] = {} end
	if not trackedUnits[unitID] then trackedUnits[unitID] = {} end

	trackedUnits[name][#trackedUnits[name] + 1] = unitID
	trackedUnits[unitID][#trackedUnits[unitID] + 1] = name
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

	Spring.GiveOrderArrayToUnitArray(trackedUnits[name], orders)
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

	local unitIDs = table.copy(trackedUnits[name])
	local quantity = #unitIDs
	for i = quantity, 1, -1 do
		Spring.DestroyUnit(unitIDs[i], selfDestruct, reclaimed)
	end
end

----------------------------------------------------------------

local function transferUnits(name, newTeam, given)
	if isNameUntracked(name) then return end

	for _, unitID in pairs(trackedUnits[name]) do
		Spring.TransferUnit(unitID, newTeam, given)
	end
end

local function nameUnits(name, teamID, unitDefName, rectangle)

	if name and not trackedUnits[name] then trackedUnits[name] = {} end

	local unitsFromTeam = {}
	if teamID then
		if unitDefName then
			if UnitDefNames[unitDefName] then
				local unitDefID = UnitDefNames[unitDefName].id
				unitsFromTeam = Spring.GetTeamUnitsByDefs(teamID, unitDefID)
			end
		else
			unitsFromTeam = Spring.GetTeamUnits(teamID)
		end
	end

	local unitsToName = {}
	if rectangle then
		local unitsInRectangle = Spring.GetUnitsInRectangle(rectangle.x1, rectangle.z1, rectangle.x2, rectangle.z2, teamID)

		-- calculate the union of unitsFromTeam and unitsInRectangle:
		local rectSet = {}
		for _, unitID in ipairs(unitsInRectangle) do
			rectSet[unitID] = true
		end
		for _, unitID in ipairs(unitsFromTeam) do
			if rectSet[unitID] then unitsToName[#unitsToName+1] = unitID
			end
		end
	else
		unitsToName = unitsFromTeam
	end

	for _, unitID in pairs(unitsToName) do
		trackUnit(name, unitID)
	end
end

local function unnameUnits(name)
	if isNameUntracked(name) then return end

	for _, unitID in pairs(trackedUnits[name]) do
		table.removeAll(trackedUnits[unitID], name)
		if #trackedUnits[unitID] == 0 then trackedUnits[unitID] = nil end
	end
	trackedUnits[name] = nil
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
