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

	local metalSpots = WG["resource_spot_finder"].metalSpotsList
	if not metalSpots or (#metalSpots > 0 and #metalSpots <= 2) then
		metalMap = true
	end
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


function widget:Update()
	local activeCmdID

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

	selectedMex = mexBuildings[-activeCmdID]
	selectedGeo = geoBuildings[-activeCmdID]

	if selectedMex and metalMap then -- no snapping on metal maps
		clear()
		return
	end

	if not (selectedMex or selectedGeo) then
		clear()
		return
	end

	-- Attempt to get position of command

	local mx, my, mb, mmb, mrb = spGetMouseState()
	local alt, ctrl, meta, shift = Spring.GetModKeyState()
	local _, pos = spTraceScreenRay(mx, my, true)
	if not pos or not pos[1] then
		clear()
		return
	end
	local x, y, z = pos[1], pos[2], pos[3]
	cursorPos = {}
	cursorPos.x, cursorPos.y, cursorPos.z = spPos2BuildPos(-activeCmdID, x, y, z)

	local nearestSpot = selectedMex and WG["resource_spot_finder"].GetClosestMexSpot(x, z) or WG["resource_spot_finder"].GetClosestGeoSpot(x, z)
	if not nearestSpot then
		clear()
		return
	end

	if shift then
		local spotIsTaken = WG["resource_spot_builder"].SpotHasExtractorQueued(nearestSpot)
		if spotIsTaken then
			clear()
			return
		end
	end

	buildCmd = {}
	local cmd = WG["resource_spot_builder"].PreviewExtractorCommand(pos, -activeCmdID, nearestSpot)
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
		local newUnitShape = { math.abs(activeCmdID), cmd[2], cmd[3], cmd[4], cmd[5], cmd[6] }
		-- check equality by position
		if unitShape and (unitShape[2] ~= newUnitShape[2] or unitShape[3] ~= newUnitShape[3] or unitShape[4] ~= newUnitShape[4]) then
			WG.StopDrawUnitShapeGL4(activeUnitShape)
			activeUnitShape = nil
		end
		unitShape = newUnitShape
	else
		clear()
	end

	-- Draw ghost
	if WG.DrawUnitShapeGL4 then
		if unitShape then
			if not activeUnitShape then
				activeUnitShape = WG.DrawUnitShapeGL4(unitShape[1], unitShape[2], unitShape[3], unitShape[4], unitShape[5] * (math.pi/2), 0.66, unitShape[6], 0.15, 0.3)
			end
		elseif activeUnitShape then
			clearGhostBuild()
		end
	end
end


function widget:MousePress(x, y, button)
	if isPregame then
		return
	end

	if button == 1 and buildCmd and buildCmd[1] then
		local alt, ctrl, meta, shift = Spring.GetModKeyState()
		if selectedMex then
			WG['resource_spot_builder'].ApplyPreviewCmds(buildCmd, mexConstructors, shift)
		end
		if selectedGeo then
			WG['resource_spot_builder'].ApplyPreviewCmds(buildCmd, geoConstructors, shift)
			if(not shift and WG["gridmenu"] and WG["gridmenu"].clearCategory) then
				WG["gridmenu"].clearCategory()
			end
			return true -- override other mouse presses and handle stuff manually
		end
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
	clear()
end
