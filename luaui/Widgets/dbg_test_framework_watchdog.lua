function widget:GetInfo()
	return {
		name = "Test Framework Watchdog",
		desc = "Quits game if test runner exits",
		date = "2024",
		license = "GNU GPL, v2 or later",
		version = 0,
		layer = 9999,
		enabled = false,
		handler = true,
	}
end

local CHECK_PERIOD = 1
local t = 0
function widget:Update(dt)
	t = t + dt
	if t > CHECK_PERIOD then
		t = 0
		if widgetHandler:FindWidget("Test Framework Runner") == nil then
			Spring.Log(widget:GetInfo().name, LOG.WARNING, "Test runner crashed, exiting game")
			widgetHandler:DisableWidget(widget:GetInfo().name)
			Spring.SendCommands("quitforce")
		end
	end
end
