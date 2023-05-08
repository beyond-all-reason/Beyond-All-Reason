
-- Hold 'tab' button for Overview camera
-- Release 'tab' to go back to original view instead zooming into cursor
-- Short 'tab' are ignored

function widget:GetInfo()
	return {
		name = "Overview Camera TAB hold & release",
		desc = "TAB button works as hold & release",
		author = "klakier",
		date = "Maj 8, 2023",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true
	}
end

include("keysym.h.lua")

local keyActivate = KEYSYMS.TAB -- hold this button to switch to Overview
local isLongPress = false; -- enabled when user presses tab for longer

local prevCamState = nil;

function widget:KeyPress(key, modifier, isRepeat)
	if key ~= keyActivate then
		return false
	end;

	local camState = Spring.GetCameraState()
	local isOverview = camState.name == "ov"

	if (isOverview and isRepeat) then
		isLongPress = true;
		return true
	else
		prevCamState = camState;
	end

	-- legacy behavior here
	Spring.SendCommands({ "toggleoverview" })
	return true
end

function widget:KeyRelease(key, modifier)
	if key ~= keyActivate then
		return false
	end

	if isLongPress ~= true then
		return false
	end

	local camState = Spring.GetCameraState()
	local isOverview = camState.name == "ov"

	isLongPress = false;

	if prevCamState ~= nil and isOverview then
		Spring.SendCommands({ "toggleoverview" })
		Spring.SetCameraState(prevCamState, 1)
		return true
	end

	return false
end
