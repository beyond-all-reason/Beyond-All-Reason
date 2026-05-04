local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Unload Snap and Preview",
		desc      = "Snaps unload pads to give nearest spot",
		author    = "DoodVanDaag, based on cmd_extractor_snap",
		version   = "v1.0",
		date      = "May 2026",
		license   = "GNU GPL, v2 or later",
		layer     = 1,
		enabled   = true,
	}
end

local TransportAPI = WG.TransportAPI

if not TransportAPI then
	Spring.Echo("TransportAPI not found, cmd_extractor_snap widget won't work")
	return false
end

-- Localized functions for performance
local mathAbs = math.abs

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

local queuedUnitShapes = {}

local function MakeLine(x1, y1, z1, x2, y2, z2)
	gl.Vertex(x1, y1, z1)
	gl.Vertex(x2, y2, z2)
end


function widget:Initialize()
	if not WG.DrawUnitShapeGL4 then
		widgetHandler:RemoveWidget()
		return
	end
end

local function clear()
	if activeUnitShape then
		WG.StopDrawUnitShapeGL4(activeUnitShape)
		activeUnitShape = nil
	end
	cursorPos = nil
	unitShape = nil
	buildCmd = {}
end

function widget:Update()
	local activeCmdID
	for unitID, data in pairs(queuedUnitShapes) do
		local found = false
		local Q = Spring.GetUnitCommands(unitID, 10)
		for i = 1, #Q do
			local cmd = Q[i]
			if cmd.id == data.cmdID and math.floor(cmd.params[1]/16)*16 == data.cmdParams[1] and math.floor(cmd.params[3]/16)*16 == data.cmdParams[3] then
				found = true
				break
			end
		end
		if not found then
			WG.StopDrawUnitShapeGL4(data.unitShapeID)
			queuedUnitShapes[unitID] = nil
		end
	end

	selectedUnload = nil

	_, activeCmdID = spGetActiveCommand()

	if not (buttonOneState) then
		if not activeCmdID then
			clear()
			return
		end

		if activeCmdID == CMD.UNLOAD_UNITS then
			selectedUnload = true
		end

		if not selectedUnload then
			clear()
			return
		end
	end
	-- Attempt to get position of command
	local mx, my, mb, mmb, mrb = spGetMouseState()
	local mouseMoved = MouseMoved(mx, my) == true
	if buttonOneState and mouseMoved then
		buttonOneState = false
		clear()
		return
	elseif buttonOneState and (not mb) then
		MouseRelease(mx, my, 1)
		return
	end

	local alt, ctrl, meta, shift = Spring.GetModKeyState()
	local _, pos = spTraceScreenRay(mx, my, true)
	if not pos or not pos[1] then
		clear()
		return
	end
	local units = Spring.GetSelectedUnits()

	local unloadPadDefID = TransportAPI.GetBiggestUnloadPadType(units)
	local x, y, z = pos[1], pos[2], pos[3]
	cursorPos = {}
	cursorPos.x, cursorPos.y, cursorPos.z = spPos2BuildPos(unloadPadDefID, x, y, z)
	local newPosX, newPosY, newPosZ = cursorPos.x, cursorPos.y, cursorPos.z

	local blocked = Spring.TestBuildOrder(unloadPadDefID, newPosX, newPosY, newPosZ, 0, Spring.GetMyTeamID()) 
	--this is to avoid los hacks from unsynced ClosestBuildPos
	--as currently, only TestBuildOrder will correctly handle los checks
	--ClosestBuildPos (https://github.com/beyond-all-reason/RecoilEngine/issues/2955) has an additional block of tests that will deny 
	--positions that were initially validated in TestBuildOrder, by ignoring LOS checks
	--it is not a perfect fix, as if TestBuildOrder returns 2 for another reason (ie cliff), 
	--ClosestBuildPos might additionally perform enemy building avoidance regardless of LOS.
	--and tbh, since AllowCommand still moves the target position, 
	--you'll still get a visual indicator of enemy building avoidance.
	--I'm hoping for a future engine fix + ability to respect LOS when performing
	--ClosestBuildPos checks from both synced and unsynced code.

	-- get nearest unload spot
	if blocked == 0 then
		newPosX, newPosY, newPosZ = Spring.ClosestBuildPos(Spring.GetMyTeamID(), unloadPadDefID, cursorPos.x, cursorPos.y, cursorPos.z, 512, 0, 0)
	end
	if newPosX < 0 then -- likely to be a failed ClosestBuildPos result (no spot found)
		clear()
		return
	end

	local cmd = { CMD.UNLOAD_UNIT, newPosX, newPosY, newPosZ, 0, Spring.GetMyTeamID() }
	if cmd and #cmd > 0 then
		targetPos = { x = cmd[2], y = cmd[3], z = cmd[4] }
		local dist = math.distance3dSquared(cursorPos.x, cursorPos.y, cursorPos.z, targetPos.x, targetPos.y, targetPos.z)
		buildCmd[1] = cmd
		local newUnitShape = { unloadPadDefID, cmd[2], cmd[3], cmd[4], cmd[5], cmd[6] }
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

function widget:CommandNotify(cmdID, params, options)
	if cmdID == CMD.UNLOAD_UNITS then
		return true
	end
end

function widget:MousePress(x, y, button)
	if button == 1 and selectedUnload then
		LastCursorPosX, LastCursorPosY = x, y
		buttonOneState = true
	end

end

function MouseMoved(x, y)
	if x ~= LastCursorPosX or y ~= LastCursorPosY then
		return true
	end
	return false
end

function MouseRelease(x, y, button)
	if button == 1 and buildCmd and buildCmd[1] then
		local alt, ctrl, meta, shift = Spring.GetModKeyState()
		shift = Spring.GetInvertQueueKey() and (not shift) or shift
		Spring.GiveOrderToUnitArray(Spring.GetSelectedUnits(), buildCmd[1][1], {buildCmd[1][2], buildCmd[1][3], buildCmd[1][4]}, shift and {"shift"} or {})
	end
	LastCursorPosX, LastCursorPosY = nil, nil
	buttonOneState = false
	clear()
end

function widget:UnitCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	if cmdID == CMD.UNLOAD_UNIT then
		local unloadPadDefID = TransportAPI.GetUnloadPadType(unitID)
		local unitShape = { unloadPadDefID, cmdParams[1], cmdParams[2], cmdParams[3], 0, teamID }
		RegisterQueuedUnitShape(unitID, unitShape)
	end
end

function RegisterQueuedUnitShape(unitID, unitShape)
	if queuedUnitShapes[unitID] then -- remove any previous shape for this unit, if it exists, 
		--a function to make sure we draw first in queue, not last, might be wanted though
		WG.StopDrawUnitShapeGL4(queuedUnitShapes[unitID].unitShapeID)
		queuedUnitShapes[unitID] = nil
	end
	local unitShapeID = WG.DrawUnitShapeGL4(unitShape[1], unitShape[2], unitShape[3], unitShape[4], unitShape[5], 0.66, unitShape[6], 0.15, 0.3)
	queuedUnitShapes[unitID] = {
		cmdID = CMD.UNLOAD_UNIT,
		cmdParams = { math.floor(unitShape[2]/16)*16, math.floor(unitShape[3]/16)*16, math.floor(unitShape[4]/16)*16 },
		unitShapeID = unitShapeID, -- store full to retrieve
	}
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
