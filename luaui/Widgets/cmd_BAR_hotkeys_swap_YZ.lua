function widget:GetInfo()
	return {
		name = "BAR Hotkeys -- swap YZ",
		desc = "Swaps Y and Z in BAR Hotkeys widget" ,
		author = "Beherith",
		date = "23 march 2012",
		license = "GNU LGPL, v2.1 or later",
		layer = 100, --should load AFTER BAR hotkeys
		enabled = false
	}
end

function widget:Initialize()
    if WG.Reload_BAR_Hotkeys then
        WG.swapYZbinds = true
        WG.Reload_BAR_Hotkeys()
    else
        Spring.Echo("BAR Hotkeys widget not found, cannot swap YZ")
        widgetHandler:RemoveWidget(self)
    end
end

function widget:Shutdown()
    WG.swapYZbinds = nil
    if WG.Reload_BAR_Hotkeys then
        WG.Reload_BAR_Hotkeys()
    else
        Spring.Echo("BAR Hotkeys widget not found, cannot swap YZ")
    end
end
