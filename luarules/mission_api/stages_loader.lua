local validation = VFS.Include('luarules/mission_api/validation.lua')

--[[
	Stages structure:
	stages = {
		stageID1 = { objectives = { 'objectiveID1', 'objectiveID2' } },
		stageID2 = { objectives = { 'objectiveID2', 'objectiveID3' } },
	}
]]

local function processRawStages(rawStages)
	local stages = {}

	if rawStages then
		stages = table.copy(rawStages)
	end

	validation.ValidateStages(stages)

	return stages
end

return {
	ProcessRawStages = processRawStages,
}
