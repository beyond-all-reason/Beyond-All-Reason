
local commands = {}
local commandsMap = {}
local commandFiles = VFS.DirList('LuaRules/Configs/ModCommands')
for i = 1, #commandFiles do
	local fileData = VFS.Include(commandFiles[i])
	fileData.cmdDesc = {
		id      = fileData.cmdID,
		type    = fileData.commandType,
		tooltip = fileData.name, -- Overridden by luaUI
		name    = fileData.humanName,
		cursor  = fileData.cursor,
		action  = fileData.actionName,
		params  = {},
	}
	commands[#commands + 1] = fileData
	commandsMap[fileData.cmdID] = fileData
end

return commands, commandsMap
