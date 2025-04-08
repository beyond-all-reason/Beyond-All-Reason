-- This widget simulates behavior from OTA where scrolling down with mouse
-- brings to megamap (overview camera).
-- Scrolling up restores previous camera

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Scrolldown Toggleoverview",
		desc = "Simulates TAs toggle megamap on scroll down/up",
		author = "badosu",
		date = "Jan 2, 2023",
		license = "GPL2+",
		layer = 999999 + 1, -- one layer above widget selector
		enabled = false
	}
end

function widget:MouseWheel(up)
	local alt, ctrl, meta, shift = Spring.GetModKeyState()

	if alt or ctrl or meta or shift then return end

	local camState = Spring.GetCameraState()
	local isOverview = camState.name == "ov"

	if Spring.GetConfigInt("ScrollWheelSpeed", 1) > 0 then
		up = not up
	end

	if up then
		if isOverview then Spring.SendCommands({ "toggleoverview" }) end

		return true
	end

	if not isOverview then Spring.SendCommands({ "toggleoverview" }) end

	return true
end
