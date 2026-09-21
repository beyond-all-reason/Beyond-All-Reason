local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "CustomFormations2",
		desc = "Allows you to draw your own formation line.",
		author = "Errrrrrr, Niobium", -- based on 'Custom Formations' by jK and gunblob
		version = "v4.4",
		date = "June, 2023",
		license = "GNU GPL, v2 or later",
		layer = 10000,
		enabled = true,
		handler = true,
	}
end

-- Localized Spring API for performance
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetSelectedUnitsCount = Spring.GetSelectedUnitsCount

-- Behavior:
-- To give a line command: select command, then right click & drag
-- To give a command within an area: select command, then left click and drag
-- To give a command at a point: select command, left click and don't drag
-- To area attack (bombers etc only): select command, hold alt, left click and drag
-- To deselect non-default command and return to default command: right click and don't drag
-- To deselect default command: left click

local getCurrentMiniMapRotationOption = VFS.Include("luaui/Include/minimap_utils.lua").getCurrentMiniMapRotationOption
local ROTATION = VFS.Include("luaui/Include/minimap_utils.lua").ROTATION

local dotImage = "LuaUI/Images/formationDot.dds"

--------------------------------------------------------------------------------
-- User Configurable Constants
--------------------------------------------------------------------------------

-- issue repeat commands for a single unit while holding shift
local repeatForSingleUnit = true

-- Minimum spacing between commands (Squared) when drawing a path for a single unit, must be >16*16 (Or orders overlap and cancel)
local minPathSpacingSq = 50 * 50

-- Minimum line length to cause formation move instead of single-click-style order
local minFormationLength = 20

-- How long should algorithms take. (~0.1 gives visible stutter, default: 0.05)
local maxHngTime = 0.01 -- Desired maximum time for hungarian algorithm
local maxNoXTime = 0.01 -- Strict maximum time for backup algorithm

local defaultHungarianUnits = 20 -- Need a baseline to start from when no config data saved
local minHungarianUnits = 10 -- If we kept reducing maxUnits it can get to a point where it can never increase, so we enforce minimums on the algorithms.
local unitIncreaseThresh = 0.85 -- We only increase maxUnits if the units are great enough for time to be meaningful

-- Alpha loss per second after releasing mouse
local lineFadeRate = 2.0

-- Landing spots of agile aircraft, these mirror the engine (CStrafeAirMoveType::FindAgileSpot / CanSetDownAt)
local agileSpotSpacing = 2.5 -- Distance between neighbouring spots, in unit radii (what the engine uses for its own pattern)
local groundSpotSpacing = 1.5 -- The same for units on the ground, in footprints: room to get past each other
local agileSpotSpacingExtra = 1 -- Added to the above (elmos), so rounding never puts two spots too close
local agileRowStep = 0.8660254 -- Distance between rows in spacings (hexagonal packing)
local agileMaxLandSlope = 0.03 -- Steeper ground than this can not be landed on

-- What commands are eligible for custom formations
local CMD_SETTARGET = GameCMD.UNIT_SET_TARGET
local CMD_MANUAL_LAUNCH = GameCMD.MANUAL_LAUNCH

-- Commands whose line formation is laid out in a shape when the line is too tight for one row
local shapedCmds = {
	[CMD.MOVE] = true,
	[CMD.FIGHT] = true,
}

local formationCmds = {
	[CMD.MOVE] = true,
	[CMD.FIGHT] = true,
	[CMD.ATTACK] = true,
	[CMD.PATROL] = true,
	[CMD.UNLOAD_UNIT] = true,
	[CMD_SETTARGET] = true,
	[CMD_MANUAL_LAUNCH] = true,
}

-- Context-based default commands that can be overridden (meaning that cf2 doesn't touch the command i.e. guard/attack when mouseover unit)
-- If the mouse remains on the same target for both Press/Release then the formation is ignored and original command is issued.
-- Normal logic will follow after override, i.e. must be a formationCmd to get formation, alt must be held if requiresAlt, etc.
local overrideCmds = {
	[CMD.GUARD] = CMD.MOVE,
	[CMD.ATTACK] = CMD.MOVE,
	[CMD_SETTARGET] = CMD.MOVE,
}

-- What commands can be issued at a position or unit/feature ID (Only used by GetUnitPosition)
local positionCmds = {
	[CMD.MOVE] = true,
	[CMD.ATTACK] = true,
	[CMD.RECLAIM] = true,
	[CMD.RESTORE] = true,
	[CMD.RESURRECT] = true,
	[CMD.PATROL] = true,
	[CMD.CAPTURE] = true,
	[CMD.FIGHT] = true,
	[CMD.MANUALFIRE] = true,
	[CMD.UNLOAD_UNIT] = true,
	[CMD.UNLOAD_UNITS] = true,
	[CMD.LOAD_UNITS] = true,
	[CMD.GUARD] = true,
	[CMD.AREA_ATTACK] = true,
	[CMD_SETTARGET] = true,
	[CMD_MANUAL_LAUNCH] = true,
}

-- What commands need more than one unit selected to be issued as a formation command
local multiUnitOnlyCmds = {
	[CMD_MANUAL_LAUNCH] = true,
}

local chobbyInterface
local lineLength = 0
local formationVersion = 0
local formationOrders = nil
local formationOrdersVersion = nil
local formationOrdersShifted = nil

--------------------------------------------------------------------------------
-- Globals
--------------------------------------------------------------------------------
local maxHungarianUnits = defaultHungarianUnits -- Also set when loading config

local fNodes = {} -- Formation nodes, filled as we draw
local fDists = {} -- fDists[i] = distance from node 1 to node i
local totaldxy = 0 -- Measure of distance mouse has moved, used to unjag lines drawn in minimap

local dimmCmd = nil -- The dimming command (Used for color)
local dimmNodes = {} -- The current nodes of dimming line
local dimmAlpha = 0 -- The current alpha of dimming line

local pathCandidate = false -- True if we should start a path on mouse move
local draggingPath = false -- True if we are dragging a path for unit(s) to follow
local lastPathPos = nil -- The last point added to the path, used for min-distance check
local pathPositions = {} -- All positions added to the path, used to prevent overlapping commands

local overriddenCmd = nil -- The command we ignored in favor of move
local overriddenTarget = nil -- The target (for params) we ignored

local usingCmd = nil -- The command to execute across the line
local usingRMB = false -- All commands use right mouse + drag to do a formation command
local inMinimap = false -- Is the line being drawn in the minimap
local endShift = false -- True to reset command when shift is released

local MiniMapFullProxy = (Spring.GetConfigInt("MiniMapFullProxy", 0) == 1)

--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------
local GL_LINE_STRIP = GL.LINE_STRIP
local GL_QUADS = GL.QUADS
local glVertex = gl.Vertex
local glTexCoord = gl.TexCoord
local glTexture = gl.Texture
local glDepthTest = gl.DepthTest
local glLineStipple = gl.LineStipple
local glLineWidth = gl.LineWidth
local glColor = gl.Color
local glBeginEnd = gl.BeginEnd
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glLoadIdentity = gl.LoadIdentity

local spGetActiveCommand = Spring.GetActiveCommand
local spSetActiveCommand = Spring.SetActiveCommand
local spGetDefaultCommand = Spring.GetDefaultCommand
local spFindUnitCmdDesc = Spring.FindUnitCmdDesc
local spGetModKeyState = Spring.GetModKeyState
local spGetInvertQueueKey = Spring.GetInvertQueueKey
local spIsAboveMiniMap = Spring.IsAboveMiniMap
local spGiveOrder = Spring.GiveOrder
local spGetUnitCommands = Spring.GetUnitCommands
local spGetUnitPosition = Spring.GetUnitPosition
local spGetGroundHeight = Spring.GetGroundHeight
local spGetFeaturePosition = Spring.GetFeaturePosition
local spGetCameraPosition = Spring.GetCameraPosition
local spGetViewGeometry = Spring.GetViewGeometry
local spTraceScreenRay = Spring.TraceScreenRay
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitRadius = Spring.GetUnitRadius
local spGetUnitStates = Spring.GetUnitStates
local spGetUnitMoveTypeData = Spring.GetUnitMoveTypeData
local spGetGroundNormal = Spring.GetGroundNormal
local spGetGroundBlocked = Spring.GetGroundBlocked
local spTestMoveOrder = Spring.TestMoveOrder

local mapSizeX, mapSizeZ = Game.mapSizeX, Game.mapSizeZ
local maxUnits = Game.maxUnits

local osclock = os.clock
local tsort = table.sort
local floor = math.floor
local sqrt = math.sqrt
local abs = math.abs
local ceil = math.ceil
local sin = math.sin
local cos = math.cos
local max = math.max
local min = math.min
local huge = math.huge

local CMD_INSERT = CMD.INSERT
local CMD_MOVE = CMD.MOVE
local CMD_ATTACK = CMD.ATTACK
local CMD_UNLOADUNIT = CMD.UNLOAD_UNIT
local CMD_UNLOADUNITS = CMD.UNLOAD_UNITS
local CMD_OPT_ALT = CMD.OPT_ALT
local CMD_OPT_CTRL = CMD.OPT_CTRL
local CMD_OPT_META = CMD.OPT_META
local CMD_OPT_SHIFT = CMD.OPT_SHIFT
local CMD_OPT_RIGHT = CMD.OPT_RIGHT

local keyShift = 304
local selectedUnits = spGetSelectedUnits()
local selectedUnitsCount = spGetSelectedUnitsCount()

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------
local function GetModKeys()
	local alt, ctrl, meta, shift = spGetModKeyState()

	if spGetInvertQueueKey() then -- Shift inversion
		shift = not shift
	end

	-- Check if PiP widget wants to force shift for right-click drags
	if WG.pipForceShift then
		shift = true
	end

	return alt, ctrl, meta, shift
end

local function GetUnitFinalPosition(uID)
	local ux, uy, uz = spGetUnitPosition(uID)
	local cmds = spGetUnitCommands(uID, 5000)

	if cmds then
		for i = #cmds, 1, -1 do
			local cmd = cmds[i]
			if (cmd.id < 0) or positionCmds[cmd.id] then
				local params = cmd.params
				if #params >= 3 then
					return params[1], params[2], params[3]
				else
					if #params == 1 then
						local pID = params[1]
						local px, py, pz

						if pID >= maxUnits then
							px, py, pz = spGetFeaturePosition(pID - maxUnits)
						else
							px, py, pz = spGetUnitPosition(pID)
						end

						if px then
							return px, py, pz
						end
					end
				end
			end
		end
	end

	return ux, uy, uz
end

local function SetColor(cmdID, alpha)
	if cmdID == CMD_MOVE then
		glColor(0.5, 1.0, 0.5, alpha) -- Green
	elseif cmdID == CMD_ATTACK or cmdID == CMD_MANUAL_LAUNCH then
		glColor(1.0, 0.2, 0.2, alpha) -- Red
	elseif cmdID == CMD_UNLOADUNIT then
		glColor(1.0, 1.0, 0.0, alpha) -- Yellow
	elseif cmdID == CMD_SETTARGET then
		glColor(1.0, 0.7, 0.0, alpha) -- Orange
	else
		glColor(0.5, 0.5, 1.0, alpha) -- Blue
	end
end

local function CanUnitExecute(uID, cmdID)
	if cmdID == CMD_UNLOADUNIT then
		cmdID = CMD_UNLOADUNITS
	end
	return (spFindUnitCmdDesc(uID, cmdID) ~= nil)
end

local function GetExecutingUnits(cmdID)
	local units = {}
	for i = 1, selectedUnitsCount do
		local uID = selectedUnits[i]
		if CanUnitExecute(uID, cmdID) then
			units[#units + 1] = uID
		end
	end
	return units
end

local function AddFNode(pos)
	local px, pz = pos[1], pos[3]
	if px < 0 or pz < 0 or px > mapSizeX or pz > mapSizeZ then
		return false
	end

	local n = #fNodes
	if n == 0 then
		fNodes[1] = pos
		fDists[1] = 0
	else
		local prevNode = fNodes[n]
		local dx, dz = px - prevNode[1], pz - prevNode[3]
		local distSq = dx * dx + dz * dz
		if distSq == 0.0 then -- Don't add if duplicate
			return false
		end

		fNodes[n + 1] = pos
		fDists[n + 1] = fDists[n] + sqrt(distSq)
		lineLength = lineLength + distSq ^ 0.5
	end

	formationVersion = formationVersion + 1
	totaldxy = 0
	return true
end

local function GetInterpNodes(mUnits)
	local number = #mUnits
	local spacing = fDists[#fNodes] / (#mUnits - 1)

	local interpNodes = {}

	local sPos = fNodes[1]
	local sX = sPos[1]
	local sZ = sPos[3]
	local sY = max(spGetGroundHeight(sX, sZ), 0)
	local sDist = 0

	local eIdx = 2
	local ePos = fNodes[2]
	local eX = ePos[1]
	local eZ = ePos[3]
	local eDist = fDists[2]
	local eY

	interpNodes[1] = { sX, sY, sZ }

	for n = 1, number - 2 do
		local reqDist = n * spacing
		while reqDist > eDist do
			sX = eX
			sZ = eZ
			sDist = eDist

			eIdx = eIdx + 1
			ePos = fNodes[eIdx]
			eX = ePos[1]
			eZ = ePos[3]
			eDist = fDists[eIdx]
		end

		local nFrac = (reqDist - sDist) / (eDist - sDist)
		local nX = sX * (1 - nFrac) + eX * nFrac
		local nZ = sZ * (1 - nFrac) + eZ * nFrac
		local nY = max(spGetGroundHeight(nX, nZ), 0)
		interpNodes[n + 1] = { nX, nY, nZ }
	end

	ePos = fNodes[#fNodes]
	eX = ePos[1]
	eZ = ePos[3]
	eY = max(spGetGroundHeight(eX, eZ), 0)
	interpNodes[number] = { eX, eY, eZ }

	return interpNodes
end

--------------------------------------------------------------------------------
-- Agile aircraft landing spots
--------------------------------------------------------------------------------
-- Aircraft with the engine's agile flight model land exactly on their move goal. When goals are closer
-- together than the aircraft can land, the engine moves each to the nearest free spot on arrival, so a
-- short line does not end up as drawn. Such a line is turned into hexagonally packed rows of spots that
-- can all be kept instead. Anything but a move order to landing agile aircraft only is left as it was.

-- Returns what the spots have to allow for, or nil if any of the units is not a landing agile aircraft
-- What a group needs of its formation: how far apart its spots should be, how near they may
-- get where the line bends, and what a spot has to be tested for. nil: leave the group alone.
local function GetFormationInfo(mUnits)
	local maxSize = 0 -- of the room one unit takes (elmos across)
	local maxLoose = 0 -- of that room with the clearance units should have around them
	local maxSway = 0
	local xsize, zsize = 1, 1
	local canWater = ((Game.waterDamage or 0) <= 0)
	local allLanders = true
	local groundDefs, groundDefCount, seenDefs = {}, 0, {}

	for i = 1, #mUnits do
		local uID = mUnits[i]
		local unitDefID = spGetUnitDefID(uID)
		local unitDef = UnitDefs[unitDefID or -1]
		if not unitDef then
			return nil
		end

		if unitDef.canFly then
			local radius = spGetUnitRadius(uID) or 0
			local moveType = unitDef.isStrafingAirUnit and spGetUnitMoveTypeData(uID) or nil
			local agile = (moveType ~= nil and moveType.agileFlight == true)
			local states = spGetUnitStates(uID)
			local flies = (states ~= nil and states.autoland == false)

			if unitDef.isStrafingAirUnit and (not agile or (flies and moveType.agileLandOnly)) then
				-- a stock fixed-wing aircraft circles its goal, it holds no spot
				allLanders = false
			else
				if agile and not flies then
					xsize = max(xsize, unitDef.xsize or 1)
					zsize = max(zsize, unitDef.zsize or 1)
					if not (unitDef.floatOnWater or unitDef.canSubmerge) then
						canWater = false
					end
				else
					-- it holds in the air over its spot (where the engine keeps room for a hover sway)
					allLanders = false
					if agile then
						maxSway = max(maxSway, min(moveType.agileHoverSway or 0, max(radius, 16) * 0.5))
					end
				end
				maxSize = max(maxSize, radius * 2)
				maxLoose = max(maxLoose, radius * agileSpotSpacing)
			end
		else
			-- on the ground (or the water): its footprint, and room to get past each other
			allLanders = false
			local size = max(unitDef.xsize or 2, unitDef.zsize or 2) * 8
			maxSize = max(maxSize, size)
			maxLoose = max(maxLoose, size * groundSpotSpacing)
			if not seenDefs[unitDefID] and groundDefCount < 8 then
				seenDefs[unitDefID] = true
				groundDefCount = groundDefCount + 1
				groundDefs[groundDefCount] = unitDefID
			end
		end
	end

	if maxSize <= 0 then
		return nil
	end

	return {
		spacing = maxLoose + maxSway * 2 + agileSpotSpacingExtra,
		-- What two of them can not do without (for aircraft that land: the sum of their radii, what
		-- the engine insists on). The spacing above is roomier, which lets a shape bend with the line
		minSpacing = maxSize + maxSway * 2 + agileSpotSpacingExtra,
		margin = maxSize * 0.5,
		xsize = xsize,
		zsize = zsize,
		canWater = canWater,
		landers = allLanders,
		groundDefs = groundDefs,
	}
end

local function IsAgileSpotBlocked(x, z, info)
	if not spGetGroundBlocked then
		return false
	end

	local x1 = (floor(x / 8) - floor(info.xsize / 2)) * 8 + 4
	local z1 = (floor(z / 8) - floor(info.zsize / 2)) * 8 + 4
	local x2 = x1 + (info.xsize - 1) * 8
	local z2 = z1 + (info.zsize - 1) * 8

	if not spGetGroundBlocked(x1, z1, x2, z2) then
		return false
	end

	-- Mobile units are expected to have moved on, look for anything else square by square
	for sx = x1, x2, 8 do
		for sz = z1, z2, 8 do
			local objType, objID = spGetGroundBlocked(sx, sz)
			if objType == "feature" then
				return true
			elseif objType == "unit" then
				local unitDef = UnitDefs[(objID and spGetUnitDefID(objID)) or -1]
				if (not unitDef) or unitDef.isImmobile then
					return true
				end
			end
		end
	end

	return false
end

local function IsAgileSpotLandable(x, z, info)
	local y = spGetGroundHeight(x, z)
	if not y then
		return false
	end
	if y < 0 and not info.canWater then
		return false
	end

	if spGetGroundNormal then
		local _, _, _, slope = spGetGroundNormal(x, z)
		if slope and slope > agileMaxLandSlope then
			return false
		end
	end

	return not IsAgileSpotBlocked(x, z, info)
end

-- Rows of spots, the first one centred on (midX, midZ) along dir, the next ones further along perp.
-- strict: spots off the map or not fit for landing are left out (nil if there are too few good ones)
-- not strict: every spot is used, pushed back inside the map if need be
-- Can the group use this spot: aircraft that land have to be able to set down on it, everything
-- that drives, walks or floats has to be able to stand there (terrain and buildings, not the units
-- that happen to be in the way now)
local function IsFormationSpotUsable(x, z, info)
	if info.landers then
		return IsAgileSpotLandable(x, z, info)
	end
	if spTestMoveOrder then
		local y = spGetGroundHeight(x, z) or 0
		for i = 1, #info.groundDefs do
			if not spTestMoveOrder(info.groundDefs[i], x, y, z, 0, 0, 0, true, true, false) then
				return false
			end
		end
	end
	return true
end

-- Where the drawn path is after <dist> elmos along it; before its start and past its end it
-- carries straight on, a shape wider than the line was drawn has to go somewhere
local function GetAgilePathPoint(dist)
	local nodeCount = #fNodes
	local pathLength = fDists[nodeCount]

	if dist < 0 or dist > pathLength then
		local i = (dist < 0) and 2 or nodeCount
		local sPos, ePos = fNodes[i - 1], fNodes[i]
		local segLength = fDists[i] - fDists[i - 1]
		if segLength > 0 then
			local dx, dz = (ePos[1] - sPos[1]) / segLength, (ePos[3] - sPos[3]) / segLength
			if dist < 0 then
				return sPos[1] + dx * dist, sPos[3] + dz * dist
			end
			return ePos[1] + dx * (dist - pathLength), ePos[3] + dz * (dist - pathLength)
		end
		dist = max(0, min(pathLength, dist))
	end

	for i = 2, nodeCount do
		if dist <= fDists[i] or i == nodeCount then
			local sPos, ePos = fNodes[i - 1], fNodes[i]
			local segLength = fDists[i] - fDists[i - 1]
			local t = (segLength > 0) and ((dist - fDists[i - 1]) / segLength) or 0
			return sPos[1] + (ePos[1] - sPos[1]) * t, sPos[3] + (ePos[3] - sPos[3]) * t
		end
	end

	return fNodes[1][1], fNodes[1][3]
end

-- Unit normal of the drawn path at <dist>, from a stretch of it as long as one spacing so that
-- the kinks of a hand-drawn line do not show
local function GetAgilePathNormal(dist, spacing)
	local x1, z1 = GetAgilePathPoint(dist - spacing * 0.5)
	local x2, z2 = GetAgilePathPoint(dist + spacing * 0.5)
	local dx, dz = x2 - x1, z2 - z1
	local length = sqrt(dx * dx + dz * dz)
	if length < 0.01 then
		local sPos, ePos = fNodes[1], fNodes[#fNodes]
		dx, dz = ePos[1] - sPos[1], ePos[3] - sPos[3]
		length = sqrt(dx * dx + dz * dz)
		if length < 0.01 then
			return 0, 1
		end
	end
	return -dz / length, dx / length
end

-- The shapes. Each is a list of places {along, across} in elmos around the middle of the drawn
-- line, best place first, no two nearer than the spacing; <width> is the length of the line.
-- A line too short for its shape says where, not how wide: the shape then takes the width it needs.
-- But a line that fits them in a few rows is exactly as wide as the player wants it.
local agileShapes = {}
local agileMaxRowsAsDrawn = 3

local function GetAgileLattice(count, spacing, width, rowStep, stagger)
	local perRow = floor(width / spacing) + 1
	local rows = ceil(count / perRow)
	if rows > agileMaxRowsAsDrawn then
		-- at least as wide as deep
		perRow = max(perRow, ceil(sqrt(count * rowStep)))
		rows = ceil(count / perRow)
	end
	local rowWidth = max(width, (perRow - 1) * spacing)

	-- As many rows as it takes, all of them as long as the line and as full as each other (the
	-- odd ones out go to the middle rows): two even rows, not one row with a clump behind its middle
	local rowCounts = {}
	for r = 1, rows do
		rowCounts[r] = floor(count / rows)
	end
	local extra = count - floor(count / rows) * rows
	local r = ceil(rows / 2)
	local stepOut = 0
	while extra > 0 do
		rowCounts[r] = rowCounts[r] + 1
		extra = extra - 1
		stepOut = (stepOut <= 0) and (1 - stepOut) or -stepOut
		r = ceil(rows / 2) + stepOut
		if r < 1 or r > rows then
			r = ceil(rows / 2)
			stepOut = 0
		end
	end
	local fullest = 1
	for i = 1, rows do
		fullest = max(fullest, rowCounts[i])
	end

	-- (two full rows next to each other have to be pushed apart along the line to interlock,
	-- a full row next to a shorter one interlocks as it is)
	local fullNeighbours = false
	for i = 1, rows - 1 do
		if rowCounts[i] == fullest and rowCounts[i + 1] == fullest then
			fullNeighbours = true
		end
	end

	local places = {}
	local placeCount = 0
	local function AddRow(rowIndex, slots)
		local across = (rowIndex - (rows + 1) * 0.5) * spacing * rowStep
		local step = (slots > 1) and (rowWidth / (slots - 1)) or 0
		local start = -(slots - 1) * step * 0.5
		if stagger and fullest > 1 then
			-- every row on the same step, every other row half of it along
			step = rowWidth / (fullest - 1)
			start = -(slots - 1) * step * 0.5
			if slots == fullest and (fullNeighbours or rowIndex < 1 or rowIndex > rows) then
				start = start + step * ((rowIndex % 2 == 0) and 0.25 or -0.25)
			end
		end
		for i = 0, slots - 1 do
			placeCount = placeCount + 1
			places[placeCount] = { start + i * step, across }
		end
	end

	for i = 1, rows do
		AddRow(i, rowCounts[i])
	end
	-- (further rows on either side, for the places above that turn out to be unusable)
	for i = 1, rows + 3 do
		AddRow(rows + i, fullest)
		AddRow(1 - i, fullest)
	end

	return places
end

agileShapes.square = function(count, spacing, width)
	return GetAgileLattice(count, spacing, width, 1, false)
end

agileShapes.hex = function(count, spacing, width)
	return GetAgileLattice(count, spacing, width, agileRowStep, true)
end

-- The engine's own pattern for aircraft sent to one point (FindAgileSpot): the point itself, then
-- seed n at the golden angle times n and a distance growing with sqrt(n + 2), no two seeds nearer
-- than 1.65 steps. Stretched along the line when that is longer than the disc is wide.
agileShapes.sunflower = function(count, spacing, width)
	local step = spacing / 1.65
	local stretch = max(1, (width * 0.5) / (step * sqrt(count + 1)))
	local places = {}

	places[1] = { 0, 0 }
	for n = 1, count * 4 + 64 do
		local angle = n * 2.39996323
		local dist = step * sqrt(n + 2)
		places[n + 1] = { sin(angle) * dist * stretch, cos(angle) * dist }
	end

	return places
end

-- A square grid standing on its corner, filled from the middle so that its outline is a diamond
-- as wide as the line (or as wide as it is deep, when the line is shorter than that)
agileShapes.diamond = function(count, spacing, width)
	local diag = spacing * 0.7071068
	local halfWidth = max(width * 0.5, spacing * 0.5)
	if count * spacing * spacing / (2 * halfWidth) > agileMaxRowsAsDrawn * spacing * 0.5 then
		-- at least as wide as deep
		halfWidth = max(halfWidth, sqrt(count * 0.5) * spacing)
	end
	local halfDepth = max(spacing, count * spacing * spacing / (2 * halfWidth))
	local reach = ceil(sqrt(count)) * 2 + 4
	local places = {}
	local placeCount = 0

	for i = -reach, reach do
		for j = -reach, reach do
			local along, across = (i + j) * diag, (i - j) * diag
			placeCount = placeCount + 1
			places[placeCount] = {
				along,
				across,
				abs(along) / halfWidth + abs(across) / halfDepth * 1.03 + ((across < 0) and 0.0001 or 0),
			}
		end
	end

	table.sort(places, function(a, b)
		return a[3] < b[3]
	end)
	return places
end

-- Lays a shape over the drawn path: <along> is measured along the path from its middle, <across>
-- along the path's normal there (<side> decides which way is positive). Where the path bends toward
-- a row its places move closer together; that is fine down to what the engine insists on, only a
-- place nearer than that to a spot already taken is left out (its aircraft gets the next free place,
-- which is out on the edge of the shape, so this must stay the exception).
local function GetAgileSpots(count, info, places, side, strict)
	local spacing = info.spacing
	local margin = info.margin
	local maxX, maxZ = mapSizeX - margin, mapSizeZ - margin
	local midDist = fDists[#fNodes] * 0.5
	local minDistSq = (info.minSpacing or spacing) ^ 2
	-- The direction "across" is taken from a stretch of the path, not from a point of it: the
	-- direction of a hand-drawn line wobbles, and the deeper a shape is, the less it can follow a
	-- tight bend before its inner rows run into each other
	local depth = 0
	for p = 1, min(count, #places) do
		depth = max(depth, abs(places[p][2]))
	end
	local normalSpan = max(spacing * 3, depth * 4)

	local spots = {}
	local spotCount = 0

	for p = 1, #places do
		local place = places[p]
		local x, z = GetAgilePathPoint(midDist + place[1])
		if place[2] ~= 0 then
			local nx, nz = GetAgilePathNormal(midDist + place[1], normalSpan)
			x, z = x + nx * place[2] * side, z + nz * place[2] * side
		end

		local usable = true
		if strict then
			usable = (x >= margin and z >= margin and x <= maxX and z <= maxZ and IsFormationSpotUsable(x, z, info))
		else
			x = max(margin, min(maxX, x))
			z = max(margin, min(maxZ, z))
		end

		if usable then
			for j = 1, spotCount do
				local spot = spots[j]
				if (spot[1] - x) ^ 2 + (spot[3] - z) ^ 2 < minDistSq then
					usable = false
					break
				end
			end
		end

		if usable then
			spotCount = spotCount + 1
			spots[spotCount] = { x, max(spGetGroundHeight(x, z) or 0, 0), z }
			if spotCount >= count then
				return spots
			end
		end
	end

	return nil
end

local function GetAgileLandingNodes(mUnits, interpNodes, shifted)
	local count = #mUnits
	if not shapedCmds[usingCmd] or count < 2 or (interpNodes and #interpNodes ~= count) then
		return nil
	end
	-- ("line": the player wants the line as drawn, however tight)
	local shapeName = WG.formationShape or "hex"
	if shapeName == "line" then
		return nil
	end
	if not (spGetUnitMoveTypeData and spGetUnitDefID and spGetUnitRadius and spGetUnitStates) then
		return nil
	end

	local nodeCount = #fNodes
	local pathLength = fDists[nodeCount]
	if nodeCount < 2 or not pathLength then
		return nil
	end

	local info = GetFormationInfo(mUnits)
	if not info then
		return nil
	end

	-- The line is long enough for all of them
	local spacing = info.spacing
	if pathLength / (count - 1) >= spacing then
		return nil
	end

	-- Further rows go behind the line, as seen from where the units are (or will be)
	local midX, midZ = GetAgilePathPoint(pathLength * 0.5)
	local normX, normZ = GetAgilePathNormal(pathLength * 0.5, max(spacing, pathLength * 0.5))
	local side = 1

	local sumX, sumZ, sumCount = 0, 0, 0
	for i = 1, count do
		local ux, uz, _
		if shifted then
			ux, _, uz = GetUnitFinalPosition(mUnits[i])
		else
			ux, _, uz = spGetUnitPosition(mUnits[i])
		end
		if ux and uz then
			sumX, sumZ, sumCount = sumX + ux, sumZ + uz, sumCount + 1
		end
	end
	if sumCount > 0 and ((sumX / sumCount - midX) * normX + (sumZ / sumCount - midZ) * normZ) > 0 then
		side = -1
	end

	-- The shape the player picked (Formation Shape widget), hexagonal rows when there is none
	local shape = agileShapes[shapeName] or agileShapes.hex
	local places = shape(count, spacing, pathLength)
	-- (spots that can be landed on first, whatever fits as the last resort)
	local nodes = GetAgileSpots(count, info, places, side, true) or GetAgileSpots(count, info, places, side, false)
	if not nodes or #nodes ~= count then
		return nil
	end

	return nodes
end

-- The positions handed out to mUnits: along the drawn line, but see above
local function GetFormationTargets(mUnits, shifted)
	local interpNodes = GetInterpNodes(mUnits)

	local ok, agileNodes = pcall(GetAgileLandingNodes, mUnits, interpNodes, shifted)
	if ok and agileNodes then
		return agileNodes
	end

	return interpNodes
end

-- The dots shown while the line is being drawn: where the units will be sent, which is not along
-- the line when that is too tight for them. Worked out again only when the line has changed.
local previewNodes, previewKey
local function GetPreviewNodes()
	local nodeCount = #fNodes
	local _, _, meta, shift = GetModKeys()
	local shifted = (shift and not meta) and true or false
	local key = nodeCount
		.. ":"
		.. lineLength
		.. ":"
		.. tostring(usingCmd)
		.. ":"
		.. tostring(WG.formationShape)
		.. ":"
		.. selectedUnitsCount
		.. ":"
		.. tostring(shifted)
	if key ~= previewKey then
		previewKey = key
		previewNodes = nil
		if nodeCount >= 2 and usingCmd and shapedCmds[usingCmd] then
			local mUnits = GetExecutingUnits(usingCmd)
			if #mUnits > 1 then
				local ok, nodes = pcall(GetAgileLandingNodes, mUnits, nil, shifted)
				if ok and nodes then
					previewNodes = nodes
				end
			end
		end
	end
	return previewNodes
end

-- What is drawn of them: every dot glides to where it belongs now. The layout is worked out afresh
-- for every bit of line that is added, and without this the dots jump about while the line is
-- still short. Only the preview is eased, the orders are given to the exact spots.
local previewShown, previewShownTime = nil, 0
local previewTargets, previewTargetsFor = nil, nil
local previewEaseRate = 12 -- per second: most of the way in a tenth of a second

-- Which new spot each drawn dot glides to: the nearest one still free, the dots that are furthest
-- from any spot choosing first. Matching them by their number instead sends dots right across the
-- formation whenever the number of rows changes.
local function MatchPreviewTargets(shown, nodes)
	local count = #nodes
	local targets = {}
	local taken = {}

	-- (the dots with the longest way to go first, or they are left with the far corners)
	local order = {}
	for i = 1, count do
		local sx, sz = shown[i][1], shown[i][3]
		local nearest = math.huge
		for j = 1, count do
			local d = (nodes[j][1] - sx) ^ 2 + (nodes[j][3] - sz) ^ 2
			if d < nearest then
				nearest = d
			end
		end
		order[i] = { i, nearest }
	end
	tsort(order, function(a, b)
		return a[2] > b[2]
	end)

	for o = 1, count do
		local i = order[o][1]
		local sx, sz = shown[i][1], shown[i][3]
		local best, bestDist = nil, math.huge
		for j = 1, count do
			if not taken[j] then
				local d = (nodes[j][1] - sx) ^ 2 + (nodes[j][3] - sz) ^ 2
				if d < bestDist then
					best, bestDist = j, d
				end
			end
		end
		taken[best] = true
		targets[i] = nodes[best]
	end

	-- Then trade spots wherever that shortens the squares of the two ways: when a spot goes at one
	-- end of a shape and a new one comes up at the other, everybody moves up one, nobody crosses it
	if count <= 150 then
		for pass = 1, 6 do
			local traded = false
			for i = 1, count - 1 do
				local si = shown[i]
				for j = i + 1, count do
					local sj = shown[j]
					local ti, tj = targets[i], targets[j]
					local kept = (ti[1] - si[1]) ^ 2 + (ti[3] - si[3]) ^ 2 + (tj[1] - sj[1]) ^ 2 + (tj[3] - sj[3]) ^ 2
					local swapped = (tj[1] - si[1]) ^ 2
						+ (tj[3] - si[3]) ^ 2
						+ (ti[1] - sj[1]) ^ 2
						+ (ti[3] - sj[3]) ^ 2
					if swapped < kept - 0.01 then
						targets[i], targets[j] = tj, ti
						traded = true
					end
				end
			end
			if not traded then
				break
			end
		end
	end

	return targets
end

local function GetShownPreviewNodes()
	local nodes = GetPreviewNodes()
	if not nodes then
		previewShown, previewTargets, previewTargetsFor = nil, nil, nil
		return nil
	end

	local now = osclock()
	if not previewShown or #previewShown ~= #nodes or (now - previewShownTime) > 0.5 then
		-- (nothing to glide from: a new group, or a new line)
		previewShown = {}
		for i = 1, #nodes do
			previewShown[i] = { nodes[i][1], nodes[i][2], nodes[i][3] }
		end
		previewTargets, previewTargetsFor = nodes, nodes
	else
		if previewTargetsFor ~= nodes then
			-- the layout has changed (matching is quadratic, a very large group keeps its numbering)
			previewTargets = (#nodes <= 300) and MatchPreviewTargets(previewShown, nodes) or nodes
			previewTargetsFor = nodes
		end
		-- (drawn more than once a frame, world and minimap: the second time no time has passed)
		local blend = 1 - math.exp(-(now - previewShownTime) * previewEaseRate)
		for i = 1, #nodes do
			local shown, node = previewShown[i], previewTargets[i]
			shown[1] = shown[1] + (node[1] - shown[1]) * blend
			shown[2] = shown[2] + (node[2] - shown[2]) * blend
			shown[3] = shown[3] + (node[3] - shown[3]) * blend
		end
	end
	previewShownTime = now

	return previewShown
end

local function GetCmdOpts(alt, ctrl, meta, shift, right)
	local opts = { alt = alt, ctrl = ctrl, meta = meta, shift = shift, right = right }
	local coded = 0

	if alt then
		coded = coded + CMD_OPT_ALT
	end
	if ctrl then
		coded = coded + CMD_OPT_CTRL
	end
	if meta then
		coded = coded + CMD_OPT_META
	end
	if shift then
		coded = coded + CMD_OPT_SHIFT
	end
	if right then
		coded = coded + CMD_OPT_RIGHT
	end

	opts.coded = coded
	return opts
end

local function GiveNotifyingOrder(cmdID, cmdParams, cmdOpts)
	if widgetHandler:CommandNotify(cmdID, cmdParams, cmdOpts) then
		return
	end

	spGiveOrder(cmdID, cmdParams, cmdOpts.coded)
end

local function GiveNotifyingOrderToUnit(uArr, oArr, uID, cmdID, cmdParams, cmdOpts)
	for _, w in ipairs(widgetHandler.widgets) do
		if w.UnitCommandNotify and w:UnitCommandNotify(uID, cmdID, cmdParams, cmdOpts) then
			return
		end
	end

	uArr[#uArr + 1] = uID
	oArr[#oArr + 1] = { cmdID, cmdParams, cmdOpts.coded }
	return
end

function widget:SelectionChanged(sel)
	selectedUnits = sel
	selectedUnitsCount = spGetSelectedUnitsCount()
end

--------------------------------------------------------------------------------
-- Mouse/keyboard Callins
--------------------------------------------------------------------------------

function widget:MousePress(mx, my, mButton)
	lineLength = 0 --for linestipple
	-- Where did we click
	inMinimap = spIsAboveMiniMap(mx, my)
	if inMinimap and not MiniMapFullProxy then
		return false
	end

	if mButton ~= 3 and usingRMB then
		fNodes = {}
		fDists = {}
		usingRMB = false
	end

	if mButton ~= 3 then
		return false
	end --all formation commands are done using right click & drag

	-- Get command that would've been issued
	local _, activeCmdID = spGetActiveCommand()
	if activeCmdID then
		usingCmd = activeCmdID
		usingRMB = true
	else
		local _, defaultCmdID = spGetDefaultCommand() --spGetActiveCommand() returns nil if the default command (typically move) is in use
		if not defaultCmdID then
			return false
		end

		local overrideCmdID = overrideCmds[defaultCmdID]
		if overrideCmdID then
			local targType, targID = spTraceScreenRay(mx, my, false, inMinimap)
			if targType == "unit" then
				overriddenCmd = defaultCmdID
				overriddenTarget = targID
			elseif targType == "feature" then
				overriddenCmd = defaultCmdID
				overriddenTarget = targID + maxUnits
			else
				-- We can't reversibly override a command if we can't get the original target, so we give up overriding it.
				return false
			end

			usingCmd = overrideCmdID
		else
			overriddenCmd = nil
			overriddenTarget = nil

			usingCmd = defaultCmdID
		end

		usingRMB = true
	end

	-- Without this, the unloads issued will use the area of the last area unload
	if usingCmd == CMD_UNLOADUNITS then
		usingCmd = CMD_UNLOADUNIT
	end

	-- Is this command eligible for a custom formation ?
	if not (formationCmds[usingCmd] and (not multiUnitOnlyCmds[usingCmd] or #GetExecutingUnits(usingCmd) > 1)) then
		return false
	end

	-- Get clicked position
	local _, pos = spTraceScreenRay(mx, my, true, inMinimap)
	if not pos then
		return false
	end

	-- Setup formation node array
	if not AddFNode(pos) then
		return false
	end

	local alt, ctrl, meta, shift = spGetModKeyState()

	-- Is this line a path candidate (We don't do a path off an overridden command)
	pathCandidate = (not overriddenCmd) and selectedUnitsCount == 1 and (not shift or repeatForSingleUnit)

	-- Initialize path positions tracking
	pathPositions = {}

	return true
end

function widget:MouseMove(mx, my, dx, dy, mButton)
	-- It is possible for MouseMove to fire after MouseRelease
	if #fNodes == 0 then
		return false
	end

	-- Minimap-specific checks
	if inMinimap then
		totaldxy = totaldxy + dx * dx + dy * dy
		if (totaldxy < 5) or not spIsAboveMiniMap(mx, my) then
			return false
		end
	end

	-- Get clicked position
	local _, pos = spTraceScreenRay(mx, my, true, inMinimap)
	if not pos then
		return false
	end

	-- Add the new formation node
	if not AddFNode(pos) then
		return false
	end

	-- Have we started drawing a line?
	if #fNodes == 2 then
		-- We have enough nodes to start drawing now
		widgetHandler:UpdateWidgetCallIn("DrawInMiniMap", self)
		widgetHandler:UpdateWidgetCallIn("DrawWorld", self)

		-- If the line is a path, start the units moving to this node
		if pathCandidate then
			-- For the first path command, use raw shift state to decide whether to clear queue
			-- This ensures queue is cleared unless user explicitly holds shift
			local alt, ctrl, meta, _ = GetModKeys()
			local _, _, _, rawShift = spGetModKeyState()
			if spGetInvertQueueKey() then
				rawShift = not rawShift
			end
			local cmdOpts = GetCmdOpts(false, ctrl, meta, rawShift, usingRMB) -- using alt uses springs box formation, so we set it off always

			GiveNotifyingOrder(usingCmd, pos, cmdOpts)
			lastPathPos = pos
			pathPositions[1] = { pos[1], pos[2], pos[3] }

			draggingPath = true
		end
	else
		-- Are we dragging a path?
		if draggingPath then
			local dx, dz = pos[1] - lastPathPos[1], pos[3] - lastPathPos[3]
			if (dx * dx + dz * dz) > minPathSpacingSq then
				-- Check if this position is too close to any previously added path position
				local tooClose = false
				for i = 1, #pathPositions do
					local prevPos = pathPositions[i]
					local pdx, pdz = pos[1] - prevPos[1], pos[3] - prevPos[3]
					if (pdx * pdx + pdz * pdz) <= minPathSpacingSq then
						tooClose = true
						break
					end
				end

				-- Only add command if it's not too close to any previous position
				if not tooClose then
					local alt, ctrl, meta, shift = GetModKeys()
					local cmdOpts = GetCmdOpts(false, ctrl, meta, true, usingRMB)

					GiveNotifyingOrder(usingCmd, pos, cmdOpts)
					lastPathPos = pos
					pathPositions[#pathPositions + 1] = { pos[1], pos[2], pos[3] }
				end
			end
		end
	end

	return false
end

function widget:MouseRelease(mx, my, mButton)
	lineLength = 0

	-- It is possible for MouseRelease to fire after MouseRelease
	if #fNodes == 0 then
		return false
	end

	-- Modkeys / command reset
	local alt, ctrl, meta, shift = GetModKeys()
	if not usingRMB then
		if shift then
			endShift = true -- Reset on release of shift
		else
			spSetActiveCommand(0) -- Deselect command
		end
	end

	if selectedUnitsCount == 1 and not shift then
		spSetActiveCommand(0) -- Deselect command
	end

	-- Are we going to use the drawn formation?
	local usingFormation = true

	-- Override checking
	if overriddenCmd then
		local targetID
		local targType, targID = spTraceScreenRay(mx, my, false, inMinimap)
		if targType == "unit" then
			targetID = targID
		elseif targType == "feature" then
			targetID = targID + maxUnits
		end

		if targetID and targetID == overriddenTarget then
			-- Signal that we are no longer using the drawn formation
			usingFormation = false

			-- Process the original command instead
			local cmdOpts = GetCmdOpts(alt, ctrl, meta, shift, usingRMB)
			GiveNotifyingOrder(overriddenCmd, { overriddenTarget }, cmdOpts)
		end
	end

	-- Using path? If so then we do nothing
	if draggingPath then
		draggingPath = false

		-- Using formation? If so then it's time to calculate and issue orders.
	elseif usingFormation then
		-- Add final position (Sometimes we don't get the last MouseMove before this MouseRelease)
		if (not inMinimap) or spIsAboveMiniMap(mx, my) then
			local _, pos = spTraceScreenRay(mx, my, true, inMinimap)
			if pos then
				AddFNode(pos)
			end
		end

		-- Get command options
		local cmdOpts = GetCmdOpts(alt, ctrl, meta, shift, usingRMB)

		-- we add the drag threshold code here
		-- tracing to a point with a drag threshold pixel delta added to mouse coord, to get world distance
		local selectionThreshold = Spring.GetConfigInt("MouseDragFrontCommandThreshold")
		local _, dragDeltaPos = spTraceScreenRay(mx, my + selectionThreshold, true, false, false, true)
		local _, pos = spTraceScreenRay(mx, my, true, false, false, true)
		local dragDelta = 0
		if dragDeltaPos and pos then
			dragDelta = pos[3] - dragDeltaPos[3]
		end
		local adjustedMinFormationLength = max(dragDelta, minFormationLength)

		if
			fDists[#fNodes] < adjustedMinFormationLength
			or (usingCmd == CMD.UNLOAD_UNIT and fDists[#fNodes] < 64 * (selectedUnitsCount - 1))
		then
			-- We should check if any units are able to execute it,
			-- but the order is small enough network-wise that the tiny bug potential isn't worth it.

			-- Check if this order was meant to target a unit
			local targetID
			if overrideCmds[usingCmd] then
				local targType, targID = spTraceScreenRay(mx, my, false, inMinimap)
				if targType == "unit" then
					targetID = targID
				elseif targType == "feature" then
					targetID = targID + maxUnits
				end
			end

			if targetID then
				-- Give order (i.e. pass the command to the engine to use as normal)
				GiveNotifyingOrder(usingCmd, { targetID }, cmdOpts)
			elseif usingCmd == CMD_MOVE then
				GiveNotifyingOrder(usingCmd, { fNodes[1][1], fNodes[1][2], fNodes[1][3] }, cmdOpts)
			else
				-- Deselect command, select default command instead
				spSetActiveCommand(0)
			end
		else
			-- Order is a formation; line was drawn
			-- Are any units able to execute it?
			local mUnits = GetExecutingUnits(usingCmd)

			if #mUnits > 0 then
				local interpNodes = GetFormationTargets(mUnits, shift and not meta)

				local orders
				if #mUnits <= maxHungarianUnits then
					orders = GetOrdersHungarian(interpNodes, mUnits, #mUnits, shift and not meta)
				else
					orders = GetOrdersNoX(interpNodes, mUnits, #mUnits, shift and not meta)
				end

				local unitArr = {}
				local orderArr = {}
				if meta then
					local altOpts = GetCmdOpts(true, false, false, false, false)
					for i = 1, #orders do
						local orderPair = orders[i]
						local orderPos = orderPair[2]
						GiveNotifyingOrderToUnit(
							unitArr,
							orderArr,
							orderPair[1],
							CMD_INSERT,
							{ 0, usingCmd, cmdOpts.coded, orderPos[1], orderPos[2], orderPos[3] },
							altOpts
						)
						if (i == #orders and #unitArr > 0) or #unitArr >= 100 then
							Spring.GiveOrderArrayToUnitArray(unitArr, orderArr, true)
							unitArr = {}
							orderArr = {}
						end
					end
				else
					for i = 1, #orders do
						local orderPair = orders[i]
						GiveNotifyingOrderToUnit(unitArr, orderArr, orderPair[1], usingCmd, orderPair[2], cmdOpts)
						if (i == #orders and #unitArr > 0) or #unitArr >= 100 then
							Spring.GiveOrderArrayToUnitArray(unitArr, orderArr, true)
							unitArr = {}
							orderArr = {}
						end
					end
				end
				if usingCmd == CMD_SETTARGET then
					Spring.SendLuaRulesMsg("settarget_line")
				end
				spSetActiveCommand(0) -- Deselect command
			end
		end
	end

	if #fNodes > 1 then
		dimmCmd = usingCmd
		dimmNodes = fNodes
		dimmAlpha = 1.0
		widgetHandler:UpdateWidgetCallIn("Update", self)
	end

	fNodes = {}
	fDists = {}

	return true
end

function widget:KeyRelease(key)
	if (key == keyShift) and endShift then
		spSetActiveCommand(0)
		endShift = false
	end
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------

local function tVertsMinimap(verts)
	for i = 1, #verts do
		local v = verts[i]
		glVertex(v[1], v[3], 1)
	end
end

local function DrawGroundquad(x, y, z, size)
	glTexCoord(0, 0)
	glVertex(x - size, y, z - size)
	glTexCoord(0, 1)
	glVertex(x - size, y, z + size)
	glTexCoord(1, 1)
	glVertex(x + size, y, z + size)
	glTexCoord(1, 0)
	glVertex(x + size, y, z - size)
end

local function DrawFormationDotQuads(dotSize, lengthPerUnit)
	local shapedNodes = GetShownPreviewNodes()
	if shapedNodes then
		for i = 1, #shapedNodes do
			local node = shapedNodes[i]
			DrawGroundquad(node[1], node[2], node[3], dotSize)
		end
		return
	end

	local nodeCount = #fNodes
	local firstNode = fNodes[1]
	DrawGroundquad(firstNode[1], firstNode[2], firstNode[3], dotSize)

	if nodeCount > 2 then
		local currentLength = 0
		local nextDotLength = lengthPerUnit
		for i = 1, nodeCount - 1 do
			local node = fNodes[i]
			local nextNode = fNodes[i + 1]
			local dx = nextNode[1] - node[1]
			local dy = nextNode[2] - node[2]
			local dz = nextNode[3] - node[3]
			local segmentLength = sqrt(dx * dx + dz * dz)
			local segmentEnd = currentLength + segmentLength
			while segmentEnd >= nextDotLength and nextDotLength < lineLength do
				local factor = (nextDotLength - currentLength) / segmentLength
				DrawGroundquad(node[1] + dx * factor, node[2] + dy * factor, node[3] + dz * factor, dotSize)
				nextDotLength = nextDotLength + lengthPerUnit
			end
			currentLength = segmentEnd
		end
	end

	local lastNode = fNodes[nodeCount]
	DrawGroundquad(lastNode[1], lastNode[2], lastNode[3], dotSize)
end

local function DrawFormationDots(zoomY)
	local lengthPerUnit = lineLength / (selectedUnitsCount - 1)
	local dotSize = sqrt(zoomY * 0.24)
	SetColor(usingCmd, 1)
	if (lengthPerUnit < 64) and (usingCmd == CMD.UNLOAD_UNIT) then
		glColor(1.0, 0.3, 0.0, 1.0)
	end
	glDepthTest(false)
	glTexture(dotImage)
	glBeginEnd(GL_QUADS, DrawFormationDotQuads, dotSize, lengthPerUnit)
	glTexture(false)
	glDepthTest(true)
end

local function DrawFormationLines(vertFunction, lineStipple)
	glLineStipple(lineStipple, 4369)
	glLineWidth(2.0)
	if #fNodes > 1 then
		SetColor(usingCmd, 1.0)
		glBeginEnd(GL_LINE_STRIP, vertFunction, fNodes)
	end
	if #dimmNodes > 1 then
		SetColor(dimmCmd, dimmAlpha)
		glBeginEnd(GL_LINE_STRIP, vertFunction, dimmNodes)
	end
	glLineWidth(1.0)
	glLineStipple(false)
end

local Xs, Ys = spGetViewGeometry()
Xs, Ys = Xs * 0.5, Ys * 0.5
function widget:ViewResize(viewSizeX, viewSizeY)
	Xs, Ys = spGetViewGeometry()
	Xs, Ys = Xs * 0.5, Ys * 0.5
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == "LobbyOverlayActive" then
		chobbyInterface = (msg:sub(1, 19) == "LobbyOverlayActive1")
	end
end

function widget:DrawWorld()
	if chobbyInterface or #fNodes <= 1 or selectedUnitsCount <= 1 or lineLength <= 0 then
		return
	end

	local camX, camY, camZ = spGetCameraPosition()
	local at, p = spTraceScreenRay(Xs, Ys, true, false, false)
	local zoomY
	if at == "ground" then
		local dx, dy, dz = camX - p[1], camY - p[2], camZ - p[3]
		--zoomY = ((dx*dx + dy*dy + dz*dz)*0.01)^0.25	--tests show that sqrt(sqrt(x)) is faster than x^0.25
		zoomY = sqrt(dx * dx + dy * dy + dz * dz)
	else
		--zoomY = sqrt((camY - max(spGetGroundHeight(camX, camZ), 0))*0.1)
		zoomY = camY - max(spGetGroundHeight(camX, camZ), 0)
	end
	if zoomY < 6 then
		zoomY = 6
	end
	DrawFormationDots(zoomY)
	glColor(1, 1, 1, 1)
end

--TODO maybe include minimap drawing again
function widget:DrawInMiniMap()
	glPushMatrix()
	glLoadIdentity()

	local currRot = getCurrentMiniMapRotationOption()
	if currRot == ROTATION.DEG_0 then
		gl.Translate(0, 1, 0)
		gl.Scale(1 / mapSizeX, -1 / mapSizeZ, 1)
	elseif currRot == ROTATION.DEG_90 then
		gl.Scale(-1 / mapSizeZ, 1 / mapSizeX, 1)
		gl.Rotate(90, 0, 0, 1)
	elseif currRot == ROTATION.DEG_180 then
		gl.Translate(1, 0, 0)
		gl.Scale(1 / mapSizeX, 1 / mapSizeZ, 1)
		gl.Rotate(180, 0, 1, 0)
	elseif currRot == ROTATION.DEG_270 then
		gl.Translate(1, 1, 0)
		gl.Scale(-1 / mapSizeZ, 1 / mapSizeX, 1)
		gl.Rotate(-90, 0, 0, 1)
	end

	DrawFormationLines(tVertsMinimap, 1)
	glPopMatrix()
end

function widget:Update(deltaTime)
	dimmAlpha = dimmAlpha - lineFadeRate * deltaTime
	if dimmAlpha <= 0 then
		dimmNodes = {}
		widgetHandler:RemoveWidgetCallIn("Update", self)
		if #fNodes == 0 then
			widgetHandler:RemoveWidgetCallIn("DrawWorld", self)
			widgetHandler:RemoveWidgetCallIn("DrawInMiniMap", self)
		end
	end
end

---------------------------------------------------------------------------------------------------------
-- Config
---------------------------------------------------------------------------------------------------------

function widget:GetConfigData() -- Saving
	return {
		maxHungarianUnits = maxHungarianUnits,
	}
end
function widget:SetConfigData(data) -- Loading
	maxHungarianUnits = data.maxHungarianUnits or defaultHungarianUnits
end

---------------------------------------------------------------------------------------------------------
-- Matching Algorithms
---------------------------------------------------------------------------------------------------------

function GetOrdersNoX(nodes, units, unitCount, shifted)
	-- Remember when  we start
	-- This is for capping total time
	-- Note: We at least complete initial assignment
	local startTime = osclock()

	-- Find initial assignments
	local unitSet = {}
	local fdist = -1
	local fm

	for u = 1, unitCount do
		-- Get unit position
		local ux, uz
		if shifted then
			ux, _, uz = GetUnitFinalPosition(units[u])
		else
			ux, _, uz = spGetUnitPosition(units[u])
		end
		if ux then
			unitSet[u] = { ux, units[u], uz, -1 } -- Such that x/z are in same place as in nodes (So we can use same sort function)

			-- Work on finding furthest points (As we have ux/uz already)
			for i = u - 1, 1, -1 do
				local up = unitSet[i]
				local vx, vz = up[1], up[3]
				local dx, dz = vx - ux, vz - uz
				local dist = dx * dx + dz * dz

				if dist > fdist then
					fdist = dist
					fm = (vz - uz) / (vx - ux)
				end
			end
		end
	end

	-- Maybe nodes are further apart than the units
	for i = 1, unitCount - 1 do
		local np = nodes[i]
		local nx, nz = np[1], np[3]

		for j = i + 1, unitCount do
			local mp = nodes[j]
			local mx, mz = mp[1], mp[3]
			local dx, dz = mx - nx, mz - nz
			local dist = dx * dx + dz * dz

			if dist > fdist then
				fdist = dist
				fm = (mz - nz) / (mx - nx)
			end
		end
	end

	local fminv = 1.0 / fm
	local function sortFunc(a, b)
		-- y = mx + c
		-- c = y - mx
		-- c = y + x / m (For perp line)
		return (a[3] + a[1] * fminv) < (b[3] + b[1] * fminv)
	end

	tsort(unitSet, sortFunc)
	tsort(nodes, sortFunc)

	for u = 1, unitCount do
		unitSet[u][4] = nodes[u]
	end

	---------------------------------------------------------------------------------------------------------
	-- Main part of algorithm
	---------------------------------------------------------------------------------------------------------

	-- M/C for each finished matching
	local Ms = {}
	local Cs = {}

	-- Stacks to hold finished and still-to-check units
	local stFin = {}
	local stFinCnt = 0
	local stChk = {}
	local stChkCnt = 0

	-- Add all units to check stack
	for u = 1, unitCount do
		stChk[u] = u
	end
	stChkCnt = unitCount

	-- Begin algorithm
	while (stChkCnt > 0) and (osclock() - startTime < maxNoXTime) do
		-- Get unit, extract position and matching node position
		local u = stChk[stChkCnt]
		local ud = unitSet[u]
		local ux, uz = ud[1], ud[3]
		local mn = ud[4]
		local nx, nz = mn[1], mn[3]

		-- Calculate M/C
		local Mu = (nz - uz) / (nx - ux)
		local Cu = uz - Mu * ux

		-- Check for clashes against finished matches
		local clashes = false

		for i = 1, stFinCnt do
			-- Get opposing unit and matching node position
			local f = stFin[i]
			local fd = unitSet[f]
			local tn = fd[4]

			-- Get collision point
			local ix = (Cs[f] - Cu) / (Mu - Ms[f])
			local iz = Mu * ix + Cu

			-- Check bounds
			if
				((ux - ix) * (ix - nx) >= 0)
				and ((uz - iz) * (iz - nz) >= 0)
				and ((fd[1] - ix) * (ix - tn[1]) >= 0)
				and ((fd[3] - iz) * (iz - tn[3]) >= 0)
			then
				-- Lines cross

				-- Swap matches, note this retains solution integrity
				ud[4] = tn
				fd[4] = mn

				-- Remove clashee from finished
				stFin[i] = stFin[stFinCnt]
				stFinCnt = stFinCnt - 1

				-- Add clashee to top of check stack
				stChkCnt = stChkCnt + 1
				stChk[stChkCnt] = f

				-- No need to check further
				clashes = true
				break
			end
		end

		if not clashes then
			-- Add checked unit to finished
			stFinCnt = stFinCnt + 1
			stFin[stFinCnt] = u

			-- Remove from to-check stack (Easily done, we know it was one on top)
			stChkCnt = stChkCnt - 1

			-- We can set the M/C now
			Ms[u] = Mu
			Cs[u] = Cu
		end
	end

	---------------------------------------------------------------------------------------------------------
	-- Return orders
	---------------------------------------------------------------------------------------------------------
	local orders = {}
	for i = 1, unitCount do
		local unit = unitSet[i]
		orders[i] = { unit[2], unit[4] }
	end
	return orders
end

function GetOrdersHungarian(nodes, units, unitCount, shifted, adjustLimit)
	-------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------
	-- (the following code is written by gunblob)
	--   this code finds the optimal solution (slow, but effective!)
	--   it uses the hungarian algorithm from http://www.public.iastate.edu/~ddoty/HungarianAlgorithm.html
	--   if this violates gpl license please let gunblob and me know
	-------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------
	local t = osclock()

	--------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------
	-- cache node<->unit distances

	local distances = {}
	--for i = 1, unitCount do distances[i] = {} end

	for i = 1, unitCount do
		local uID = units[i]
		local ux, uz

		if shifted then
			ux, _, uz = GetUnitFinalPosition(uID)
		else
			ux, _, uz = spGetUnitPosition(uID)
		end
		if ux then
			distances[i] = {}
			local dists = distances[i]
			for j = 1, unitCount do
				local nodePos = nodes[j]
				local dx, dz = nodePos[1] - ux, nodePos[3] - uz
				dists[j] = floor(sqrt(dx * dx + dz * dz) + 0.5)
				-- Integer distances = greatly improved algorithm speed
			end
		end
	end

	--------------------------------------------------------------------------------------------
	-- find optimal solution and send orders
	local result = findHungarian(distances, unitCount)
	--------------------------------------------------------------------------------------------
	-- determine needed time and optimize the maxUnits limit

	local delay = osclock() - t

	if adjustLimit ~= false and (delay > maxHngTime) and (maxHungarianUnits > minHungarianUnits) then
		-- Delay is greater than desired, we have to reduce units
		maxHungarianUnits = maxHungarianUnits - 1
	elseif adjustLimit ~= false then
		-- Delay is less than desired, so that's OK
		-- To make judgements we need number of units to be close to max
		-- Because we are making predictions of time and we want them to be accurate
		if #units > maxHungarianUnits * unitIncreaseThresh then
			-- This implementation of Hungarian algorithm is O(n3)
			-- Because we have less than maxUnits, but are altering maxUnits...
			-- We alter the time, to 'predict' time we would be getting at maxUnits
			-- We then recheck that against maxHngTime

			local nMult = maxHungarianUnits / #units

			if (delay * nMult * nMult * nMult) < maxHngTime then
				maxHungarianUnits = maxHungarianUnits + 1
			else
				if maxHungarianUnits > minHungarianUnits then
					maxHungarianUnits = maxHungarianUnits - 1
				end
			end
		end
	end

	-- Return orders
	local orders = {}
	for i = 1, unitCount do
		local rPair = result[i]
		orders[i] = { units[rPair[1]], nodes[rPair[2]] }
	end

	return orders
end

function findHungarian(array, n)
	-- Vars
	local colcover = {}
	local rowcover = {}
	local starscol = {}
	local primescol = {}

	-- Initialization
	for i = 1, n do
		rowcover[i] = false
		colcover[i] = false
		starscol[i] = false
		primescol[i] = false
	end

	-- Subtract minimum from rows
	for i = 1, n do
		local aRow = array[i]
		local minVal = aRow[1]
		for j = 2, n do
			if aRow[j] < minVal then
				minVal = aRow[j]
			end
		end

		for j = 1, n do
			aRow[j] = aRow[j] - minVal
		end
	end

	-- Subtract minimum from columns
	for j = 1, n do
		local minVal = array[1][j]
		for i = 2, n do
			if array[i][j] < minVal then
				minVal = array[i][j]
			end
		end

		for i = 1, n do
			array[i][j] = array[i][j] - minVal
		end
	end

	-- Star zeroes
	for i = 1, n do
		local aRow = array[i]
		for j = 1, n do
			if (aRow[j] == 0) and not colcover[j] then
				colcover[j] = true
				starscol[i] = j
				break
			end
		end
	end

	-- Start solving system
	while true do
		-- Are we done ?
		local done = true
		for i = 1, n do
			if not colcover[i] then
				done = false
				break
			end
		end

		if done then
			local pairings = {}
			for i = 1, n do
				pairings[i] = { i, starscol[i] }
			end
			return pairings
		end

		-- Not done
		local r, c = stepPrimeZeroes(array, colcover, rowcover, n, starscol, primescol)
		stepFiveStar(colcover, rowcover, r, c, n, starscol, primescol)
	end
end

function doPrime(array, colcover, rowcover, n, starscol, r, c, rmax, primescol)
	primescol[r] = c
	local starCol = starscol[r]

	if starCol then
		rowcover[r] = true
		colcover[starCol] = false

		for i = 1, rmax do
			if not rowcover[i] and (array[i][starCol] == 0) then
				local rr, cc = doPrime(array, colcover, rowcover, n, starscol, i, starCol, rmax, primescol)
				if rr then
					return rr, cc
				end
			end
		end

		return
	else
		return r, c
	end
end

function stepPrimeZeroes(array, colcover, rowcover, n, starscol, primescol)
	-- Infinite loop
	while true do
		-- Find uncovered zeros and prime them
		for i = 1, n do
			if not rowcover[i] then
				local aRow = array[i]
				for j = 1, n do
					if (aRow[j] == 0) and not colcover[j] then
						local i, j = doPrime(array, colcover, rowcover, n, starscol, i, j, i - 1, primescol)
						if i then
							return i, j
						end
						break -- this row is covered
					end
				end
			end
		end

		-- Find minimum uncovered
		local minVal = huge
		for i = 1, n do
			if not rowcover[i] then
				local aRow = array[i]
				for j = 1, n do
					if (aRow[j] < minVal) and not colcover[j] then
						minVal = aRow[j]
					end
				end
			end
		end

		-- There is the potential for minVal to be 0, very very rarely though. (Checking for it costs more than the +/- 0's)

		-- Covered rows = +
		-- Uncovered cols = -
		for i = 1, n do
			local aRow = array[i]
			if rowcover[i] then
				for j = 1, n do
					if colcover[j] then
						aRow[j] = aRow[j] + minVal
					end
				end
			else
				for j = 1, n do
					if not colcover[j] then
						aRow[j] = aRow[j] - minVal
					end
				end
			end
		end
	end
end

function stepFiveStar(colcover, rowcover, row, col, n, starscol, primescol)
	-- Star the initial prime
	primescol[row] = false
	starscol[row] = col
	local ignoreRow = row -- Ignore the star on this row when looking for next

	repeat
		local noFind = true

		for i = 1, n do
			if (starscol[i] == col) and (i ~= ignoreRow) then
				noFind = false

				-- Unstar the star
				-- Turn the prime on the same row into a star (And ignore this row (aka star) when searching for next star)

				local pcol = primescol[i]
				primescol[i] = false
				starscol[i] = pcol
				ignoreRow = i
				col = pcol

				break
			end
		end
	until noFind

	for i = 1, n do
		rowcover[i] = false
		colcover[i] = false
		primescol[i] = false
	end

	for i = 1, n do
		local scol = starscol[i]
		if scol then
			colcover[scol] = true
		end
	end
end

function widget:Initialize()
	WG.customformations = {}
	WG.customformations.getRepeatForSingleUnit = function()
		return repeatForSingleUnit
	end
	WG.customformations.setRepeatForSingleUnit = function(value)
		repeatForSingleUnit = value
	end

	-- External formation dragging API (for PIP window, etc.)
	local isFirstPathCommand = true -- Track whether next path command should clear queue

	WG.customformations.StartFormation = function(worldPos, cmdID, fromMinimap)
		-- Reset state
		fNodes = {}
		fDists = {}
		totaldxy = 0
		lineLength = 0
		pathCandidate = false
		draggingPath = false
		lastPathPos = nil
		pathPositions = {}
		overriddenCmd = nil
		overriddenTarget = nil
		isFirstPathCommand = true -- Reset for new formation

		-- Set command
		usingCmd = cmdID or CMD_MOVE
		usingRMB = true
		inMinimap = fromMinimap or false

		-- Add first node
		if AddFNode(worldPos) then
			local alt, ctrl, meta, shift = spGetModKeyState()
			pathCandidate = selectedUnitsCount == 1 and (not shift or repeatForSingleUnit)
			return true
		end
		return false
	end

	WG.customformations.AddFormationNode = function(worldPos)
		if #fNodes == 0 then
			return false
		end

		local added = AddFNode(worldPos)

		-- Start drawing when we have 2+ nodes
		if #fNodes == 2 then
			widgetHandler:UpdateWidgetCallIn("DrawWorld", self)
			widgetHandler:UpdateWidgetCallIn("DrawInMiniMap", self)
		end

		-- Path handling
		if #fNodes > 1 and pathCandidate then
			local minDist = minPathSpacingSq
			if lastPathPos then
				local dx, dz = worldPos[1] - lastPathPos[1], worldPos[3] - lastPathPos[3]
				local distSq = dx * dx + dz * dz
				if distSq >= minDist then
					-- Check if this position is too close to any previously added path position
					local tooClose = false
					for i = 1, #pathPositions do
						local prevPos = pathPositions[i]
						local pdx, pdz = worldPos[1] - prevPos[1], worldPos[3] - prevPos[3]
						if (pdx * pdx + pdz * pdz) <= minPathSpacingSq then
							tooClose = true
							break
						end
					end

					-- Only add command if it's not too close to any previous position
					if not tooClose then
						draggingPath = true
						-- Use raw shift for first path command, GetModKeys for subsequent
						local alt, ctrl, meta, shift = GetModKeys()
						if isFirstPathCommand then
							-- First command: use raw shift to decide queue clearing
							_, _, _, shift = spGetModKeyState()
							if spGetInvertQueueKey() then
								shift = not shift
							end
							isFirstPathCommand = false
						end
						local cmdOpts = GetCmdOpts(alt, ctrl, meta, shift, usingRMB)
						GiveNotifyingOrder(usingCmd, worldPos, cmdOpts)
						lastPathPos = worldPos
						pathPositions[#pathPositions + 1] = { worldPos[1], worldPos[2], worldPos[3] }
					end
				end
			else
				lastPathPos = worldPos
				pathPositions[1] = { worldPos[1], worldPos[2], worldPos[3] }
			end
		end

		return added
	end

	WG.customformations.EndFormation = function(worldPos, cmdID)
		if #fNodes == 0 then
			return false
		end

		-- Add final position
		if worldPos then
			AddFNode(worldPos)
		end

		-- Determine if we used the formation
		local usingFormation = not draggingPath
		local result = false

		if usingFormation then
			-- Use raw shift for single-click orders (first command should clear queue unless user holds shift)
			local alt, ctrl, meta, shift = GetModKeys()
			if isFirstPathCommand then
				-- This is effectively a single click or very short drag - use raw shift
				_, _, _, shift = spGetModKeyState()
				if spGetInvertQueueKey() then
					shift = not shift
				end
			end
			local cmdOpts = GetCmdOpts(alt, ctrl, meta, shift, usingRMB)

			-- Get drag threshold
			local selectionThreshold = Spring.GetConfigInt("MouseDragFrontCommandThreshold") or 20
			local dragDelta = selectionThreshold -- Approximate for external callers
			local adjustedMinFormationLength = max(dragDelta, minFormationLength)

			if
				fDists[#fNodes] < adjustedMinFormationLength
				or (usingCmd == CMD.UNLOAD_UNIT and fDists[#fNodes] < 64 * (selectedUnitsCount - 1))
			then
				-- Single-click style order
				if usingCmd == CMD_MOVE and #fNodes > 0 then
					GiveNotifyingOrder(usingCmd, { fNodes[1][1], fNodes[1][2], fNodes[1][3] }, cmdOpts)
					result = true
				end
			else
				-- Formation order
				local mUnits = GetExecutingUnits(usingCmd)
				if #mUnits > 0 then
					local interpNodes = GetFormationTargets(mUnits, shift and not meta)
					local orders
					if #mUnits <= maxHungarianUnits then
						orders = GetOrdersHungarian(interpNodes, mUnits, #mUnits, shift and not meta)
					else
						orders = GetOrdersNoX(interpNodes, mUnits, #mUnits, shift and not meta)
					end

					local unitArr = {}
					local orderArr = {}
					if meta then
						local altOpts = GetCmdOpts(true, false, false, false, false)
						for i = 1, #orders do
							local orderPair = orders[i]
							local orderPos = orderPair[2]
							GiveNotifyingOrderToUnit(
								unitArr,
								orderArr,
								orderPair[1],
								CMD_INSERT,
								{ 0, usingCmd, cmdOpts.coded, orderPos[1], orderPos[2], orderPos[3] },
								altOpts
							)
							if (i == #orders and #unitArr > 0) or #unitArr >= 100 then
								Spring.GiveOrderArrayToUnitArray(unitArr, orderArr, true)
								unitArr = {}
								orderArr = {}
							end
						end
					else
						for i = 1, #orders do
							local orderPair = orders[i]
							GiveNotifyingOrderToUnit(unitArr, orderArr, orderPair[1], usingCmd, orderPair[2], cmdOpts)
							if (i == #orders and #unitArr > 0) or #unitArr >= 100 then
								Spring.GiveOrderArrayToUnitArray(unitArr, orderArr, true)
								unitArr = {}
								orderArr = {}
							end
						end
					end
					result = true
				end
			end
		end

		-- Show dimming line
		if #fNodes > 1 then
			dimmCmd = usingCmd
			dimmNodes = fNodes
			dimmAlpha = 1.0
			widgetHandler:UpdateWidgetCallIn("Update", self)
		end

		-- Reset
		fNodes = {}
		fDists = {}
		draggingPath = false

		return result
	end

	WG.customformations.CancelFormation = function()
		fNodes = {}
		fDists = {}
		draggingPath = false
		pathCandidate = false
		pathPositions = {}
		return true
	end

	WG.customformations.IsFormationActive = function()
		return #fNodes > 0
	end

	WG.customformations.GetFormationNodes = function()
		return fNodes
	end

	WG.customformations.GetFormationCommand = function()
		return usingCmd
	end

	WG.customformations.GetFormationLineLength = function()
		return lineLength
	end

	WG.customformations.GetSelectedUnitsCount = function()
		return selectedUnitsCount
	end

	WG.customformations.GetFormationOrders = function()
		if #fNodes < 2 then
			return nil
		end

		local _, _, meta, shift = GetModKeys()
		local shifted = shift and not meta
		if formationOrdersVersion ~= formationVersion or formationOrdersShifted ~= shifted then
			local mUnits = GetExecutingUnits(usingCmd)
			if #mUnits == 0 then
				return nil
			end
			local interpNodes = GetFormationTargets(mUnits, shifted)
			local orders
			if #mUnits <= maxHungarianUnits then
				orders = GetOrdersHungarian(interpNodes, mUnits, #mUnits, shifted, false)
			else
				orders = GetOrdersNoX(interpNodes, mUnits, #mUnits, shifted)
			end

			formationOrders = {}
			for i = 1, #orders do
				local order = orders[i]
				formationOrders[order[1]] = order[2]
			end
			formationOrdersVersion = formationVersion
			formationOrdersShifted = shifted
		end
		return formationOrders
	end
end

function widget:Shutdown()
	WG.customformations = nil
end
