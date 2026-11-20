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

local triggersByTypeAndUnitName = {}
local indexedParameterVersion
local NO_TRIGGERS = {}

local function init(dependencies)
	processTriggersOfType = dependencies.processTriggersOfType
	activateTrigger = dependencies.activateTrigger
	evaluateMetric = dependencies.evaluateMetric
	conditionKinds = dependencies.conditionKinds
	batch = dependencies.batch
	triggersByTypeAndUnitName = {}
end

local function evaluateLastValue(trigger)
	evaluateMetric(trigger, trigger.lastValue)
end

local function updateTriggerCount(trigger, triggerID, isMetric, direction)
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
end

local function getTriggersCountingUnitName(conditionType, unitName)
	local parameterVersion = GG["MissionAPI"].parameterVersion
	if parameterVersion ~= indexedParameterVersion then
		triggersByTypeAndUnitName = {}
		indexedParameterVersion = parameterVersion
	end

	local byUnitName = triggersByTypeAndUnitName[conditionType]
	if byUnitName == nil then
		byUnitName = {}
		processTriggersOfType(conditionType, function(trigger, triggerID)
			local countedName = trigger.parameters.unitName
			if countedName then
				local countingTriggers = byUnitName[countedName]
				if countingTriggers == nil then
					countingTriggers = {}
					byUnitName[countedName] = countingTriggers
				end
				countingTriggers[#countingTriggers + 1] = { trigger = trigger, triggerID = triggerID }
			end
		end)
		triggersByTypeAndUnitName[conditionType] = byUnitName
	end
	return byUnitName[unitName] or NO_TRIGGERS
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

		updateTriggerCount(trigger, triggerID, isMetric, direction)
	end)
end

local function countUnitNameChange(conditionType, teamID, unitDefName, unitName, direction)
	local isMetric = conditionKinds[conditionType] == ConditionKinds.Metric
	local countingTriggers = getTriggersCountingUnitName(conditionType, unitName)
	for i = 1, #countingTriggers do
		local trigger = countingTriggers[i].trigger
		local parameters = trigger.parameters
		if
			parameters.teamName == teamID
			and (parameters.unitDefName == nil or parameters.unitDefName == unitDefName)
		then
			updateTriggerCount(trigger, countingTriggers[i].triggerID, isMetric, direction)
		end
	end
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
	CountUnitNameChange = countUnitNameChange,
}
