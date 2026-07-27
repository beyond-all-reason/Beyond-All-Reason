local ACTIONS_DIR = 'luarules/mission_api/actions/'
local ACTION_FILES_PATTERN = '*.lua'

local function loadActionDefinitions()

	local types = {}
	local typesCount = 0
	local parameters = {}
	local actionFunctions = {}
	local actionsSubdirs = {
		ACTIONS_DIR,
	}

	repeat
		--Spring.Echo("Mission API Actions SubDir", actionsSubdirs[1])
		local actionFiles = VFS.DirList(actionsSubdirs[1], ACTION_FILES_PATTERN)
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

		for _, subDir in pairs(VFS.SubDirs(actionsSubdirs[1])) do
			actionsSubdirs[#actionsSubdirs + 1] = subDir
		end

		table.remove(actionsSubdirs, 1)
	until #actionsSubdirs == 0

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
