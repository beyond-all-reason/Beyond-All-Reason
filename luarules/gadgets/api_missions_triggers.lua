local gadget = gadget ---@type Gadget

local tracking = VFS.Include('luarules/mission_api/tracking.lua')
local initializeTracking = tracking.InitializeTracking
local doesUnitHaveName = tracking.DoesUnitHaveName
local untrackUnitID = tracking.UntrackUnitID

function gadget:GetInfo()
	return {
		name = "Mission API triggers",
		desc = "Monitor and activate triggers, and dispatch actions",
		date = "2023.03.16",
		layer = 1, -- MUST be loaded after api_missions
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local unitLocationCheckInterval = 15

local actionsDispatcher
local types, triggers


----------------------------------------------------------------
--- Utility Functions:
----------------------------------------------------------------

local function processTriggersOfType(triggerType, func)
	for triggerID, trigger in pairs(triggers) do
		if trigger.type == triggerType then
			func(trigger, triggerID)
		end
	end
end

local function isTriggerValid(trigger)
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

local function activateTrigger(trigger)
	if not isTriggerValid(trigger) then
		return
	end

	trigger.triggered = true
	trigger.repeatCount = trigger.repeatCount + 1

	for _, actionID in ipairs(trigger.actions) do
		actionsDispatcher.Invoke(actionID)
	end
end

local function getUnitsInArea(trigger)
	local area = trigger.parameters.area
	local teamID = trigger.parameters.teamID
	local unitsInArea = {}
	if area.x1 and area.z1 and area.x2 and area.z2 then
		unitsInArea = Spring.GetUnitsInRectangle(area.x1, area.z1, area.x2, area.z2, teamID)
	elseif area.x and area.z and area.radius then
		unitsInArea = Spring.GetUnitsInCylinder(area.x, area.z, area.radius, teamID)
	end
	return unitsInArea
end


----------------------------------------------------------------
--- Trigger Checks:
----------------------------------------------------------------

local function checkTimeElapsed(trigger, gameframe)
	local targetframe = trigger.parameters.gameFrame
	local interval = trigger.parameters.interval

	if gameframe == targetframe or (trigger.settings.repeating and gameframe > targetframe and (gameframe - targetframe) % interval == 0) then
		activateTrigger(trigger)
	end
end

local function checkUnitExists(trigger, unitDefID, teamID)
	if trigger.parameters.unitDefName ~= UnitDefs[unitDefID].name then
		return
	end
	local requiredTeamID = trigger.parameters.teamID
	local requiredQuantity = trigger.parameters.quantity
	if requiredTeamID then
		if requiredTeamID ~= teamID then
			return
		elseif Spring.GetTeamUnitDefCount(requiredTeamID, unitDefID) < (requiredQuantity or 1) then
			return
		end
	end
	if requiredQuantity then
		local count = 0
		for _, allyTeamID in pairs(Spring.GetAllyTeamList()) do
			for _, teamIDForAllyTeam in pairs(Spring.GetTeamList(allyTeamID)) do
				count = count + Spring.GetTeamUnitDefCount(teamIDForAllyTeam, unitDefID)
			end
		end
		if count < requiredQuantity then
			return
		end
	end
	activateTrigger(trigger)
end

local function checkUnitRemoved(trigger, unitID, unitDefID, unitTeam)
	if trigger.parameters.unitName and not doesUnitHaveName(unitID, trigger.parameters.unitName) then
		return
	end
	if trigger.parameters.unitDefName and trigger.parameters.unitDefName ~= UnitDefs[unitDefID].name then
		return
	end
	if trigger.parameters.teamID and unitTeam ~= trigger.parameters.teamID then
		return
	end
	activateTrigger(trigger)
end

local function checkUnitCaptured(trigger, unitID, unitDefID, oldTeam, newTeam)
	if trigger.parameters.unitName and not doesUnitHaveName(unitID, trigger.parameters.unitName) then
		return
	end
	if trigger.parameters.unitDefName and trigger.parameters.unitDefName ~= UnitDefs[unitDefID].name then
		return
	end
	if trigger.parameters.oldTeamID and oldTeam ~= trigger.parameters.oldTeamID then
		return
	end
	if trigger.parameters.newTeamID and newTeam ~= trigger.parameters.newTeamID then
		return
	end
	activateTrigger(trigger)
end

local function checkUnitResurrected(trigger, unitDefID, unitTeam, builderID)
	-- same res check as in https://github.com/beyond-all-reason/Beyond-All-Reason/blob/ff188bda741e1320d4f52e89f1098f55bc1d56e2/luarules/gadgets/unit_resurrected.lua#L63
	if not builderID then
		return
	end

	if Spring.GetUnitWorkerTask(builderID) ~= CMD.RESURRECT then
		return
	end

	-- TODO: feature tracking
	--if trigger.parameters.featureName and not doesFeatureHaveName(featureID, trigger.parameters.featureName) then
	--	return
	--end
	if trigger.parameters.unitDefName and trigger.parameters.unitDefName ~= UnitDefs[unitDefID].name then
		return
	end
	if trigger.parameters.teamID and unitTeam ~= trigger.parameters.teamID then
		return
	end
	activateTrigger(trigger)
end

local previousUnitsInAreas = {}
local function checkUnitEnteredLocation(trigger, triggerID)
	if not isTriggerValid(trigger) then
		return
	end

	local unitsInArea = getUnitsInArea(trigger)

	local unitsEnteredArea = table.filterArray(unitsInArea, function(unitID)
		return not table.contains(previousUnitsInAreas[triggerID] or {}, unitID)
			and (not trigger.parameters.unitName or doesUnitHaveName(unitID, trigger.parameters.unitName))
			and (not trigger.parameters.unitDefName or UnitDefs[Spring.GetUnitDefID(unitID)].name == trigger.parameters.unitDefName)
	end)
	previousUnitsInAreas[triggerID] = unitsInArea

	for _, unitID in ipairs(unitsEnteredArea) do
		activateTrigger(trigger)
	end
end

local function checkUnitLeftLocation(trigger, triggerID)
	if not isTriggerValid(trigger) then
		return
	end

	local unitsInArea = getUnitsInArea(trigger)

	local unitsLeftArea = table.filterArray(previousUnitsInAreas[triggerID] or {}, function(unitID)
		return not table.contains(unitsInArea, unitID)
			and (not trigger.parameters.unitName or doesUnitHaveName(unitID, trigger.parameters.unitName))
			and (not trigger.parameters.unitDefName or UnitDefs[Spring.GetUnitDefID(unitID)].name == trigger.parameters.unitDefName)
	end)
	previousUnitsInAreas[triggerID] = unitsInArea

	for _, unitID in ipairs(unitsLeftArea) do
		activateTrigger(trigger)
	end
end

local dwellingUnitsInAreas = {}
local function checkUnitDwellLocation(trigger, triggerID)
	local unitsInArea = getUnitsInArea(trigger)

	for _, unitID in pairs(unitsInArea) do
		-- If unit already dwelling in area, increase dwelling time:
		if dwellingUnitsInAreas[triggerID] and dwellingUnitsInAreas[triggerID][unitID] ~= nil then
			dwellingUnitsInAreas[triggerID][unitID] = dwellingUnitsInAreas[triggerID][unitID] + unitLocationCheckInterval

			-- Check duration, and if unit still has required name:
			if dwellingUnitsInAreas[triggerID][unitID] >= trigger.parameters.duration and
				(not trigger.parameters.unitName or doesUnitHaveName(unitID, trigger.parameters.unitName)) then
				activateTrigger(trigger)
			end

		-- If unit just entered area, start counting:
		elseif (not trigger.parameters.unitName or doesUnitHaveName(unitID, trigger.parameters.unitName))
			and (not trigger.parameters.unitDefName or UnitDefs[Spring.GetUnitDefID(unitID)].name == trigger.parameters.unitDefName) then
			if not dwellingUnitsInAreas[triggerID] then
				dwellingUnitsInAreas[triggerID] = {}
			end
			dwellingUnitsInAreas[triggerID][unitID] = 0
		end
	end

	-- Remove units that left area:
	for unitID, _ in pairs(dwellingUnitsInAreas[triggerID] or {}) do
		if not table.contains(unitsInArea, unitID) then
			dwellingUnitsInAreas[triggerID][unitID] = nil
		end
	end
end

local function checkUnitEnteredOrLeftLos(trigger, unitID, unitTeam, allyTeamID, unitDefID)
	if trigger.parameters.unitName and not doesUnitHaveName(unitID, trigger.parameters.unitName) then
		return
	end
	if trigger.parameters.teamID and unitTeam ~= trigger.parameters.teamID then
		return
	end
	if trigger.parameters.allyTeamID and allyTeamID ~= trigger.parameters.allyTeamID then
		return
	end
	if trigger.parameters.unitDefName and trigger.parameters.unitDefName ~= UnitDefs[unitDefID].name then
		return
	end
	activateTrigger(trigger)
end

local function checkConstructionStarted(trigger, unitID, unitDefID, unitTeam)
	if not Spring.GetUnitIsBeingBuilt(unitID) then
		return
	end
	if trigger.parameters.teamID and unitTeam ~= trigger.parameters.teamID then
		return
	end
	if trigger.parameters.unitDefName and trigger.parameters.unitDefName ~= UnitDefs[unitDefID].name then
		return
	end
	activateTrigger(trigger)
end

local function checkConstructionFinished(trigger, unitID, unitDefID, unitTeam)
	if trigger.parameters.unitName and not doesUnitHaveName(unitID, trigger.parameters.unitName) then
		return
	end
	if trigger.parameters.teamID and unitTeam ~= trigger.parameters.teamID then
		return
	end
	if trigger.parameters.unitDefName and trigger.parameters.unitDefName ~= UnitDefs[unitDefID].name then
		return
	end
	activateTrigger(trigger)
end

local function checkTeamDestroyed(trigger, teamID)
	if teamID == trigger.parameters.teamID then
		activateTrigger(trigger)
	end
end


----------------------------------------------------------------
--- Call-ins:
----------------------------------------------------------------

function gadget:Initialize()
	if not GG['MissionAPI'] then
		gadgetHandler:RemoveGadget()
		return
	end

	actionsDispatcher = VFS.Include('luarules/mission_api/actions_dispatcher.lua')
	types = GG['MissionAPI'].TriggerTypes
	triggers = GG['MissionAPI'].Triggers
	initializeTracking()
end

function gadget:GameFrame(frameNumber)
	processTriggersOfType(types.TimeElapsed, function(trigger, _)
		checkTimeElapsed(trigger, frameNumber)
	end)
	if frameNumber % unitLocationCheckInterval == 0 then
		processTriggersOfType(types.UnitEnteredLocation, function(trigger, triggerID)
			checkUnitEnteredLocation(trigger, triggerID)
		end)
		processTriggersOfType(types.UnitLeftLocation, function(trigger, triggerID)
			checkUnitLeftLocation(trigger, triggerID)
		end)
		processTriggersOfType(types.UnitDwellLocation, function(trigger, triggerID)
			checkUnitDwellLocation(trigger, triggerID)
		end)
	end
end

function gadget:MetaUnitAdded(_, unitDefID, unitTeam)
	processTriggersOfType(types.UnitExists, function(trigger, _)
		checkUnitExists(trigger, unitDefID, unitTeam)
	end)
end

function gadget:MetaUnitRemoved(unitID, unitDefID, unitTeam)
	processTriggersOfType(types.UnitNotExists, function(trigger, _)
		checkUnitRemoved(trigger, unitID, unitDefID, unitTeam)
	end)
	-- Don't untrack unit here, as other call-ins run after this one (UnitDestroyed, UnitTaken, ...)
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	processTriggersOfType(types.UnitResurrected, function(trigger, _)
		checkUnitResurrected(trigger, unitDefID, unitTeam, builderID)
	end)
	processTriggersOfType(types.ConstructionStarted, function(trigger, _)
		checkConstructionStarted(trigger, unitID, unitDefID, unitTeam)
	end)
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, _, _, _)
	processTriggersOfType(types.UnitKilled, function(trigger, _)
		checkUnitRemoved(trigger, unitID, unitDefID, unitTeam)
	end)
	untrackUnitID(unitID)
end

function gadget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
	processTriggersOfType(types.UnitCaptured, function(trigger, _)
		checkUnitCaptured(trigger, unitID, unitDefID, oldTeam, newTeam)
	end)
end

function gadget:UnitEnteredLos(unitID, unitTeam, allyTeamID, unitDefID)
	processTriggersOfType(types.UnitSpotted, function(trigger, _)
		checkUnitEnteredOrLeftLos(trigger, unitID, unitTeam, allyTeamID, unitDefID)
	end)
end

function gadget:UnitLeftLos(unitID, unitTeam, allyTeamID, unitDefID)
	processTriggersOfType(types.UnitUnspotted, function(trigger, _)
		checkUnitEnteredOrLeftLos(trigger, unitID, unitTeam, allyTeamID, unitDefID)
	end)
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	processTriggersOfType(types.ConstructionFinished, function(trigger, _)
		checkConstructionFinished(trigger, unitID, unitDefID, unitTeam)
	end)
end

function gadget:TeamDied(teamID)
	processTriggersOfType(types.TeamDestroyed, function(trigger, _)
		checkTeamDestroyed(trigger, teamID)
	end)
end
