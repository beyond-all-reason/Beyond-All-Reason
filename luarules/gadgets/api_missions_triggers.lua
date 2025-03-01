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

local actionsDefs = VFS.Include('luarules/mission_api/types.lua')

local actionsDispatcher, trackedUnits

local types, triggers

--============================================================--

local function triggerValid(trigger)
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

local function activateTrigger(trigger)
	if not triggerValid(trigger) then
		return
	end

	trigger.triggered = true
	trigger.repeatCount = trigger.repeatCount + 1

	for _, actionID in ipairs(trigger.actions) do
		actionsDispatcher.Invoke(actionID)
	end
end

--============================================================--

-- Time

----------------------------------------------------------------

local function checkTimeElapsed(trigger, gameframe)
	local targetframe = trigger.parameters.gameFrame
	local interval = trigger.parameters.interval

	if gameframe == targetframe or (trigger.settings.repeating and gameframe > targetframe and (gameframe - targetframe) % interval == 0) then
		activateTrigger(trigger)
		return
	end
end

----------------------------------------------------------------

-- Units

----------------------------------------------------------------

local function checkUnitExists(trigger)
	local quantity = trigger.parameters.quantity or 1

	local units = Spring.GetTeamUnitsByDefs(trigger.parameters.unitDef.team, trigger.parameters.unitDef.getName())
	if #units >= quantity then
		activateTrigger(trigger)
		return
	end
end

----------------------------------------------------------------

local function checkUnitNotExists(trigger)
	local unit = trigger.parameters.unit

	if unit.type == actionsDefs.type.name then
		if trackedUnits[unit.ID] == nil then
			activateTrigger(trigger)
			return
		end
	elseif unit.type == actionsDefs.type.unitID then
		if not Spring.IsValidUnit(unit.ID) then
			activateTrigger(trigger)
			return
		end
	elseif unit.type == actionsDefs.type.unitDefID then
		if #(Spring.GetTeamUnitsByDefs(unit.team, unit.ID)) == 0 then
			activateTrigger(trigger)
			return
		end
	elseif unit.type == actionsDefs.type.unitDefName then
		if #(Spring.GetTeamUnitsByDefs(unit.team, UnitDefNames[unit.ID])) == 0 then
			activateTrigger(trigger)
			return
		end
	end
end

----------------------------------------------------------------

local function checkUnitKilled(trigger, unitID, unitDefID)
	if trigger.parameters.unit.isUnit(unitID, unitDefID) then
		activateTrigger(trigger)
	end
end

----------------------------------------------------------------

local function checkUnitCaptured(trigger, unitID, unitDefID)
	if trigger.parameters.unit.isUnit(unitID, unitDefID) then
		activateTrigger(trigger)
	end
end

----------------------------------------------------------------

local function checkConstructionStarted(trigger, unitID, unitDefID)
	if trigger.parameters.unit.isUnit(unitID, unitDefID) then
		activateTrigger(trigger)
		return
	end
end

----------------------------------------------------------------

local function checkConstructionFinished(trigger, unitID, unitDefID)
	if trigger.parameters.unit.isUnit(unitID, unitDefID) then
		activateTrigger(trigger)
		return
	end
end

----------------------------------------------------------------

-- Team

----------------------------------------------------------------

local function checkTeamDestroyed(trigger, teamID)
	if teamID == trigger.parameters.teamID then
		activateTrigger(trigger)
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
			checkTimeElapsed(trigger, n)
		elseif trigger.type == types.UnitExists then
			checkUnitExists(trigger)
		elseif trigger.type == types.UnitNotExists then
			checkUnitNotExists(trigger)
		end
	end
end

----------------------------------------------------------------

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	for triggerID, trigger in pairs(triggers) do
		if trigger.type == types.UnitKilled then
			checkUnitKilled(trigger, unitID, unitDefID)
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
			checkUnitCaptured(trigger, unitID, unitDefID)
		end
	end
end

----------------------------------------------------------------

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	for triggerID, trigger in pairs(triggers) do
		if trigger.type == types.ConstructionStarted then
			checkConstructionStarted(trigger, unitID, unitDefID)
		end
	end
end

----------------------------------------------------------------

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	for triggerID, trigger in pairs(triggers) do
		if trigger.type == types.ConstructionFinished then
			checkConstructionFinished(trigger, unitID, unitDefID)
		end
	end
end

----------------------------------------------------------------

function gadget:TeamDied(teamID)
	for triggerID, trigger in pairs(triggers) do
		if trigger.type == types.TeamDestroyed then
			checkTeamDestroyed(trigger, teamID)
		end
	end
end

--============================================================--