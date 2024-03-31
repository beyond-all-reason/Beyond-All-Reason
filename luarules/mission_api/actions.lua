--============================================================--

local trackedUnits = GG['MissionAPI'].TrackedUnits
local triggers = GG['MissionAPI'].Triggers
local actionsDefs = VFS.Include('luarules/mission_api/actions_defs.lua')

--============================================================--

-- Triggers

--============================================================--

local function EnableTrigger(triggerID)
	triggers[triggerID].settings.active = true
end

----------------------------------------------------------------

local function DisableTrigger(triggerID)
	triggers[triggerID].settings.active = false
end

--============================================================--

-- Orders

--============================================================--

local function IssueOrders(unit, orders)
	local units = unit.GetUnits()
	Spring.GiveOrderArrayToUnitArray(units, orders)
end

--============================================================--

-- Units

--============================================================--

local function SpawnUnits(name, unitDef, quantity, position, facing, construction)
	if quantity == 0 then return end

	position.y = position.y or Spring.GetGroundHeight(position.x, position.z)

	local unitID = -1
	local unitDefName = unitDef.getName()

	if not trackedUnits[name] then trackedUnits[name] = {} end

	for i = 1, quantity do
		unitID = Spring.CreateUnit(unitDefName, position.x, position.y, position.z, facing, unitDef.team, construction)

		if unitID and name then
			trackedUnits[name][#trackedUnits[name] + 1] = unitID
			trackedUnits[unitID] = name
		end
	end
end

----------------------------------------------------------------

local function DespawnUnits(unit)
	local units = unit.GetUnits()

	for _, id in ipairs(units) do
		Spring.DestroyUnit(id)
	end
end

----------------------------------------------------------------

local function TransferUnits(unit, newTeam, given)
	local units = unit.GetUnits()

	for _, id in ipairs(units) do
		Spring.TransferUnit(id, newTeam, given)
	end
end

--============================================================--

-- SFX

--============================================================--

local function SpawnExplosion(position, direction, params)
	SpawnExplosion(position[1], position[2], position[3], direction[1], direction[2], direction[3], params)
end

--============================================================--

-- Media

--============================================================--

local function SendMessage(message)
	Spring.Echo(message)
end

--============================================================--

-- Custom

--============================================================--

local function Custom(func)
	func()
end

--============================================================--

return {
	-- Triggers
	['EnableTrigger'] = EnableTrigger,
	['DisableTrigger'] = DisableTrigger,

	-- Orders
	['IssueOrders'] = IssueOrders,

	-- Build Options

	-- Units
	['SpawnUnits'] = SpawnUnits,
	['DespawnUnits'] = DespawnUnits,
	['TransferUnits'] = TransferUnits,

	-- SFX
	['SpawnExplosion'] = SpawnExplosion,

	-- Map

	-- Media
	['SendMessage'] = SendMessage,

	-- Win Condition

	-- Custom
	['Custom'] = Custom,
}

--============================================================--