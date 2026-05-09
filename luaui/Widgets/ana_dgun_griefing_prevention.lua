local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name    = "DGun Griefing Prevention Bridge",
		desc    = "Receives DGun griefing events from LuaRules and forwards them to analytics.",
		author  = "TheDujin, Codex",
		date    = "2026-05-09",
		license = "GNU GPL, v2 or later",
		layer   = -1,
		enabled = true,
	}
end

local USE_WG_ANALYTICS = true -- set false to echo events locally while debugging

local function DGunGriefingPrevention(eventType, eventData)
	if USE_WG_ANALYTICS and WG and WG.Analytics and WG.Analytics.SendEvent then
		WG.Analytics.SendEvent(eventType, eventData)
		return
	end

	Spring.Echo(string.format("[DGunAnalytics] %s %s", eventType, table.toString(eventData)))
end

function widget:Initialize()
	widgetHandler:RegisterGlobal("DGunGriefingPrevention", DGunGriefingPrevention)
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal("DGunGriefingPrevention")
end
