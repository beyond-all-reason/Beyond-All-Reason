local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Self-D Resign Analytics Bridge",
		desc = "Receives mass self-D events from LuaRules and forwards them to analytics.",
		author = "Rysica",
		date = "2026-07-17",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

local function SelfDResignAnalytics(eventType, eventData)
	if not WG or not WG.Analytics or not WG.Analytics.SendEvent then
		return
	end
	WG.Analytics.SendEvent(eventType, eventData)
end

function widget:Initialize()
	if Spring.IsReplay() or Spring.GetSpectatingState() then
		widgetHandler:RemoveWidget(self)
		return
	end
	widgetHandler:RegisterGlobal("SelfDResignAnalytics", SelfDResignAnalytics)
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal("SelfDResignAnalytics")
end
