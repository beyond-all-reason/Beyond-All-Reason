--============================================================--

local unpack = unpack or table.unpack -- lua 5.2 compat
local trackedUnits = GG['MissionAPI'].TrackedUnits
local triggers = GG['MissionAPI'].Triggers
local actionsDefs = VFS.Include('luarules/mission_api/types.lua')

--============================================================--

-- Triggers

--============================================================--

local function enableTrigger(triggerID)
	triggers[triggerID].settings.active = true
end

----------------------------------------------------------------

local function disableTrigger(triggerID)
	triggers[triggerID].settings.active = false
end

--============================================================--

-- Orders

--============================================================--

local function issueOrders(unit, orders)
	local units = unit.GetUnits()
	Spring.GiveOrderArrayToUnitArray(units, orders)
end

--============================================================--

-- Units

--============================================================--

local function spawnUnits(name, unitDefName, quantity, position, facing, construction)
	if quantity == 0 then return end

	position.y = position.y or Spring.GetGroundHeight(position.x, position.z)

	--local unitID = -1
	--local unitDefName = unitDef.getName()

	--if not trackedUnits[name] then trackedUnits[name] = {} end

	for i = 1, quantity do
		local unitID = Spring.CreateUnit(unitDefName, position.x, position.y, position.z, facing.value, 0, construction)

		--if unitID and name then
		--	trackedUnits[name][#trackedUnits[name] + 1] = unitID
		--	trackedUnits[unitID] = name
		--end
	end
end

----------------------------------------------------------------

local function despawnUnits(unit)
	local units = unit.GetUnits()

	for _, id in ipairs(units) do
		Spring.DestroyUnit(id)
	end
end

----------------------------------------------------------------

local function transferUnits(unit, newTeam, given)
	local units = unit.GetUnits()

	for _, id in ipairs(units) do
		Spring.TransferUnit(id, newTeam, given)
	end
end

--============================================================--

-- SFX

--============================================================--

local function spawnExplosion(position, direction, params)
	spawnExplosion(position[1], position[2], position[3], direction[1], direction[2], direction[3], params)
end

--============================================================--

-- Media

--============================================================--

local function sendMessage(message)
	Spring.Echo(message)
end

--============================================================--

-- Win Condition

--============================================================--

local function getAllyTeamsHavingPlayers()
	local allyTeamsHavingPlayers = {}
	for _, playerID in pairs(Spring.GetPlayerList()) do
		local _, _, spec, _, allyTeamID = Spring.GetPlayerInfo(playerID, false)
		if not spec and not allyTeamsHavingPlayers[allyTeamID] then
			allyTeamsHavingPlayers[allyTeamID] = allyTeamID
		end
	end
	return allyTeamsHavingPlayers
end

----------------------------------------------------------------

local function victory()
	Spring.GameOver({ unpack(getAllyTeamsHavingPlayers()) })
end

----------------------------------------------------------------

local function defeat()
	local allyTeamsHavingPlayers = getAllyTeamsHavingPlayers()
	local allAllyTeamIDs = Spring.GetAllyTeamList()
	local allyTeamsWithoutPlayers = {}
	for _, allyTeamID in pairs(allAllyTeamIDs) do
		if not allyTeamsHavingPlayers[allyTeamID] then
			allyTeamsWithoutPlayers[allyTeamID] = allyTeamID
		end
	end
	Spring.GameOver({ unpack(allyTeamsWithoutPlayers) })
end

--============================================================--

-- Custom

--============================================================--

local function custom(func)
	func()
end

--============================================================--

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

--============================================================--
