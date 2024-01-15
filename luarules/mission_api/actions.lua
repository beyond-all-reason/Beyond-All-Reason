--============================================================--

local trackedUnits = GG['MissionAPI'].TrackedUnits
local triggers = GG['MissionAPI'].Triggers
local actionsDefs = VFS.Include('luarules/mission_api/actions_defs.lua')

--============================================================--

-- Utils

--============================================================--

local function GetUnitsFromUnit(unit)
	if unit.team == nil then unit.team = Spring.ALL_UNITS end

	if unit.type == actionsDefs.unitType.name then
		return trackedUnits[unit.unit]
	elseif unit.type == actionsDefs.unitType.unitID then
		return { unit.unit }
	elseif unit.type == actionsDefs.unitType.UnitDefID then
		return Spring.GetTeamUnitsByDefs(unit.team, unit.unit)
	elseif unit.type == actionsDefs.unitType.UnitDefName then
		return Spring.GetTeamUnitsByDefs(unit.team, UnitDefNames[unit.unit])
	end
end

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
	local units = GetUnitsFromUnit(unit)
	Spring.GiveOrderArrayToUnitArray(units, orders)
end

--============================================================--

-- Units

--============================================================--

local function SpawnUnits(name, unitDef, quantity, position, facing, construction)
	if quantity == 0 then return end

	position.y = position.y or Spring.GetGroundHeight(position.x, position.z)

	local unitId = -1
	local unitDefName = ''
	if unitDef.type == actionsDefs.unitDefType.name then
		unitDefName = unitDef.unitDef
	elseif unitDef.type == actionsDefs.unitDefType.ID then
		unitId = UnitDefs[unitDef.unitDef].name
	end

	if not trackedUnits[name] then trackedUnits[name] = {} end

	for i = 1, quantity do
		unitId = Spring.CreateUnit(unitDefName, position.x, position.y, position.z, facing, unitDef.team, construction)

		if unitId and name then
			trackedUnits[name][#trackedUnits[name] + 1] = unitId
			trackedUnits[unitId] = name
		end
	end
end

----------------------------------------------------------------

local function DespawnUnits(unit)
	local units = GetUnitsFromUnit(unit)

	for _, id in ipairs(units) do
		Spring.DestroyUnit(id)
	end
end

----------------------------------------------------------------

local function TransferUnits(unit, newTeam, given)
	local units = GetUnitsFromUnit(unit)

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
}

--============================================================--