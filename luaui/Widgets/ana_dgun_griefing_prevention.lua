local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name    = "DGun Griefing Detection Bridge",
		desc    = "Receives DGun griefing events from LuaRules and forwards them to analytics.",
		author  = "TheDujin, Codex",
		date    = "2026-05-09",
		license = "GNU GPL, v2 or later",
		layer   = -1,
		enabled = true,
	}
end

local USE_WG_ANALYTICS = false -- set false to echo events locally while debugging
local cachedEvents = {}

local function DGunGriefingDetection(eventType, eventData)
	if USE_WG_ANALYTICS then
		cachedEvents[#cachedEvents + 1] = {
			eventType = eventType,
			eventData = eventData,
		}
		return
	end

	Spring.Echo(string.format("[DGunAnalytics] %s %s", eventType, table.toString(eventData)))
end

function widget:GameOver()
	if not USE_WG_ANALYTICS or not WG or not WG.Analytics or not WG.Analytics.SendEvent then
		return
	end

	for i = 1, #cachedEvents do
		local event = cachedEvents[i]
		WG.Analytics.SendEvent(event.eventType, event.eventData)
	end

	cachedEvents = {}
end

function widget:Initialize()
	widgetHandler:RegisterGlobal("DGunGriefingDetection", DGunGriefingDetection)
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal("DGunGriefingDetection")
end
