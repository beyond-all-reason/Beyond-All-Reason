-- This widget is a duplicate of gui_pip.lua
-- It includes all the code from that widget to create a second independent PiP window

if not Spring.GetModOptions().pip then --and not Spring.GetModOptions().allowuserwidgets then
	return
end

pipNumber = 2

VFS.Include("LuaUI/Widgets/gui_pip.lua")


-- Override GetInfo to change the name and layer
widget.GetInfo = function()
	return {
		name      = "Picture-in-Picture 2",
		desc      = "Second PiP window instance",
		author    = "Floris",
		version   = "1.0",
		date      = "November 2025",
		license   = "GNU GPL, v2 or later",
		layer     = -990009,
		enabled   = false,
		handler   = true,
	}
end

return widget
