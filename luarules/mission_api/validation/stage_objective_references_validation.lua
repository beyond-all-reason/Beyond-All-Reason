---
--- Checks that the objectives a stage lists, and the nextStage an objective advances to, exist.
--- Unit, feature, and marker names are checked by name_references_validation.
---

local SECTION = VFS.Include('luarules/mission_api/validation/validation_report.lua').Sections.References

local function validateStageObjectiveReferences(context, report)
	for stageID, stageData in pairs(context.Stages) do
		if type(stageData) == 'table' and type(stageData.objectives) == 'table' then
			for _, objectiveID in ipairs(stageData.objectives) do
				if type(objectiveID) == 'string' and context.Objectives[objectiveID] == nil then
					report.Error(SECTION, 'Stage', stageID, "Stage refers to non-existent objective",
						"Objective: " .. objectiveID)
				end
			end
		end
	end
end

local function validateObjectiveNextStageReferences(context, report)
	for objectiveID, objective in pairs(context.Objectives) do
		if type(objective) == 'table' and objective.nextStage ~= nil then
			if type(objective.nextStage) ~= 'string' then
				report.Error(SECTION, 'Objective', objectiveID,
					"Unexpected parameter type, expected string, got " .. type(objective.nextStage), "Field: nextStage")
			elseif context.Stages[objective.nextStage] == nil then
				report.Error(SECTION, 'Objective', objectiveID, "Objective references non-existent nextStage",
					"Stage: " .. objective.nextStage)
			end
		end
	end
end

local function validate(context, report)
	validateStageObjectiveReferences(context, report)
	validateObjectiveNextStageReferences(context, report)
end

return {
	Validate = validate,
}
