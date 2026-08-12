local stagesLoader = VFS.Include('luarules/mission_api/stages_loader.lua')

--[[
	objectiveID = {
		textKey = "complete_objective",

		-- The condition, written exactly as on a trigger:
		type = eventTypes.ConstructionFinished,
		parameters = { unitDefName = 'corak', teamID = 0 },
		count = 3,                        -- events; metrics use atLeast / atMost

		onComplete = {
			nextStage = 'secondStage',
			actions = { 'spawnReinforcements' },
		},
		coop = true,
	},
]]

local OBJECTIVE_CONDITION_PREFIX = '__objective_'

--- Each objective contributes a condition record to the same space the triggers
--- gadget dispatches over, so objectives reuse all 27 condition handlers rather
--- than duplicating their matching logic.
---
--- The record carries `onActivate` instead of `actions`: activation completes
--- the objective rather than invoking mission actions. Records are never
--- repeating, which is what makes completion latched.
local function buildConditionRecord(objectiveID, objective, objectiveStages)
	return {
		type       = objective.type,
		parameters = objective.parameters or {},
		count      = objective.count,
		atLeast    = objective.atLeast,
		atMost     = objective.atMost,
		settings   = {
			stages = objectiveStages,
		},
		onActivate = function()
			GG['MissionAPI'].Modules.Objectives.Complete(objectiveID)
		end,
		onProgress = function(progress)
			GG['MissionAPI'].Modules.Objectives.ReportProgress(objectiveID, progress)
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

local function processRawObjectives(rawObjectives, rawTriggers, rawActions, stages)
	local objectives = rawObjectives or {}
	local stagesByObjective = stagesLoader.IndexStagesByObjective(stages)

	for objectiveID, objective in pairs(objectives) do
		if type(objectiveID) == 'string' and type(objective) == 'table' and objective.type ~= nil then
			objective.completed = false
			objective.progress = 0
			objective.target = targetOf(objective)

			rawTriggers[OBJECTIVE_CONDITION_PREFIX .. objectiveID] =
				buildConditionRecord(objectiveID, objective, stagesByObjective[objectiveID] or {})
		end
	end

	return objectives
end

return {
	ProcessRawObjectives = processRawObjectives,
	ObjectiveConditionPrefix = OBJECTIVE_CONDITION_PREFIX,
}
