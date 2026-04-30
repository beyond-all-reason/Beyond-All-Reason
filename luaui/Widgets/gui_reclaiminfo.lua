--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    gui_ReclaimInfo.lua
--  brief:   Shows the amount of metal/energy when using area reclaim.
--  original author:  Janis Lukss
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "ReclaimInfo",
		desc = "Shows the amount of metal/energy when using area reclaim.",
		author = "Pendrokar",
		date = "Nov 17, 2007",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-- Localized functions for performance
local mathFloor = math.floor
local mathSqrt = math.sqrt

-- Localized Spring API for performance
local spGetUnitDefID = Spring.GetUnitDefID
local spTraceScreenRay = Spring.TraceScreenRay
local spGetActiveCommand = Spring.GetActiveCommand
local spGetMouseState = Spring.GetMouseState
local spGetMouseCursor = Spring.GetMouseCursor
local spGetFeaturesInCylinder = Spring.GetFeaturesInCylinder
local spGetFeatureResources = Spring.GetFeatureResources
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetMiniMapGeometry = Spring.GetMiniMapGeometry
local spGetGroundHeight = Spring.GetGroundHeight
local spI18N = I18N

local start = false --reclaim area cylinder drawing has been started
local metal = 0 --metal count from features in cylinder
local energy = 0 --energy count from features in cylinder
local nonground = "" --if reclaim order done with right click on a feature or unit
local rangestart = { 0, 0, 0 } --counting start center
local rangestartinminimap = false --both start and end need to be equaly checked
local rangeend = {} --counting radius end point
local b1was = false -- cursor was outside the map?
local vsx, vsy = widgetHandler:GetViewSizes()
local form = 12 --text format depends on screen size
local xstart, ystart = 0, 0
local cmd, xend, yend, x, y, b1, b2
local font

-- Pre-allocated i18n parameter tables
local metalParams = { metal = 0 }
local energyParams = { energy = 0 }

-- Cache for reclaim text to avoid rebuilding every frame
local cachedMetal = -1
local cachedEnergy = -1
local cachedAreaText = ""
local cachedUnitMetal = -1
local cachedUnitText = ""
local lastScanX, lastScanY = -1, -1

local isReclaimable = {}
local unitMetalCost = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.reclaimable then
		isReclaimable[unitDefID] = unitDef.reclaimable
	end
	unitMetalCost[unitDefID] = unitDef.metalCost
end

local mapSizeX = Game.mapSizeX
local mapSizeZ = Game.mapSizeZ

function widget:Initialize()
	widget:ViewResize()
end

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()
	font = WG["fonts"].getFont(1, 1.5)
	form = mathFloor(vsx / 87)
end

local minimapPosx, minimapPosy, minimapSizex, minimapSizey, minimapMinimized, minimapMaximized = 0, 0, 1, 1, false, false
local minimapUpdateFrame = 0

local function UpdateMinimapGeometry()
	minimapPosx, minimapPosy, minimapSizex, minimapSizey, minimapMinimized, minimapMaximized = spGetMiniMapGeometry()
end

local function InMinimap(mx, my)
	local rx, ry = (mx - minimapPosx) / minimapSizex, (my - minimapPosy) / minimapSizey
	return (not (minimapMinimized or minimapMaximized)) and (rx >= 0) and (rx <= 1) and (ry >= 0) and (ry <= 1), rx, ry
end

local function MinimapToWorld(rx, ry)
	if rx >= 0 and rx <= 1 and ry >= 0 and ry <= 1 then
		local mapx, mapz = mapSizeX * rx, mapSizeZ - mapSizeZ * ry
		local mapy = spGetGroundHeight(mapx, mapz)
		return { mapx, mapy, mapz }
	else
		return { -1, -1, -1 }
	end
end

function widget:DrawScreen()
	_, cmd, _ = spGetActiveCommand()
	x, y, b1, _, b2 = spGetMouseState() --b1 = left button pressed?
	nonground = spGetMouseCursor()
	x, y = mathFloor(x), mathFloor(y) --TraceScreenRay needs this

	-- Update minimap geometry infrequently
	minimapUpdateFrame = minimapUpdateFrame + 1
	if minimapUpdateFrame >= 30 then
		minimapUpdateFrame = 0
		UpdateMinimapGeometry()
	end

	if (cmd == CMD.RECLAIM and rangestart ~= nil and b1 and b1was == false) or (nonground == "Reclaim" and b1was == false and b2 and rangestart ~= nil) then
		if rangestart[1] == 0 and rangestart[3] == 0 then
			local inMinimap, rx, ry = InMinimap(x, y)
			if inMinimap then
				rangestart = MinimapToWorld(rx, ry)
				xstart, ystart = x, y
				start = false
				rangestartinminimap = true
			else
				xstart, ystart = x, y
				start = false
				rangestartinminimap = false
				_, rangestart = spTraceScreenRay(x, y, true) --cursor on world pos
			end
		end
	elseif rangestart == nil and b1 then
		b1was = true
	else
		b1was = false
		rangestart[1] = 0
		rangestart[2] = 0
		rangestart[3] = 0
	end
	--bit more precise showing when mouse is moved by 4 pixels (start)
	if (b1 and rangestart ~= nil and cmd == CMD.RECLAIM and start == false) or (nonground == "Reclaim" and rangestart ~= nil and start == false and b2) then
		xend, yend = x, y
		if (xend > xstart + 4 or xend < xstart - 4) or (yend > ystart + 4 or yend < ystart - 4) then
			start = true
		end
	end
	--
	if (b1 and rangestart ~= nil and cmd == CMD.RECLAIM and start) or (nonground == "Reclaim" and start and b2 and rangestart ~= nil) then
		local inMinimap, rx, ry = InMinimap(x, y)
		if inMinimap and rangestartinminimap then
			rangeend = MinimapToWorld(rx, ry)
		else
			_, rangeend = spTraceScreenRay(x, y, true)
		end

		if rangeend == nil then
			return
		end

		-- Only rescan features when mouse position changes
		if x ~= lastScanX or y ~= lastScanY then
			lastScanX, lastScanY = x, y
			metal = 0
			energy = 0
			local rdx, rdy = (rangestart[1] - rangeend[1]), (rangestart[3] - rangeend[3])
			local dist = mathSqrt((rdx * rdx) + (rdy * rdy))
			local features = spGetFeaturesInCylinder(rangestart[1], rangestart[3], dist)
			for i = 1, #features do
				local fm, _, fe = spGetFeatureResources(features[i])
				metal = metal + fm
				energy = energy + fe
			end
			metal = mathFloor(metal)
			energy = mathFloor(energy)
		end

		-- Only rebuild text when values change
		if metal ~= cachedMetal or energy ~= cachedEnergy then
			cachedMetal = metal
			cachedEnergy = energy
			metalParams.metal = metal
			energyParams.energy = energy
			cachedAreaText = "   " .. spI18N("ui.reclaimInfo.metal", metalParams) .. "\255\255\255\128" .. " " .. spI18N("ui.reclaimInfo.energy", energyParams)
		end

		local tx = x
		local ty = y
		local textwidth = 12 * font:GetTextWidth(cachedAreaText)
		if textwidth + tx > vsx then
			tx = tx - textwidth - 10
		end
		if 12 + ty > vsy then
			ty = ty - form
		end
		font:Begin()
		font:SetOutlineColor(0, 0, 0, 0.6)
		font:SetTextColor(1, 1, 1, 1)
		font:Print(cachedAreaText, tx, ty, form, "o")
		font:End()
	else
		-- Reset cache when not dragging
		lastScanX, lastScanY = -1, -1
		cachedMetal = -1
		cachedEnergy = -1
		metal = 0
		energy = 0
	end

	-- Unit resource info when mouse on one
	if nonground == "Reclaim" and rangestart ~= nil and (energy == 0 or metal == 0) and b1 == false then
		local isunit, unitID = spTraceScreenRay(x, y) --if on unit pos!
		if isunit == "unit" and (spGetUnitHealth(unitID)) then
			-- Getunithealth just to make sure that it is in los
			local unitDefID = spGetUnitDefID(unitID)
			local _, buildprogress = spGetUnitIsBeingBuilt(unitID)
			metal = mathFloor(unitMetalCost[unitDefID] * buildprogress)

			-- Only rebuild text when metal value changes
			if metal ~= cachedUnitMetal then
				cachedUnitMetal = metal
				metalParams.metal = metal
				local color = isReclaimable[unitDefID] and "\255\255\255\255" or "\255\220\10\10"
				cachedUnitText = color .. "   " .. spI18N("ui.reclaimInfo.metal", metalParams)
			end

			local tx = x
			local ty = y
			local textwidth = 12 * font:GetTextWidth(cachedUnitText)
			if textwidth + tx > vsx then
				tx = tx - textwidth - 10
			end
			if 12 + ty > vsy then
				ty = ty - form
			end
			font:Begin()
			font:SetOutlineColor(0, 0, 0, 0.5)
			font:SetTextColor(1, 1, 1, 1)
			font:Print(cachedUnitText, tx, ty, form, "o")
			font:End()
		end
	end
end
