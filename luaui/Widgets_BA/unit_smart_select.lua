--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    unit_smart_select.lua
--  version: 1.36
--  brief:   Selects units as you drag over them and provides selection modifier hotkeys
--  original author: Ryan Hileman (aegis)
--
--  Copyright (C) 2011.
--  Public Domain.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name      = "SmartSelect",
		desc      = "Selects units as you drag over them. (SHIFT: select all, Z: same type, SPACE: new idle units, CTRL: invert selection) /selectionmode toggles filtering buildings in selection",
		author    = "aegis",
		date      = "Jan 2, 2011",
		license   = "Public Domain",
		layer     = 0,
		enabled   = true
	}
end

-----------------------------------------------------------------
-- user config section
-----------------------------------------------------------------

-- whether to select buildings when mobile units are inside selection rectangle
local selectBuildingsWithMobile = false
local includeNanosAsMobile = true

local includeBuilders = true

-- only select new units identical to those already selected
local sameSelectKey = 'z'

-- only select new idle units
local idleSelectKey = 'space'

-----------------------------------------------------------------
-- manually generated locals because I don't have trepan's script
-----------------------------------------------------------------
local GetTimer = Spring.GetTimer
local GetMouseState = Spring.GetMouseState
local GetModKeyState = Spring.GetModKeyState
local GetKeyState = Spring.GetKeyState

local TraceScreenRay = Spring.TraceScreenRay
local WorldToScreenCoords = Spring.WorldToScreenCoords

local GetMyTeamID = Spring.GetMyTeamID
local GetMyPlayerID = Spring.GetMyPlayerID
local GetPlayerInfo = Spring.GetPlayerInfo
local GetTeamUnits = Spring.GetTeamUnits
local GetAllUnits = Spring.GetAllUnits
local GetSelectedUnits = Spring.GetSelectedUnits
local GetUnitsInRectangle = Spring.GetUnitsInRectangle
local SelectUnitArray = Spring.SelectUnitArray
local GetActiveCommand = Spring.GetActiveCommand
local GetUnitTeam = Spring.GetUnitTeam

local GetGroundHeight = Spring.GetGroundHeight
local GetMiniMapGeometry = Spring.GetMiniMapGeometry
local IsAboveMiniMap = Spring.IsAboveMiniMap

local GetUnitDefID = Spring.GetUnitDefID
local GetUnitPosition = Spring.GetUnitPosition
local GetUnitCommands = Spring.GetUnitCommands

local UnitDefs = UnitDefs
local min = math.min
local max = math.max

local glColor = gl.Color
local glVertex = gl.Vertex
local glLineWidth = gl.LineWidth
local glDepthTest = gl.DepthTest
local glBeginEnd = gl.BeginEnd
local GL_LINE_STRIP = GL.LINE_STRIP

local GaiaTeamID  = Spring.GetGaiaTeamID()

-----------------------------------------------------------------
-- end function locals ------------------------------------------
-----------------------------------------------------------------

sameSelectKey = Spring.GetKeyCode(sameSelectKey)
idleSelectKey = Spring.GetKeyCode(idleSelectKey)
local minimapOnLeft = (Spring.GetMiniMapDualScreen() == "left")

local combatFilter, builderFilter, buildingFilter, mobileFilter

local referenceCoords
local referenceScreenCoords
local referenceSelection
local referenceSelectionTypes
local lastSelection
local minimapRect

local lastCoords
local lastMeta
local filtered

local myPlayerID

local function sort(v1, v2)
	if v1 > v2 then
		return v2, v1
	else
		return v1, v2
	end
end


local mapWidth, mapHeight = Game.mapSizeX, Game.mapSizeZ
local function MinimapToWorldCoords(x, y)
	px, py, sx, sy = GetMiniMapGeometry()
	local plx = 0
	if (minimapOnLeft) then plx = sx end

	x = ((x - px + plx) / sx) * mapWidth
	local z = (1 - ((y - py) / sy)) * mapHeight
	y = GetGroundHeight(x, z)
	return x, y, z
end

local function GetUnitsInMinimapRectangle(x1, y1, x2, y2, team)
	left, _, top = MinimapToWorldCoords(x1, y1)
	right, _, bottom = MinimapToWorldCoords(x2, y2)

	local left, right = sort(left, right)
	local bottom, top = sort(bottom, top)

	minimapRect = {left, bottom, right, top}
	return GetUnitsInRectangle(left, bottom, right, top, team)
end

local function GetUnitsInScreenRectangle(x1, y1, x2, y2, team)
	local units
	if (team) then
		units = GetTeamUnits(team)
	else
		units = GetAllUnits()
	end
	
	local left, right = sort(x1, x2)
	local bottom, top = sort(y1, y2)

	local result = {}

	for i=1, #units do
		local uid = units[i]
		x, y, z = GetUnitPosition(uid)
		x, y = WorldToScreenCoords(x, y, z)
		if (left <= x and x <= right) and (top >= y and y >= bottom) then
			result[#result+1] = uid
		end
	end
	return result
end

function widget:MousePress(x, y, button)
	if (button == 1) then
		referenceSelection = GetSelectedUnits()
		referenceSelectionTypes = {}
		for i=1, #referenceSelection do
			udid = GetUnitDefID(referenceSelection[i])
			if udid then
				referenceSelectionTypes[udid] = 1
			end
		end
		referenceScreenCoords = {x, y}
		lastMeta = nil
		lastSelection = nil
		filtered = false

		if (IsAboveMiniMap(x, y)) then
			referenceCoords = {0, 0, 0}
			lastCoords = {0, 0, 0}
		else
			local _, c = TraceScreenRay(x, y, true, false, true)

			referenceCoords = c
			lastCoords = c
		end
	end
end

function widget:TextCommand(command)
    if (string.find(command, "selectionmode") == 1  and  string.len(command) == 13) then 
		selectBuildingsWithMobile = not selectBuildingsWithMobile
		if selectBuildingsWithMobile then
			Spring.Echo("SmartSelect: Selects whatever comes under selection rectangle.")
		else
			Spring.Echo("SmartSelect: Ignores buildings if it can select mobile units.")
		end
	end
    if (string.find(command, "selectionnanos") == 1  and  string.len(command) == 14) then 
		includeNanosAsMobile = not includeNanosAsMobile
		init()
		if includeNanosAsMobile then
			Spring.Echo("SmartSelect: Treats nanos like mobile units and wont exclude them")
		else
			Spring.Echo("SmartSelect: Stops treating nanos as if they are mobile units")
		end
	end
end

function widget:GetConfigData(data)
    savedTable = {}
    savedTable.selectBuildingsWithMobile = selectBuildingsWithMobile
    savedTable.includeNanosAsMobile = includeNanosAsMobile
	savedTable.includeBuilders = includeBuilders
    return savedTable
end

function widget:SetConfigData(data)
    if data.selectBuildingsWithMobile ~= nil 	then  selectBuildingsWithMobile	= data.selectBuildingsWithMobile end
	if data.includeNanosAsMobile ~= nil 	then  includeNanosAsMobile	= data.includeNanosAsMobile end
	if data.includeBuilders ~= nil 	then  includeBuilders	= data.includeBuilders end
end


function widget:Update()
	--[[
	local newUpdate = GetTimer()
	if (DiffTimers(newUpdate, lastUpdate) < 0.1) then
		return
	end
	lastUpdate = newUpdate
	--]]

	if (referenceCoords ~= nil and GetActiveCommand() == 0) then
		x, y, pressed = GetMouseState()
		local px, py, sx, sy = GetMiniMapGeometry()
		
		if (pressed) and (referenceSelection ~= nil) then
			local alt, ctrl, meta, shift = GetModKeyState()
			if (#referenceSelection == 0) then
				-- no point in inverting an empty selection
				ctrl = false
			end

			local sameSelect = GetKeyState(sameSelectKey)
			local idleSelect = GetKeyState(idleSelectKey)
			
			local sameLast = (referenceScreenCoords ~= nil) and (x == referenceScreenCoords[1] and y == referenceScreenCoords[2])
			if (sameLast and lastCoords == referenceCoords) then
				return
			end

			if sameLast and (lastMeta ~= nil) and (alt == lastMeta[1] and ctrl == lastMeta[2]
						and meta == lastMeta[3] and shift == lastMeta[4])
				then return end

			lastCoords = {x, y}
			lastMeta = {alt, ctrl, meta, shift}

			local mouseSelection, originalMouseSelection
			local r = referenceScreenCoords
			local playing = GetPlayerInfo(myPlayerID).spectating == false
			local team = (playing and GetMyTeamID())
			if (r ~= nil and IsAboveMiniMap(r[1], r[2])) then
				local mx, my = max(px, min(px+sx, x)), max(py, min(py+sy, y))
				mouseSelection = GetUnitsInMinimapRectangle(r[1], r[2], x, y, nil)
			else
				local d = referenceCoords
				local x1, y1 = WorldToScreenCoords(d[1], d[2], d[3])
				mouseSelection = GetUnitsInScreenRectangle(x, y, x1, y1, nil)
			end
			originalMouseSelection = mouseSelection

			
			-- filter gaia units
			local filteredselection = {}
			local filteredselectionCount = 0
			for i=1, #mouseSelection do
				if GetUnitTeam(mouseSelection[i]) ~= GaiaTeamID then
					filteredselectionCount = filteredselectionCount + 1
					filteredselection[filteredselectionCount] = mouseSelection[i]
				end
			end
			mouseSelection = filteredselection
			filteredselection = nil
			
			local newSelection = {}
			local uid, udid, udef, tmp

			if (idleSelect) then
				tmp = {}
				for i=1, #mouseSelection do
					uid = mouseSelection[i]
					udid = GetUnitDefID(uid)
					if (mobileFilter[udid] or builderFilter[udid]) and (#GetUnitCommands(uid, 1) == 0) then
						tmp[#tmp+1] = uid
					end
				end
				mouseSelection = tmp
			end

			if (sameSelect) and (#referenceSelection > 0) then
				-- only select new units identical to those already selected
				tmp = {}
				for i=1, #mouseSelection do
					uid = mouseSelection[i]
					udid = GetUnitDefID(uid)
					if (referenceSelectionTypes[udid] ~= nil) then
						tmp[#tmp+1] = uid
					end
				end
				mouseSelection = tmp
			end


			if (alt) then
				-- only select mobile combat units

				if (ctrl == false) then
					tmp = {}
					for i=1, #referenceSelection do
						uid = referenceSelection[i]
						udid = GetUnitDefID(uid)
						if (combatFilter[udid]) then -- is a combat unit
							tmp[#tmp+1] = uid
						end
					end
					newSelection = tmp
				end

				tmp = {}
				for i=1, #mouseSelection do
					uid = mouseSelection[i]
					udid = GetUnitDefID(uid)
					if (combatFilter[udid]) then -- is a combat unit
						tmp[#tmp+1] = uid
					end
				end
				mouseSelection = tmp
			elseif (selectBuildingsWithMobile == false) and (shift == false) and (ctrl == false) then
				-- only select mobile units, not buildings
				local mobiles = false
				for i=1, #mouseSelection do
					uid = mouseSelection[i]
					udid = GetUnitDefID(uid)
					if (mobileFilter[udid]) then
						mobiles = true
						break
					end
				end

				if (mobiles) then
					tmp = {}
					local tmp2 = {}
					for i=1, #mouseSelection do
						uid = mouseSelection[i]
						udid = GetUnitDefID(uid)
						if (buildingFilter[udid] == false) then
							if (includeBuilders or not builderFilter[udid]) then
								tmp[#tmp+1] = uid
							else
								tmp2[#tmp2+1] = uid
							end
						end
					end
					if #tmp == 0 then
						tmp = tmp2
					end
					mouseSelection = tmp
				end
			end

			if (#newSelection < 1) then
				newSelection = referenceSelection
			end


			if (ctrl) then
				-- deselect units inside the selection rectangle, if we already had units selected
				local negative = {}

				for i=1, #mouseSelection do
					uid = mouseSelection[i]
					negative[uid] = 1
				end

				tmp = {}
				for i=1, #newSelection do
					uid = newSelection[i]
					if (negative[uid] == nil) then
						tmp[#tmp+1] = uid
					end
				end
				newSelection = tmp
				SelectUnitArray(newSelection)
			elseif (shift) then
				-- append units inside selection rectangle to current selection
				SelectUnitArray(newSelection)
				SelectUnitArray(mouseSelection, true)
			elseif (#mouseSelection > 0) then
				-- select units inside selection rectangle
				SelectUnitArray(mouseSelection)
			elseif (#originalMouseSelection > 0) and (#mouseSelection == 0) then
				SelectUnitArray({})
			else
				-- keep current selection while dragging until more things are selected
				SelectUnitArray(referenceSelection)
				lastSelection = nil
				return
			end
			lastSelection = GetSelectedUnits()
		elseif (lastSelection ~= nil) then
			SelectUnitArray(lastSelection)
			lastSelection = nil
			referenceSelection = nil
			referenceSelectionTypes = nil
			referenceCoords = nil
			minimapRect = nil
		else
			referenceSelection = nil
			referenceSelectionTypes = nil
			referenceCoords = nil
			minimapRect = nil
		end
	end
end

function init()
	myPlayerID = GetMyPlayerID()
	combatFilter = {}
	builderFilter = {}
	buildingFilter = {}
	mobileFilter = {}
	
	for udid, udef in pairs(UnitDefs) do
		local mobile = (udef.canMove and udef.speed > 0.000001) or (includeNanosAsMobile and (UnitDefs[udid].name == "armnanotc" or UnitDefs[udid].name == "cornanotc" or UnitDefs[udid].name == "armnanotc_bar" or UnitDefs[udid].name == "cornanotc_bar"))
		local builder = (udef.canReclaim and udef.reclaimSpeed > 0) or
						--(udef.builder and udef.buildSpeed > 0) or					-- udef.builder = deprecated it seems
						(udef.canResurrect and udef.resurrectSpeed > 0) or
						(udef.canRepair and udef.repairSpeed > 0)
		local building = (mobile == false)
		local combat = (builder == false) and (mobile == true) and (#udef.weapons > 0)
		
		combatFilter[udid] = combat
		builderFilter[udid] = builder
		buildingFilter[udid] = building
		mobileFilter[udid] = mobile
	end
end

function widget:Shutdown()
	WG['smartselect'] = nil
end

function widget:Initialize()

  WG['smartselect'] = {}
	WG['smartselect'].getIncludeBuildings = function()
		return selectBuildingsWithMobile
	end
	WG['smartselect'].setIncludeBuildings = function(value)
		selectBuildingsWithMobile = value
	end
	WG['smartselect'].getIncludeBuilders = function()
		return includeBuilders
	end
	WG['smartselect'].setIncludeBuilders = function(value)
		includeBuilders = value
	end
	init()
end

local function DrawRectangle(r)
	local x1, y1, x2, y2 = r[1], r[2], r[3], r[4]
	glVertex(r[1], 0, r[2])
	glVertex(r[1], 0, r[4])
	glVertex(r[3], 0, r[4])
	glVertex(r[3], 0, r[2])
	glVertex(r[1], 0, r[2])
end

function widget:DrawWorld()
	if (minimapRect ~= nil) then
		glColor(1, 1, 1, 1)
		glLineWidth(1.0)
		glDepthTest(false)
		glBeginEnd(GL_LINE_STRIP, DrawRectangle, minimapRect)
	end
end
