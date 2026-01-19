local trackedUnits = GG['MissionAPI'].TrackedUnits
local triggers = GG['MissionAPI'].Triggers

local function enableTrigger(triggerID)
	triggers[triggerID].settings.active = true
end

local function disableTrigger(triggerID)
	triggers[triggerID].settings.active = false
end

local function issueOrders(name, orders)
    if not trackedUnits[name] or #trackedUnits[name] == 0 then return end

	Spring.GiveOrderArrayToUnitArray(trackedUnits[name], orders)
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

local function spawnUnits(name, unitDefName, teamID, position, quantity, facing, construction)
	if name and not trackedUnits[name] then trackedUnits[name] = {} end

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
		if unitID and name then
			trackedUnits[name][#trackedUnits[name] + 1] = unitID
			trackedUnits[unitID] = name
		end
	end
end

----------------------------------------------------------------

local function despawnUnits(name, selfDestruct, reclaimed)
    local unitIDs = trackedUnits[name]
	local quantity = #unitIDs
	for i = quantity, 1, -1 do
		Spring.DestroyUnit(unitIDs[i], selfDestruct, reclaimed)
	end
	trackedUnits[name] = nil
end

----------------------------------------------------------------

local function transferUnits(name, newTeam, given)
	for _, unitID in pairs(trackedUnits[name]) do
		Spring.TransferUnit(unitID, newTeam, given)
	end
end

local function spawnExplosion(position, direction, params)
	spawnExplosion(position[1], position[2], position[3], direction[1], direction[2], direction[3], params)
end

local function sendMessage(message)
	Spring.Echo(message)
end

local function addMarker(position, label, teamID)
	position.y = position.y or Spring.GetGroundHeight(position.x, position.z)
	Spring.MarkerAddPoint(position.x, position.y, position.z, label, false, teamID)
end

local function eraseMarker(position, teamID)
	position.y = position.y or Spring.GetGroundHeight(position.x, position.z)
	Spring.MarkerErasePosition(position.x, position.y, position.z, nil, false, teamID, true)
end

local function drawLines(positions, teamID)
	for _, pos in pairs(positions) do
		pos.y = pos.y or Spring.GetGroundHeight(pos.x, pos.z)
	end
	for i = 1, #positions, 2 do
		pos1 = positions[i]
		pos2 = positions[i + 1]
		Spring.MarkerAddLine(pos1.x, pos1.y, pos1.z, pos2.x, pos2.y, pos2.z, false, teamID)
	end
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

	-- SFX
	SpawnExplosion = spawnExplosion,

	-- Map

	-- Media
	SendMessage = sendMessage,
	AddMarker = addMarker,
	DrawLines = drawLines,
	EraseMarker = eraseMarker,

	-- Win Condition
	Victory = victory,
	Defeat = defeat,

	-- Custom
	Custom = custom,
}
