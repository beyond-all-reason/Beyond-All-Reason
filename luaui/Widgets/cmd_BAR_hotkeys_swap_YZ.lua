function widget:GetInfo()
	return {
		name = "BAR Hotkeys - swap YZ",
		desc = "Swaps Y and Z in BAR Hotkeys widget" ,
		author = "Beherith",
		date = "23 march 2012",
		license = "GNU LGPL, v2.1 or later",
		layer = 100, --should load AFTER BAR hotkeys
		enabled = false
	}
end

function widget:Initialize()
	Spring.SetConfigString("KeyboardLayout", "qwertz")
	if WG.reloadBindings then WG.reloadBindings() end
	widgetHandler:RemoveWidget()
end
