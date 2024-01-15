--============================================================--

local trackedUnits = GG['MissionAPI'].TrackedUnits
local triggers = GG['MissionAPI'].Triggers
local actionsDefs = VFS.Include('luarules/mission_api/actions_defs.lua')

--============================================================--

-- Triggers

--============================================================--

local function EnableTrigger(triggerID)
	triggers[triggerId].settings.active = true
end

----------------------------------------------------------------

local function DisableTrigger(triggerID)
	triggers[triggerId].settings.active = false
end

--============================================================--

-- Orders

--============================================================--

local function IssueOrdersID(unitID, teamID, orders)
	Spring.GiveOrderArrayToUnitArray({unitID}, orders)
end

----------------------------------------------------------------

local function IssueOrdersName(name, teamID, orders)
	local units = trackedUnits[name]
	if type(units) == 'number' then
		IssueOrdersID(units, orders)
	elseif type(units) == 'table' then
		for _, unitID in ipairs(units) do
			IssueOrdersID(unitID, teamID, orders)
		end
	end
end

----------------------------------------------------------------

local function IssueOrdersDefID(unitDefID, teamID, orders)
	local units = Spring.GetTeamUnitsByDefs(teamID, unitDefID)

	for _, unitID in ipairs(units) do
		IssueOrdersID(unitID, orders)
	end
end

----------------------------------------------------------------

local function IssueOrdersDefName(unitDefName, teamID, orders)
	local unitDefID = UnitDefNames[unitDefName]
	if unitDefID then
		IssueOrdersDefID(unitDefID, teamID, orders)
	end
end

----------------------------------------------------------------

local function IssueOrders(unit, orders)
	if not unit.team then unit.team = Spring.ALL_UNITS end

	if unit.type == actionsDefs.unitType.name then
		IssueOrdersName(unit.unit, unit.team, orders)
	elseif unit.type == actionsDefs.unitType.ID then
		IssueOrdersID(unit.unit, unit.team, orders)
	elseif unit.type == actionsDefs.unitType.unitDefID then
		IssueOrdersDefID(unit.unit, unit.team, orders)
	elseif unit.type == actionsDefs.unitType.unitDefName then
		IssueOrdersDefName(unit.unit, unit.team, orders)
	end
end

--============================================================--

-- Units

--============================================================--

local function SpawnUnits(name, unitDef, quantity, position, facing)
	if quantity == 0 then return end

	position.y = position.y or Spring.GetGroundHeight(position.x, position.z)

	local unitId = -1
	local unitDefName = ''
	if unitDef.type == actionsDefs.unitDefType.name then
		unitDefName = unitDef.unitDef
	elseif unitDef.type == actionsDefs.unitDefType.ID then
		unitId = UnitDefs[unitDef.unitDef].name
	end

	if quantity == 1 then
		unitId = Spring.CreateUnit(unitDefName, position.x, position.y, position.z, facing, unitDef.team)

		if unitId and name then
			trackedUnits[name] = unitId
			trackedUnits[unitId] = name
		end
	else
		trackedUnits[name] = {}
		for i = 1, quantity do
			unitId = Spring.CreateUnit(unitDefName, position.x, position.y, position.z, facing, unitDef.team)

			if unitId and name then
				trackedUnits[name][#trackedUnits[name] + 1] = unitId
				trackedUnits[unitId] = name
			end
		end
	end
end

----------------------------------------------------------------

local function DespawnUnits(name)
	if type(trackedUnits[name] == 'number') then
		local unitId = trackedUnits[name]

		if unitId then
			trackedUnits[name] = nil
			trackedUnits[unitId] = nil

			Spring.DestroyUnit(unitId, false, true)
		end
	elseif type(trackedUnits[name] == 'table') then
		for _, id in ipairs(trackedUnits[name]) do
			Spring.DestroyUnit(id)
			trackedUnits[id] = nil
		end
		trackedUnits[name] = nil
	end
		
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

	-- Map

	-- Media
	['SendMessage'] = SendMessage,

	-- Win Condition
}

--============================================================--