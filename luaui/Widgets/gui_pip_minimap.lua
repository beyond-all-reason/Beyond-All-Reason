-- This widget replaces the standard minimap with a PIP-style minimap
-- It uses pipNumber = 0 to trigger minimap replacement mode in gui_pip.lua
-- Features:
--   - Positioned at top-left like standard minimap
--   - No screen margin restrictions (edge-to-edge)
--   - No minimize button (always visible)
--   - Calls DrawInMiniMap overlays from other widgets during R2T rendering

pipNumber = 0 -- Triggers minimap mode in gui_pip.lua

VFS.Include("LuaUI/Widgets/gui_pip.lua")

-- Override GetInfo to change the name and layer
widget.GetInfo = function()
	return {
		name = "Picture-in-Picture Minimap",
		desc = "Replaces minimap with an interactive PIP-style map view. Supports panning, zooming, and unit tracking.",
		author = "Floris",
		version = "1.0",
		date = "January 2026",
		license = "GNU GPL, v2 or later",
		layer = -99000,
		enabled = true,
		handler = true,
	}
end

return widget
