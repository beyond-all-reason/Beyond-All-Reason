local ACTIONS_DIR = 'luarules/mission_api/actions/'
local ACTION_FILES_PATTERN = '*.lua'

local function loadActionDefinitions()

	local types = {}
	local typesCount = 0
	local parameters = {}
	local actionFunctions = {}
	local actionsSubdirs = VFS.SubDirs(ACTIONS_DIR)

	local mainActionFiles = VFS.DirList(ACTIONS_DIR, ACTION_FILES_PATTERN) -- Keep this until all action files are in subfolders
	for _, filePath in ipairs(mainActionFiles) do
		local actionDefinitions = VFS.Include(filePath)
		for _, actionDefinition in ipairs(actionDefinitions) do
			typesCount = typesCount + 1
			local actionType = actionDefinition.type

			types[actionType] = typesCount
			parameters[typesCount] = actionDefinition.parameters or {}
			actionFunctions[typesCount] = actionDefinition.actionFunction
		end
	end

	for _, subdirPath in ipairs(actionsSubdirs) do
		Spring.Echo("subdirPath", subdirPath)
		local actionFiles = VFS.DirList(subdirPath, ACTION_FILES_PATTERN)
		for _, filePath in ipairs(actionFiles) do
			local actionDefinitions = VFS.Include(filePath)
			for _, actionDefinition in ipairs(actionDefinitions) do
				typesCount = typesCount + 1
				local actionType = actionDefinition.type

				types[actionType] = typesCount
				parameters[typesCount] = actionDefinition.parameters or {}
				actionFunctions[typesCount] = actionDefinition.actionFunction
			end
		end
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
