
-- Hold 'tab' button for Overview camera
-- Release 'tab' to go back to original view instead zooming into cursor
-- Short 'tab' are ignored

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Overview Camera TAB hold & release",
		desc = "TAB button works as hold & release",
		author = "klakier",
		date = "May 8, 2023",
		license = "GNU GPL, v2 or later",
		layer = -9999999,
		enabled = true
	}
end


local keyConfig = VFS.Include("luaui/configs/keyboard_layouts.lua")
local camKeys = {} -- list of buttons that switch to Overview
local isLongPress = false -- enabled when user presses tab for longer
local prevCamState = nil


local function setActionHotkeys(action)
	camKeys = {}
	local keyTable = Spring.GetActionHotKeys(action)
	for _, key in pairs(keyTable) do
		local btn = keyConfig.sanitizeKey(key):upper()
		table.insert(camKeys, btn)
	end
end

-- works only with single key binds
local function isCamKey(keyNum)
	local pressedSymbol = Spring.GetKeySymbol(keyNum):upper()
	for _, symbol in pairs(camKeys) do
		if pressedSymbol == symbol then
			return true
		end
	end
	return false
end

function widget:Initialize()
	setActionHotkeys("toggleoverview")
end

function widget:KeyPress(key, modifier, isRepeat)
	if not isCamKey(key) then
		return false
	end

	local camState = Spring.GetCameraState()
	local isOverview = camState.name == "ov"

	if isOverview and isRepeat then
		isLongPress = true
		return true
	else
		prevCamState = camState
	end

	-- legacy behavior here
	return false
end

function widget:KeyRelease(key, modifier)
	if not isCamKey(key) then
		return false
	end

	if isLongPress ~= true then
		return false
	end

	local camState = Spring.GetCameraState()
	local isOverview = camState.name == "ov"

	isLongPress = false

	if prevCamState ~= nil and isOverview then
		Spring.SendCommands({ "toggleoverview" })
		Spring.SetCameraState(prevCamState, 1)
		return true
	end

	return false
end
