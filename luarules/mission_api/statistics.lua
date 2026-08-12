---
--- Statistics engine for the Mission API.
---
--- Owns the shared per-condition counting for the statistics condition types
--- (TotalUnitsLost/Built/Killed/Captured, UnitsOwned), which declare no call-ins
--- of their own.
---
--- The TotalUnits* types are events: cumulative tallies that only ever rise, so
--- each matching occurrence is handed to ActivateTrigger, which applies `count`.
--- UnitsOwned is a metric: a level that moves in both directions, so its running
--- value is handed to EvaluateMetric, which applies `atLeast`/`atMost`.
---
--- Trigger activation and iteration belong to the triggers gadget, so they are
--- injected via Init() rather than imported.
---

local statisticsTriggerCounts = {}
local processTriggersOfType, activateTrigger, evaluateMetric, conditionKinds

local function init(dependencies)
	processTriggersOfType = dependencies.processTriggersOfType
	activateTrigger       = dependencies.activateTrigger
	evaluateMetric        = dependencies.evaluateMetric
	conditionKinds        = dependencies.conditionKinds
end

local function updateUnitStatistics(triggerType, teamID, unitDefName, unitNames, direction)
	unitNames = unitNames or {}

	local isMetric = conditionKinds[triggerType] == 'metric'

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

		if isMetric then
			-- A level: compare the running value against the condition's bounds.
			evaluateMetric(trigger, statisticsTriggerCounts[triggerID])
		elseif direction > 0 then
			-- A tally: report the occurrence and let `count` decide whether it fires.
			activateTrigger(trigger)
		end
	end)
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
