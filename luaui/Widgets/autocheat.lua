if not Spring.Utilities.IsDevMode() then
	return
end

function widget:GetInfo()
	return {
		name      = "Auto cheat",
		desc      = "Enables cheats for $VERSION game versions",
		author    = "ivand",
		date      = "2017",
		license   = "GNU LGPL, v2.1 or later",
		layer     = 0,
		enabled   = false
	}
end

local gf = Spring.GetGameFrame()

function widget:Initialize()
	local enable = (not Spring.IsCheatingEnabled())
	if enable then
		widgetHandler:UpdateCallIn('GameFrame');
	else
		widgetHandler:RemoveCallIn('GameFrame');
	end
end

function widget:GameFrame(f)
	if f > gf then
		if not Spring.IsCheatingEnabled() and not Spring.IsReplay() then 
			Spring.SendCommands("say !cheats")
			Spring.SendCommands("say !hostsay /globallos")
			Spring.SendCommands("say !hostsay /godmode")
			--Spring.SendCommands("say !hostsay /nocost")

			Spring.SendCommands("cheat")
			Spring.SendCommands("globallos")
			Spring.SendCommands("godmode")
			--Spring.SendCommands("nocost")
		end

		widgetHandler:RemoveCallIn('GameFrame');
	end
end
