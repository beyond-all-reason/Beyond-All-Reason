
function widget:GetInfo()
	return {
		name      = "Fix Ctrl groups",
		desc      =  "Unbinds specteam keys to workaround spring bug preventing ctrl groups to work",
		author    = "BD",
		date      = "24 feb 2012",
		license   = "WTFPL",
		layer     = 0,
		enabled   = true  --  loaded by default?
	}
end

function widget:Initialize()
	if Game.version == "85.0" then
		Spring.SendCommands({"unbindaction specteam"})
	end
	widgetHandler:RemoveWidget()
end
