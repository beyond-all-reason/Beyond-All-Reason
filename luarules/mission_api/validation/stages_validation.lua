---
--- Stage validation: stage shape and the mission's initial stage.
---

local SECTION = VFS.Include('luarules/mission_api/validation/validation_report.lua').Sections.Stages
local LABEL = 'Stage'

local function validateStages(stages, report)
	for stageID, stageData in pairs(stages) do
		if type(stageID) ~= 'string' then
			report.Error(SECTION, LABEL, stageID, "Stage ID must be a string, got " .. type(stageID))
		end

		if type(stageData) ~= 'table' then
			report.Error(SECTION, LABEL, stageID, "Stage data must be a table, got " .. type(stageData))
		else
			local objectives = stageData.objectives
			if objectives == nil then
				report.Error(SECTION, LABEL, stageID, "Stage missing 'objectives' field")
			elseif type(objectives) ~= 'table' then
				report.Error(SECTION, LABEL, stageID, "Stage 'objectives' field must be a table, got " .. type(objectives))
			elseif #objectives == 0 then
				report.Warn(SECTION, LABEL, stageID, "Stage has empty 'objectives' table")
			else
				for index, objectiveID in ipairs(objectives) do
					if type(objectiveID) ~= 'string' then
						report.Error(SECTION, LABEL, stageID,
							"Stage 'objectives' entry must be a string, got " .. type(objectiveID), "Entry: " .. index)
					end
				end
			end
		end
	end
end

local function validateInitialStage(stages, initialStage, report)
	if next(stages) then
		if not initialStage then
			report.Error(SECTION, nil, nil, "Stages are defined, but initialStage is not provided")
		elseif stages[initialStage] == nil then
			report.Error(SECTION, LABEL, initialStage, "Initial stage does not exist in stages")
		end
	elseif initialStage then
		report.Warn(SECTION, LABEL, initialStage, "initialStage is set, but no stages are defined")
	end
end

local function validate(context, report)
	validateStages(context.Stages, report)
	validateInitialStage(context.Stages, context.InitialStage, report)
end

return {
	Validate = validate,
}
