local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Test Runner Watchdog",
		desc = "Quits game if test runner exits",
		license = "GNU GPL, v2 or later",
		layer = 9999,
		enabled = false,
		handler = true,
	}
end

if not Spring.Utilities.IsDevMode() or not Spring.Utilities.Gametype.IsSinglePlayer() then
	return
end

local CHECK_PERIOD = 1
local t = 0
function widget:Update(dt)
	t = t + dt
	if t > CHECK_PERIOD then
		t = 0
		if widgetHandler:FindWidget("Test Runner") == nil then
			Spring.Log(widget:GetInfo().name, LOG.WARNING, "Test runner crashed, exiting game")
			widgetHandler:DisableWidget(widget:GetInfo().name)
			Spring.SendCommands("quitforce")
		end
	end
end
