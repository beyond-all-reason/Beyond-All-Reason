if not Spring.Utilities.IsDevMode() then
	return
end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Dev Auto cheat",
		desc = "Enables cheats for $VERSION game versions",
		author = "ivand",
		date = "2017",
		license = "GNU LGPL, v2.1 or later",
		layer = 0,
		enabled = false,
	}
end

function widget:Update(f)
	local modOpts = Engine.Shared.GetModOptions()
	if modOpts ~= nil and modOpts.scenariooptions ~= nil then
		widgetHandler:RemoveCallIn("Update")
		return
	end
	if not Engine.Shared.IsCheatingEnabled() then
		Engine.Unsynced.SendCommands("say !cheats")
		Engine.Unsynced.SendCommands("say !hostsay /globallos")
		Engine.Unsynced.SendCommands("say !hostsay /godmode")
		--Spring.SendCommands("say !hostsay /nocost")

		Engine.Unsynced.SendCommands("cheat")
		Engine.Unsynced.SendCommands("globallos")
		Engine.Unsynced.SendCommands("godmode")
		--Spring.SendCommands("nocost")
	end
	widgetHandler:RemoveCallIn("Update")
end
