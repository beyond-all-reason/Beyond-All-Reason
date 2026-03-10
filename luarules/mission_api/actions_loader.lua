local validateActions = VFS.Include('luarules/mission_api/validation.lua').ValidateActions
local processActionsParameters = VFS.Include('luarules/mission_api/parameter_processing.lua').ProcessActionsParameters

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
	processActionsParameters(actions)
	return actions
end

return {
	ProcessRawActions = processRawActions,
}
