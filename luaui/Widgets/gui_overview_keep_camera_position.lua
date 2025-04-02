
-- When tabbing out of the overview, the camera DOES NOT "zoom-to-cursor"
-- When scrolling out of the overiew, the camera DOES "zoom-to-cursor"

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Overview Camera Keep Position",
		desc = "When the overview closes, the camera returns to its previous position",
		author = "FlexTerror",
		date = "May 13, 2023",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true
	}
end

local keyConfig = VFS.Include("luaui/configs/keyboard_layouts.lua")
local camKeys = {} -- list of buttons that switch to Overview
local prevCamState

local function storeCamKeys()
	camKeys = {}
	local keyTable = Spring.GetActionHotKeys("toggleoverview")
	for _, key in pairs(keyTable) do
		local btn = keyConfig.sanitizeKey(key):upper()
		table.insert(camKeys, btn)
	end
end

function widget:Initialize()
	storeCamKeys()
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

local function isOverview()
	return Spring.GetCameraState().name == "ov"
end


function widget:MouseWheel(up, value)
	if isOverview() and up then
		Spring.SendCommands({ "toggleoverview" })
		return true;
	end

	return false
end

function widget:KeyPress(key, modifier)
	if not isCamKey(key) then return end
	if isOverview() then
		if prevCamState ~= nil then
			Spring.SetCameraState(prevCamState, 1)
		end
	else
		prevCamState = Spring.GetCameraState()
	end
end

