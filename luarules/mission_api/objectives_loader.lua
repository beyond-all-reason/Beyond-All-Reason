local validateObjectives = VFS.Include('luarules/mission_api/validation.lua').ValidateObjectives

--[[
	objectiveID = {
		text = "Complete this objective.",
		amount = 3,
	},
]]

local function processRawObjectives(rawObjectives)
	local objectives = table.map(rawObjectives, table.copy)
	validateObjectives(objectives)
	return objectives
end

return {
	ProcessRawObjectives = processRawObjectives,
}
