function widget:GetInfo()
  return {
    name      = "Cheater",
    desc      = "Cheats enabler",
    author    = "ivand",
    date      = "2017",
    license   = "GNU LGPL, v2.1 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

local gf

function widget:Initialize()
	local enable = (not Spring.IsCheatingEnabled()) and string.find(string.upper(Game.gameVersion), "$VERSION")
	if enable then
		widgetHandler:UpdateCallIn('GameFrame');
	else
		widgetHandler:RemoveCallIn('GameFrame');
	end
	gf = Spring.GetGameFrame()
end

function widget:GameFrame(f)
	if f > gf then
		Spring.SendCommands("say !cheats")
		Spring.SendCommands("say !hostsay /globallos")
		Spring.SendCommands("say !hostsay /godmode")
		--Spring.SendCommands("say !hostsay /nocost")

		Spring.SendCommands("cheat")
		Spring.SendCommands("globallos")
		Spring.SendCommands("godmode")
		--Spring.SendCommands("nocost")

		widgetHandler:RemoveCallIn('GameFrame');
	end
end