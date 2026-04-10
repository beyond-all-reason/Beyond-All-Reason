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
	if not SpringShared.IsCheatingEnabled() then
		SpringUnsynced.SendCommands("say !cheats")
		SpringUnsynced.SendCommands("say !hostsay /globallos")
		SpringUnsynced.SendCommands("say !hostsay /godmode")
		--Spring.SendCommands("say !hostsay /nocost")

		SpringUnsynced.SendCommands("cheat")
		SpringUnsynced.SendCommands("globallos")
		SpringUnsynced.SendCommands("godmode")
		--Spring.SendCommands("nocost")
	end
	widgetHandler:RemoveCallIn('Update');
end
