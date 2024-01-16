--============================================================--

function gadget:GetInfo()
	return {
		name = "Mission API triggers",
		desc = "Monitor and activate triggers, and dispatch actions",
		date = "2023.03.16",
		layer = 1, -- MUST be loaded after api_missions
		enabled = true,
	}
end

--============================================================--

if not gadgetHandler:IsSyncedCode() then
	return false
end

--============================================================--

local actionsDefs = VFS.Include('luarules/mission_api/actions_defs.lua')

local actionsDispatcher, trackedUnits

local types, triggers

--============================================================--

local function TriggerValid(trigger)
	if not trigger.settings.active then return false end

	for _, prerequisiteTrigger in pairs(trigger.settings.prerequisites) do
		if not prerequisiteTrigger.triggered then return false end
	end

	if trigger.triggered and not trigger.settings.repeating then return false end
	if trigger.settings.repeating and trigger.settings.maxRepeats ~= nil and trigger.repeatCount > trigger.settings.maxRepeats then return false end
	if trigger.settings.difficulties ~= nil and not trigger.settings.difficulties[GG['MissionAPI'].Difficulty] then return false end

	--[[
	--TODO: co-op check
	if trigger.coop and not ??? then return false end
	]]

	return true
end

----------------------------------------------------------------

local function ActivateTrigger(trigger)
	if not TriggerValid(trigger) then
		return
	end

	trigger.triggered = true
	trigger.repeatCount = trigger.repeatCount + 1

	for _, actionID in ipairs(trigger.actions) do
		actionsDispatcher.Invoke(actionID)
	end
end

--============================================================--

local function UnitIsUnit(unit, unitID, unitDefID)
	if unit.type == actionsDefs.type.name then
		for _, id in ipairs(trackedUnits[unit.unit]) do
			if unitID == id then
				return true
			end
		end
	elseif unit.type == actionsDefs.type.unitID then
		if unitID == unit.unit then
			return true
		end
	elseif unit.type == actionsDefs.type.unitDefID then
		if unitDefID == unit.unit then
			return true
		end
	elseif unit.type == actionsDefs.type.unitDefName then
		if unitDefID == UnitDefNames[unit.unit] then
			return true
		end
	end

	return false
end

--============================================================--

-- Time

----------------------------------------------------------------

local function CheckTimeElapsed(trigger, gameframe)
	local targetframe = trigger.parameters.gameFrame
	local interval = trigger.parameters.interval

	if gameframe == targetframe or (trigger.settings.repeating and gameframe > targetframe and (gameframe - targetframe) % interval == 0) then
		ActivateTrigger(trigger)
		return
	end
end

----------------------------------------------------------------

-- Units

----------------------------------------------------------------

local function CheckUnitExists(trigger)
	local team = trigger.parameters.teamID or Spring.ALL_UNITS
	local quantity = trigger.parameters.quantity or 1

	local units = Spring.GetTeamUnitsByDefs(team, trigger.parameters.unitDefID)
	if #units >= quantity then
		ActivateTrigger(trigger)
		return
	end
end

----------------------------------------------------------------

local function CheckUnitNotExists(trigger)
	local team = trigger.parameters.unit.team or Spring.ALL_UNITS
	local type = trigger.parameters.unit.type
	local unit = trigger.parameters.unit.unit

	if type == actionsDefs.type.name then
		if trackedUnits[unit] == nil then
			ActivateTrigger(trigger)
			return
		end
	elseif type == actionsDefs.type.unitID then
		if not Spring.IsValidUnit(unit) then
			ActivateTrigger(trigger)
			return
		end
	elseif type == actionsDefs.type.unitDefID then
		if #(Spring.GetTeamUnitsByDefs(team, unit)) == 0 then
			ActivateTrigger(trigger)
			return
		end
	elseif type == actionsDefs.type.unitDefName then
		if #(Spring.GetTeamUnitsByDefs(team, UnitDefNames[unit])) == 0 then
			ActivateTrigger(trigger)
			return
		end
	end
end

----------------------------------------------------------------

local function CheckUnitKilled(trigger, unitID, unitDefID)
	if UnitIsUnit(trigger.parameters.unit, unit.unitID, unit.unitDefID) then
		ActivateTrigger(trigger)
	end
end

----------------------------------------------------------------

local function CheckUnitCaptured(trigger, unitID, unitDefID)
	if UnitIsUnit(trigger.parameters.unit, unit.unitID, unit.unitDefID) then
		ActivateTrigger(trigger)
	end
end

----------------------------------------------------------------

local function CheckUnitEnteredLocation(trigger)
	local unit = trigger.parameters.unit
	if not unit.team then unit.team = Spring.ALL_UNITS end
	local position = trigger.parameters.position
	local width = trigger.parameters.width
	local height = trigger.parameters.height

	local units = {}

	if height then
		units = Spring.GetUnitsInRectangle(position[1], position[2], position[1] + width, position[2] + height, unit.team)
	else
		units = Spring.GetUnitsInCylinder(position[1], position[2], width, unit.team)
	end

	for _, id in ipairs(units) do
		if UnitIsUnit(unit, id, Spring.GetUnitDefID(id)) then
			ActivateTrigger(trigger)
			return
		end
	end
end

----------------------------------------------------------------

local function CheckConstructionStarted(trigger, unitID, unitDefID)
	if UnitIsUnit(trigger.parameters.unit, unitID, unitDefID) then
		ActivateTrigger(trigger)
		return
	end
end

----------------------------------------------------------------

local function CheckConstructionFinished(trigger, unitID, unitDefID)
	if UnitIsUnit(trigger.parameters.unit, unitID, unitDefID) then
		ActivateTrigger(trigger)
		return
	end
end

----------------------------------------------------------------

-- Team

----------------------------------------------------------------

local function CheckTeamDestroyed(trigger, teamID)
	if teamID == trigger.parameters.teamID then
		ActivateTrigger(trigger)
	end
end

--============================================================--

function gadget:Initialize()
	if not GG['MissionAPI'] then
		gadgetHandler:RemoveGadget()
		return
	end

	actionsDispatcher = VFS.Include('luarules/mission_api/actions_dispatcher.lua')
	types = GG['MissionAPI'].TriggerTypes
	triggers = GG['MissionAPI'].Triggers
	trackedUnits = GG['MissionAPI'].TrackedUnits
end

----------------------------------------------------------------

function gadget:GameFrame(n)
	for triggerID, trigger in pairs(triggers) do
		if trigger.type == types.TimeElapsed then
			CheckTimeElapsed(trigger, n)
		elseif trigger.type == types.UnitExists then
			CheckUnitExists(trigger)
		elseif trigger.type == types.UnitNotExists then
			CheckUnitNotExists(trigger)
		elseif trigger.type == types.UnitEnteredLocation then
			CheckUnitEnteredLocation(trigger)
		end
	end
end

----------------------------------------------------------------

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	for triggerID, trigger in pairs(triggers) do
		if trigger.type == types.UnitKilled then
			CheckUnitKilled(trigger, unitID, unitDefID)
		end
	end

	-- Remove destroyed tracked units
	local trackedUnits = GG['MissionAPI'].TrackedUnits
	local name = trackedUnits[unitID]

	if not name then return end

	for i, id in ipairs(trackedUnits[name]) do
		if id == unitID then
			table.remove(trackedUnits[name], i)
		end
	end

	if #trackedUnits[name] == 0 then trackedUnits[name] = nil end
	
	trackedUnits[unitID] = nil
end

----------------------------------------------------------------

function gadget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
	for triggerID, trigger in pairs(triggers) do
		if trigger.type == types.UnitCaptured then
			CheckUnitCaptured(trigger, unitID, unitDefID)
		end
	end
end

----------------------------------------------------------------

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	for triggerID, trigger in pairs(triggers) do
		if trigger.type == types.ConstructionStarted then
			CheckConstructionStarted(trigger, unitID, unitDefID)
		end
	end
end

----------------------------------------------------------------

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	for triggerID, trigger in pairs(triggers) do
		if trigger.type == types.ConstructionFinished then
			CheckConstructionFinished(trigger, unitID, unitDefID)
		end
	end
end

----------------------------------------------------------------

function gadget:TeamDied(teamID)
	for triggerID, trigger in pairs(triggers) do
		if trigger.type == types.TeamDestroyed then
			CheckTeamDestroyed(trigger, teamID)
		end
	end
end

--============================================================--