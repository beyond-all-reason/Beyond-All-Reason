function widget:GetInfo()
	return {
		name = "Set Target Hotkeys",
		desc = "Binds y for Set Target and j for Cancel Target" ,
		author = "Bluestone",
		date = "14/05/2013",
		license = "Horses",
		layer = 1,
		enabled = true
	}
end

function widget:Initialize()
	Spring.SendCommands("bind y settarget")
	Spring.SendCommands("bind j canceltarget")
	
	widgetHandler:RemoveWidget(self)
	return
end
