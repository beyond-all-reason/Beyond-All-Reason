local validateActions = VFS.Include('luarules/mission_api/validation.lua').ValidateActions

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
	validateActions(actions)
	return actions
end

return {
	ProcessRawActions = processRawActions,
}
