local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Waypoint Dragger",
		desc      = "Enables Waypoint Dragging",
		author    = "Kloot",
		date      = "Aug. 8, 2007 [updated Aug. 14, 2009]",
		license   = "GNU GPL v2",
		layer     = 5,
		enabled   = true
	}
end

local spGetActiveCommand    = Spring.GetActiveCommand
local spGetGameSeconds      = Spring.GetGameSeconds
local spGetSelectedUnits    = Spring.GetSelectedUnits
local spGetUnitCommands     = Spring.GetUnitCommands
local spGetMouseState       = Spring.GetMouseState
local spGetModKeyState      = Spring.GetModKeyState
local spGiveOrderToUnit     = Spring.GiveOrderToUnit
local spIsAboveMiniMap      = Spring.IsAboveMiniMap

local spWorldToScreenCoords = Spring.WorldToScreenCoords
local spTraceScreenRay      = Spring.TraceScreenRay

local floor = math.floor

local glVertex           = gl.Vertex
local glBeginEnd         = gl.BeginEnd
local glColor            = gl.Color
local glLineStipple      = gl.LineStipple
local glDrawGroundCircle = gl.DrawGroundCircle

local cmdColorsTbl = {
	[CMD.MOVE]         = {0.5, 1.0, 0.5, 0.55},
	[CMD.PATROL]       = {0.3, 0.3, 1.0, 0.55},
	[CMD.RECLAIM]      = {1.0, 0.2, 1.0, 0.55},
	[CMD.REPAIR]       = {0.3, 1.0, 1.0, 0.55},
	[CMD.ATTACK]       = {1.0, 0.2, 0.2, 0.55},
	[CMD.AREA_ATTACK]  = {1.0, 0.2, 0.2, 0.55},
	[CMD.FIGHT]        = {0.5, 0.5, 1.0, 0.55},
	[CMD.LOAD_UNITS]   = {0.3, 1.0, 1.0, 0.55},
	[CMD.UNLOAD_UNITS] = {1.0, 1.0, 0.0, 0.55},
	[CMD.RESURRECT]    = {0.2, 0.6, 1.0, 0.55},
	[CMD.RESTORE]      = {0.0, 1.0, 0.0, 0.55},
}

local wayPtSelDist = 15
local wayPtSelDistSqr = wayPtSelDist * wayPtSelDist
local selWayPtsTbl = {}


local function GetCommandColor(cmdID)
	if cmdColorsTbl[cmdID] ~= nil then
		return cmdColorsTbl[cmdID][1], cmdColorsTbl[cmdID][2], cmdColorsTbl[cmdID][3], cmdColorsTbl[cmdID][4]
	end

	return 1.0, 1.0, 1.0, 1.0
end

local function GetMouseWorldCoors(mx, my)
	local cwc
	if spIsAboveMiniMap(mx, my) then
		--cwc = Spring.MinimapMouseToWorld(mx, my) -- Spring.MinimapMouseToWorld was removed
	else
		_, cwc = spTraceScreenRay(mx, my, true)
	end
	return cwc
end

local function GetSqDist2D(x, y, p, q)
	local dx = x - p
	local dy = y - q
	return (dx * dx + dy * dy)
end

local function GetCommandWorldPosition(cmd)
	local cmdID = cmd.id
	local cmdPars = cmd.params
	if cmdID == CMD.RECLAIM or cmdID == CMD.REPAIR or cmdID == CMD.RESURRECT or cmdID == CMD.LOAD_UNITS or cmdID == CMD.UNLOAD_UNITS or cmdID == CMD.AREA_ATTACK or cmdID == CMD.RESTORE then
		if #cmdPars >= 4 then
			return cmdPars[1], cmdPars[2], cmdPars[3], cmdPars[4]
		end
	elseif cmdID == CMD.ATTACK then
		if #cmdPars >= 3 then
			return cmdPars[1], cmdPars[2], cmdPars[3], 0
		end
	elseif cmdID == CMD.MOVE or cmdID == CMD.FIGHT or cmdID == CMD.PATROL then
		return cmdPars[1], cmdPars[2], cmdPars[3], 0
	end
	return nil, nil, nil, nil
end

local function GetWayPointsNearCursor(wpTbl, mx, my)
	local selUnitsTbl = spGetSelectedUnits()
	local numSelWayPts = 0

	if selUnitsTbl == nil or #selUnitsTbl == 0 then
		return numSelWayPts
	end

	for i = 1, #selUnitsTbl do
		local unitID = selUnitsTbl[i]
		local commands = spGetUnitCommands(unitID,20)
		if commands then
			for cmdNum = 1, #commands do
				local curCmd      = commands[cmdNum    ]
				if cmdColorsTbl[curCmd.id] then
					local nxtCmd      = commands[cmdNum + 1]
					local x, y, z, fr = GetCommandWorldPosition(curCmd)
					if x and y and z then
						local p, q  = spWorldToScreenCoords(x, y, z)
						if GetSqDist2D(mx,my,p,q) < wayPtSelDistSqr then
							-- save the tag of the next command
							local wpLink = (nxtCmd and nxtCmd.tag) or nil
							local wpData = {x, y, z, fr, wpLink, curCmd, unitID}
							local wpKey  = tostring(unitID) .. "-" .. tostring(curCmd.tag)

							wpTbl[wpKey] = wpData
							numSelWayPts = numSelWayPts + 1
						end
					end
				end
			end
		end
	end

	return numSelWayPts
end

local function MoveWayPoints(wpTbl, mx, my, finalize)
	local cursorWorldCoors = GetMouseWorldCoors(mx, my)

	if cursorWorldCoors ~= nil then
		local wpTblTmp = {}
		local cx, cy, cz = cursorWorldCoors[1], cursorWorldCoors[2], cursorWorldCoors[3]
		local alt, ctrl, _, _ = spGetModKeyState()

		if ctrl then
			-- merge waypoints that are currently near
			-- the cursor with those that were near it
			-- at the time of the MousePress event
			GetWayPointsNearCursor(wpTblTmp, mx, my)

			for wpKey, wpData in pairs(wpTblTmp) do
				wpTbl[wpKey] = wpData
			end
		end

		for wpKey, wpData in pairs(wpTbl) do
			-- facing for build orders,
			-- radius for area orders
			local cmdFacRad = wpData[4]
			local cmdLink   = wpData[5]
			local cmdID     = wpData[6].id
			local cmdPars   = wpData[6].params
			local cmdTag    = wpData[6].tag
			local cmdUnitID = wpData[7]

			if finalize then
				if cmdLink == nil then
					cmdLink = cmdTag
				end
				if cmdFacRad > 0 then
					-- spGiveOrderToUnit(cmdUnitID, CMD.INSERT, {cmdNum, cmdID, 0, cx, cy, cz, cmdFacRad}, {"alt"})
					spGiveOrderToUnit(cmdUnitID, CMD.INSERT, {cmdLink, cmdID, 0, cx, cy, cz, cmdFacRad}, 0)
				else
					-- spGiveOrderToUnit(cmdUnitID, CMD.INSERT, {cmdNum, cmdID, 0, cx, cy, cz}, {"alt"})
					spGiveOrderToUnit(cmdUnitID, CMD.INSERT, {cmdLink, cmdID, 0, cx, cy, cz}, 0)
				end
				if not alt then
					spGiveOrderToUnit(cmdUnitID, CMD.REMOVE, {cmdTag}, 0)
				end
			else
				wpData[1] = cx
				wpData[2] = cy
				wpData[3] = cz
			end
		end
	end

	if finalize then
		for wpKey, _ in pairs(wpTbl) do
			selWayPtsTbl[wpKey] = nil
		end
	end
end

local function UpdateWayPoints(wpTbl)
	local _, _, _, shift = spGetModKeyState()
	local badWayPtsTbl = {}

	for wpKey, wpData in pairs(wpTbl) do
		local cmdTag    = wpData[6].tag
		local cmdUnitID = wpData[7]
		local cmdValid  = false

		local unitCmds = spGetUnitCommands(cmdUnitID,20)

		-- check if the command has not been completed
		-- since the MousePress() event occurred (tags
		-- don't wrap around within a unit's cmd queue
		-- until 1 << 24 of them have been assigned, so
		-- this should be safe)
		if unitCmds then
			for unitCmdNum = 1, #unitCmds do
				if unitCmds[unitCmdNum].tag == cmdTag then
					cmdValid = true; break
				end
			end
		end

		-- if shift was released while dragging,
		-- make sure to erase all waypoints here
		if not cmdValid or not shift then
			badWayPtsTbl[wpKey] = true
		end
	end

	for wpKey, _ in pairs(badWayPtsTbl) do
		wpTbl[wpKey] = nil
	end
end

function widget:MousePress(mx, my, mb)
	-- decide whether to steal this press from the engine
	-- so that we get the subsequent MouseMove() call-ins
	--
	-- we do this when the following conditions are true:
	--   1. we have at least one unit selected
	--   2. we have the shift key pressed
	--   3. we pressed the LEFT mouse button (otherwise shift-move orders would break)
	--   4. our mouse cursor is within "grabbing" radius of (at least)
	--      one waypoint of at least one of the units we have selected
	local _, actCmdID, _, _      = spGetActiveCommand()
	if actCmdID and actCmdID < 0 then
		return false
	end
	local alt, ctrl, meta, shift = spGetModKeyState()
	local numWayPts              = 0
	if not shift then return false end
	if mb ~= 1 then return false end
	numWayPts = GetWayPointsNearCursor(selWayPtsTbl, mx, my)
	if numWayPts == 0 then
		return false
	end
	return true
end

function widget:MouseMove(mx, my, mdx, mdy, mb)
	MoveWayPoints(selWayPtsTbl, mx, my, false)
	return false
end

function widget:MouseRelease(mx, my, mb)
	MoveWayPoints(selWayPtsTbl, mx, my, true)
	return false
end

function widget:Update(_)
	-- remove waypoints that units have
	-- "passed" in some sense since the
	-- MousePress event was received
	UpdateWayPoints(selWayPtsTbl)
end

function widget:DrawWorld()
	local mx, my, _, _, _ = spGetMouseState()
	local _, _, _, shift = spGetModKeyState()
	if not shift then
		return
	end
	for _, wpData in pairs(selWayPtsTbl) do
		local cmd           = wpData[6]
		local nx, ny, nz    = wpData[1], wpData[2], wpData[3]
		local ox, oy, oz, _ = GetCommandWorldPosition(cmd)
		local p, q          = spWorldToScreenCoords(ox, oy, oz)
		local d             = GetSqDist2D(mx, my, p, q)
		local r, g, b, a    = GetCommandColor(cmd.id)
		glColor(r, g, b, a)

		if d > (wayPtSelDist * wayPtSelDist) then
			glDrawGroundCircle(ox, oy, oz, 13, 64)
		end

		local pattern = (65536 - 775)
		local offset = floor((spGetGameSeconds() * 16) % 16)
		glLineStipple(2, pattern, -offset)
		glBeginEnd(GL.LINES,
			function()
				glVertex(ox, oy, oz)
				glVertex(nx, ny, nz)
			end
		)
		glLineStipple(false)
	end
	glColor(1.0, 1.0, 1.0, 1.0)
end
