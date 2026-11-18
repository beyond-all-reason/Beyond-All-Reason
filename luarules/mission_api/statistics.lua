---
--- Statistics engine for the Mission API.
---
--- Owns the shared per-condition counting for the statistics condition types
--- (TotalUnitsLost/Built/Killed/Captured, UnitsOwned), which declare no call-ins
--- of their own.
---
--- The TotalUnits* types are events: cumulative tallies that only ever rise, so
--- each matching occurrence is deferred to ActivateTrigger, which applies `count`.
--- UnitsOwned is a metric: a level that moves in both directions, so its running
--- value is deferred to EvaluateMetric, which applies `atLeast`/`atMost`.
---
--- Trigger activation and iteration belong to the triggers gadget, so they are
--- injected via Init() rather than imported.
---

local ConditionKinds = VFS.Include("luarules/mission_api/condition_kinds.lua")

local statisticsTriggerCounts = {}
local processTriggersOfType, activateTrigger, evaluateMetric, conditionKinds
local batch

local function init(dependencies)
	processTriggersOfType = dependencies.processTriggersOfType
	activateTrigger = dependencies.activateTrigger
	evaluateMetric = dependencies.evaluateMetric
	conditionKinds = dependencies.conditionKinds
	batch = dependencies.batch
end

local function evaluateLastValue(trigger)
	evaluateMetric(trigger, trigger.lastValue)
end

local function updateUnitStatistics(conditionType, teamID, unitDefName, unitNames, direction)
	unitNames = unitNames or {}

	local isMetric = conditionKinds[conditionType] == ConditionKinds.Metric

	processTriggersOfType(conditionType, function(trigger, triggerID)
		if teamID ~= trigger.parameters.teamName then
			return
		end
		if trigger.parameters.unitDefName and unitDefName ~= trigger.parameters.unitDefName then
			return
		end
		if trigger.parameters.unitName and not unitNames[trigger.parameters.unitName] then
			return
		end

		local count = (statisticsTriggerCounts[triggerID] or 0) + direction
		statisticsTriggerCounts[triggerID] = count

		if isMetric then
			-- A level: compare the running value against the condition's bounds.
			trigger.lastValue = count
			batch.DeferNetValue(evaluateLastValue, trigger)
		elseif direction > 0 then
			-- A tally: report the occurrence and let `count` decide whether it fires.
			batch.Defer(activateTrigger, trigger)
		end
	end)
end

local function increment(conditionType, teamID, unitDefName, unitNames)
	updateUnitStatistics(conditionType, teamID, unitDefName, unitNames, 1)
end

local function decrement(conditionType, teamID, unitDefName, unitNames)
	updateUnitStatistics(conditionType, teamID, unitDefName, unitNames, -1)
end

return {
	Init = init,
	Increment = increment,
	Decrement = decrement,
}
