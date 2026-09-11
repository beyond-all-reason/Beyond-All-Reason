---
--- Statistics engine for the Mission API.
---
--- Owns the shared per-trigger counting for the statistics trigger types
--- (TotalUnitsLost/Built/Killed/Captured, UnitsOwned) and bridges those events
--- to managed objectives.
---
--- Trigger activation and iteration belong to the triggers gadget, so they are
--- injected via Init() rather than imported.
---

local statisticsTriggerCounts = {}
local processTriggersOfType, activateTrigger

local function init(dependencies)
	processTriggersOfType = dependencies.processTriggersOfType
	activateTrigger = dependencies.activateTrigger
end

local function updateUnitStatistics(triggerType, teamID, unitDefName, unitNames, direction)
	unitNames = unitNames or {}

	processTriggersOfType(triggerType, function(trigger, triggerID)
		if teamID ~= trigger.parameters.teamID then
			return
		end
		if trigger.parameters.unitDefName and unitDefName ~= trigger.parameters.unitDefName then
			return
		end
		if trigger.parameters.unitName and not unitNames[trigger.parameters.unitName] then
			return
		end

		statisticsTriggerCounts[triggerID] = (statisticsTriggerCounts[triggerID] or 0) + direction

		-- quantity > 0: fire each time the count crosses a milestone (quantity, 2*quantity, ...), and only when incrementing.
		-- quantity == 0 is a special case: fire only when count reaches 0
		local quantity = trigger.parameters.quantity
		if quantity > 0 and direction > 0 then
			local nextThreshold = (trigger.repeatCount + 1) * quantity
			if statisticsTriggerCounts[triggerID] >= nextThreshold then
				activateTrigger(trigger)
			end
		elseif quantity == 0 and statisticsTriggerCounts[triggerID] == 0 then
			activateTrigger(trigger)
		end
	end)

	-- Update managed objectives:
	for _, managedObjective in ipairs(GG["MissionAPI"].ManagedObjectives[triggerType] or {}) do
		GG["MissionAPI"].Modules.Objectives.UpdateObjectiveProgress(
			managedObjective.objectiveID,
			teamID,
			unitDefName,
			unitNames,
			direction,
			managedObjective
		)
	end
end

local function increment(triggerType, teamID, unitDefName, unitNames)
	updateUnitStatistics(triggerType, teamID, unitDefName, unitNames, 1)
end

local function decrement(triggerType, teamID, unitDefName, unitNames)
	updateUnitStatistics(triggerType, teamID, unitDefName, unitNames, -1)
end

return {
	Init = init,
	Increment = increment,
	Decrement = decrement,
}
