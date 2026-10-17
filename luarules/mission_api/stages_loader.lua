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

return {
	ProcessRawStages = processRawStages,
}
