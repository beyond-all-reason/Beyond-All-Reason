-- Disabled in BAR Zombie Defense: individual unit control & RTS command queues are removed;
-- tactical targeting is rendered cleanly by gfx_zdef_laser_sights_gl4.lua (Green Infantry / Blue Armor / Red Aircraft).

function widget:GetInfo()
	return {
		name = "Commands FX",
		desc = "Disabled in BAR Zombie Defense MVP (replaced by GL4 class-coded tactical laser sights)",
		author = "BAR Zombie Defense",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 2,
		enabled = false,
		handler = true,
	}
end

function widget:Initialize()
	if widgetHandler and widgetHandler.RemoveWidget then
		widgetHandler:RemoveWidget(self)
	end
end
