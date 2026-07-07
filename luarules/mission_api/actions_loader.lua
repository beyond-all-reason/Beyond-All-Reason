local ACTIONS_DIR = 'luarules/mission_api/actions/'
local ACTION_FILES_PATTERN = '*_action.lua'

local function loadActionDefinitions()
	local actionFiles = VFS.DirList(ACTIONS_DIR, ACTION_FILES_PATTERN)
	table.sort(actionFiles)

	local types = {}
	local parameters = {}
	local functionsByType = {}

	for typeID, filePath in ipairs(actionFiles) do
		local actionDefinition = VFS.Include(filePath)
		local actionName = actionDefinition.name

		types[actionName] = typeID
		parameters[typeID] = actionDefinition.parameters or {}
		functionsByType[typeID] = actionDefinition.execute or function() end
	end

	return {
		Types = types,
		Parameters = parameters,
		Functions = functionsByType,
	}
end

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
	local validateActions = VFS.Include('luarules/mission_api/validation.lua').ValidateActions
	validateActions(actions)
	return actions
end

return {
	LoadActionDefinitions = loadActionDefinitions,
	ProcessRawActions = processRawActions,
}
