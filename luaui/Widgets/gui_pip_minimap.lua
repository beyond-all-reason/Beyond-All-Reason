-- Disabled in BAR Zombie Defense so standard BAR Minimap (gui_minimap.lua) + custom DrawInMiniMap tactical Spot/Unit overlays stay active
-- and Picture-in-Picture Minimap never resets gl.SlaveMiniMap(false) during startup/shutdown.

function widget:GetInfo()
	return {
		name = "Picture-in-Picture Minimap",
		desc = "Disabled in BAR Zombie Defense MVP (uses standard Minimap + tactical DrawInMiniMap overlays)",
		author = "BAR Zombie Defense",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = -99000,
		enabled = false,
		handler = true,
	}
end

function widget:Initialize()
	if widgetHandler and widgetHandler.RemoveWidget then
		widgetHandler:RemoveWidget(self)
	end
end
