local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Mouse to Mexes",
		desc = "Click to make a mex table. Alt+M to toggle. Works with any game.",
		author = "Google Frog",
		date = "April 28, 2012",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = false
	}
end


-- Localized Spring API for performance
local spEcho = Spring.Echo

include("keysym.h.lua")

local floor = math.floor

------------------------------------------------
-- Variables
------------------------------------------------

local enabled = true
local markers = {}
local mexIndex = 1
local metal = 2.0
local handle

------------------------------------------------
-- Press Handling
------------------------------------------------

function widget:KeyPress(key, modifier, isRepeat)
	if modifier.alt then
		if key == KEYSYMS.M then
			enabled = not enabled
		end
	end
end

local function legalPos(pos)
	return pos and pos[1] > 0 and pos[3] > 0 and pos[1] < Game.mapSizeX and pos[3] < Game.mapSizeZ
end

function widget:MousePress(mx, my, button)
	if enabled and (not Spring.IsAboveMiniMap(mx, my)) then
		local _, pos = Spring.TraceScreenRay(mx, my, true)
		if legalPos(pos) then
			--if true then
				handle:write("[" .. mexIndex .. "] = {x = " .. floor(pos[1] + 0.5) .. ", z = " .. floor(pos[3] + 0.5) .. ", metal = " .. tostring(metal) .. "},\n")
				handle:flush()
				markers[#markers + 1] = { pos[1], 0, pos[3] }
				Spring.MarkerAddPoint(pos[1], 0, pos[3], mexIndex)
				mexIndex = mexIndex + 1
			--else
				-- TODO: make right click remove markers
			--	Spring.MarkerErasePosition(pos[1], 0, pos[3])
			--end
		end
	end
end

function widget:Initialize()
	if not Spring.IsCheatingEnabled() then
		spEcho("This widget requires cheats enabled")
		widgetHandler:RemoveWidget()
		return
	end
	handle = io.open("MexSpots_" .. Game.mapName, "w")
	if (handle == nil) then
		widgetHandler:RemoveWidget()
		return
	end
end

function widget:Shutdown()
	for _, i in pairs(markers) do
		Spring.MarkerErasePosition(i[1], i[2], i[3])
	end
	if handle ~= nil then
		io.close(handle)
		spEcho("Writen Mex Spots To: " .. "MexSpots_" .. Game.mapName)
	end
end
