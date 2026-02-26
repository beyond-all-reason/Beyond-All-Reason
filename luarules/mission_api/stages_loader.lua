local validateStages = VFS.Include('luarules/mission_api/validation.lua').ValidateStages

--[[
	stageID = {
		title = "Destroy their base",
	}
]]

local function processRawStages(rawStages, initialStage)
	local stages = table.map(rawStages, table.copy)
	validateStages(stages, initialStage)
	return stages
end

return {
	ProcessRawStages = processRawStages,
}
