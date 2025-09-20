local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Extractor Snap (mex/geo)",
		desc      = "Snaps extractors to give nearest spot",
		author    = "Hobo Joe, based on work by Niobium and Floris",
		version   = "v1.0",
		date      = "Jan 2024",
		license   = "GNU GPL, v2 or later",
		layer     = 1,
		enabled   = true,
	}
end

include("keysym.h.lua")

local spGetActiveCommand = Spring.GetActiveCommand
local spGetMouseState = Spring.GetMouseState
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
local buildCmd
local unitShape
local activeUnitShape
local metalMap = false
local metalSpots = {}
local geoSpots = {}

local isPregame = Spring.GetGameFrame() == 0 and not Spring.GetSpectatingState()

local function MakeLine(x1, y1, z1, x2, y2, z2)
	gl.Vertex(x1, y1, z1)
	gl.Vertex(x2, y2, z2)
end


function widget:Initialize()
	if not WG.DrawUnitShapeGL4 then
		widgetHandler:RemoveWidget()
		return
	end

	WG.ExtractorSnap = {}
	local builder = WG.resource_spot_builder

	mexConstructors = builder.GetMexConstructors()
	geoConstructors = builder.GetGeoConstructors()

	mexBuildings = builder.GetMexBuildings()
	geoBuildings = builder.GetGeoBuildings()

	geoSpots = WG["resource_spot_finder"].geoSpotsList
	metalSpots = WG["resource_spot_finder"].metalSpotsList
	metalMap = WG["resource_spot_finder"].isMetalMap
end


function widget:GameStart()
	isPregame = false
end


local function clear()
	if activeUnitShape then
		WG.StopDrawUnitShapeGL4(activeUnitShape)
		activeUnitShape = nil
	end
	nearestSpot = nil
	cursorPos = nil
	unitShape = nil
	selectedMex = nil
	selectedGeo = nil
	WG.ExtractorSnap.position = nil
	buildCmd = {}
end


---If position of the active blueprint is an extractor, the snap behavior of this widget will be
---disabled to allow cancelling queue actions the same way other buildings would.
---@param uid table unitDefID
---@param pos table position in format { x, y, z }
local function clashesWithBuildQueue(uid, pos)
	local units = Spring.GetSelectedUnits()

	-- local building test functions taken from pregame_build
	local function GetBuildingDimensions(uDefID, facing)
		local bDef = UnitDefs[uDefID]
		if (facing % 2 == 1) then
			return 4 * bDef.zsize, 4 * bDef.xsize
		else
			return 4 * bDef.xsize, 4 * bDef.zsize
		end
	end

	local function DoBuildingsClash(buildData1, buildData2)
		if not buildData1[5] or not buildData2[5] then
			return false
		end
		local w1, h1 = GetBuildingDimensions(buildData1[1], buildData1[5])
		local w2, h2 = GetBuildingDimensions(buildData2[1], buildData2[5])

		return math.abs(buildData1[2] - buildData2[2]) < w1 + w2 and
			math.abs(buildData1[4] - buildData2[4]) < h1 + h2
	end

	local buildFacing = Spring.GetBuildFacing()
	local newBuildData = { uid, pos.x, pos.y, pos.z, buildFacing }
	if isPregame then
		local queue = WG['pregame-build'].getBuildQueue()
		for i = 1, #queue do
			if DoBuildingsClash(newBuildData, queue[i]) then
				return true
			end
		end
	else
		for i = 1, #units do
			local queue = Spring.GetUnitCommands(units[i], 100)
			if queue then
				for j=1, #queue do
					local command = queue[j]
					local id = command.id and command.id or command[1]
					if id < 0 then
						local x = command.params and command.params[1] or command[2]
						local y = command.params and command.params[2] or command[3]
						local z = command.params and command.params[3] or command[4]
						local facing = command.params and command.params[4] or 1
						local buildData = { -id, x, y, z, facing }
						if DoBuildingsClash(newBuildData, buildData) then
							return true
						end
					end
				end
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
		activeCmdID = WG['pregame-build'] and WG['pregame-build'].getPreGameDefID()
		if activeCmdID then activeCmdID = -activeCmdID end
	else
		_, activeCmdID = spGetActiveCommand()
	end

	if not activeCmdID then
		clear()
		return
	end

	if mexBuildings[-activeCmdID] then selectedMex = -activeCmdID end
	if geoBuildings[-activeCmdID] then selectedGeo = -activeCmdID end

	if not (selectedMex or selectedGeo) then
		clear()
		return
	end


	if selectedMex and metalMap then -- no snapping on metal maps
		clear()
		return
	end

	-- Attempt to get position of command
	local buildingId = -activeCmdID
	local mx, my, mb, mmb, mrb = spGetMouseState()
	local alt, ctrl, meta, shift = Spring.GetModKeyState()
	local _, pos = spTraceScreenRay(mx, my, true)
	if not pos or not pos[1] then
		clear()
		return
	end
	local x, y, z = pos[1], pos[2], pos[3]
	cursorPos = {}
	cursorPos.x, cursorPos.y, cursorPos.z = spPos2BuildPos(buildingId, x, y, z)

	-- check if there is stuff in the way - if there is we change behavior
	local clashes = clashesWithBuildQueue(buildingId, cursorPos)
	if clashes and isPregame then
		if shift then
			clear()
			return
		end
	end
	if clashes and not isPregame then
		clear()
		return
	end

	-- get nearest unoccupied spot, we have to separate shift behavior for pregame reasons here
	local nearestSpot
	if selectedMex then
		nearestSpot = shift and
			WG["resource_spot_builder"].FindNearestValidSpotForExtractor(x, z, metalSpots, selectedMex) or
			WG["resource_spot_finder"].GetClosestMexSpot(x, z)
	else
		nearestSpot = shift and
			WG["resource_spot_builder"].FindNearestValidSpotForExtractor(x, z, geoSpots, selectedGeo) or
			WG["resource_spot_finder"].GetClosestGeoSpot(x, z)
	end
	if not nearestSpot then
		clear()
		return
	end


	buildCmd = {}
	local cmd = WG["resource_spot_builder"].PreviewExtractorCommand(pos, buildingId, nearestSpot)
	if cmd and #cmd > 0 then
		targetPos = { x = cmd[2], y = cmd[3], z = cmd[4] }
		WG.ExtractorSnap.position = targetPos -- used by prospector and pregame queue

		local dist = math.distance3dSquared(cursorPos.x, cursorPos.y, cursorPos.z, targetPos.x, targetPos.y, targetPos.z)
		if(dist < 1) then
			clear()
			WG.ExtractorSnap.position = targetPos --bit of a hack, this still needs to be set during pregame
			return
		end

		buildCmd[1] = cmd
		local newUnitShape = { math.abs(buildingId), cmd[2], cmd[3], cmd[4], cmd[5], cmd[6] }
		-- check equality by position
		if unitShape and (unitShape[2] ~= newUnitShape[2] or unitShape[3] ~= newUnitShape[3] or unitShape[4] ~= newUnitShape[4]) then
			if WG.StopDrawUnitShapeGL4 then
				WG.StopDrawUnitShapeGL4(activeUnitShape)
			end
			activeUnitShape = nil
		end
		unitShape = newUnitShape
	else
		clear()
	end

	-- Draw ghost
	if WG.DrawUnitShapeGL4 then
		if unitShape then
			if not activeUnitShape and WG.DrawUnitShapeGL4 then
				activeUnitShape = WG.DrawUnitShapeGL4(unitShape[1], unitShape[2], unitShape[3], unitShape[4], unitShape[5] * (math.pi/2), 0.66, unitShape[6], 0.15, 0.3)
			end
		elseif activeUnitShape then
			clearGhostBuild()
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
	local grid = WG["gridmenu"]
	if not grid or not grid.clearCategory or not grid.getAlwaysReturn or not grid.setCurrentCategory then
		return
	end

	if (not shift and not grid.getAlwaysReturn()) then
		grid.clearCategory()
	elseif grid.getAlwaysReturn() then
		grid.setCurrentCategory(nil)
	end
end


function widget:MousePress(x, y, button)
	if isPregame then
		return
	end

	if button == 1 and buildCmd and buildCmd[1] then
		local alt, ctrl, meta, shift = Spring.GetModKeyState()
		shift = Spring.GetInvertQueueKey() and (not shift) or shift
		if selectedMex then
			WG['resource_spot_builder'].ApplyPreviewCmds(buildCmd, mexConstructors, shift)
			handleBuildMenu(shift)
			return true
		end
		if selectedGeo then
			WG['resource_spot_builder'].ApplyPreviewCmds(buildCmd, geoConstructors, shift)
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


function widget:DrawWorld()
	if not WG.DrawUnitShapeGL4
	or not targetPos
	or not cursorPos then
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
