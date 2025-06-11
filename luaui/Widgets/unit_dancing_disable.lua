local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Unit dancing disable",
		desc      = "Disables dancing for increased immersion.",
		author    = "uBdead",
		date      = "Jun, 2025",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = false
	}
end

function widget:Initialize()
	-- Send a lua message to the game engine to disable dancing
	Spring.SendLuaRulesMsg("dancingDisabled")
end

function widget:Shutdown()
	-- Send a lua message to the game engine to re-enable dancing
	Spring.SendLuaRulesMsg("dancingEnabled")
end
