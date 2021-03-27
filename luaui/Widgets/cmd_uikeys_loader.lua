function widget:GetInfo()
	return {
	name      = "Lua UiKeys loader",
	desc      = "Loads uikeys.txt file in LuaUI/Widgets to apply binds",
	author    = "Doo",
	date      = "2018",
	layer     = 0,
	enabled   = false, --enabled by default
	}
end

function widget:Initialize()
	local k = ""
	if VFS.FileExists("LuaUI/Widgets/uikeys.txt") then
		k = tostring(VFS.LoadFile("LuaUI/Widgets/uikeys.txt"))
	end
	local lines = {}
	for s in k:gmatch("[^\r\n]+") do
		table.insert(lines, s)
	end
	for ct, line in pairs(lines) do
		Spring.SendCommands(line)
	end
	Spring.Echo("Succesfully loaded LuaUI/Widgets/uikeys.txt")
end
