local validateAction = VFS.Include('luarules/mission_api/validation.lua').ValidateAction

--[[
	actionID = {
		type = actionTypes.EnableTrigger,
		parameters = {
			triggerID = 'triggerID'
		}
	}
]]

local function getAllActionIDsReferencedByTriggers()
	local allActionIDsReferencedByTriggers = {}
	for _, trigger in pairs(GG['MissionAPI'].Triggers) do
		if not table.isNilOrEmpty(trigger.actions) then
			for _, actionID in pairs(trigger.actions) do
				allActionIDsReferencedByTriggers[actionID] = true
			end
		end
	end
	return allActionIDsReferencedByTriggers
end

local function validateActions(actions)
	local allActionIDsReferencedByTriggers = getAllActionIDsReferencedByTriggers()

	for actionID, action in pairs(actions) do
		if not allActionIDsReferencedByTriggers[actionID] then
			Spring.Log('actions_loader.lua', LOG.WARNING, "[Mission API] Action not referenced by any trigger: " .. actionID)
		end

		validateAction(actionID, action)
	end
end

local function processRawActions(rawActions)
	local actions = table.map(rawActions, table.copy)
	validateActions(actions)
	return actions
end

return {
	ProcessRawActions = processRawActions,
}
