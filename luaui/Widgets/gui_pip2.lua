-- This widget is a duplicate of gui_pip.lua
-- It includes all the code from that widget to create a second independent PiP window

pipNumber = 2

VFS.Include("LuaUI/Widgets/gui_pip.lua")

-- Override GetInfo to change the name and layer
widget.GetInfo = function()
	return {
		name = "Picture-in-Picture " .. pipNumber,
		desc = "Second PiP window instance",
		author = "Floris",
		version = "1.0",
		date = "November 2025",
		license = "GNU GPL, v2 or later",
		layer = (99020 - pipNumber),
		enabled = false,
		handler = true,
	}
end

return widget
