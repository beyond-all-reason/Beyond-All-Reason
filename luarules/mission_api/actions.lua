local trackedUnits = GG['MissionAPI'].TrackedUnits
local triggers = GG['MissionAPI'].Triggers

local function enableTrigger(triggerID)
	triggers[triggerID].settings.active = true
	Spring.Log(gadget:GetInfo().name, LOG.WARNING, "Enabled trigger "..triggerID)
end

local function disableTrigger(triggerID)
	triggers[triggerID].settings.active = false
	Spring.Log(gadget:GetInfo().name, LOG.WARNING, "Disabled trigger "..triggerID)
end

local function issueOrders(name, orders)
    if not trackedUnits[name] or #trackedUnits[name] == 0 then return end

	Spring.GiveOrderArrayToUnitArray(trackedUnits[name], orders)
	Spring.Log(gadget:GetInfo().name, LOG.WARNING, "Ordered units named "..name.." with IDs "..table.toString(trackedUnits[name]).." : "..table.toString(orders))
end

local function generateGridPositions(center, quantity, spacing)
	local positions = {}
	local gridSize = math.ceil(math.sqrt(quantity)) * spacing
	local offset = math.floor(gridSize / 2)
	local left = center.x - offset
	local top = center.z - offset
	local count = 0

	for x = left, left + gridSize - spacing, spacing do
		for z = top, top + gridSize - spacing, spacing do
			if count >= quantity then return positions end
			table.insert(positions, {x = x, z = z})
			count = count + 1
		end
	end
	return positions
end

local function spawnUnits(name, unitDefName, teamID, position, quantity, spacing, facing, construction, alert)
	if name and not trackedUnits[name] then trackedUnits[name] = {} end

	local positions = generateGridPositions(position, quantity or 1, spacing or 50)

	for _, pos in pairs(positions) do
		pos.y = Spring.GetGroundHeight(pos.x, pos.z)
		local unitID = Spring.CreateUnit(unitDefName, pos.x, pos.y, pos.z, facing, teamID, construction)
		if unitID and name then
			trackedUnits[name][#trackedUnits[name] + 1] = unitID
			trackedUnits[unitID] = name
		end
		if alert then
			Spring.TransferUnit(unitID, teamID, given)
		end
	end
	if name then
		Spring.Log(gadget:GetInfo().name, LOG.WARNING, "Spawned "..#positions.."x "..unitDefName.." named "..name.." : "..table.toString(trackedUnits))
	else
		Spring.Log(gadget:GetInfo().name, LOG.WARNING, "Spawned "..#positions.."x "..unitDefName.." unnamed : ")
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
	Spring.Log(gadget:GetInfo().name, LOG.WARNING, "Despawned "..#unitIDs.." units named "..name.." : "..table.toString(trackedUnits))
end

----------------------------------------------------------------

local function transferUnits(units, newTeam, given)
	for _, id in ipairs(units) do
		Spring.TransferUnit(id, newTeam, given)
	end
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
