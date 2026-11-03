local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Extractor Snap (mex/geo)",
		desc = "Snaps extractors to give nearest spot",
		author = "Hobo Joe, based on work by Niobium and Floris",
		version = "v1.0",
		date = "Jan 2024",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end

-- Localized functions for performance
local mathAbs = math.abs

include("keysym.h.lua")

local spGetActiveCommand = Spring.GetActiveCommand
local spGetMouseState = Spring.GetMouseState
local spGetMouseCursor = Spring.GetMouseCursor
local spGetModKeyState = Spring.GetModKeyState
local spGetBuildFacing = Spring.GetBuildFacing
local spTraceScreenRay = Spring.TraceScreenRay
local spPos2BuildPos = Spring.Pos2BuildPos

local mexConstructors
local geoConstructors
local mexBuildings
local geoBuildings

local selectedMex
local selectedGeo
local targetPos
local cursorPos
local cursorPoint = {}
local buildCmd = {}
local unitShape
local unitShapeData = {}
local activeUnitShape
local metalMap = false
local metalSpots = {}
local geoSpots = {}

local isPregame = Spring.GetGameFrame() == 0 and not Spring.GetSpectatingState()

-- the cursor as last drawn (DrawScreenPost)
local shownCursor

---Over the world the active command's cursor shows. The engine shows "cursornormal" over IsAbove widgets
---(the PIP), and HUD panels set it over themselves in DrawScreen. Pregame has no command cursor to compare.
local function overInterface()
	return spGetMouseCursor() == "cursornormal" or shownCursor == "cursornormal"
end

local function MakeLine(x1, y1, z1, x2, y2, z2)
	gl.Vertex(x1, y1, z1)
	gl.Vertex(x2, y2, z2)
end

function widget:Initialize()
	if not WG.DrawUnitShapeGL4 then
		widgetHandler:RemoveWidget()
		return
	end

	if not WG.resource_spot_builder or not WG.resource_spot_finder then
		Spring.Echo("Extractor Snap: the mex/geo resource spot API is missing, disabling")
		widgetHandler:RemoveWidget()
		return
	end

	WG.ExtractorSnap = {}
	local builder = WG.resource_spot_builder

	mexConstructors = builder.GetMexConstructors()
	geoConstructors = builder.GetGeoConstructors()

	mexBuildings = builder.GetMexBuildings()
	geoBuildings = builder.GetGeoBuildings()

	geoSpots = WG.resource_spot_finder.geoSpotsList
	metalSpots = WG.resource_spot_finder.metalSpotsList
	metalMap = WG.resource_spot_finder.isMetalMap
end

function widget:GameStart()
	isPregame = false
end

local function clear()
	if activeUnitShape then
		WG.StopDrawUnitShapeGL4(activeUnitShape)
		activeUnitShape = nil
	end
	cursorPos = nil
	unitShape = nil
	selectedMex = nil
	selectedGeo = nil
	WG.ExtractorSnap.position = nil
	buildCmd[1] = nil
end

-- Footprint half sizes, read from UnitDefs once per def
local halfSizeX, halfSizeZ = {}, {}

-- local building test functions taken from pregame_build
local function getBuildingDimensions(uDefID, facing)
	local sizeX = halfSizeX[uDefID]
	if not sizeX then
		local bDef = UnitDefs[uDefID]
		if not bDef then
			return
		end
		sizeX = 4 * bDef.xsize
		halfSizeX[uDefID] = sizeX
		halfSizeZ[uDefID] = 4 * bDef.zsize
	end
	if facing % 2 == 1 then
		return halfSizeZ[uDefID], sizeX
	end
	return sizeX, halfSizeZ[uDefID]
end

---If position of the active blueprint is an extractor, the snap behavior of this widget will be
---disabled to allow cancelling queue actions the same way other buildings would.
---@param uid number unitDefID
---@param x number
---@param z number
local function clashesWithBuildQueue(uid, x, z)
	local w1, h1 = getBuildingDimensions(uid, spGetBuildFacing())
	local count, defs, xs, zs, facings = WG.resource_spot_builder.GetSelectedBuildQueue()
	for i = 1, count do
		local facing = facings[i]
		if facing then
			local w2, h2 = getBuildingDimensions(defs[i], facing)
			if w2 and mathAbs(x - xs[i]) < w1 + w2 and mathAbs(z - zs[i]) < h1 + h2 then
				return true
			end
		end
	end
	return false
end

function widget:Update()
	local activeCmdID
	selectedMex = nil
	selectedGeo = nil

	if isPregame then
		activeCmdID = WG["pregame-build"] and WG["pregame-build"].getPreGameDefID()
		if activeCmdID then
			activeCmdID = -activeCmdID
		end
	else
		_, activeCmdID = spGetActiveCommand()
	end

	if not activeCmdID then
		clear()
		return
	end

	if mexBuildings[-activeCmdID] then
		selectedMex = -activeCmdID
	end
	if geoBuildings[-activeCmdID] then
		selectedGeo = -activeCmdID
	end

	if not (selectedMex or selectedGeo) then
		clear()
		return
	end

	if selectedMex and metalMap then -- no snapping on metal maps
		clear()
		return
	end

	if not isPregame and overInterface() then
		clear()
		return
	end

	-- Attempt to get position of command (through the minimap: the spot it shows there)
	local buildingId = -activeCmdID
	local mx, my = spGetMouseState()
	local _, _, _, shift = spGetModKeyState()
	local _, pos = spTraceScreenRay(mx, my, true, true)
	if not pos or not pos[1] then
		clear()
		return
	end
	local x, y, z = pos[1], pos[2], pos[3]
	cursorPos = cursorPoint
	cursorPos.x, cursorPos.y, cursorPos.z = spPos2BuildPos(buildingId, x, y, z)

	-- check if there is stuff in the way - if there is we change behavior (in pregame only with shift held)
	if (shift or not isPregame) and clashesWithBuildQueue(buildingId, cursorPos.x, cursorPos.z) then
		clear()
		return
	end

	local isMetalExtractor = selectedMex ~= nil
	local spotsToSearch = isMetalExtractor and metalSpots or geoSpots
	local selectedExtractor = isMetalExtractor and selectedMex or selectedGeo
	local buildingsToCheck = isMetalExtractor and mexBuildings or geoBuildings

	if WG.skip_allied_upgrade then
		spotsToSearch = WG.skip_allied_upgrade.filterOutAlliedSpots(spotsToSearch, buildingsToCheck)
	end

	local shouldIgnoreAlreadyQueuedUpSpots = shift
	local nearestSpot = WG.resource_spot_builder.FindNearestValidSpotForExtractor(
		x,
		z,
		spotsToSearch,
		selectedExtractor,
		shouldIgnoreAlreadyQueuedUpSpots
	)

	if not nearestSpot then
		clear()
		return
	end

	buildCmd[1] = nil
	local cmd = WG.resource_spot_builder.PreviewExtractorCommand(pos, buildingId, nearestSpot)
	if cmd and #cmd > 0 then
		-- a new table only when the target moves, other widgets may hold on to it
		if not targetPos or targetPos.x ~= cmd[2] or targetPos.y ~= cmd[3] or targetPos.z ~= cmd[4] then
			targetPos = { x = cmd[2], y = cmd[3], z = cmd[4] }
		end
		WG.ExtractorSnap.position = targetPos -- used by prospector and pregame queue

		local dist =
			math.distance3dSquared(cursorPos.x, cursorPos.y, cursorPos.z, targetPos.x, targetPos.y, targetPos.z)
		if dist < 1 then
			clear()
			WG.ExtractorSnap.position = targetPos --bit of a hack, this still needs to be set during pregame
			return
		end

		buildCmd[1] = cmd
		local unitDefID = mathAbs(buildingId)
		-- redraw the ghost when its building, position, facing or owner changes
		if
			unitShape
			and (
				unitShape[1] ~= unitDefID
				or unitShape[2] ~= cmd[2]
				or unitShape[3] ~= cmd[3]
				or unitShape[4] ~= cmd[4]
				or unitShape[5] ~= cmd[5]
				or unitShape[6] ~= cmd[6]
			)
		then
			if WG.StopDrawUnitShapeGL4 then
				WG.StopDrawUnitShapeGL4(activeUnitShape)
			end
			activeUnitShape = nil
		end
		unitShape = unitShapeData
		unitShape[1], unitShape[2], unitShape[3], unitShape[4], unitShape[5], unitShape[6] =
			unitDefID, cmd[2], cmd[3], cmd[4], cmd[5], cmd[6]
	else
		clear()
	end

	-- Draw ghost
	if WG.DrawUnitShapeGL4 then
		if unitShape then
			if not activeUnitShape and WG.DrawUnitShapeGL4 then
				activeUnitShape = WG.DrawUnitShapeGL4(
					unitShape[1],
					unitShape[2],
					unitShape[3],
					unitShape[4],
					unitShape[5] * (math.pi / 2),
					0.66,
					unitShape[6],
					0.15,
					0.3
				)
			end
		elseif activeUnitShape then
			clear()
		end
	end
end

-- Since mex snap bypasses normal building behavior, we have to hand hold gridmenu a little bit
local endShift = false
local function handleBuildMenu(shift)
	endShift = shift
	if not shift then
		Spring.SetActiveCommand(0)
	end
	local grid = WG.gridmenu
	if not grid or not grid.clearCategory or not grid.getAlwaysReturn or not grid.setCurrentCategory then
		return
	end

	if not shift and not grid.getAlwaysReturn() then
		grid.clearCategory()
	elseif grid.getAlwaysReturn() then
		grid.setCurrentCategory(nil)
	end
end

function widget:MousePress(x, y, button)
	if isPregame then
		return
	end

	if button == 1 and buildCmd[1] and not overInterface() then
		local _, _, _, shift = spGetModKeyState()
		shift = Spring.GetInvertQueueKey() and not shift or shift
		if selectedMex then
			WG.resource_spot_builder.ApplyPreviewCmds(buildCmd, mexConstructors, shift)
			handleBuildMenu(shift)
			return true
		end
		if selectedGeo then
			WG.resource_spot_builder.ApplyPreviewCmds(buildCmd, geoConstructors, shift)
			handleBuildMenu(shift)
			return true -- override other mouse presses and handle stuff manually
		end
	end
end

-- I really hate that I have to do this, but something is hardcoding shift behavior with mouse clicks, and I need to override it
function widget:KeyRelease(code)
	if endShift and (code == KEYSYMS.LSHIFT or code == KEYSYMS.RSHIFT) then
		Spring.SetActiveCommand(0)
		endShift = false
	end
end

function widget:DrawScreenPost()
	shownCursor = spGetMouseCursor()
end

function widget:DrawWorld()
	if not WG.DrawUnitShapeGL4 or not targetPos or not cursorPos then
		return
	end

	-- Draw line
	gl.DepthTest(false)
	gl.LineWidth(2)
	gl.Color(1, 1, 0, 0.45)
	gl.BeginEnd(GL.LINE_STRIP, MakeLine, cursorPos.x, cursorPos.y, cursorPos.z, targetPos.x, targetPos.y, targetPos.z)
	gl.LineWidth(1.0)
	gl.DepthTest(true)
end

function widget:Shutdown()
	if not WG.DrawUnitShapeGL4 then
		return
	end
	clear()
end
