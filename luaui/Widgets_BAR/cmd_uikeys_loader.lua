function widget:GetInfo()
	return {
	name      = "Lua UiKeys loader",
	desc      = "Loads uikeys.txt file in LuaUI/Widgets_BAR to apply binds",
	author    = "Doo",
	date      = "2018",
	license   = "GNU GPL, v2 or later",
	layer     = 0,
	enabled   = false, --enabled by default
	}
end

function widget:Initialize()
	local k = ""
	if VFS.FileExists("LuaUI/Widgets_BAR/uikeys.txt") then
		k = tostring(VFS.LoadFile("LuaUI/Widgets_BAR/uikeys.txt"))
	end
	local lines = {}
	for s in k:gmatch("[^\r\n]+") do
		table.insert(lines, s)
	end
	for ct, line in pairs(lines) do
		Spring.SendCommands(line)
	end
	Spring.Echo("Succesfully loaded LuaUI/Widgets_BAR/uikeys.txt")
end
