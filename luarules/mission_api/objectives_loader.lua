--[[
	objectiveID = {
		textKey = "complete_objective",
		amount = 3,
		trigger = {
			type = conditionTypes.ConstructionFinished,
			parameters = { unitDefName = 'corak', teamID = 0 },
		},
		nextStage = 'secondStage',
		coop = true,
	},
]]

local OBJECTIVE_CONDITION_PREFIX = "__objective_"
local THRESHOLD_FIELDS = { "count", "atLeast", "atMost" }

--- Each objective contributes a condition record to the same space the triggers
--- gadget dispatches over, so objectives reuse every condition handler rather
--- than duplicating their matching logic.
---
--- The record carries `onActivate` instead of `actions`: activation completes
--- the objective rather than invoking mission actions. Records are never
--- repeating, which is what makes completion latched. They start inactive; the
--- objective switches its record on and off as it is activated and canceled.
local function buildConditionRecord(objectiveID, objective, objectiveStages)
	return {
		type = objective.trigger.type,
		parameters = objective.trigger.parameters or {},
		settings = {
			stages = objectiveStages,
			active = false,
		},
		onActivate = function()
			GG["MissionAPI"].Modules.Objectives.CompleteObjective(objectiveID)
		end,
		onProgress = function(progress)
			GG["MissionAPI"].Modules.Objectives.ReportProgress(objectiveID, progress)
		end,
	}
end

--- An objective's `amount` is how many events it counts, or for a metric such as
--- UnitsOwned, the level it must reach. A missing amount completes on the first event.
local function thresholdsOf(objective)
	local amount = objective.amount
	local trigger = objective.trigger
	local conditionDefinitions = GG["MissionAPI"].ConditionDefinitions
	local kind = type(trigger) == "table" and conditionDefinitions and conditionDefinitions.Kinds[trigger.type]
	if kind == "metric" then
		return { atLeast = amount or 1 }
	end
	return { count = amount }
end

--- Copies an objective's threshold onto its condition record. The amount can depend on
--- the difficulty or a variable, which are only resolved after the records were built.
local function applyThresholds(objectiveID, objective, triggers)
	objective.target = objective.amount or 1

	local triggerID = GG["MissionAPI"].ObjectiveTriggers[objectiveID]
	local trigger = triggerID and triggers[triggerID]
	if not trigger then
		return
	end
	local thresholds = thresholdsOf(objective)
	for _, field in ipairs(THRESHOLD_FIELDS) do
		trigger[field] = thresholds[field]
	end
end

local function processRawObjectives(rawObjectives, rawTriggers, rawActions, stages)
	local objectives = rawObjectives or {}

	-- Build objective-to-stages mapping from stages structure
	local objectiveToStages = GG["MissionAPI"].ObjectiveStages
	for stageID, stageData in pairs(stages) do
		for _, objectiveID in ipairs(stageData.objectives) do
			table.insert(table.ensureTable(objectiveToStages, objectiveID), stageID)
		end
	end

	for objectiveID, objective in pairs(objectives) do
		objective.active = false
		objective.completed = false
		objective.progress = 0
		objective.target = objective.amount or 1

		-- An objective without a trigger is completed by actions instead (CompleteObjective, UpdateObjective).
		if type(objective.trigger) == "table" then
			local triggerID = OBJECTIVE_CONDITION_PREFIX .. objectiveID
			local record = buildConditionRecord(objectiveID, objective, objectiveToStages[objectiveID] or {})
			for field, value in pairs(thresholdsOf(objective)) do
				record[field] = value
			end
			rawTriggers[triggerID] = record
			GG["MissionAPI"].ObjectiveTriggers[objectiveID] = triggerID
		end
	end

	return objectives
end

return {
	ProcessRawObjectives = processRawObjectives,
	ApplyThresholds = applyThresholds,
	ObjectiveConditionPrefix = OBJECTIVE_CONDITION_PREFIX,
	ThresholdFields = THRESHOLD_FIELDS,
}
