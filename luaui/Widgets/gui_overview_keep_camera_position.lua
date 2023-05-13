
-- When the overview closes, the camera returns to its previous position

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
local prevCamState = nil;


local function storeCamKeys()
	camKeys = {}
	local keyTable = Spring.GetActionHotKeys("toggleoverview")
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
	storeCamKeys()
end

function widget:KeyPress(key, modifier)
	if not isCamKey(key) then
		return
	end

	local camState = Spring.GetCameraState()
	local isOverview = camState.name == "ov"


	if not isOverview then
		-- Entering overview
		prevCamState = camState;
		return
	else
		-- Leaving overview
		Spring.SetCameraState(prevCamState, 1)
	end
end
