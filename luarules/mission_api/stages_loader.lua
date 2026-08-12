--[[
	Stages structure:
	stages = {
		stageID1 = { objectives = { 'objectiveID1', 'objectiveID2' } },
		stageID2 = { objectives = { 'objectiveID2', 'objectiveID3' } },
	}
]]

local function processRawStages(rawStages)
	return rawStages or {}
end

--- Inverts the stage -> objectives mapping, so a condition can be restricted to
--- the stages its objective appears in. Built once at load.
local function indexStagesByObjective(stages)
	local stagesByObjective = {}

	for stageID, stageData in pairs(stages or {}) do
		if type(stageData) == 'table' and type(stageData.objectives) == 'table' then
			for _, objectiveID in ipairs(stageData.objectives) do
				local ofObjective = stagesByObjective[objectiveID]
				if not ofObjective then
					ofObjective = {}
					stagesByObjective[objectiveID] = ofObjective
				end
				ofObjective[#ofObjective + 1] = stageID
			end
		end
	end

	return stagesByObjective
end

return {
	ProcessRawStages = processRawStages,
	IndexStagesByObjective = indexStagesByObjective,
}
