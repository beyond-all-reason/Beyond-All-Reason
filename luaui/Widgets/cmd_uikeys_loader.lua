local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Lua UiKeys loader",
		desc      = "Loads uikeys.txt file in LuaUI/Widgets to apply binds",
		author    = "Doo",
		date      = "2018",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = false,
	}
end

function widget:Initialize()
	local k = ''
	if VFS.FileExists("LuaUI/Widgets/uikeys.txt") then
		k = tostring(VFS.LoadFile("LuaUI/Widgets/uikeys.txt"))
	end
	local lines = {}
	local numLines = 0
	for s in k:gmatch("[^\r\n]+") do
		table.insert(lines, s)
		numLines = numLines + 1
	end
	for ct, line in pairs(lines) do
		Spring.SendCommands(line)
	end
	if numLines > 0 then
		Spring.Echo("Succesfully loaded LuaUI/Widgets/uikeys.txt")
	end
end
