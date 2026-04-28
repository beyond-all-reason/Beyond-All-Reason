function widget:GetInfo()
	return {
		name      = "Start Positions Tool",
		desc      = "Place and configure start positions and start boxes for map editing",
		author    = "Terraform Brush Team",
		date      = "2026",
		license   = "GPL v2",
		layer     = 0,
		enabled   = true,
		handler   = true,
	}
end

-- ============================================================
-- Spring API Caching
-- ============================================================
local Spring          = Spring
local Echo            = Spring.Echo
local GetMouseState   = Spring.GetMouseState
local TraceScreenRay  = Spring.TraceScreenRay
local GetGroundHeight = Spring.GetGroundHeight
local GetViewGeometry = Spring.GetViewGeometry
local GetMapSize      = Spring.GetMapSize or function() return Game.mapSizeX, Game.mapSizeZ end
local WorldToScreenCoords = Spring.WorldToScreenCoords
local GetDrawFrame    = Spring.GetDrawFrame

local gl = gl
local glColor         = gl.Color
local glLineWidth     = gl.LineWidth
local glDrawGroundCircle = gl.DrawGroundCircle
local glPushMatrix    = gl.PushMatrix
local glPopMatrix     = gl.PopMatrix
local glTranslate     = gl.Translate
local glRotate        = gl.Rotate
local glScale         = gl.Scale
local glBillboard     = gl.Billboard
local glText          = gl.Text
local glBeginEnd      = gl.BeginEnd
local glVertex        = gl.Vertex
local glTexture       = gl.Texture
local glTexRect       = gl.TexRect
local glBlending      = gl.Blending
local glDepthTest     = gl.DepthTest
local glCreateList    = gl.CreateList
local glCallList      = gl.CallList
local glDeleteList    = gl.DeleteList
local GL_LINE_LOOP    = GL.LINE_LOOP
local GL_LINE_STRIP   = GL.LINE_STRIP
local GL_LINES        = GL.LINES
local GL_TRIANGLE_FAN = GL.TRIANGLE_FAN
local GL_TRIANGLE_STRIP = GL.TRIANGLE_STRIP
local GL_TRIANGLES    = GL.TRIANGLES
local GL_SRC_ALPHA    = GL.SRC_ALPHA
local GL_ONE          = GL.ONE
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA

-- Commander icons cycled by allyteam index — adds visual variety & "2026" faction flavor
local COMMANDER_ICONS = {
	"icons/armcom.png",
	"icons/corcom.png",
	"icons/legcom.png",
}

local DRAGGABLE_DIST_SQ = 120 * 120  -- world distance² inside which cursor becomes "move"

local math_floor = math.floor
local math_sqrt  = math.sqrt
local math_sin   = math.sin
local math_cos   = math.cos
local math_pi    = math.pi
local math_max   = math.max
local math_min   = math.min
local math_random = math.random
local math_atan2 = math.atan2

-- ============================================================
-- Constants
-- ============================================================
local MARKER_RADIUS       = 80     -- world radius of start position marker circle
local MARKER_SEGMENTS     = 32     -- circle smoothness
local DRAG_THRESHOLD_SQ   = 25     -- pixels^2 before drag starts
local CLICK_DISTANCE_SQ   = 120*120 -- world distance^2 to pick a marker
local MIN_RADIUS          = 64
local MAX_RADIUS          = 16384  -- allow full-map shapes
local RADIUS_STEP         = 32     -- scroll step for startpos mode (faster)
local MAX_POSITIONS       = 256    -- absolute hard cap (players)
local MAX_ALLYTEAMS       = 32     -- max configurable ally teams
local MAX_TEAMS_PER_ALLY  = 16     -- max team slots per ally team
local SAVE_DIR            = "Terraform Brush/StartPositions/"
local STARTBOX_SAVE_DIR   = "Terraform Brush/Startboxes/"
local VERTEX_PICK_DIST_SQ = 60*60  -- world distance^2 to pick a startbox vertex

-- Team colors matching game_autocolors.lua FFA palette (0-1 float RGBA); extended past 16 for 256-player support
local TEAM_COLORS = {
	{0.000, 0.302, 1.000, 1.0},  --  1: Blue       #004DFF
	{1.000, 0.063, 0.020, 1.0},  --  2: Red        #FF1005
	{0.047, 0.914, 0.031, 1.0},  --  3: Green      #0CE908
	{1.000, 0.824, 0.000, 1.0},  --  4: Yellow     #FFD200
	{0.973, 0.031, 0.537, 1.0},  --  5: Fuchsia    #F80889
	{0.035, 0.961, 0.961, 1.0},  --  6: Cyan       #09F5F5
	{1.000, 0.380, 0.027, 1.0},  --  7: Orange     #FF6107
	{0.945, 0.565, 0.702, 1.0},  --  8: Pink       #F190B3
	{0.035, 0.494, 0.110, 1.0},  --  9: Dark Green #097E1C
	{0.784, 0.545, 0.184, 1.0},  -- 10: Brown      #C88B2F
	{0.486, 0.631, 1.000, 1.0},  -- 11: Light Blue #7CA1FF
	{0.624, 0.051, 0.020, 1.0},  -- 12: Dark Red   #9F0D05
	{0.243, 1.000, 0.635, 1.0},  -- 13: Mint       #3EFFA2
	{0.961, 0.635, 0.000, 1.0},  -- 14: Amber      #F5A200
	{0.769, 0.663, 1.000, 1.0},  -- 15: Lavender   #C4A9FF
	{0.043, 0.518, 0.608, 1.0},  -- 16: Teal       #0B849B
	{0.600, 0.200, 0.800, 1.0},  -- 17: Purple
	{0.900, 0.500, 0.100, 1.0},  -- 18: Burnt Orange
	{0.400, 0.800, 0.700, 1.0},  -- 19: Seafoam
	{0.800, 0.100, 0.400, 1.0},  -- 20: Magenta
	{0.300, 0.600, 0.100, 1.0},  -- 21: Olive
	{0.100, 0.400, 0.700, 1.0},  -- 22: Navy
	{0.950, 0.850, 0.400, 1.0},  -- 23: Pale Gold
	{0.500, 0.500, 0.500, 1.0},  -- 24: Gray
	{0.900, 0.900, 0.900, 1.0},  -- 25: White
	{0.200, 0.200, 0.200, 1.0},  -- 26: Charcoal
	{0.700, 0.300, 0.300, 1.0},  -- 27: Rose
	{0.300, 0.700, 0.500, 1.0},  -- 28: Jade
	{0.500, 0.300, 0.100, 1.0},  -- 29: Chocolate
	{0.900, 0.400, 0.600, 1.0},  -- 30: Flamingo
	{0.200, 0.800, 0.900, 1.0},  -- 31: Sky
	{0.700, 0.800, 0.200, 1.0},  -- 32: Lime
}

-- ============================================================
-- State
-- ============================================================
local active     = false
local subMode    = "express"  -- "express" | "shape" | "startbox"
local positions  = {}         -- { {x=, z=, allyTeam=, teamSlot=, playerIdx=}, ... }
local nextAllyTeam = 1        -- next allyteam in rotation
local nextTeamSlot = 1        -- next player slot within that allyteam
local numAllyTeams = 2        -- configurable count (ally teams)
local numTeamsPerAlly = 1     -- configurable count (players per ally)
local placementMode = "roundrobin" -- "roundrobin" = A,B,C,A,B,C... | "sequential" = A,A,B,B,C,C...

-- Shape placement state
local shapeType      = "circle"  -- "circle"|"square"|"hexagon"|"octagon"|"triangle"
local shapeRadius    = 2000
local shapeRotation  = 0    -- degrees
local shapeCount     = 4    -- number of positions to place with shape
local shapePreview   = {}   -- preview positions for shape mode
local shapeCenterX   = nil  -- shape center (set on click)
local shapeCenterZ   = nil

-- Startbox state
local startboxes     = {}   -- { {vertices={{x=,z=}, ...}, allyTeam=}, ... }
-- Forward declarations for cached-fill-list helpers defined further down in the drawing section.
-- Needed because removeLastStartbox / clearAllStartboxes / drag handlers reference them from
-- this upper part of the file.
local ensureBoxFillList, invalidateBoxFill, freeBoxFillList
-- Forward decl: world radius needed for a constant on-screen pixel size at (wx, wz).
-- Used by DrawWorld for handles/arrows so they keep size while zooming. Defined alongside
-- getScreenMarker further down in the rendering section.
local worldRadiusForScreenPx
local startboxMode   = "polygon" -- "polygon" | "box" | "freedraw"
local drawingBox     = false
local currentBoxVerts = {}
local boxDragIdx     = nil  -- which vertex is being dragged
local boxDragBoxIdx  = nil  -- which box
local boxEdgeDrag    = nil  -- { bi = <box index>, edge = "L"/"R"/"T"/"B" } for box-kind edge drag
local hoverBoxEdge   = nil  -- { bi, edge } for hover highlight of the edge currently under cursor
local nextBoxAllyTeam = 1
-- Whole-box drag (mouse pressed inside a startbox body, not on a handle/edge). Records the
-- world-space cursor delta between frames and offsets every vertex (and spline control point
-- when applicable). Separate from vertex-drag so hover hit-tests stay simple.
local boxBodyDrag    = nil  -- { bi = <box index>, lastX = <world x>, lastZ = <world z> }
-- Set true whenever a startbox vertex / edge / body drag is in progress. Used by
-- ensureBoxFillList to defer the expensive fill-list rebuild until MouseRelease.
local isDraggingBox  = false
local pendingFillRebuildIdx = nil  -- box index whose fill needs rebuilding on drag end
-- Box drag-rect (startboxMode == "box"): two corners, live-updated during drag
local boxRectStartX  = nil
local boxRectStartZ  = nil
local boxRectEndX    = nil
local boxRectEndZ    = nil
local boxRectActive  = false
-- Free-draw state (startboxMode == "freedraw"): collect points with minimum spacing
local freeDrawPts    = {}
local freeDrawActive = false
local FREEDRAW_MIN_DIST_SQ = 40 * 40   -- minimum world distance between sample points

-- Drag state
local dragging       = false
local dragIdx        = nil  -- which position index is being dragged
local dragStartX     = nil
local dragStartY     = nil  -- screen coords at mouse-down
local mouseDownWorldX = nil
local mouseDownWorldZ = nil

-- Hover state (drives cursor + marker highlight)
local hoverPosIdx    = nil  -- index of position currently hovered (express mode)
local hoverBoxIdx    = nil  -- which startbox is being vertex-hovered
local hoverVertIdx   = nil
-- Polygon edge-midpoint hover: shows a "ghost" handle at the middle of a polygon edge
-- so the user can click/hold there to insert a new vertex (which immediately becomes a
-- live drag handle). { bi, edgeIdx, x, z } — edgeIdx is index of the edge's start vertex.
local hoverPolyEdge  = nil

-- Undo history: each entry = { count=N, prevNextAllyTeam=M }
-- Means: the last N entries in `positions` were added in one action;
-- restoring removes them and rewinds nextAllyTeam to M.
local undoHistory    = {}

-- ============================================================
-- Helper Functions
-- ============================================================

local function getWorldMousePosition()
	local mx, my = GetMouseState()
	local _, pos = TraceScreenRay(mx, my, true)
	if pos then
		return pos[1], pos[3]
	end
	return nil, nil
end

local function getColorForAllyTeam(at)
	local idx = ((at - 1) % #TEAM_COLORS) + 1
	return TEAM_COLORS[idx]
end

-- Unique color per (allyTeam, teamSlot) pair — gives every player a distinct color
-- when multiple teams per allyteam are used. playerIdx = (allyTeam-1)*numTeamsPerAlly + teamSlot.
local function getColorForPlayer(playerIdx)
	local idx = ((playerIdx - 1) % #TEAM_COLORS) + 1
	return TEAM_COLORS[idx]
end

local function distSq(x1, z1, x2, z2)
	local dx = x1 - x2
	local dz = z1 - z2
	return dx * dx + dz * dz
end

local function clampToMap(x, z)
	local mapX, mapZ = Game.mapSizeX, Game.mapSizeZ
	x = math_max(0, math_min(mapX, x))
	z = math_max(0, math_min(mapZ, z))
	return x, z
end

-- ============================================================
-- Shape Position Generation
-- ============================================================

local function generateCirclePositions(cx, cz, radius, count, rotation)
	local pts = {}
	local angleStep = (2 * math_pi) / count
	local rotRad = rotation * math_pi / 180
	for i = 1, count do
		local angle = rotRad + (i - 1) * angleStep
		local x = cx + radius * math_cos(angle)
		local z = cz + radius * math_sin(angle)
		x, z = clampToMap(x, z)
		pts[#pts + 1] = {x = x, z = z}
	end
	return pts
end

local function generatePolygonPositions(cx, cz, radius, sides, count, rotation)
	-- Place positions on vertices first, then midpoints if count > sides
	local pts = {}
	local rotRad = rotation * math_pi / 180
	-- Generate all vertices
	local vertices = {}
	for i = 1, sides do
		local angle = rotRad + (i - 1) * (2 * math_pi / sides)
		vertices[i] = {
			x = cx + radius * math_cos(angle),
			z = cz + radius * math_sin(angle),
		}
	end
	-- Fill positions: vertices first, then midpoints, then quarter-points, etc.
	local allPoints = {}
	-- Start with vertices
	for i = 1, sides do
		allPoints[#allPoints + 1] = vertices[i]
	end
	-- If we need more, add midpoints between each pair of vertices
	local level = 1
	while #allPoints < count do
		local newPoints = {}
		local prevPoints = {}
		-- Collect edge endpoints at current subdivision level
		-- At level 1: midpoints between vertices
		-- At level 2: midpoints of those segments, etc.
		local segCount = sides * (2 ^ (level - 1))
		for i = 1, #allPoints do
			local j = (i % #allPoints) + 1
			local mx = (allPoints[i].x + allPoints[j].x) * 0.5
			local mz = (allPoints[i].z + allPoints[j].z) * 0.5
			prevPoints[#prevPoints + 1] = allPoints[i]
			prevPoints[#prevPoints + 1] = {x = mx, z = mz}
		end
		allPoints = prevPoints
		level = level + 1
		if level > 6 then break end -- safety cap
	end
	-- Take up to count points
	for i = 1, math_min(count, #allPoints) do
		local x, z = clampToMap(allPoints[i].x, allPoints[i].z)
		pts[i] = {x = x, z = z}
	end
	return pts
end

local function generateSquarePositions(cx, cz, radius, count, rotation)
	return generatePolygonPositions(cx, cz, radius, 4, count, rotation)
end

local function generateShapePositions(cx, cz)
	local sides = ({
		circle   = 0,
		square   = 4,
		triangle = 3,
		hexagon  = 6,
		octagon  = 8,
	})[shapeType] or 0

	if sides == 0 then
		return generateCirclePositions(cx, cz, shapeRadius, shapeCount, shapeRotation)
	else
		return generatePolygonPositions(cx, cz, shapeRadius, sides, shapeCount, shapeRotation)
	end
end

local function generateRandomPositions(cx, cz)
	local pts = {}
	local sides = ({
		circle   = 0,
		square   = 4,
		triangle = 3,
		hexagon  = 6,
		octagon  = 8,
	})[shapeType] or 0

	for i = 1, shapeCount do
		if sides == 0 then
			-- Random within circle
			local angle = math_random() * 2 * math_pi
			local r = shapeRadius * math_sqrt(math_random())
			local x = cx + r * math_cos(angle)
			local z = cz + r * math_sin(angle)
			x, z = clampToMap(x, z)
			pts[i] = {x = x, z = z}
		else
			-- Random within polygon bounds (simple: use bounding circle, reject outside polygon)
			-- For simplicity, use full radius bounding circle and accept
			local angle = math_random() * 2 * math_pi
			local r = shapeRadius * math_sqrt(math_random())
			local x = cx + r * math_cos(angle)
			local z = cz + r * math_sin(angle)
			x, z = clampToMap(x, z)
			pts[i] = {x = x, z = z}
		end
	end
	return pts
end

-- ============================================================
-- Core Operations
-- ============================================================

-- Commander-slope tolerance (cached). Engine-transferable across Recoil games: we scan
-- UnitDefs for units flagged as commanders via common customParams conventions. If no
-- commander-tagged units exist, we fall back to the smallest maxSlope among any grounded
-- movedef (conservative: picks the most restrictive). Result is in the same normalized
-- "1 - cos(angle)" space that `Spring.GetGroundNormal` returns as its 4th value.
local _cachedCommanderMaxSlope = nil
local function getCommanderMaxSlope()
	if _cachedCommanderMaxSlope ~= nil then
		return _cachedCommanderMaxSlope or nil
	end
	-- Mod-option override (per-game tunable without code changes)
	local modOpt = Spring.GetModOptions and Spring.GetModOptions()
	if modOpt and tonumber(modOpt.startpos_max_slope) then
		_cachedCommanderMaxSlope = tonumber(modOpt.startpos_max_slope)
		return _cachedCommanderMaxSlope
	end
	local best = nil
	local function isCommander(ud)
		local cp = ud.customParams
		if not cp then return false end
		-- BAR + most Recoil commander conventions
		if cp.iscommander or cp.isCommander then return true end
		if cp.commander or cp.is_commander then return true end
		-- Fallback heuristic: name contains "com" AND costs metal (filters out turrets)
		local n = ud.name and ud.name:lower()
		return n and (n:find("commander") or n:find("^armcom") or n:find("^corcom") or n:find("^legcom")) and true or false
	end
	for _, ud in pairs(UnitDefs) do
		if isCommander(ud) then
			local md = ud.moveDef
			local ms = md and md.maxSlope
			if ms and ms > 0 then
				if not best or ms < best then
					best = ms
				end
			end
		end
	end
	-- Conservative default when the game ships no movedef on its commander (e.g. airborne com).
	-- 0.5 ~ 30° in the 1-cos space; generous enough to not reject reasonable slopes.
	_cachedCommanderMaxSlope = best or 0.5
	return _cachedCommanderMaxSlope
end

-- Returns (slopeVal, maxSlope). slopeVal is the ground slope at (x,z) in 1-cos space
-- (same domain as movedef.maxSlope). maxSlope is the commander-tolerable limit. If
-- `slopeVal > maxSlope` the point is commander-un-spawnable.
local function getGroundSlopeAt(x, z)
	-- Spring.GetGroundNormal returns nx, ny, nz, slope where slope = 1 - ny (normalized).
	local _, _, _, slope = Spring.GetGroundNormal(x, z, false)
	return slope or 0
end

local function isPlaceableForCommander(x, z)
	local maxS = getCommanderMaxSlope()
	if not maxS then return true end
	return getGroundSlopeAt(x, z) <= maxS
end

local function addPosition(x, z, allyTeam, teamSlot)
	if #positions >= MAX_POSITIONS then return false end
	x, z = clampToMap(x, z)
	-- Reject commander-unspawnable spots (ground too steep for the commander's movedef).
	-- Transferable across Recoil games via customParams.iscommander on UnitDefs; override
	-- via modOption `startpos_max_slope`.
	if not isPlaceableForCommander(x, z) then
		Echo("[StartPos Tool] Skipped: slope exceeds commander tolerance at (" ..
			math_floor(x) .. "," .. math_floor(z) .. ")")
		return false
	end
	local y = GetGroundHeight(x, z) or 0
	teamSlot = teamSlot or 1
	local playerIdx = (allyTeam - 1) * math_max(1, numTeamsPerAlly) + teamSlot
	positions[#positions + 1] = {
		x = x, z = z, y = y,
		allyTeam = allyTeam,
		teamSlot = teamSlot,
		playerIdx = playerIdx,
	}
	return true
end

-- Advance (nextAllyTeam, nextTeamSlot) per placement mode; returns the pair AFTER advancing.
local function advanceNextPlayer()
	local ally = nextAllyTeam
	local slot = nextTeamSlot
	local numAlly = math_max(1, numAllyTeams)
	local numSlot = math_max(1, numTeamsPerAlly)
	if placementMode == "sequential" then
		-- Fill all slots of current ally before next ally
		slot = slot + 1
		if slot > numSlot then
			slot = 1
			ally = (ally % numAlly) + 1
		end
	else
		-- Round-robin: cycle allyTeam first (A,B,C,A,B,C...); when back to start, bump slot.
		ally = ally + 1
		if ally > numAlly then
			ally = 1
			slot = (slot % numSlot) + 1
		end
	end
	nextAllyTeam = ally
	nextTeamSlot = slot
end

local function removePosition(idx)
	if idx >= 1 and idx <= #positions then
		table.remove(positions, idx)
		return true
	end
	return false
end

local function removeNearestPosition(wx, wz)
	local bestIdx = nil
	local bestDist = CLICK_DISTANCE_SQ
	for i, pos in ipairs(positions) do
		local d = distSq(wx, wz, pos.x, pos.z)
		if d < bestDist then
			bestDist = d
			bestIdx = i
		end
	end
	if bestIdx then
		removePosition(bestIdx)
		return true
	end
	return false
end

local function findNearestPosition(wx, wz)
	local bestIdx = nil
	local bestDist = CLICK_DISTANCE_SQ
	for i, pos in ipairs(positions) do
		local d = distSq(wx, wz, pos.x, pos.z)
		if d < bestDist then
			bestDist = d
			bestIdx = i
		end
	end
	return bestIdx
end

local function clearAllPositions()
	positions = {}
	nextAllyTeam = 1
	nextTeamSlot = 1
	undoHistory = {}
end

-- Shape/random placement: always distribute evenly across all allyteam×teamSlot combinations
-- so a 4-ally × 2-team shape of 8 places yields one of each.
local function placeShapePositions(cx, cz)
	local pts = generateShapePositions(cx, cz)
	local numAlly = math_max(1, numAllyTeams)
	local numSlot = math_max(1, numTeamsPerAlly)
	for i, pt in ipairs(pts) do
		local zeroIdx = i - 1
		local at, slot
		if placementMode == "sequential" then
			at   = math_floor(zeroIdx / numSlot) % numAlly + 1
			slot = (zeroIdx % numSlot) + 1
		else
			at   = (zeroIdx % numAlly) + 1
			slot = math_floor(zeroIdx / numAlly) % numSlot + 1
		end
		addPosition(pt.x, pt.z, at, slot)
	end
end

-- Place all shape positions assigning every slot to the same allyTeam (used by symmetric copies).
-- teamSlot still cycles within that ally so players stay distinct.
local function placeShapePositionsForTeam(cx, cz, allyTeam)
	local pts = generateShapePositions(cx, cz)
	local numSlot = math_max(1, numTeamsPerAlly)
	for i, pt in ipairs(pts) do
		local slot = ((i - 1) % numSlot) + 1
		addPosition(pt.x, pt.z, allyTeam, slot)
	end
end

local function placeRandomPositions(cx, cz)
	local pts = generateRandomPositions(cx, cz)
	local numAlly = math_max(1, numAllyTeams)
	local numSlot = math_max(1, numTeamsPerAlly)
	for i, pt in ipairs(pts) do
		local zeroIdx = i - 1
		local at, slot
		if placementMode == "sequential" then
			at   = math_floor(zeroIdx / numSlot) % numAlly + 1
			slot = (zeroIdx % numSlot) + 1
		else
			at   = (zeroIdx % numAlly) + 1
			slot = math_floor(zeroIdx / numAlly) % numSlot + 1
		end
		addPosition(pt.x, pt.z, at, slot)
	end
end

-- ============================================================
-- Startbox Operations
-- ============================================================

local function addStartboxVertex(x, z)
	x, z = clampToMap(x, z)
	currentBoxVerts[#currentBoxVerts + 1] = {x = x, z = z}
end

local function finishStartbox()
	if #currentBoxVerts >= 3 then
		startboxes[#startboxes + 1] = {
			vertices = currentBoxVerts,
			allyTeam = nextBoxAllyTeam,
		}
		nextBoxAllyTeam = nextBoxAllyTeam + 1
		if nextBoxAllyTeam > numAllyTeams then
			nextBoxAllyTeam = 1
		end
	end
	currentBoxVerts = {}
	drawingBox = false
end

-- Reduce a dense polyline to ~targetCount control points preserving high-curvature vertices.
local function fitControlPoints(pts, targetCount)
	targetCount = targetCount or 8
	local n = #pts
	if n <= targetCount then
		local out = {}
		for i = 1, n do out[i] = { x = pts[i].x, z = pts[i].z } end
		return out
	end
	-- Curvature score per point: turning angle between (p-1 -> p) and (p -> p+1).
	local scored = {}
	for i = 1, n do
		local prev = pts[((i - 2) % n) + 1]
		local cur  = pts[i]
		local nxt  = pts[(i % n) + 1]
		local ax, az = cur.x - prev.x, cur.z - prev.z
		local bx, bz = nxt.x - cur.x,  nxt.z - cur.z
		local la = math.sqrt(ax * ax + az * az) + 1e-9
		local lb = math.sqrt(bx * bx + bz * bz) + 1e-9
		local d = (ax * bx + az * bz) / (la * lb)
		if d > 1 then d = 1 elseif d < -1 then d = -1 end
		scored[#scored + 1] = { idx = i, score = math.acos(d) }
	end
	table.sort(scored, function(a, b) return a.score > b.score end)
	-- Pick top-K with minimum index spacing so handles don't clump.
	local picked = {}
	local minSpacing = math_max(1, math.floor(n / (targetCount * 2)))
	for _, s in ipairs(scored) do
		if #picked >= targetCount then break end
		local ok = true
		for _, pi in ipairs(picked) do
			local di = math.abs(s.idx - pi)
			if di > n / 2 then di = n - di end
			if di < minSpacing then ok = false; break end
		end
		if ok then picked[#picked + 1] = s.idx end
	end
	while #picked < math_max(4, math.floor(targetCount / 2)) do
		picked[#picked + 1] = math.floor((#picked + 1) * n / (targetCount + 1))
	end
	table.sort(picked)
	local out = {}
	for _, i in ipairs(picked) do
		out[#out + 1] = { x = pts[i].x, z = pts[i].z }
	end
	return out
end

-- Closed centripetal Catmull-Rom tessellation. Writes into `out` (reused when provided) and
-- truncates to the required length. Returning a fresh table each mousemove during drag was
-- the dominant source of GC pressure -> LuaRAM warnings on large freedraw splines.
local function tessellateClosedCatmullRom(ctrls, samplesPerSegment, out)
	samplesPerSegment = samplesPerSegment or 12
	local n = #ctrls
	out = out or {}
	if n < 3 then
		for i = 1, n do
			local v = out[i]
			if v then v.x, v.z = ctrls[i].x, ctrls[i].z
			else out[i] = { x = ctrls[i].x, z = ctrls[i].z } end
		end
		for i = #out, n + 1, -1 do out[i] = nil end
		return out
	end
	local total = n * samplesPerSegment
	local idx = 0
	for i = 1, n do
		local p0 = ctrls[((i - 2) % n) + 1]
		local p1 = ctrls[((i - 1) % n) + 1]
		local p2 = ctrls[(i % n) + 1]
		local p3 = ctrls[((i + 1) % n) + 1]
		for s = 0, samplesPerSegment - 1 do
			local t  = s / samplesPerSegment
			local t2 = t * t
			local t3 = t2 * t
			local a = -0.5 * t3 + t2       - 0.5 * t
			local b =  1.5 * t3 - 2.5 * t2 + 1.0
			local c = -1.5 * t3 + 2.0 * t2 + 0.5 * t
			local d =  0.5 * t3 - 0.5 * t2
			idx = idx + 1
			local x = a * p0.x + b * p1.x + c * p2.x + d * p3.x
			local z = a * p0.z + b * p1.z + c * p2.z + d * p3.z
			local v = out[idx]
			if v then v.x, v.z = x, z
			else out[idx] = { x = x, z = z } end
		end
	end
	for i = #out, total + 1, -1 do out[i] = nil end
	return out
end

-- Refresh tessellated vertices for a spline-kind startbox after its controls have changed.
-- Mutates box.vertices in place and only flags a *pending* fill rebuild — the actual fill
-- display list is regenerated on drag release (see isDraggingBox gate in ensureBoxFillList).
local function retessellateSpline(box)
	if box.kind ~= "spline" or not box.controls then return end
	box.vertices = tessellateClosedCatmullRom(box.controls, 12, box.vertices)
	box._fillNeedsRebuild = true
end

local function removeLastStartbox()
	if #startboxes > 0 then
		freeBoxFillList(startboxes[#startboxes])
		table.remove(startboxes, #startboxes)
		if nextBoxAllyTeam > 1 then
			nextBoxAllyTeam = nextBoxAllyTeam - 1
		end
	end
end

local function clearAllStartboxes()
	for i = 1, #startboxes do freeBoxFillList(startboxes[i]) end
	startboxes = {}
	currentBoxVerts = {}
	drawingBox = false
	nextBoxAllyTeam = 1
end

local function findNearestBoxVertex(wx, wz)
	for bi, box in ipairs(startboxes) do
		if box.kind == "box" then
			-- Axis-aligned rectangles: corners ARE drag handles too (in addition to edges).
			-- Dragging a corner moves both adjacent edges so the rect stays axis-aligned.
			for vi, v in ipairs(box.vertices) do
				if distSq(wx, wz, v.x, v.z) < VERTEX_PICK_DIST_SQ then
					return bi, vi
				end
			end
		elseif box.kind == "spline" and box.controls then
			-- Spline-kind boxes expose their control points as drag handles (not the dense
			-- tessellated vertices). Dragging a control moves the whole curve smoothly.
			for vi, v in ipairs(box.controls) do
				if distSq(wx, wz, v.x, v.z) < VERTEX_PICK_DIST_SQ then
					return bi, vi
				end
			end
		else
			for vi, v in ipairs(box.vertices) do
				if distSq(wx, wz, v.x, v.z) < VERTEX_PICK_DIST_SQ then
					return bi, vi
				end
			end
		end
	end
	return nil, nil
end

-- Point-in-polygon test (ray-cast / crossing-number) on the XZ plane. Works for both the
-- "box" (4 CCW corners) and spline-tessellated vertex lists.
local function pointInPolygon(wx, wz, verts)
	local n = verts and #verts or 0
	if n < 3 then return false end
	local inside = false
	local j = n
	for i = 1, n do
		local vi, vj = verts[i], verts[j]
		if ((vi.z > wz) ~= (vj.z > wz)) and
		   (wx < (vj.x - vi.x) * (wz - vi.z) / ((vj.z - vi.z) + 1e-9) + vi.x) then
			inside = not inside
		end
		j = i
	end
	return inside
end

-- Returns the topmost startbox whose polygon contains (wx,wz), or nil. Used for body-drag
-- (grab a box anywhere in its interior, not just on a handle). Iterates in reverse so the
-- most-recently-placed (visually on top) box wins.
local function findBoxContaining(wx, wz)
	for bi = #startboxes, 1, -1 do
		local box = startboxes[bi]
		if box.vertices and pointInPolygon(wx, wz, box.vertices) then
			return bi
		end
	end
	return nil
end

-- For "box"-kind startboxes: find the nearest edge (T=top/B=bottom/L=left/R=right) to (wx,wz).
-- Returns bi, edgeName where edgeName is one of "T","B","L","R" (based on min/max bounds).
local function findNearestBoxEdge(wx, wz)
	local EDGE_PICK_DIST = 55  -- world units from edge line
	for bi, box in ipairs(startboxes) do
		if box.kind == "box" and #box.vertices == 4 then
			local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
			for _, v in ipairs(box.vertices) do
				if v.x < minX then minX = v.x end
				if v.x > maxX then maxX = v.x end
				if v.z < minZ then minZ = v.z end
				if v.z > maxZ then maxZ = v.z end
			end
			-- Only consider an edge if cursor is within the perpendicular span of that edge.
			if wx >= minX - EDGE_PICK_DIST and wx <= maxX + EDGE_PICK_DIST and
			   wz >= minZ - EDGE_PICK_DIST and wz <= maxZ + EDGE_PICK_DIST then
				local dL = math.abs(wx - minX)  -- left   edge (constant X = minX)
				local dR = math.abs(wx - maxX)  -- right  edge
				local dT = math.abs(wz - minZ)  -- top    edge (min Z)
				local dB = math.abs(wz - maxZ)  -- bottom edge
				local best, which = EDGE_PICK_DIST, nil
				-- Left/right edges only valid within Z span
				if wz >= minZ - EDGE_PICK_DIST and wz <= maxZ + EDGE_PICK_DIST then
					if dL < best then best, which = dL, "L" end
					if dR < best then best, which = dR, "R" end
				end
				-- Top/bottom edges only valid within X span
				if wx >= minX - EDGE_PICK_DIST and wx <= maxX + EDGE_PICK_DIST then
					if dT < best then best, which = dT, "T" end
					if dB < best then best, which = dB, "B" end
				end
				if which then return bi, which end
			end
		end
	end
	return nil, nil
end

-- Polygon-kind boxes (kind == nil or "polygon") expose an edge-midpoint "ghost" handle for
-- inserting a new vertex. Returns box index, edge index (= start-vertex index), and the
-- midpoint world coords; nil if no edge mid is within VERTEX_PICK_DIST_SQ of the cursor.
local function isPolygonKind(box)
	return box.kind == nil or box.kind == "polygon"
end

-- Returns the editable-handle list for a box (polygon: vertices; spline: controls). Nil for
-- "box"-kind axis-aligned rects (those use edge resize, not handle insertion).
local function getEditHandles(box)
	if isPolygonKind(box) then return box.vertices end
	if box.kind == "spline" then return box.controls end
	return nil
end

local function findNearestPolygonEdgeMid(wx, wz)
	local bestD = VERTEX_PICK_DIST_SQ
	local bestBi, bestEi, bestMx, bestMz = nil, nil, nil, nil
	for bi, box in ipairs(startboxes) do
		local handles = getEditHandles(box)
		if handles and #handles >= 3 then
			local n = #handles
			for i = 1, n do
				local a = handles[i]
				local b = handles[(i % n) + 1]
				local mx = (a.x + b.x) * 0.5
				local mz = (a.z + b.z) * 0.5
				local d = distSq(wx, wz, mx, mz)
				if d < bestD then
					bestD = d
					bestBi, bestEi, bestMx, bestMz = bi, i, mx, mz
				end
			end
		end
	end
	return bestBi, bestEi, bestMx, bestMz
end

-- ============================================================
-- Save / Load
-- ============================================================

local function getMapName()
	return Game.mapName or "unknown"
end

local function saveStartPositions(name)
	Spring.CreateDir(SAVE_DIR)
	local filename = SAVE_DIR .. (name or getMapName()) .. ".lua"
	local lines = {}
	lines[#lines + 1] = "-- Start Positions Config"
	lines[#lines + 1] = "-- Map: " .. getMapName()
	lines[#lines + 1] = "-- Generated by Start Positions Tool"
	lines[#lines + 1] = ""
	lines[#lines + 1] = "local startPositions = {"
	for i, pos in ipairs(positions) do
		lines[#lines + 1] = string.format("  [%d] = { x = %d, z = %d, allyTeam = %d, teamSlot = %d },", i, math_floor(pos.x), math_floor(pos.z), pos.allyTeam, pos.teamSlot or 1)
	end
	lines[#lines + 1] = "}"
	lines[#lines + 1] = ""
	lines[#lines + 1] = "return startPositions"
	local content = table.concat(lines, "\n")

	local file = io.open(filename, "w")
	if file then
		file:write(content)
		file:close()
		Echo("[StartPos Tool] Saved start positions to: " .. filename)
		return true
	else
		Echo("[StartPos Tool] ERROR: Could not write to: " .. filename)
		return false
	end
end

local function loadStartPositions(name)
	local filename = SAVE_DIR .. (name or getMapName()) .. ".lua"
	local ok, data = pcall(function()
		return VFS.Include(filename, nil, VFS.RAW_FIRST)
	end)
	if ok and data then
		clearAllPositions()  -- also clears undoHistory
		for i, pos in ipairs(data) do
			addPosition(pos.x, pos.z, pos.allyTeam or i, pos.teamSlot or 1)
		end
		undoHistory = {}  -- load is a clean slate
		Echo("[StartPos Tool] Loaded start positions from: " .. filename)
		return true
	else
		Echo("[StartPos Tool] No saved config found: " .. filename)
		return false
	end
end

local function listSavedConfigs()
	local files = VFS.DirList(SAVE_DIR, "*.lua", VFS.RAW_FIRST)
	local names = {}
	for _, f in ipairs(files or {}) do
		local name = f:match("([^/\\]+)%.lua$")
		if name then names[#names + 1] = name end
	end
	return names
end

local function saveStartboxes(name)
	Spring.CreateDir(STARTBOX_SAVE_DIR)
	local filename = STARTBOX_SAVE_DIR .. (name or getMapName()) .. ".lua"
	local lines = {}
	lines[#lines + 1] = "-- Startbox Config"
	lines[#lines + 1] = "-- Map: " .. getMapName()
	lines[#lines + 1] = "-- Generated by Start Positions Tool"
	lines[#lines + 1] = ""
	lines[#lines + 1] = "local startboxes = {"
	for i, box in ipairs(startboxes) do
		lines[#lines + 1] = string.format("  [%d] = {", i)
		lines[#lines + 1] = string.format("    allyTeam = %d,", box.allyTeam)
		lines[#lines + 1] = "    vertices = {"
		for _, v in ipairs(box.vertices) do
			lines[#lines + 1] = string.format("      { x = %d, z = %d },", math_floor(v.x), math_floor(v.z))
		end
		lines[#lines + 1] = "    },"
		lines[#lines + 1] = "  },"
	end
	lines[#lines + 1] = "}"
	lines[#lines + 1] = ""
	lines[#lines + 1] = "return startboxes"
	local content = table.concat(lines, "\n")

	local file = io.open(filename, "w")
	if file then
		file:write(content)
		file:close()
		Echo("[StartPos Tool] Saved startboxes to: " .. filename)
		return true
	else
		Echo("[StartPos Tool] ERROR: Could not write to: " .. filename)
		return false
	end
end

local function loadStartboxes(name)
	local filename = STARTBOX_SAVE_DIR .. (name or getMapName()) .. ".lua"
	local ok, data = pcall(function()
		return VFS.Include(filename, nil, VFS.RAW_FIRST)
	end)
	if ok and data then
		clearAllStartboxes()
		for i, box in ipairs(data) do
			startboxes[i] = {
				vertices = box.vertices,
				allyTeam = box.allyTeam or i,
			}
		end
		Echo("[StartPos Tool] Loaded startboxes from: " .. filename)
		return true
	else
		Echo("[StartPos Tool] No saved startbox config found: " .. filename)
		return false
	end
end

local function listSavedStartboxConfigs()
	local files = VFS.DirList(STARTBOX_SAVE_DIR, "*.lua", VFS.RAW_FIRST)
	local names = {}
	for _, f in ipairs(files or {}) do
		local name = f:match("([^/\\]+)%.lua$")
		if name then names[#names + 1] = name end
	end
	return names
end

-- ============================================================
-- Start Script Generation
-- ============================================================

local STARTSCRIPT_SAVE_DIR = "Terraform Brush/StartScripts/"

--- Generate a Spring engine start script (script.txt) from the current
--- polygon startboxes. Each polygon is converted to an axis-aligned
--- bounding rectangle normalised to 0-1 map coordinates.
---@param opts table|nil  Optional overrides:
---   mapname        (string)   default: current map
---   playerName     (string)   default: "Player"
---   aiShortName    (string)   AI type for non-player teams, default "NullAI"
---   aiVersion      (string)   default "0.1"
---   startpostype   (number)   0=fixed,1=random,2=choose  default 2
---   modoptions     (table)    key-value pairs for [modoptions] section
---@return string  The full script text
local function generateStartScript(opts)
	opts = opts or {}
	local mapName     = opts.mapname or getMapName()
	local playerName  = opts.playerName or "Player"
	local aiShort     = opts.aiShortName or "NullAI"
	local aiVersion   = opts.aiVersion or "0.1"
	local sposType    = opts.startpostype or 2
	local modopts     = opts.modoptions or {}

	local mapSizeX = Game.mapSizeX
	local mapSizeZ = Game.mapSizeZ

	local boxes = startboxes
	if #boxes == 0 then
		Echo("[StartPos Tool] No startboxes to export.")
		return nil
	end

	-- Collect unique allyTeam ids and sort them
	local allyTeamSet = {}
	for _, box in ipairs(boxes) do
		allyTeamSet[box.allyTeam] = true
	end
	local allyTeamIds = {}
	for at in pairs(allyTeamSet) do
		allyTeamIds[#allyTeamIds + 1] = at
	end
	table.sort(allyTeamIds)

	-- Build ally-team index mapping (allyTeam value -> 0-based script index)
	local atToIdx = {}
	for i, at in ipairs(allyTeamIds) do
		atToIdx[at] = i - 1
	end

	local numTeams = #allyTeamIds

	local lines = {}
	local function L(s) lines[#lines + 1] = s end

	L("[Game]")
	L("{")

	-- Ally teams with bounding-rect start boxes
	for _, at in ipairs(allyTeamIds) do
		local idx = atToIdx[at]
		-- Find the box(es) for this allyTeam and compute combined AABB
		local minX, minZ = mapSizeX, mapSizeZ
		local maxX, maxZ = 0, 0
		for _, box in ipairs(boxes) do
			if box.allyTeam == at then
				for _, v in ipairs(box.vertices) do
					if v.x < minX then minX = v.x end
					if v.x > maxX then maxX = v.x end
					if v.z < minZ then minZ = v.z end
					if v.z > maxZ then maxZ = v.z end
				end
			end
		end
		-- Normalise to 0-1
		local left   = minX / mapSizeX
		local right  = maxX / mapSizeX
		local top    = minZ / mapSizeZ
		local bottom = maxZ / mapSizeZ

		L(string.format("\t[allyTeam%d]", idx))
		L("\t{")
		L(string.format("\t\tstartrectleft = %.8f;", left))
		L(string.format("\t\tstartrectright = %.8f;", right))
		L(string.format("\t\tstartrecttop = %.8f;", top))
		L(string.format("\t\tstartrectbottom = %.8f;", bottom))
		L("\t\tnumallies = 0;")
		L("\t}")
		L("")
	end

	-- Teams: one team per allyTeam, alternating sides
	local sides = { "Armada", "Cortex" }
	for i, at in ipairs(allyTeamIds) do
		local idx = i - 1
		L(string.format("\t[team%d]", idx))
		L("\t{")
		L(string.format("\t\tSide = %s;", sides[((i - 1) % 2) + 1]))
		L("\t\tHandicap = 0;")
		L("\t\tRgbColor = 0.99609375 0.546875 0;")
		L(string.format("\t\tAllyTeam = %d;", atToIdx[at]))
		L("\t\tTeamLeader = 0;")
		L("\t}")
		L("")
	end

	-- Player 0 (human, spectator if > 2 teams else team 0)
	L("\t[player0]")
	L("\t{")
	L("\t\tIsFromDemo = 0;")
	L(string.format("\t\tName = %s;", playerName))
	L("\t\tTeam = 0;")
	L("\t\trank = 0;")
	L("\t}")
	L("")

	-- AI players for remaining teams (team 1 .. N-1)
	for i = 2, numTeams do
		local aiIdx = i - 2  -- ai0, ai1, ...
		local teamIdx = i - 1
		L(string.format("\t[ai%d]", aiIdx))
		L("\t{")
		L("\t\tHost = 0;")
		L("\t\tIsFromDemo = 0;")
		L(string.format("\t\tName = %s(%d);", aiShort, aiIdx + 1))
		L(string.format("\t\tShortName = %s;", aiShort))
		L(string.format("\t\tTeam = %d;", teamIdx))
		L(string.format("\t\tVersion = %s;", aiVersion))
		L("\t}")
		L("")
	end

	-- Mod options
	L("\t[modoptions]")
	L("\t{")
	for k, v in pairs(modopts) do
		L(string.format("\t\t%s = %s;", tostring(k), tostring(v)))
	end
	L("\t}")
	L("")

	-- Global game keys
	L("\thostip = 127.0.0.1;")
	L("\thostport = 0;")
	L("\tishost = 1;")
	L("\tGameStartDelay = 5;")
	L("\tnumplayers = 1;")
	L(string.format("\tnumusers = %d;", 1 + (numTeams - 1)))  -- 1 player + N-1 AIs
	L(string.format("\tstartpostype = %d;", sposType))
	L(string.format("\tmapname = %s;", mapName))
	L(string.format("\tmyplayername = %s;", playerName))
	L("\tgametype = Beyond All Reason $VERSION;")
	L("\tnohelperais = 0;")
	L("}")

	return table.concat(lines, "\n")
end

local function saveStartScript(name, opts)
	local script = generateStartScript(opts)
	if not script then return false end

	Spring.CreateDir(STARTSCRIPT_SAVE_DIR)
	local filename = STARTSCRIPT_SAVE_DIR .. (name or getMapName()) .. ".txt"

	local file = io.open(filename, "w")
	if file then
		file:write(script)
		file:close()
		Echo("[StartPos Tool] Saved start script to: " .. filename)
		return true
	else
		Echo("[StartPos Tool] ERROR: Could not write to: " .. filename)
		return false
	end
end

-- ============================================================
-- Activate / Deactivate / State
-- ============================================================

local function activate(mode)
	active = true
	subMode = mode or "express"
	Echo("[StartPos Tool] Activated: " .. subMode:upper())
end

local function deactivate()
	if active then
		Echo("[StartPos Tool] Deactivated")
	end
	active = false
	dragging = false
	dragIdx = nil
	drawingBox = false
end

local function setSubMode(mode)
	if mode == "express" or mode == "shape" or mode == "startbox" then
		subMode = mode
	end
end

local function setShape(shape)
	if shape == "circle" or shape == "square" or shape == "hexagon"
		or shape == "octagon" or shape == "triangle" then
		shapeType = shape
	end
end

local function setRadius(v)
	shapeRadius = math_max(MIN_RADIUS, math_min(MAX_RADIUS, v))
end

local function setRotation(deg)
	shapeRotation = deg % 360
end

local function setShapeCount(c)
	shapeCount = math_max(2, math_min(MAX_POSITIONS, c))
end

local function setNumAllyTeams(n)
	numAllyTeams = math_max(2, math_min(MAX_ALLYTEAMS, n))
	if nextAllyTeam > numAllyTeams then nextAllyTeam = 1 end
end

local function setNumTeamsPerAlly(n)
	numTeamsPerAlly = math_max(1, math_min(MAX_TEAMS_PER_ALLY, n))
	if nextTeamSlot > numTeamsPerAlly then nextTeamSlot = 1 end
end

local function setPlacementMode(m)
	if m == "roundrobin" or m == "sequential" then
		placementMode = m
	end
end

local function togglePlacementMode()
	placementMode = (placementMode == "roundrobin") and "sequential" or "roundrobin"
	return placementMode
end

local function setStartboxMode(m)
	if m == "polygon" or m == "box" or m == "freedraw" then
		startboxMode = m
		-- Reset any in-progress drawing when switching modes
		currentBoxVerts = {}
		drawingBox = false
		boxRectActive = false
		boxRectStartX, boxRectStartZ, boxRectEndX, boxRectEndZ = nil, nil, nil, nil
		freeDrawActive = false
		freeDrawPts = {}
	end
end

-- Chaikin corner-cutting smoothing: each iteration doubles point count and rounds corners.
-- Closed polygon version. 2 iterations gives a pleasing smooth curve without blowing up point count.
local function smoothClosedPolygon(pts, iterations)
	local out = pts
	for _ = 1, (iterations or 2) do
		local smoothed = {}
		local n = #out
		if n < 3 then return out end
		for i = 1, n do
			local p0 = out[i]
			local p1 = out[(i % n) + 1]
			-- Q = 0.75*p0 + 0.25*p1 ; R = 0.25*p0 + 0.75*p1
			smoothed[#smoothed + 1] = { x = 0.75 * p0.x + 0.25 * p1.x, z = 0.75 * p0.z + 0.25 * p1.z }
			smoothed[#smoothed + 1] = { x = 0.25 * p0.x + 0.75 * p1.x, z = 0.25 * p0.z + 0.75 * p1.z }
		end
		out = smoothed
	end
	return out
end

-- Simplify: drop points that are too close to previous (post-smoothing decimation).
local function decimatePoints(pts, minDistSq)
	if #pts < 3 then return pts end
	local out = { pts[1] }
	for i = 2, #pts do
		local prev = out[#out]
		local dx, dz = pts[i].x - prev.x, pts[i].z - prev.z
		if dx * dx + dz * dz >= minDistSq then
			out[#out + 1] = pts[i]
		end
	end
	return out
end

local function getState()
	return {
		active        = active,
		subMode       = subMode,
		positions     = positions,
		numAllyTeams  = numAllyTeams,
		numTeamsPerAlly = numTeamsPerAlly,
		nextAllyTeam  = nextAllyTeam,
		nextTeamSlot  = nextTeamSlot,
		placementMode = placementMode,
		totalPlayers  = numAllyTeams * numTeamsPerAlly,
		maxAllyTeams  = MAX_ALLYTEAMS,
		maxTeamsPerAlly = MAX_TEAMS_PER_ALLY,
		maxPositions  = MAX_POSITIONS,
		shapeType     = shapeType,
		shapeRadius   = shapeRadius,
		shapeRotation = shapeRotation,
		shapeCount    = shapeCount,
		startboxes    = startboxes,
		startboxMode  = startboxMode,
		drawingBox    = drawingBox,
		currentBoxVerts = currentBoxVerts,
		boxRectActive = boxRectActive,
		freeDrawActive = freeDrawActive,
	}
end

-- ============================================================
-- Mouse Handlers
-- ============================================================

function widget:MousePress(mx, my, button)
	if not active then return false end

	-- Defer to measure tool when active
	do
		local tb = WG.TerraformBrush
		local stb = tb and tb.getState and tb.getState() or nil
		if stb and stb.measureActive then return false end
	end

	local wx, wz = getWorldMousePosition()
	if not wx then return false end

	if subMode == "express" then
		if button == 1 then
			-- LMB: Check if clicking near existing position (start drag)
			local nearIdx = findNearestPosition(wx, wz)
			if nearIdx then
				dragIdx = nearIdx
				dragStartX = mx
				dragStartY = my
				dragging = false
				return true
			end
			-- Place new position; smart-assign teams across symmetric copies when symmetry is active
			do
				local tb = WG.TerraformBrush
				local stb = tb and tb.getState and tb.getState() or nil
				local prevNext = nextAllyTeam
				local prevNextSlot = nextTeamSlot
				local prevCount = #positions
				if stb and stb.symmetryActive and tb.getSymmetricPositions then
					local copies = tb.getSymmetricPositions(wx, wz, 0)
					for _, p in ipairs(copies) do
						addPosition(p.x, p.z, nextAllyTeam, nextTeamSlot)
						advanceNextPlayer()
					end
				elseif addPosition(wx, wz, nextAllyTeam, nextTeamSlot) then
					advanceNextPlayer()
				end
				local added = #positions - prevCount
				if added > 0 then
					undoHistory[#undoHistory + 1] = {
						count = added,
						prevNextAllyTeam = prevNext,
						prevNextTeamSlot = prevNextSlot,
					}
				end
			end
			return true
		elseif button == 3 then
			-- RMB: Undo last placement (remove most recently placed player/shape-batch)
			local entry = undoHistory[#undoHistory]
			if entry then
				for i = 1, entry.count do
					if #positions > 0 then
						positions[#positions] = nil
					end
				end
				nextAllyTeam = entry.prevNextAllyTeam
				nextTeamSlot = entry.prevNextTeamSlot or 1
				undoHistory[#undoHistory] = nil
			end
			if #positions == 0 then
				nextAllyTeam = 1
				nextTeamSlot = 1
			end
			return true
		end

	elseif subMode == "shape" then
		if button == 1 then
			-- LMB: Place positions using current shape at click location
			local tb = WG.TerraformBrush
			local stb = tb and tb.getState and tb.getState() or nil
			local sx, sz = wx, wz
			if stb and stb.gridSnap and tb.snapWorld then
				sx, sz = tb.snapWorld(wx, wz, shapeRotation)
			end
			local prevNext = nextAllyTeam
			local prevNextSlot = nextTeamSlot
			local prevCount = #positions
			if stb and stb.symmetryActive and tb.getSymmetricPositions then
				local copies = tb.getSymmetricPositions(sx, sz, shapeRotation)
				if copies and #copies > 0 then
					for _, p in ipairs(copies) do
						placeShapePositionsForTeam(p.x, p.z, nextAllyTeam)
						advanceNextPlayer()
					end
				else
					placeShapePositions(sx, sz)
				end
			else
				placeShapePositions(sx, sz)
			end
			local added = #positions - prevCount
			if added > 0 then
				undoHistory[#undoHistory + 1] = {
					count = added,
					prevNextAllyTeam = prevNext,
					prevNextTeamSlot = prevNextSlot,
				}
			end
			return true
		elseif button == 3 then
			-- RMB: Remove nearest
			removeNearestPosition(wx, wz)
			return true
		end

	elseif subMode == "startbox" then
		if button == 1 then
			-- Check for vertex drag first (polygon/freedraw boxes — placed boxes are always editable)
			local bi, vi = findNearestBoxVertex(wx, wz)
			if bi and vi then
				boxDragIdx = vi
				boxDragBoxIdx = bi
				dragStartX = mx
				dragStartY = my
				dragging = false
				return true
			end
			-- Polygon edge-midpoint: clicking the ghost handle inserts a new vertex on that edge
			-- and immediately starts dragging it, so the user can place it where they want.
			local pbi, pei, pmx, pmz = findNearestPolygonEdgeMid(wx, wz)
			if pbi and pei then
				local box = startboxes[pbi]
				local handles = box and getEditHandles(box)
				if handles then
					local insertAt = pei + 1
					table.insert(handles, insertAt, { x = pmx, z = pmz })
					if box.kind == "spline" then
						retessellateSpline(box)
					end
					invalidateBoxFill(box)
					boxDragIdx = insertAt
					boxDragBoxIdx = pbi
					dragStartX = mx
					dragStartY = my
					dragging = false
					return true
				end
			end
			-- Edge drag for axis-aligned "box"-kind startboxes (4 corners, no vertex handles).
			local ebi, edge = findNearestBoxEdge(wx, wz)
			if ebi and edge then
				boxEdgeDrag = { bi = ebi, edge = edge }
				dragStartX = mx
				dragStartY = my
				dragging = false
				return true
			end

			-- Body drag: if the click is inside an existing startbox (and not on any handle/edge
			-- per the checks above), start a whole-box translation so the user can reposition
			-- the entire polygon by grabbing it mid-area.
			local containBi = findBoxContaining(wx, wz)
			if containBi then
				boxBodyDrag = { bi = containBi, lastX = wx, lastZ = wz }
				dragStartX = mx
				dragStartY = my
				dragging = false
				return true
			end

			if startboxMode == "box" then
				-- Drag rectangle: press to start, release to finish (like copy tool's box)
				boxRectActive = true
				boxRectStartX, boxRectStartZ = wx, wz
				boxRectEndX,   boxRectEndZ   = wx, wz
				dragStartX, dragStartY = mx, my
				return true
			elseif startboxMode == "freedraw" then
				-- Start a free-hand path; points appended during MouseMove
				freeDrawActive = true
				freeDrawPts = { { x = wx, z = wz } }
				dragStartX, dragStartY = mx, my
				return true
			else
				-- polygon mode: click-to-add vertex, RMB to finish
				if not drawingBox then
					drawingBox = true
					currentBoxVerts = {}
				end
				addStartboxVertex(wx, wz)
				return true
			end
		elseif button == 3 then
			-- RMB on an existing polygon vertex: delete it (must keep at least 3 verts).
			-- Check this before the polygon-finish/cancel/remove-last branches so users can
			-- prune vertices from a finished polygon without dropping the whole box.
			do
				local dbi, dvi = findNearestBoxVertex(wx, wz)
				if dbi and dvi then
					local box = startboxes[dbi]
					local handles = box and getEditHandles(box)
					if handles and #handles > 3 then
						table.remove(handles, dvi)
						if box.kind == "spline" then
							retessellateSpline(box)
						end
						invalidateBoxFill(box)
						return true
					end
				end
			end
			-- RMB: Finish current polygon OR cancel drag-rect / free-draw, else remove last placed box
			if startboxMode == "polygon" and drawingBox and #currentBoxVerts >= 3 then
				finishStartbox()
			elseif startboxMode == "polygon" and drawingBox then
				currentBoxVerts = {}
				drawingBox = false
			elseif boxRectActive then
				boxRectActive = false
				boxRectStartX, boxRectStartZ, boxRectEndX, boxRectEndZ = nil, nil, nil, nil
			elseif freeDrawActive then
				freeDrawActive = false
				freeDrawPts = {}
			else
				removeLastStartbox()
			end
			return true
		end
	end

	return false
end

function widget:MouseMove(mx, my, dx, dy, button)
	if not active then return false end

	if subMode == "express" and dragIdx then
		local moved = (mx - dragStartX)^2 + (my - dragStartY)^2
		if moved > DRAG_THRESHOLD_SQ then
			dragging = true
		end
		if dragging then
			local wx, wz = getWorldMousePosition()
			if wx and positions[dragIdx] then
				local cx, cz = clampToMap(wx, wz)
				-- Only move if the new spot is commander-spawnable; else keep position (silent).
				if isPlaceableForCommander(cx, cz) then
					positions[dragIdx].x, positions[dragIdx].z = cx, cz
					positions[dragIdx].y = GetGroundHeight(cx, cz) or 0
				end
			end
			return true
		end
	end

	if subMode == "startbox" and boxDragIdx then
		local moved = (mx - dragStartX)^2 + (my - dragStartY)^2
		if moved > DRAG_THRESHOLD_SQ then
			dragging = true
		end
		if dragging then
			isDraggingBox = true
			pendingFillRebuildIdx = boxDragBoxIdx
			local wx, wz = getWorldMousePosition()
			if wx and startboxes[boxDragBoxIdx] then
				local box = startboxes[boxDragBoxIdx]
				if box.kind == "spline" and box.controls then
					local v = box.controls[boxDragIdx]
					if v then
						v.x, v.z = clampToMap(wx, wz)
						retessellateSpline(box)
					end
				elseif box.kind == "box" and #box.vertices == 4 then
					-- Axis-aligned corner drag: move the dragged corner, then propagate its X/Z
					-- to its two neighbours so all 4 corners stay rectilinear (CCW order:
					-- 1=(minX,minZ), 2=(maxX,minZ), 3=(maxX,maxZ), 4=(minX,maxZ)).
					local cx, cz = clampToMap(wx, wz)
					local i = boxDragIdx
					-- Determine the diagonally-opposite corner (kept fixed) and enforce a
					-- minimum size so the rect can't collapse / invert during the drag.
					local opp = ((i + 1) % 4) + 1  -- 1<->3, 2<->4
					local ox, oz = box.vertices[opp].x, box.vertices[opp].z
					local MIN_SIZE = 50
					if cx > ox then cx = math_max(cx, ox + MIN_SIZE)
					else            cx = math_min(cx, ox - MIN_SIZE) end
					if cz > oz then cz = math_max(cz, oz + MIN_SIZE)
					else            cz = math_min(cz, oz - MIN_SIZE) end
					local minX, maxX = math_min(cx, ox), math_max(cx, ox)
					local minZ, maxZ = math_min(cz, oz), math_max(cz, oz)
					box.vertices[1].x, box.vertices[1].z = minX, minZ
					box.vertices[2].x, box.vertices[2].z = maxX, minZ
					box.vertices[3].x, box.vertices[3].z = maxX, maxZ
					box.vertices[4].x, box.vertices[4].z = minX, maxZ
					invalidateBoxFill(box)
				else
					local v = box.vertices[boxDragIdx]
					if v then
						v.x, v.z = clampToMap(wx, wz)
						invalidateBoxFill(box)
					end
				end
			end
			return true
		end
	end

	-- Startbox: whole-box body drag (translate every vertex + spline control by world delta).
	if subMode == "startbox" and boxBodyDrag then
		local moved = (mx - dragStartX)^2 + (my - dragStartY)^2
		if moved > DRAG_THRESHOLD_SQ then
			dragging = true
		end
		if dragging then
			isDraggingBox = true
			pendingFillRebuildIdx = boxBodyDrag.bi
			local wx, wz = getWorldMousePosition()
			local box = wx and startboxes[boxBodyDrag.bi]
			if box then
				local dwx = wx - boxBodyDrag.lastX
				local dwz = wz - boxBodyDrag.lastZ
				-- Clamp the delta against the union bbox of vertices+controls so the whole shape
				-- "docks" against the map edge instead of compressing (per-vertex clampToMap was
				-- crushing corners that crossed the boundary). This keeps the box rigid at edges.
				local mapX, mapZ = Game.mapSizeX, Game.mapSizeZ
				local minX, maxX = math.huge, -math.huge
				local minZ, maxZ = math.huge, -math.huge
				if box.vertices then
					for _, v in ipairs(box.vertices) do
						if v.x < minX then minX = v.x end
						if v.x > maxX then maxX = v.x end
						if v.z < minZ then minZ = v.z end
						if v.z > maxZ then maxZ = v.z end
					end
				end
				if box.controls then
					for _, v in ipairs(box.controls) do
						if v.x < minX then minX = v.x end
						if v.x > maxX then maxX = v.x end
						if v.z < minZ then minZ = v.z end
						if v.z > maxZ then maxZ = v.z end
					end
				end
				if minX ~= math.huge then
					if dwx < -minX        then dwx = -minX        end
					if dwx >  mapX - maxX then dwx =  mapX - maxX end
					if dwz < -minZ        then dwz = -minZ        end
					if dwz >  mapZ - maxZ then dwz =  mapZ - maxZ end
				end
				-- Advance the drag origin only by the delta we actually applied so the box
				-- "sticks" to the edge while the cursor keeps moving outward (Windows-dock feel).
				boxBodyDrag.lastX = boxBodyDrag.lastX + dwx
				boxBodyDrag.lastZ = boxBodyDrag.lastZ + dwz
				-- Translate vertices
				if box.vertices then
					for _, v in ipairs(box.vertices) do
						v.x = v.x + dwx
						v.z = v.z + dwz
					end
				end
				-- Translate spline control points in lockstep (preserves shape)
				if box.controls then
					for _, v in ipairs(box.controls) do
						v.x = v.x + dwx
						v.z = v.z + dwz
					end
				end
				invalidateBoxFill(box)
			end
			return true
		end
	end

	-- Startbox: edge drag for box-kind (axis-aligned rectangle resize)
	if subMode == "startbox" and boxEdgeDrag then
		local moved = (mx - dragStartX)^2 + (my - dragStartY)^2
		if moved > DRAG_THRESHOLD_SQ then
			dragging = true
		end
		if dragging then
			isDraggingBox = true
			pendingFillRebuildIdx = boxEdgeDrag.bi
			local wx, wz = getWorldMousePosition()
			local box = wx and startboxes[boxEdgeDrag.bi]
			if box and box.vertices and #box.vertices == 4 then
				-- Recompute current bounds
				local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
				for _, v in ipairs(box.vertices) do
					if v.x < minX then minX = v.x end
					if v.x > maxX then maxX = v.x end
					if v.z < minZ then minZ = v.z end
					if v.z > maxZ then maxZ = v.z end
				end
				wx, wz = clampToMap(wx, wz)
				local MIN_SIZE = 50
				local edge = boxEdgeDrag.edge
				if edge == "L" then
					minX = math_min(wx, maxX - MIN_SIZE)
				elseif edge == "R" then
					maxX = math_max(wx, minX + MIN_SIZE)
				elseif edge == "T" then
					minZ = math_min(wz, maxZ - MIN_SIZE)
				elseif edge == "B" then
					maxZ = math_max(wz, minZ + MIN_SIZE)
				end
				-- Rewrite the 4 corner vertices (CCW)
				box.vertices[1].x, box.vertices[1].z = minX, minZ
				box.vertices[2].x, box.vertices[2].z = maxX, minZ
				box.vertices[3].x, box.vertices[3].z = maxX, maxZ
				box.vertices[4].x, box.vertices[4].z = minX, maxZ
				invalidateBoxFill(box)
			end
			return true
		end
	end

	-- Startbox: drag-rect live update
	if subMode == "startbox" and boxRectActive then
		local wx, wz = getWorldMousePosition()
		if wx then
			boxRectEndX, boxRectEndZ = wx, wz
		end
		return true
	end

	-- Startbox: freedraw sample accumulation
	if subMode == "startbox" and freeDrawActive then
		local wx, wz = getWorldMousePosition()
		if wx then
			local last = freeDrawPts[#freeDrawPts]
			if not last then
				freeDrawPts[#freeDrawPts + 1] = { x = wx, z = wz }
			else
				local dx, dz = wx - last.x, wz - last.z
				if dx * dx + dz * dz >= FREEDRAW_MIN_DIST_SQ then
					freeDrawPts[#freeDrawPts + 1] = { x = wx, z = wz }
				end
			end
		end
		return true
	end

	return false
end

function widget:MouseRelease(mx, my, button)
	if not active then return false end

	if subMode == "express" and dragIdx then
		dragIdx = nil
		dragging = false
		return true
	end

	-- Consolidated release for all startbox drag kinds (vertex / edge / body). Trigger the
	-- deferred fill-list rebuild here so the translucent fill catches up after the user
	-- lets go. During the drag itself ensureBoxFillList returned the stale list to avoid
	-- O(N^2) rebuilds per mousemove.
	if subMode == "startbox" and (boxDragIdx or boxEdgeDrag or boxBodyDrag) then
		if pendingFillRebuildIdx and startboxes[pendingFillRebuildIdx] then
			invalidateBoxFill(startboxes[pendingFillRebuildIdx])
		end
		pendingFillRebuildIdx = nil
		isDraggingBox = false
		boxDragIdx = nil
		boxDragBoxIdx = nil
		boxEdgeDrag = nil
		boxBodyDrag = nil
		dragging = false
		return true
	end

	-- Startbox: finish drag-rect on release (4 corners, CCW order)
	if subMode == "startbox" and boxRectActive and button == 1 then
		boxRectActive = false
		if boxRectStartX and boxRectEndX then
			local x1, x2 = math_min(boxRectStartX, boxRectEndX), math_max(boxRectStartX, boxRectEndX)
			local z1, z2 = math_min(boxRectStartZ, boxRectEndZ), math_max(boxRectStartZ, boxRectEndZ)
			-- Minimum size threshold to avoid zero-area accidental clicks
			if (x2 - x1) >= 50 and (z2 - z1) >= 50 then
				currentBoxVerts = {
					{ x = x1, z = z1 },
					{ x = x2, z = z1 },
					{ x = x2, z = z2 },
					{ x = x1, z = z2 },
				}
				drawingBox = true
				finishStartbox()
				-- Tag the just-added box as axis-aligned rectangle (edge-drag only, no vertex handles).
				local added = startboxes[#startboxes]
				if added then added.kind = "box" end
			end
		end
		boxRectStartX, boxRectStartZ, boxRectEndX, boxRectEndZ = nil, nil, nil, nil
		return true
	end

	-- Startbox: finish freedraw on release — smooth via Chaikin, decimate, fit to spline
	if subMode == "startbox" and freeDrawActive and button == 1 then
		freeDrawActive = false
		if #freeDrawPts >= 4 then
			local smoothed = smoothClosedPolygon(freeDrawPts, 2)
			smoothed = decimatePoints(smoothed, 50 * 50)
			if #smoothed >= 3 then
				-- Scale control-point count with drawn perimeter so longer curves get more
				-- handles (finer control) and short loops stay simple. One handle per ~400u
				-- of perimeter, clamped to [6, 24].
				local perim = 0
				for i = 1, #smoothed do
					local a = smoothed[i]
					local b = smoothed[(i % #smoothed) + 1]
					local dx, dz = b.x - a.x, b.z - a.z
					perim = perim + math.sqrt(dx * dx + dz * dz)
				end
				local targetCtrls = math_floor(perim / 400 + 0.5)
				if targetCtrls < 6  then targetCtrls = 6  end
				if targetCtrls > 24 then targetCtrls = 24 end
				-- Fit a minimal set of control points from the smoothed trace, then store as
				-- a spline-kind box so the user can reshape via curve handles (not raw verts).
				local controls = fitControlPoints(smoothed, targetCtrls)
				local vertices = tessellateClosedCatmullRom(controls, 12)
				startboxes[#startboxes + 1] = {
					vertices = vertices,
					controls = controls,
					kind     = "spline",
					allyTeam = nextBoxAllyTeam,
				}
				nextBoxAllyTeam = nextBoxAllyTeam + 1
				if nextBoxAllyTeam > numAllyTeams then
					nextBoxAllyTeam = 1
				end
			end
		end
		freeDrawPts = {}
		return true
	end

	return false
end

function widget:MouseWheel(up, value)
	if not active then return false end

	local altHeld, ctrlHeld, _, shiftHeld = Spring.GetModKeyState()

	if subMode == "shape" or subMode == "express" then
		if altHeld then
			-- Alt+Scroll: rotate shape (snap to TB protractor step when angleSnap on)
			local step = 5
			local tb = WG.TerraformBrush
			local tbs = tb and tb.getState and tb.getState() or nil
			if tbs and tbs.angleSnap and (tbs.angleSnapStep or 0) > 0 then
				step = tbs.angleSnapStep
			end
			local delta = up and step or -step
			setRotation(shapeRotation + delta)
			return true
		elseif ctrlHeld then
			-- Ctrl+Scroll: resize shape
			local delta = up and RADIUS_STEP or -RADIUS_STEP
			setRadius(shapeRadius + delta)
			return true
		end
	end

	return false
end

function widget:KeyPress(key, mods, isRepeat)
	if not active then return false end
	-- Ctrl+Z: undo last placement
	if key == 122 and mods.ctrl then  -- 122 = 'z'
		local entry = undoHistory[#undoHistory]
		if entry then
			for i = 1, entry.count do
				if #positions > 0 then
					positions[#positions] = nil
				end
			end
			nextAllyTeam = entry.prevNextAllyTeam
			nextTeamSlot = entry.prevNextTeamSlot or 1
			undoHistory[#undoHistory] = nil
		end
		return true
	end
	return false
end

-- ============================================================
-- Drawing
-- ============================================================

-- Draw a polygon-fan disc (soft filled circle) on the ground using a vertical cylinder approximation.
-- We fake a ground-glow by stacking multiple DrawGroundCircle calls with decreasing alpha.
local function drawSoftDisc(px, pz, radius, r, g, b, coreAlpha, segments)
	segments = segments or 28
	-- 5 concentric filled rings — fake gradient glow
	for i = 1, 5 do
		local t = i / 5
		local rr = radius * t
		local a  = coreAlpha * (1 - t * 0.7)
		glColor(r, g, b, a)
		glDrawGroundCircle(px, 0, pz, rr, segments)
	end
end

-- Builds a ground-hugging fan-tessellated fill mesh for a polygon and compiles it into a
-- GL display list stored on the box itself. Called on first draw and whenever the box is
-- mutated (vertex drag, body drag, edge drag). Eliminates per-frame table allocation +
-- GetGroundHeight sampling that was triggering the 1.2GB LuaRAM emergency GC warning
-- when large freedraw/polygon boxes were dragged around.
local function buildPolygonFillList(verts, lift, cellSize)
	local n = #verts
	if n < 3 then return nil end
	local cx, cz = 0, 0
	for i = 1, n do cx = cx + verts[i].x; cz = cz + verts[i].z end
	cx, cz = cx / n, cz / n
	return glCreateList(function()
		glBeginEnd(GL_TRIANGLES, function()
			-- Flat scratch buffer reused across all triangles. row[ri] holds (ri+1) vertices,
			-- each as 3 consecutive entries (px,py,pz). Index of vertex j (0..ri) on row ri is
			-- (ri*(ri+1)/2 + j) * 3. One allocation per fan instead of ~50 per fan.
			local rowBuf = {}
			for i = 1, n do
				local a1 = verts[i]
				local b1 = verts[(i % n) + 1]
				local eAB = math_sqrt((b1.x - a1.x) * (b1.x - a1.x) + (b1.z - a1.z) * (b1.z - a1.z))
				local eCA = math_sqrt((a1.x - cx)  * (a1.x - cx)  + (a1.z - cz)  * (a1.z - cz))
				local eCB = math_sqrt((b1.x - cx)  * (b1.x - cx)  + (b1.z - cz)  * (b1.z - cz))
				local N   = math_max(1, math.ceil(math_max(eAB, eCA, eCB) / cellSize))
				local invN = 1 / N
				for ri = 0, N do
					local tC = 1 - ri * invN
					local rowBase = ri * (ri + 1) * 0.5  -- (ri*(ri+1))/2 vertices before this row
					for j = 0, ri do
						local wA, wB
						if ri == 0 then wA, wB = 0, 0 else wA = (ri - j) * invN; wB = j * invN end
						local px = tC * cx + wA * a1.x + wB * b1.x
						local pz = tC * cz + wA * a1.z + wB * b1.z
						local py = (GetGroundHeight(px, pz) or 0) + lift
						local k  = (rowBase + j) * 3
						rowBuf[k + 1] = px
						rowBuf[k + 2] = py
						rowBuf[k + 3] = pz
					end
				end
				for ri = 0, N - 1 do
					local rUBase = ri * (ri + 1) * 0.5
					local rDBase = (ri + 1) * (ri + 2) * 0.5
					for j = 0, ri do
						local uK  = (rUBase + j)     * 3
						local d1K = (rDBase + j)     * 3
						local d2K = (rDBase + j + 1) * 3
						glVertex(rowBuf[uK + 1],  rowBuf[uK + 2],  rowBuf[uK + 3])
						glVertex(rowBuf[d1K + 1], rowBuf[d1K + 2], rowBuf[d1K + 3])
						glVertex(rowBuf[d2K + 1], rowBuf[d2K + 2], rowBuf[d2K + 3])
					end
					for j = 0, ri - 1 do
						local u1K = (rUBase + j)     * 3
						local dK  = (rDBase + j + 1) * 3
						local u2K = (rUBase + j + 1) * 3
						glVertex(rowBuf[u1K + 1], rowBuf[u1K + 2], rowBuf[u1K + 3])
						glVertex(rowBuf[dK  + 1], rowBuf[dK  + 2], rowBuf[dK  + 3])
						glVertex(rowBuf[u2K + 1], rowBuf[u2K + 2], rowBuf[u2K + 3])
					end
				end
			end
		end)
	end)
end

-- Ensures box has a current fill display list; rebuilds only when marked dirty.
local BOX_FILL_CELL          = 20   -- world units per tessellation cell (lower = higher fidelity)
local BOX_FILL_LIFT          = 2
local BOX_FILL_DRAG_INTERVAL = 4    -- during drag, rebuild list at most every Nth draw frame
ensureBoxFillList = function(box)
	if box._fillList and not box._fillDirty then return box._fillList end
	-- During drag, large polygon/spline shapes (>12 verts) defer the expensive triangulation
	-- to MouseRelease — buildPolygonFillList does O(N^2) fan subdivision that can burn thousands
	-- of allocs per frame on a freedraw spline. Small shapes (boxes — 4 verts — and simple polys)
	-- rebuild every frame so the fill follows the drag in real time. We also coarsen the cell
	-- size during drag so even mid-size polys stay responsive.
	local verts = box.vertices
	local nv = verts and #verts or 0
	if isDraggingBox and box._fillList then
		if nv > 12 then return box._fillList end
		-- Throttle rebuild rate during drag so the GL display list isn't recreated every frame
		-- (each rebuild allocates ~N² entries in the row scratch buffer + one new GL list, which
		-- previously triggered the 1.2GB LuaRAM emergency GC during edge drags). Visually this
		-- is ~15Hz updates instead of ~60Hz — still reads as live without the alloc storm.
		local frame = GetDrawFrame and GetDrawFrame() or 0
		if box._fillLastFrame and (frame - box._fillLastFrame) < BOX_FILL_DRAG_INTERVAL then
			return box._fillList
		end
		box._fillLastFrame = frame
	end
	if box._fillList then
		glDeleteList(box._fillList)
		box._fillList = nil
	end
	local cell = isDraggingBox and (BOX_FILL_CELL * 3) or BOX_FILL_CELL
	box._fillList = buildPolygonFillList(verts, BOX_FILL_LIFT, cell)
	box._fillDirty = isDraggingBox  -- final crisp rebuild on release
	box._fillNeedsRebuild = false
	if not isDraggingBox then box._fillLastFrame = nil end
	return box._fillList
end

invalidateBoxFill = function(box)
	if box then box._fillDirty = true end
end

freeBoxFillList = function(box)
	if box and box._fillList then
		glDeleteList(box._fillList)
		box._fillList = nil
		box._fillDirty = true
	end
end

-- Draw N evenly-spaced arcs (gaps between them) around a circle — animated rotating "landing ring".
-- Rendered as thick curved ribbons (triangle-strip bands between inner/outer radii) so they read
-- like chunky indicator segments rather than a thin stroke.
local function drawArcSegments(px, pz, radius, r, g, b, alpha, rotationRad, arcCount, arcFrac, segmentsPerArc)
	local slotStep  = (2 * math_pi) / arcCount
	local arcSpan   = slotStep * arcFrac
	local stepInArc = arcSpan / segmentsPerArc
	local halfW     = radius * 0.085        -- ribbon half-thickness (as fraction of radius)
	local rInner    = radius - halfW
	local rOuter    = radius + halfW
	glColor(r, g, b, alpha)
	for a = 0, arcCount - 1 do
		local start = rotationRad + a * slotStep
		glBeginEnd(GL_TRIANGLE_STRIP, function()
			for s = 0, segmentsPerArc do
				local ang = start + s * stepInArc
				local cs, sn = math_cos(ang), math_sin(ang)
				local ix = px + rInner * cs
				local iz = pz + rInner * sn
				local ox = px + rOuter * cs
				local oz = pz + rOuter * sn
				glVertex(ix, (GetGroundHeight(ix, iz) or 0) + 6, iz)
				glVertex(ox, (GetGroundHeight(ox, oz) or 0) + 6, oz)
			end
		end)
	end
end

-- Vertical beam-of-light going up from the start position.
-- Drawn as stacked world-space line segments with decreasing alpha.
local function drawBeam(px, pz, r, g, b, alphaBase, pulseT)
	local gy = GetGroundHeight(px, pz) or 0
	local steps = 6
	local beamHeight = 280   -- fixed, no pulsing
	glLineWidth(1.8)
	glBeginEnd(GL_LINES, function()
		for i = 0, steps - 1 do
			local t0 = i / steps
			local t1 = (i + 1) / steps
			local a0 = alphaBase * (1 - t0) * (1 - t0)
			local a1 = alphaBase * (1 - t1) * (1 - t1)
			glColor(r, g, b, a0)
			glVertex(px, gy + t0 * beamHeight, pz)
			glColor(r, g, b, a1)
			glVertex(px, gy + t1 * beamHeight, pz)
		end
	end)
end

-- Billboarded commander icon above the marker (team-tinted).
-- Icon scales with camera distance so it stays readable when zoomed out
-- (clamped so it doesn't balloon when zoomed in close).
local spGetCameraPosition = Spring.GetCameraPosition
local function drawCommanderBillboard(px, pz, r, g, b, alpha, iconPath, hovered)
	local gy = (GetGroundHeight(px, pz) or 0)
	-- Base size: 20% smaller than legacy. Further -10% per player-count tier (>16, >32, >64).
	local playerScale = 0.8
	local totalPlayers = (numAllyTeams or 2) * (numTeamsPerAlly or 1)
	if totalPlayers > 16 then playerScale = playerScale * 0.9 end
	if totalPlayers > 32 then playerScale = playerScale * 0.9 end
	if totalPlayers > 64 then playerScale = playerScale * 0.9 end
	local baseSize = (hovered and 52 or 48) * playerScale
	-- Distance-based scale: reference camera distance ~2000u → 1.0x
	local cx, cy, cz = spGetCameraPosition()
	local dx, dy, dz = cx - px, cy - (gy + 110), cz - pz
	local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
	local scale = dist / 2000
	if scale < 0.6 then scale = 0.6 end
	if scale > 4.0 then scale = 4.0 end
	local iconSize = baseSize * scale
	local lift     = 110                     -- height above ground
	glPushMatrix()
	glTranslate(px, gy + lift, pz)
	glBillboard()
	glTexture(iconPath)
	glColor(r, g, b, alpha)
	-- Soft outer glow quad (slightly larger, additive)
	glBlending(GL_SRC_ALPHA, GL_ONE)
	glColor(r, g, b, alpha * 0.35)
	local gs = iconSize * 1.35
	glTexRect(-gs, -gs, gs, gs)
	-- Core icon (normal blending)
	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	glColor(r, g, b, alpha)
	glTexRect(-iconSize, -iconSize, iconSize, iconSize)
	glTexture(false)
	glPopMatrix()
end

-- Drop four diamond hint-dots at the cardinal points — shown only when a marker is draggable-hovered.
local function drawDragHintDots(px, pz, radius, r, g, b, alpha)
	local gy = (GetGroundHeight(px, pz) or 0) + 8
	local d = radius * 1.18
	local offsets = { { d, 0 }, { -d, 0 }, { 0, d }, { 0, -d } }
	glColor(r, g, b, alpha)
	for i = 1, 4 do
		local o = offsets[i]
		glDrawGroundCircle(px + o[1], gy, pz + o[2], 8, 10)
	end
end

-- Main sleek marker: soft glow + subtle slow-rotating ring + inner ring + commander billboard.
-- Gentle, not flashy — minimal pulsing, slow rotation.
local function drawStartPosMarker(px, pz, color, alpha, iconPath, hovered, phase)
	local a = alpha or 1.0
	local r, g, b = color[1], color[2], color[3]

	-- 1) Soft ground glow (barely pulses)
	local pulse = 0.5 + 0.5 * math_sin(phase * 0.5)
	local glowMul = hovered and 1.6 or 1.0
	drawSoftDisc(px, pz, MARKER_RADIUS * (0.96 + 0.04 * pulse),
		r, g, b, 0.09 * a * glowMul, 20)

	-- 1b) On hover: steady bright outer ring — no pulsing, no wide halo
	if hovered then
		glColor(1, 1, 1, 0.55 * a)
		glLineWidth(2.5)
		glDrawGroundCircle(px, 0, pz, MARKER_RADIUS * 1.18, 40)
	end

	-- 2) Crisp inner hair-ring (static)
	glColor(r, g, b, 0.35 * a)
	glLineWidth(1.0)
	glDrawGroundCircle(px, 0, pz, MARKER_RADIUS * 0.55, 28)

	-- 3) Slow rotating arc-ring (single slow layer, 3 arcs)
	local rot = phase * 0.25   -- gentle slow spin
	glLineWidth(hovered and 2.8 or 2.0)
	drawArcSegments(px, pz, MARKER_RADIUS, r, g, b, (hovered and 0.85 or 0.65) * a, rot, 3, 0.66, 10)

	-- 4) (removed counter-rotating inner arcs for calmer look)

	-- 5) Faint vertical beam (subtle, non-pulsing)
	drawBeam(px, pz, r, g, b, (hovered and 0.30 or 0.18) * a, 0.5)

	-- 6) Commander billboard icon (static size diff on hover, no scale pulse)
	drawCommanderBillboard(px, pz, r, g, b, (hovered and 1.0 or 0.90) * a, iconPath, hovered)

	-- 7) Hover hint dots (kept, drag affordance)
	if hovered then
		drawDragHintDots(px, pz, MARKER_RADIUS, r, g, b, 0.7 * a)
	end
end

-- Lightweight preview marker (used by shape mode) — skips beam and hint dots for speed & clarity.
local function drawPreviewMarker(px, pz, color, alpha, iconPath, phase)
	local a = alpha or 1.0
	local r, g, b = color[1], color[2], color[3]
	drawSoftDisc(px, pz, MARKER_RADIUS * 0.85, r, g, b, 0.08 * a, 16)
	glColor(r, g, b, 0.55 * a)
	glLineWidth(1.8)
	local rot = phase * 0.4
	drawArcSegments(px, pz, MARKER_RADIUS, r, g, b, 0.55 * a, rot, 3, 0.66, 8)
	-- Smaller billboard icon for previews
	local gy = GetGroundHeight(px, pz) or 0
	glPushMatrix()
	glTranslate(px, gy + 90, pz)
	glBillboard()
	glTexture(iconPath)
	glColor(r, g, b, 0.65 * a)
	glTexRect(-36, -36, 36, 36)
	glTexture(false)
	glPopMatrix()
end

function widget:Update()
	-- Hover detection — drives cursor change + highlighted marker
	hoverPosIdx  = nil
	hoverBoxIdx  = nil
	hoverVertIdx = nil
	hoverBoxEdge = nil
	hoverPolyEdge = nil
	if not active then
		if WG.StartPosTool then WG.StartPosTool.hoveringDraggable = false end
		return
	end
	-- Don't steal cursor while a drag is in progress (cursor already correct)
	if dragIdx or boxDragIdx or boxEdgeDrag then
		if WG.StartPosTool then WG.StartPosTool.hoveringDraggable = true end
		return
	end

	local wx, wz = getWorldMousePosition()
	if wx then
		if subMode == "express" then
			local bestIdx, bestDist = nil, DRAGGABLE_DIST_SQ
			for i, pos in ipairs(positions) do
				local d = distSq(wx, wz, pos.x, pos.z)
				if d < bestDist then bestDist = d; bestIdx = i end
			end
			hoverPosIdx = bestIdx
		elseif subMode == "startbox" then
			hoverBoxIdx, hoverVertIdx = findNearestBoxVertex(wx, wz)
			if not hoverBoxIdx then
				local ebi, edge = findNearestBoxEdge(wx, wz)
				if ebi and edge then
					hoverBoxEdge = { bi = ebi, edge = edge }
				else
					local pbi, pei, pmx, pmz = findNearestPolygonEdgeMid(wx, wz)
					if pbi and pei then
						hoverPolyEdge = { bi = pbi, edgeIdx = pei, x = pmx, z = pmz }
					end
				end
			end
		end
	end

	local shouldMove = (hoverPosIdx ~= nil) or (hoverVertIdx ~= nil) or (hoverBoxEdge ~= nil) or (hoverPolyEdge ~= nil)
	if WG.StartPosTool then WG.StartPosTool.hoveringDraggable = shouldMove end
end

function widget:DrawWorld()
	if not active then return end

	local drawFrame = GetDrawFrame() or 0
	local phase = drawFrame * 0.04  -- ~2.4 rad/sec @ 60fps

	local wx, wz = getWorldMousePosition()

	-- Draw placed start positions (sleek 2026 style)
	for i, pos in ipairs(positions) do
		local pIdx = pos.playerIdx or pos.allyTeam
		local color = getColorForPlayer(pIdx)
		local iconPath = COMMANDER_ICONS[((pIdx - 1) % #COMMANDER_ICONS) + 1]
		local hovered = (hoverPosIdx == i) or (dragIdx == i)
		drawStartPosMarker(pos.x, pos.z, color, 1.0, iconPath, hovered, phase + i * 0.6)
	end

	-- Shape mode: preview outline + preview markers
	if subMode == "shape" and wx then
		local previewPts = generateShapePositions(wx, wz)
		glColor(1, 1, 1, 0.22)
		glLineWidth(1.5)
		local gy = GetGroundHeight(wx, wz) or 0

		local sides = ({
			circle   = 0,
			square   = 4,
			triangle = 3,
			hexagon  = 6,
			octagon  = 8,
		})[shapeType] or 0

		if sides == 0 then
			glDrawGroundCircle(wx, gy, wz, shapeRadius, MARKER_SEGMENTS)
		else
			local rotRad = shapeRotation * math_pi / 180
			glBeginEnd(GL_LINE_LOOP, function()
				for i = 1, sides do
					local angle = rotRad + (i - 1) * (2 * math_pi / sides)
					local vx = wx + shapeRadius * math_cos(angle)
					local vz = wz + shapeRadius * math_sin(angle)
					local vy = GetGroundHeight(vx, vz) or 0
					glVertex(vx, vy + 5, vz)
				end
			end)
		end

		for i, pt in ipairs(previewPts) do
			local zeroIdx = i - 1
			local numSlot = math_max(1, numTeamsPerAlly)
			local numAlly = math_max(1, numAllyTeams)
			local at, slot
			if placementMode == "sequential" then
				at   = math_floor(zeroIdx / numSlot) % numAlly + 1
				slot = (zeroIdx % numSlot) + 1
			else
				at   = (zeroIdx % numAlly) + 1
				slot = math_floor(zeroIdx / numAlly) % numSlot + 1
			end
			local pIdx = (at - 1) * numSlot + slot
			local color = getColorForPlayer(pIdx)
			local iconPath = COMMANDER_ICONS[((pIdx - 1) % #COMMANDER_ICONS) + 1]
			drawPreviewMarker(pt.x, pt.z, color, 0.55, iconPath, phase + i * 0.4)
		end
	end

	-- Express mode: ghost-cursor preview of the next position (or all symmetric copies)
	if subMode == "express" and wx and not dragIdx and hoverPosIdx == nil then
		local tb = WG.TerraformBrush
		local stb = tb and tb.getState and tb.getState() or nil
		local numSlot = math_max(1, numTeamsPerAlly)
		local numAlly = math_max(1, numAllyTeams)
		local baseIdx = (nextAllyTeam - 1) * numSlot + (nextTeamSlot or 1)
		-- Desaturated gray tint when the cursor is over terrain the commander can't spawn on
		-- (slope > unit moveDef.maxSlope). Makes the "click here" indicator read as disabled.
		local function tintForPlace(x, z, col)
			if isPlaceableForCommander(x, z) then return col end
			local lum = 0.299 * col[1] + 0.587 * col[2] + 0.114 * col[3]
			lum = lum * 0.6
			return { lum, lum, lum }
		end
		if stb and stb.symmetryActive and tb.getSymmetricPositions then
			local copies = tb.getSymmetricPositions(wx, wz, 0)
			for k, p in ipairs(copies) do
				local pIdx = ((baseIdx - 1 + (k - 1)) % math_max(1, numAlly * numSlot)) + 1
				local color = getColorForPlayer(pIdx)
				local iconPath = COMMANDER_ICONS[((pIdx - 1) % #COMMANDER_ICONS) + 1]
				drawPreviewMarker(p.x, p.z, tintForPlace(p.x, p.z, color), 0.5, iconPath, phase + k * 0.5)
			end
		else
			local color = getColorForPlayer(baseIdx)
			local iconPath = COMMANDER_ICONS[((baseIdx - 1) % #COMMANDER_ICONS) + 1]
			drawPreviewMarker(wx, wz, tintForPlace(wx, wz, color), 0.55, iconPath, phase)
		end
	end

	-- Draw startboxes (flat translucent mono-color fill via cached tessellated display list)
	for bi, box in ipairs(startboxes) do
		local color = getColorForAllyTeam(box.allyTeam)
		local verts = box.vertices
		if #verts >= 3 then
			local listId = ensureBoxFillList(box)
			if listId then
				glColor(color[1], color[2], color[3], 0.22)
				glCallList(listId)
			end
			glColor(color[1], color[2], color[3], 0.9)
			glLineWidth(2.5)
			glBeginEnd(GL_LINE_LOOP, function()
				for i = 1, #verts do
					local v  = verts[i]
					local vn = verts[(i % #verts) + 1]
					local segLen = math.sqrt((vn.x - v.x)^2 + (vn.z - v.z)^2)
					local steps = math_max(1, math.ceil(segLen / 48))
					for s = 0, steps - 1 do
						local t = s / steps
						local x = v.x + (vn.x - v.x) * t
						local z = v.z + (vn.z - v.z) * t
						local y = (GetGroundHeight(x, z) or 0) + 5
						glVertex(x, y, z)
					end
				end
			end)
			if box.kind == "box" and #verts == 4 then
				-- Draw edge resize handles as pairs of arrow tips (filled triangles) straddling
				-- the edge and pointing in opposite directions along the edge's normal axis.
				local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
				for _, v in ipairs(verts) do
					if v.x < minX then minX = v.x end
					if v.x > maxX then maxX = v.x end
					if v.z < minZ then minZ = v.z end
					if v.z > maxZ then maxZ = v.z end
				end
				local midEdges = {
					-- edge name -> midpoint + outward-normal axis (nx/nz) + tangent (tx/tz)
					L = { x = minX,             z = (minZ + maxZ) * 0.5, nx = -1, nz = 0, tx = 0, tz = 1 },
					R = { x = maxX,             z = (minZ + maxZ) * 0.5, nx =  1, nz = 0, tx = 0, tz = 1 },
					T = { x = (minX + maxX)*.5, z = minZ,                 nx = 0, nz = -1, tx = 1, tz = 0 },
					B = { x = (minX + maxX)*.5, z = maxZ,                 nx = 0, nz =  1, tx = 1, tz = 0 },
				}
				for name, mp in pairs(midEdges) do
					local isHover = (hoverBoxEdge and hoverBoxEdge.bi == bi and hoverBoxEdge.edge == name)
					-- Constant-screen-px sizing so arrows stay readable at any zoom.
					local sizePx = isHover and 22 or 16
					local size = worldRadiusForScreenPx(mp.x, mp.z, sizePx)
					local half = size * 0.55            -- half-base along the edge tangent
					local gap  = size * 0.35            -- clearance from the edge line so tips don't overlap
					local rim  = worldRadiusForScreenPx(mp.x, mp.z, 1.5)  -- 1.5px dark rim halo
					-- Two tips: one OUTSIDE the rect (apex pointing outward = +normal) and one
					-- INSIDE (apex pointing inward = -normal). Together they read as an
					-- up-and-down / left-and-right resize affordance across the edge.
					local function emitTip(signNormal, expand)
						-- Base center is offset `gap` off the edge along signNormal; apex is
						-- another `size` further along the same direction.
						local sz   = size + (expand or 0)
						local hf   = half + (expand or 0)
						local gp   = math_max(0, gap - (expand or 0))
						local bcx = mp.x + signNormal * gp * mp.nx
						local bcz = mp.z + signNormal * gp * mp.nz
						local apx = bcx + signNormal * sz * mp.nx
						local apz = bcz + signNormal * sz * mp.nz
						local b1x = bcx + mp.tx *  hf
						local b1z = bcz + mp.tz *  hf
						local b2x = bcx - mp.tx *  hf
						local b2z = bcz - mp.tz *  hf
						local apy = (GetGroundHeight(apx, apz) or 0) + 6
						local b1y = (GetGroundHeight(b1x, b1z) or 0) + 6
						local b2y = (GetGroundHeight(b2x, b2z) or 0) + 6
						glVertex(apx, apy, apz)
						glVertex(b1x, b1y, b1z)
						glVertex(b2x, b2y, b2z)
					end
					-- Dark crisp rim (slightly inflated triangle behind the colored fill).
					glColor(0, 0, 0, isHover and 0.85 or 0.70)
					glBeginEnd(GL_TRIANGLES, function()
						emitTip( 1, rim)
						emitTip(-1, rim)
					end)
					-- Flat solid color fill (matches handle disk styling).
					glColor(color[1], color[2], color[3], isHover and 1.0 or 0.92)
					glBeginEnd(GL_TRIANGLES, function()
						emitTip( 1, 0)
						emitTip(-1, 0)
					end)
					if isHover then
						-- Bright outline around both tips to highlight the picked edge
						glColor(1, 1, 1, 0.75)
						glLineWidth(2.0)
						local function outlineTip(signNormal)
							local bcx = mp.x + signNormal * gap * mp.nx
							local bcz = mp.z + signNormal * gap * mp.nz
							local apx = bcx + signNormal * size * mp.nx
							local apz = bcz + signNormal * size * mp.nz
							local b1x = bcx + mp.tx *  half
							local b1z = bcz + mp.tz *  half
							local b2x = bcx - mp.tx *  half
							local b2z = bcz - mp.tz *  half
							local apy = (GetGroundHeight(apx, apz) or 0) + 7
							local b1y = (GetGroundHeight(b1x, b1z) or 0) + 7
							local b2y = (GetGroundHeight(b2x, b2z) or 0) + 7
							glBeginEnd(GL_LINE_LOOP, function()
								glVertex(apx, apy, apz)
								glVertex(b1x, b1y, b1z)
								glVertex(b2x, b2y, b2z)
							end)
						end
						outlineTip( 1)
						outlineTip(-1)
					end
				end
				-- Corner handles for box-kind: draggable to resize from a corner (rect stays
				-- axis-aligned via the MouseMove drag handler).
				for vi, v in ipairs(verts) do
					local vy = GetGroundHeight(v.x, v.z) or 0
					local isHoverVert = (hoverBoxIdx == bi and hoverVertIdx == vi)
					local rPx   = isHoverVert and 22 or 14
					local vertR = worldRadiusForScreenPx(v.x, v.z, rPx)
					local rim   = worldRadiusForScreenPx(v.x, v.z, 1.5)
					local cy    = vy + 5
					local segs  = 22
					-- Dark crisp outline (matches arrow rim aesthetic).
					glBeginEnd(GL_TRIANGLE_FAN, function()
						glColor(0, 0, 0, isHoverVert and 0.85 or 0.70)
						glVertex(v.x, cy - 0.1, v.z)
						for s = 0, segs do
							local a = (s / segs) * 2 * math.pi
							glVertex(v.x + math_cos(a) * (vertR + rim), cy - 0.1, v.z + math_sin(a) * (vertR + rim))
						end
					end)
					-- Flat solid color disk (same color/alpha as the arrows).
					glBeginEnd(GL_TRIANGLE_FAN, function()
						glColor(color[1], color[2], color[3], isHoverVert and 1.0 or 0.92)
						glVertex(v.x, cy, v.z)
						for s = 0, segs do
							local a = (s / segs) * 2 * math.pi
							glVertex(v.x + math_cos(a) * vertR, cy, v.z + math_sin(a) * vertR)
						end
					end)
					if isHoverVert then
						glColor(1, 1, 1, 0.55)
						glLineWidth(2.0)
						glDrawGroundCircle(v.x, vy, v.z, vertR + worldRadiusForScreenPx(v.x, v.z, 4), 24)
					end
				end
			else
				local handles = (box.kind == "spline" and box.controls) or verts
				for vi, v in ipairs(handles) do
					local vy = GetGroundHeight(v.x, v.z) or 0
					local isHoverVert = (hoverBoxIdx == bi and hoverVertIdx == vi)
					local rPx   = isHoverVert and 22 or 14
					local vertR = worldRadiusForScreenPx(v.x, v.z, rPx)
					local rim   = worldRadiusForScreenPx(v.x, v.z, 1.5)
					local cy    = vy + 5
					local segs  = 22
					glBeginEnd(GL_TRIANGLE_FAN, function()
						glColor(0, 0, 0, isHoverVert and 0.85 or 0.70)
						glVertex(v.x, cy - 0.1, v.z)
						for s = 0, segs do
							local a = (s / segs) * 2 * math.pi
							glVertex(v.x + math_cos(a) * (vertR + rim), cy - 0.1, v.z + math_sin(a) * (vertR + rim))
						end
					end)
					glBeginEnd(GL_TRIANGLE_FAN, function()
						glColor(color[1], color[2], color[3], isHoverVert and 1.0 or 0.92)
						glVertex(v.x, cy, v.z)
						for s = 0, segs do
							local a = (s / segs) * 2 * math.pi
							glVertex(v.x + math_cos(a) * vertR, cy, v.z + math_sin(a) * vertR)
						end
					end)
					if isHoverVert then
						glColor(1, 1, 1, 0.55)
						glLineWidth(2.0)
						glDrawGroundCircle(v.x, vy, v.z, vertR + worldRadiusForScreenPx(v.x, v.z, 4), 24)
					end
				end
				-- Polygon / spline edge-midpoint ghost handle: faint circle at the edge midpoint
				-- under the cursor; clicking it inserts a new vertex / control point there and
				-- starts a drag (spline retessellates on each move).
				if hoverPolyEdge and hoverPolyEdge.bi == bi then
					local gmx, gmz = hoverPolyEdge.x, hoverPolyEdge.z
					local gy = GetGroundHeight(gmx, gmz) or 0
					glColor(color[1], color[2], color[3], 0.55)
					glDrawGroundCircle(gmx, gy, gmz, 28, 14)
					glColor(1, 1, 1, 0.55)
					glLineWidth(1.5)
					glDrawGroundCircle(gmx, gy, gmz, 36, 18)
				end
				-- Spline: show the control polygon as a faint closed polyline so the user sees
				-- the handle skeleton behind the smoothed curve.
				if box.kind == "spline" and box.controls and #box.controls >= 2 then
					glColor(color[1], color[2], color[3], 0.35)
					glLineWidth(1.0)
					glBeginEnd(GL_LINE_LOOP, function()
						for _, c in ipairs(box.controls) do
							local gy = GetGroundHeight(c.x, c.z) or 0
							glVertex(c.x, gy + 6, c.z)
						end
					end)
				end
			end
		end
	end

	-- Draw current box being drawn
	if drawingBox and #currentBoxVerts > 0 then
		local color = getColorForAllyTeam(nextBoxAllyTeam)
		glColor(color[1], color[2], color[3], 0.6)
		glLineWidth(2.0)
		if #currentBoxVerts >= 2 then
			glBeginEnd(GL_LINE_STRIP, function()
				for _, v in ipairs(currentBoxVerts) do
					local gy = GetGroundHeight(v.x, v.z) or 0
					glVertex(v.x, gy + 5, v.z)
				end
			end)
		end
		for _, v in ipairs(currentBoxVerts) do
			local gy = GetGroundHeight(v.x, v.z) or 0
			glColor(color[1], color[2], color[3], 0.8)
			glDrawGroundCircle(v.x, gy, v.z, 30, 12)
		end
		if wx and #currentBoxVerts >= 1 then
			local last = currentBoxVerts[#currentBoxVerts]
			glColor(color[1], color[2], color[3], 0.4)
			glLineWidth(1.5)
			local gy1 = GetGroundHeight(last.x, last.z) or 0
			local gy2 = GetGroundHeight(wx, wz) or 0
			glBeginEnd(GL_LINES, function()
				glVertex(last.x, gy1 + 5, last.z)
				glVertex(wx, gy2 + 5, wz)
			end)
		end
	end

	-- Draw drag-rect preview (startboxMode == "box")
	if subMode == "startbox" and boxRectActive and boxRectStartX and boxRectEndX then
		local color = getColorForAllyTeam(nextBoxAllyTeam)
		local x1, x2 = math_min(boxRectStartX, boxRectEndX), math_max(boxRectStartX, boxRectEndX)
		local z1, z2 = math_min(boxRectStartZ, boxRectEndZ), math_max(boxRectStartZ, boxRectEndZ)
		glColor(color[1], color[2], color[3], 0.75)
		glLineWidth(2.5)
		glBeginEnd(GL_LINE_LOOP, function()
			local y = GetGroundHeight(x1, z1) or 0; glVertex(x1, y + 6, z1)
			y = GetGroundHeight(x2, z1) or 0;       glVertex(x2, y + 6, z1)
			y = GetGroundHeight(x2, z2) or 0;       glVertex(x2, y + 6, z2)
			y = GetGroundHeight(x1, z2) or 0;       glVertex(x1, y + 6, z2)
		end)
		-- Light fill outline (second pass, fainter)
		glColor(color[1], color[2], color[3], 0.18)
		glLineWidth(1.0)
		glBeginEnd(GL_LINE_LOOP, function()
			local y = GetGroundHeight(x1, z1) or 0; glVertex(x1, y + 3, z1)
			y = GetGroundHeight(x2, z1) or 0;       glVertex(x2, y + 3, z1)
			y = GetGroundHeight(x2, z2) or 0;       glVertex(x2, y + 3, z2)
			y = GetGroundHeight(x1, z2) or 0;       glVertex(x1, y + 3, z2)
		end)
	end

	-- Draw freedraw in-progress path
	if subMode == "startbox" and freeDrawActive and #freeDrawPts >= 2 then
		local color = getColorForAllyTeam(nextBoxAllyTeam)
		glColor(color[1], color[2], color[3], 0.85)
		glLineWidth(2.2)
		glBeginEnd(GL_LINE_STRIP, function()
			for _, p in ipairs(freeDrawPts) do
				local gy = GetGroundHeight(p.x, p.z) or 0
				glVertex(p.x, gy + 5, p.z)
			end
		end)
		-- Dot at start so the user sees where it will close
		local first = freeDrawPts[1]
		local gy = GetGroundHeight(first.x, first.z) or 0
		glColor(1, 1, 1, 0.8)
		glDrawGroundCircle(first.x, gy, first.z, 24, 14)
	end

	glColor(1, 1, 1, 1)
	glLineWidth(1.0)
end

-- Team name lookup for labels
local TEAM_NAMES = {
	"Blue", "Red", "Green", "Yellow", "Fuchsia", "Cyan", "Orange", "Pink",
	"DkGreen", "Brown", "LtBlue", "DkRed", "Mint", "Amber", "Lavender", "Teal",
}

local function getTeamName(at)
	local idx = ((at - 1) % #TEAM_NAMES) + 1
	return TEAM_NAMES[idx]
end

-- Compute screen-space radius of a world-space circle at (wx, wz) with given worldRadius.
-- Returns screenCenterX, screenCenterY, screenRadiusPx, visible(bool)
local function getScreenMarker(wx, wz, worldRadius)
	local gy = GetGroundHeight(wx, wz) or 0
	local cx, cy, cz = WorldToScreenCoords(wx, gy, wz)
	if not cz or cz <= 0 or cz >= 1 then return nil end
	-- Project an edge point to measure screen radius
	local ex, ey = WorldToScreenCoords(wx + worldRadius, gy, wz)
	local screenR = math_sqrt((ex - cx) * (ex - cx) + (ey - cy) * (ey - cy))
	return cx, cy, screenR, true
end

-- World radius needed at (wx, wz) so the resulting on-screen size is `screenPx` pixels.
-- Lets handles/arrows keep a constant pixel size at any zoom level.
worldRadiusForScreenPx = function(wx, wz, screenPx)
	local gy = GetGroundHeight(wx, wz) or 0
	local sx0, sy0, sz0 = WorldToScreenCoords(wx, gy, wz)
	if not sz0 or sz0 <= 0 or sz0 >= 1 then return screenPx end
	local probe = 100
	local sxe, sye = WorldToScreenCoords(wx + probe, gy, wz)
	if not sxe then return screenPx end
	local pxPerWorld = math_sqrt((sxe - sx0) * (sxe - sx0) + (sye - sy0) * (sye - sy0)) / probe
	if pxPerWorld < 0.0001 then return screenPx end
	return screenPx / pxPerWorld
end

-- Minimum screen-space padding between marker top and text bottom
local LABEL_PAD = 18

local glGetTextWidth = gl.GetTextWidth

-- Draw a sleek screen-space badge: colored left-bar + "Team N" label.
-- Uses filled quads via glBeginEnd + glText. "2026" aesthetic: minimal, high-contrast, CHUNKY.
local function drawScreenBadge(cx, cy, color, allyTeamNum, teamName, playerIdx, fontSize, hovered)
	local padX, padY = 14, 10
	local barW = 5
	local gap  = 10
	local label = "Team " .. tostring(allyTeamNum)

	-- Measure text widths in pixels (gl.GetTextWidth returns factor to multiply by fontSize)
	local function measure(s, sz)
		local w = glGetTextWidth and glGetTextWidth(s) or (#s * 0.55)
		return w * sz
	end
	local bigSize    = fontSize
	local textW      = measure(label, bigSize)
	local w          = barW + gap + textW + padX * 2
	local h          = bigSize * 1.18 + padY * 2
	local bx         = cx - w * 0.5
	local by         = cy

	-- Card background (dark chamfered-corner rect — octagon fan)
	local bgA = hovered and 0.85 or 0.68
	glColor(0.04, 0.06, 0.09, bgA)
	glBeginEnd(GL_TRIANGLE_FAN, function()
		glVertex(bx + 4,     by)
		glVertex(bx + w - 4, by)
		glVertex(bx + w,     by + 4)
		glVertex(bx + w,     by + h - 4)
		glVertex(bx + w - 4, by + h)
		glVertex(bx + 4,     by + h)
		glVertex(bx,         by + h - 4)
		glVertex(bx,         by + 4)
	end)

	-- Outer accent frame on hover (bright white thin ring)
	if hovered then
		glColor(1, 1, 1, 0.85)
		glLineWidth(2.0)
		glBeginEnd(GL_LINE_LOOP, function()
			glVertex(bx + 4,     by)
			glVertex(bx + w - 4, by)
			glVertex(bx + w,     by + 4)
			glVertex(bx + w,     by + h - 4)
			glVertex(bx + w - 4, by + h)
			glVertex(bx + 4,     by + h)
			glVertex(bx,         by + h - 4)
			glVertex(bx,         by + 4)
		end)
	end

	-- Colored left accent bar
	glColor(color[1], color[2], color[3], 1.0)
	glBeginEnd(GL_TRIANGLE_FAN, function()
		glVertex(bx + padX,          by + padY)
		glVertex(bx + padX + barW,   by + padY)
		glVertex(bx + padX + barW,   by + h - padY)
		glVertex(bx + padX,          by + h - padY)
	end)

	-- Soft color tint bg
	glColor(color[1], color[2], color[3], hovered and 0.22 or 0.12)
	glBeginEnd(GL_TRIANGLE_FAN, function()
		glVertex(bx + padX + barW + 1, by + padY)
		glVertex(bx + w - padX,        by + padY)
		glVertex(bx + w - padX,        by + h - padY)
		glVertex(bx + padX + barW + 1, by + h - padY)
	end)

	-- "Team N" label (shadow + color-bright)
	local textX = bx + padX + barW + gap
	local textY = by + padY
	glColor(0, 0, 0, 0.90)
	glText(label, textX + 2, textY + 2, bigSize, "o")
	glColor(math_min(1, color[1] * 0.55 + 0.45), math_min(1, color[2] * 0.55 + 0.45), math_min(1, color[3] * 0.55 + 0.45), 1.0)
	glText(label, textX, textY, bigSize, "o")
end

function widget:DrawScreenEffects()
	if not active then return end

	-- Screen-space sleek badges for placed positions
	for i, pos in ipairs(positions) do
		local sx, sy, sr, vis = getScreenMarker(pos.x, pos.z, MARKER_RADIUS)
		if vis then
			local pIdx = pos.playerIdx or pos.allyTeam
			local color = getColorForPlayer(pIdx)
			local badgeY = sy + sr + LABEL_PAD
			local fontSize = 32   -- 2026 chunky
			local hovered = (hoverPosIdx == i) or (dragIdx == i)
			drawScreenBadge(sx, badgeY, color, pos.allyTeam, getTeamName(pIdx), pIdx, fontSize, hovered)
		end
	end

	-- Startbox labels: centroid card
	for _, box in ipairs(startboxes) do
		if #box.vertices >= 3 then
			-- Place the badge above the box's TOP screen edge so it doesn't sit on top of
			-- the body-drag affordance at the centroid. Find the smallest screen-y across
			-- the projected vertices, pick its X for horizontal anchoring, then offset up.
			local bestSx, bestSy, bestVis
			for _, v in ipairs(box.vertices) do
				local vy = GetGroundHeight(v.x, v.z) or 0
				local sx, sy, sz = WorldToScreenCoords(v.x, vy, v.z)
				if sz and sz > 0 and sz < 1 then
					if (not bestSy) or sy > bestSy then  -- screen y grows downward; max sy = top of screen
						bestSy = sy
						bestSx = sx
						bestVis = true
					end
				end
			end
			if not bestVis then
				-- Fallback: centroid (e.g. all corners off-screen but center on-screen)
				local ccx, ccz = 0, 0
				for _, v in ipairs(box.vertices) do ccx = ccx + v.x; ccz = ccz + v.z end
				ccx = ccx / #box.vertices
				ccz = ccz / #box.vertices
				local ccy = GetGroundHeight(ccx, ccz) or 0
				local sx, sy, sz = WorldToScreenCoords(ccx, ccy, ccz)
				if sz and sz > 0 and sz < 1 then bestSx, bestSy, bestVis = sx, sy, true end
			end
			if bestVis then
				local color = getColorForAllyTeam(box.allyTeam)
				drawScreenBadge(bestSx, bestSy + 28, color, box.allyTeam, getTeamName(box.allyTeam) .. " BOX", box.allyTeam, 26, false)
			end
		end
	end

	-- Shape preview small badges
	if subMode == "shape" then
		local wx, wz = getWorldMousePosition()
		if wx then
			local previewPts = generateShapePositions(wx, wz)
			local numAlly = math_max(1, numAllyTeams)
			local numSlot = math_max(1, numTeamsPerAlly)
			for i, pt in ipairs(previewPts) do
				local zeroIdx = i - 1
				local at, slot
				if placementMode == "sequential" then
					at   = math_floor(zeroIdx / numSlot) % numAlly + 1
					slot = (zeroIdx % numSlot) + 1
				else
					at   = (zeroIdx % numAlly) + 1
					slot = math_floor(zeroIdx / numAlly) % numSlot + 1
				end
				local pIdx = (at - 1) * numSlot + slot
				local psx, psy, psr, pvis = getScreenMarker(pt.x, pt.z, MARKER_RADIUS * 0.72)
				if pvis then
					local color = getColorForPlayer(pIdx)
					local label = "Team" .. at .. " P" .. pIdx
					local baseY = psy + psr + LABEL_PAD
					glColor(0, 0, 0, 0.7)
					glText(label, psx + 2, baseY - 2, 22, "cn")
					glColor(color[1], color[2], color[3], 0.85)
					glText(label, psx, baseY, 22, "cn")
				end
			end
		end
	end

	glColor(1, 1, 1, 1)
end

-- ============================================================
-- Widget Interface
-- ============================================================

function widget:Initialize()
	WG.StartPosTool = {
		activate            = activate,
		deactivate          = deactivate,
		getState            = getState,
		hoveringDraggable   = false,
		setSubMode          = setSubMode,
		setShape            = setShape,
		setRadius           = setRadius,
		setRotation         = setRotation,
		setShapeCount       = setShapeCount,
		setNumAllyTeams     = setNumAllyTeams,
		setNumTeamsPerAlly  = setNumTeamsPerAlly,
		setPlacementMode    = setPlacementMode,
		togglePlacementMode = togglePlacementMode,
		setStartboxMode     = setStartboxMode,
		clearAllPositions   = clearAllPositions,
		placeRandomPositions = placeRandomPositions,
		saveStartPositions  = saveStartPositions,
		loadStartPositions  = loadStartPositions,
		listSavedConfigs    = listSavedConfigs,
		saveStartboxes      = saveStartboxes,
		loadStartboxes      = loadStartboxes,
		listSavedStartboxConfigs = listSavedStartboxConfigs,
		clearAllStartboxes  = clearAllStartboxes,
		finishStartbox      = finishStartbox,
		generateStartScript = generateStartScript,
		saveStartScript     = saveStartScript,
	}
end

function widget:Shutdown()
	WG.StartPosTool = nil
	for i = 1, #startboxes do freeBoxFillList(startboxes[i]) end
end
