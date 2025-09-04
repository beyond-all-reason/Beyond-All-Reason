local trackedUnits = GG['MissionAPI'].TrackedUnits
local triggers = GG['MissionAPI'].Triggers

local function enableTrigger(triggerID)
	triggers[triggerID].settings.active = true
end

local function disableTrigger(triggerID)
	triggers[triggerID].settings.active = false
end

local function issueOrders(units, orders)
	Spring.GiveOrderArrayToUnitArray(units, orders)
end

local function spawnUnits(name, unitDefName, teamID, positions, facing, construction)
    if #positions == 0 then return end

	if not trackedUnits[name] then trackedUnits[name] = {} end

    for _, position in pairs(positions) do
		position.y = position.y or Spring.GetGroundHeight(position.x, position.z)
		local unitID = Spring.CreateUnit(unitDefName, position.x, position.y, position.z, facing, teamID, construction)
		if unitID and name then
			trackedUnits[name][#trackedUnits[name] + 1] = unitID
			trackedUnits[unitID] = name
		end
	end
	Spring.Log(gadget:GetInfo().name, LOG.WARNING, "Spawned "..#positions.."x "..unitDefName.." named "..name.." : "..table.toString(trackedUnits))
end

----------------------------------------------------------------

local function despawnUnits(name, selfDescruct, reclaimed)
    local unitIDs = trackedUnits[name]
	local quantity = #unitIDs
	for i = quantity, 1, -1 do
		Spring.DestroyUnit(unitIDs[i], selfDescruct, reclaimed)
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
