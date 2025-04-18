if not Spring.Utilities.IsDevMode() then
	return
end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Dev Auto cheat",
		desc      = "Enables cheats for $VERSION game versions",
		author    = "ivand",
		date      = "2017",
		license   = "GNU LGPL, v2.1 or later",
		layer     = 0,
		enabled   = false
	}
end

function widget:Update(f)
	if not Spring.IsCheatingEnabled() then
		Spring.SendCommands("say !cheats")
		Spring.SendCommands("say !hostsay /globallos")
		Spring.SendCommands("say !hostsay /godmode")
		--Spring.SendCommands("say !hostsay /nocost")

		Spring.SendCommands("cheat")
		Spring.SendCommands("globallos")
		Spring.SendCommands("godmode")
		--Spring.SendCommands("nocost")
	end
	widgetHandler:RemoveCallIn('Update');
end
