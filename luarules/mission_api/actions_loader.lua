--[[
	actionID = {
		type = actionTypes.EnableTrigger,
		parameters = {
			triggerID = 'triggerID'
		}
	}
]]

local function processRawActions(rawActions)
	local actions = table.map(rawActions, table.copy)
	return actions
end

return {
	ProcessRawActions = processRawActions,
}
