local ACTIONS_DIR = 'luarules/mission_api/actions/'
local ACTION_FILES_PATTERN = '*.lua'

local function loadActionDefinitions()
	local actionFiles = VFS.DirList(ACTIONS_DIR, ACTION_FILES_PATTERN)

	local types = {}
	local parameters = {}
	local actionFunctions = {}

	for typeID, filePath in ipairs(actionFiles) do
		local actionDefinition = VFS.Include(filePath)
		local actionType = actionDefinition.type

		types[actionType] = typeID
		parameters[typeID] = actionDefinition.parameters or {}
		actionFunctions[typeID] = actionDefinition.actionFunction
	end

	return {
		Types = types,
		Parameters = parameters,
		Functions = actionFunctions,
	}
end

local function processRawActions(rawActions)
	local actions = table.map(rawActions, table.copy)
	return actions
end

return {
	LoadActionDefinitions = loadActionDefinitions,
	ProcessRawActions = processRawActions,
}
