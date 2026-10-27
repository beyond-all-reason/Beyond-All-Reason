local stagesLoader = VFS.Include("luarules/mission_api/stages_loader.lua")

--[[
	objectiveID = {
		textKey = "complete_objective",

		-- The condition, written exactly as on a trigger. Leave it out for an objective
		-- that only actions complete (CompleteObjective, UpdateObjective):
		type = conditionTypes.ConstructionFinished,
		parameters = { unitDefName = 'corak', teamID = 0 },
		count = 3,                        -- events; metrics use atLeast / atMost

		nextStage = 'secondStage',
		onCompleted = 'reinforcementsTrigger', -- an Event trigger; see objectives_schema.lua for the others
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
		type = objective.type,
		parameters = objective.parameters or {},
		count = objective.count,
		atLeast = objective.atLeast,
		atMost = objective.atMost,
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

--- The value an objective counts towards, used for UI progress. Metrics approach
--- whichever bound they declare; events count occurrences towards `count`, which
--- defaults to 1 because a bare event completes on its first occurrence.
local function targetOf(objective)
	if objective.atLeast ~= nil then
		return objective.atLeast
	end
	if objective.atMost ~= nil then
		return objective.atMost
	end
	return objective.count or 1
end

--- Copies an objective's threshold onto its condition record. Thresholds can depend on
--- the difficulty or a variable, which are only resolved after the records were built.
local function applyThresholds(objectiveID, objective, triggers)
	objective.target = targetOf(objective)

	local triggerID = GG["MissionAPI"].ObjectiveTriggers[objectiveID]
	local trigger = triggerID and triggers[triggerID]
	if not trigger then
		return
	end
	for _, field in ipairs(THRESHOLD_FIELDS) do
		trigger[field] = objective[field]
	end
end

local function processRawObjectives(rawObjectives, rawTriggers, rawActions, stages)
	local objectives = rawObjectives or {}
	local stagesByObjective = stagesLoader.IndexStagesByObjective(stages)
	local objectiveStages = GG["MissionAPI"].ObjectiveStages

	for objectiveID, objective in pairs(objectives) do
		objectiveStages[objectiveID] = stagesByObjective[objectiveID]

		objective.active = false
		objective.completed = false
		objective.progress = 0
		objective.target = targetOf(objective)

		if objective.type ~= nil then
			local triggerID = OBJECTIVE_CONDITION_PREFIX .. objectiveID
			rawTriggers[triggerID] = buildConditionRecord(objectiveID, objective, stagesByObjective[objectiveID] or {})
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
