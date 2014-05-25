
function widget:GetInfo()
	return {
		name      = "Dummy Script.LuaUI",
		desc      = "Inserts dummy Script.LuaUI calls to prevent engine thinking unattached ones are errors",
		author    = "Bluestone",
		version   = "",
		date      = "",
		license   = "Horses",
		layer     = 0,
		enabled   = true
	}
end

function widget:Initialize()
	widgetHandler:RegisterGlobal('PlayerReadyStateChanged', PlayerReadyStateChanged)
end 

function PlayerReadyStateChanged()
	--moo
end