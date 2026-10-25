function widget:GetInfo()
	return {
		name = "Start Positions Tool",
		desc = "Place and configure start positions and start boxes for map editing",
		author = "PtaQ",
		date = "2026",
		license = "GPL v2",
		layer = 1000000,
		enabled = false,
		handler = true,
	}
end

-- ============================================================
-- Spring API Caching
-- ============================================================
local Spring = Spring
local Echo = Spring.Echo
local GetMouseState = Spring.GetMouseState
local TraceScreenRay = Spring.TraceScreenRay
local GetGroundHeight = Spring.GetGroundHeight
local WorldToScreenCoords = Spring.WorldToScreenCoords
local GetDrawFrame = Spring.GetDrawFrame

local gl = gl
local glColor = gl.Color
local glLineWidth = gl.LineWidth
local glDrawGroundCircle = gl.DrawGroundCircle
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glTranslate = gl.Translate
local glBillboard = gl.Billboard
local glText = gl.Text
local glBeginEnd = gl.BeginEnd
local glVertex = gl.Vertex
local glTexture = gl.Texture
local glTexRect = gl.TexRect
local glBlending = gl.Blending
local glDepthTest = gl.DepthTest
local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList
local GL_LINE_LOOP = GL.LINE_LOOP
local GL_LINE_STRIP = GL.LINE_STRIP
local GL_LINES = GL.LINES
local GL_TRIANGLE_FAN = GL.TRIANGLE_FAN
local GL_TRIANGLE_STRIP = GL.TRIANGLE_STRIP
local GL_TRIANGLES = GL.TRIANGLES
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE = GL.ONE
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA

-- Commander icons, cycled by player index (allyTeam when a position has no playerIdx).
local COMMANDER_ICONS = {
	"icons/armcom.png",
	"icons/corcom.png",
	"icons/legcom.png",
}

local DRAGGABLE_DIST_SQ = 120 * 120 -- world distance^2 inside which the cursor becomes "move"

local math_floor = math.floor
local math_sqrt = math.sqrt
local math_sin = math.sin
local math_cos = math.cos
local math_pi = math.pi
local math_max = math.max
local math_min = math.min
local math_random = math.random

-- ============================================================
-- Constants
-- ============================================================
local MARKER_RADIUS = 80 -- world radius of start position marker circle
local MARKER_SEGMENTS = 32 -- circle smoothness
local DRAG_THRESHOLD_SQ = 25 -- pixels^2 before drag starts
local CLICK_DISTANCE_SQ = 120 * 120 -- world distance^2 to pick a marker
local MIN_RADIUS = 64
local MAX_RADIUS = 16384 -- allow full-map shapes
local RADIUS_STEP = 32 -- scroll step for startpos mode (faster)
local MAX_POSITIONS = 256 -- absolute hard cap (players)
local MAX_ALLYTEAMS = 32 -- max configurable ally teams
local MAX_TEAMS_PER_ALLY = 16 -- max team slots per ally team
local SAVE_DIR = "Terraform Brush/StartPositions/"
local STARTBOX_SAVE_DIR = "Terraform Brush/Startboxes/"
local VERTEX_PICK_DIST_SQ = 60 * 60 -- world distance^2 to pick a startbox vertex

-- Role-labelling config and state for start-position-suggestions export.
local roleConfig = {
	options = { "front", "air", "tech", "sea", "front/air", "front/tech", "front/sea", "air/tech" },
	saveDir = "Terraform Brush/StartPositions/Suggestions/",
}

-- Team colors: the game_autocolors.lua FFA palette (0-1 RGBA) plus 16 extras. Indices wrap,
-- so 256 players reuse colors.
local TEAM_COLORS = {
	{ 0.000, 0.302, 1.000, 1.0 }, --  1: Blue       #004DFF
	{ 1.000, 0.063, 0.020, 1.0 }, --  2: Red        #FF1005
	{ 0.047, 0.914, 0.031, 1.0 }, --  3: Green      #0CE908
	{ 1.000, 0.824, 0.000, 1.0 }, --  4: Yellow     #FFD200
	{ 0.973, 0.031, 0.537, 1.0 }, --  5: Fuchsia    #F80889
	{ 0.035, 0.961, 0.961, 1.0 }, --  6: Cyan       #09F5F5
	{ 1.000, 0.380, 0.027, 1.0 }, --  7: Orange     #FF6107
	{ 0.945, 0.565, 0.702, 1.0 }, --  8: Pink       #F190B3
	{ 0.035, 0.494, 0.110, 1.0 }, --  9: Dark Green #097E1C
	{ 0.784, 0.545, 0.184, 1.0 }, -- 10: Brown      #C88B2F
	{ 0.486, 0.631, 1.000, 1.0 }, -- 11: Light Blue #7CA1FF
	{ 0.624, 0.051, 0.020, 1.0 }, -- 12: Dark Red   #9F0D05
	{ 0.243, 1.000, 0.635, 1.0 }, -- 13: Mint       #3EFFA2
	{ 0.961, 0.635, 0.000, 1.0 }, -- 14: Amber      #F5A200
	{ 0.769, 0.663, 1.000, 1.0 }, -- 15: Lavender   #C4A9FF
	{ 0.043, 0.518, 0.608, 1.0 }, -- 16: Teal       #0B849B
	{ 0.600, 0.200, 0.800, 1.0 }, -- 17: Purple
	{ 0.900, 0.500, 0.100, 1.0 }, -- 18: Burnt Orange
	{ 0.400, 0.800, 0.700, 1.0 }, -- 19: Seafoam
	{ 0.800, 0.100, 0.400, 1.0 }, -- 20: Magenta
	{ 0.300, 0.600, 0.100, 1.0 }, -- 21: Olive
	{ 0.100, 0.400, 0.700, 1.0 }, -- 22: Navy
	{ 0.950, 0.850, 0.400, 1.0 }, -- 23: Pale Gold
	{ 0.500, 0.500, 0.500, 1.0 }, -- 24: Gray
	{ 0.900, 0.900, 0.900, 1.0 }, -- 25: White
	{ 0.200, 0.200, 0.200, 1.0 }, -- 26: Charcoal
	{ 0.700, 0.300, 0.300, 1.0 }, -- 27: Rose
	{ 0.300, 0.700, 0.500, 1.0 }, -- 28: Jade
	{ 0.500, 0.300, 0.100, 1.0 }, -- 29: Chocolate
	{ 0.900, 0.400, 0.600, 1.0 }, -- 30: Flamingo
	{ 0.200, 0.800, 0.900, 1.0 }, -- 31: Sky
	{ 0.700, 0.800, 0.200, 1.0 }, -- 32: Lime
}

-- ============================================================
-- State
-- ============================================================
local active = false
local subMode = "express" -- "express" | "shape" | "startbox" | "roles"
local positions = {} -- { {x=, z=, allyTeam=, teamSlot=, playerIdx=}, ... }
local nextAllyTeam = 1 -- next allyteam in rotation
local nextTeamSlot = 1 -- next player slot within that allyteam
local numAllyTeams = 2 -- configurable count (ally teams)
local numTeamsPerAlly = 1 -- configurable count (players per ally)
local placementMode = "roundrobin" -- "roundrobin" = A,B,C,A,B,C... | "sequential" = A,A,B,B,C,C...

-- Shape placement state
local shapeType = "circle" -- "circle"|"square"|"hexagon"|"octagon"|"triangle"
local shapeRadius = 2000
local shapeRotation = 0 -- degrees
local shapeCount = 4 -- number of positions to place with shape

-- Startbox state
local startboxes = {} -- { {vertices={{x=,z=}, ...}, allyTeam=}, ... }
-- Forward declarations: the fill-list helpers live in the drawing section but box edits up
-- here call them. Typed so the analyzer does not read those calls as calls on nil.
---@type fun(box: any): any
local ensureBoxFillList
---@type fun(box: any)
local invalidateBoxFill
---@type fun(box: any)
local freeBoxFillList
-- World radius that gives a constant on-screen pixel size at (wx, wz), so handles keep
-- their size while zooming. Defined in the drawing section.
---@type fun(wx: number, wz: number, screenPx: number): number
local worldRadiusForScreenPx
local startboxMode = "polygon" -- "polygon" | "box" | "freedraw"
local drawingBox = false
local currentBoxVerts = {}
local boxDragIdx = nil -- which vertex is being dragged
local boxDragBoxIdx = nil -- which box
local boxEdgeDrag = nil -- { bi = <box index>, edge = "L"/"R"/"T"/"B" } for box-kind edge drag
local hoverBoxEdge = nil -- { bi, edge } for hover highlight of the edge currently under cursor
-- Curvature editing: clicking a handle without moving selects it and raises a gizmo along
-- its outward normal; dragging along the gizmo sets the anchor strength (0 to 1).
-- One table instead of file-level locals: the main chunk sits on Lua's 200-local ceiling.
-- selBox / selVert (box index, vertex index) are left out of the constructor: a `= nil`
-- there makes the analyzer read them as never set.
local strengthEdit = {
	dragging = false,
	GIZMO_LEN = 240, -- world units from anchor to the strength-1 end of the gizmo
	scratch = {}, -- reused anchor ring, see buildRing
}
-- Whole-box drag (pressed inside a box body, not on a handle or edge): moves every vertex
-- and spline control by the cursor delta between frames.
local boxBodyDrag = nil -- { bi = <box index>, lastX = <world x>, lastZ = <world z> }
-- True during any startbox vertex, edge or body drag; ensureBoxFillList uses it to defer
-- the costly fill rebuild until MouseRelease.
local isDraggingBox = false
local pendingFillRebuildIdx = nil -- box index whose fill needs rebuilding on drag end
-- Box drag-rect (startboxMode == "box"): two corners, live-updated during drag
local boxRectStartX = nil
local boxRectStartZ = nil
local boxRectEndX = nil
local boxRectEndZ = nil
local boxRectActive = false
-- Free-draw state (startboxMode == "freedraw"): collect points with minimum spacing
local freeDrawPts = {}
local freeDrawActive = false
local FREEDRAW_MIN_DIST_SQ = 40 * 40 -- minimum world distance between sample points

-- Drag state
local dragging = false
local dragIdx = nil -- which position index is being dragged
local dragStartX = nil
local dragStartY = nil -- screen coords at mouse-down
local dragFrom = nil -- { pos, x, z, y } of the position at mouse-down, for the drag's undo entry

-- Hover state (drives cursor + marker highlight)
local hoverPosIdx = nil -- index of position currently hovered (express mode)
local hoverBoxIdx = nil -- which startbox is being vertex-hovered
local hoverVertIdx = nil
-- Ghost handle at a polygon edge midpoint: click there to insert a vertex and drag it.
-- { bi, edgeIdx, x, z }, edgeIdx is the index of the edge's start vertex.
local hoverPolyEdge = nil

-- Undo history shared by both submodes; each entry carries the `mode` that made it so
-- Ctrl+Z in one submode never rewinds the other.
-- Position entry: { mode, count, prevNextAllyTeam, prevNextTeamSlot }: drop the last
-- `count` positions and restore the rotation counters.
local undoHistory = {}
-- Startbox entries snapshot just the box they touch, so no operation needs an inverse.
-- The functions are assigned further down, after retessellateSpline is in scope.
local boxUndo = { redo = {} }
-- Override-modoption export. Libs load on first use (a button press), not at include time.
local boxExport = {}

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

-- One color per player, so teammates in the same allyteam stay distinct.
-- playerIdx = (allyTeam-1)*numTeamsPerAlly + teamSlot.
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
		pts[#pts + 1] = { x = x, z = z }
	end
	return pts
end

local function generatePolygonPositions(cx, cz, radius, sides, count, rotation)
	-- Vertices first; if count > sides, subdivide edges at their midpoints until there are
	-- enough points (at most 6 levels). The last level only splits as many edges as it needs,
	-- spread evenly around the ring, so every vertex is always kept.
	local pts = {}
	local rotRad = rotation * math_pi / 180
	local vertices = {}
	for i = 1, sides do
		local angle = rotRad + (i - 1) * (2 * math_pi / sides)
		vertices[i] = {
			x = cx + radius * math_cos(angle),
			z = cz + radius * math_sin(angle),
		}
	end
	local allPoints = {}
	for i = 1, sides do
		allPoints[#allPoints + 1] = vertices[i]
	end
	-- Each pass interleaves midpoints into the ring (v1, m12, v2, m23, ...).
	local level = 1
	while #allPoints < count do
		local prevPoints = {}
		local n = #allPoints
		local need = count - n
		local split = nil -- edges that get a midpoint on a partial level; nil = all of them
		if need < n then
			split = {}
			for k = 0, need - 1 do
				split[math_floor(k * n / need) + 1] = true
			end
		end
		for i = 1, n do
			prevPoints[#prevPoints + 1] = allPoints[i]
			if not split or split[i] then
				local j = (i % n) + 1
				local mx = (allPoints[i].x + allPoints[j].x) * 0.5
				local mz = (allPoints[i].z + allPoints[j].z) * 0.5
				prevPoints[#prevPoints + 1] = { x = mx, z = mz }
			end
		end
		allPoints = prevPoints
		level = level + 1
		if level > 6 then
			break
		end -- safety cap
	end
	-- The first `count` points walking around the ring: all of them when count > sides, the
	-- first `count` vertices otherwise.
	for i = 1, math_min(count, #allPoints) do
		local x, z = clampToMap(allPoints[i].x, allPoints[i].z)
		pts[i] = { x = x, z = z }
	end
	return pts
end

local function generateShapePositions(cx, cz)
	local sides = ({
		circle = 0,
		square = 4,
		triangle = 3,
		hexagon = 6,
		octagon = 8,
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
		circle = 0,
		square = 4,
		triangle = 3,
		hexagon = 6,
		octagon = 8,
	})[shapeType] or 0

	for i = 1, shapeCount do
		if sides == 0 then
			-- Uniform inside the circle (sqrt keeps the density even).
			local angle = math_random() * 2 * math_pi
			local r = shapeRadius * math_sqrt(math_random())
			local x = cx + r * math_cos(angle)
			local z = cz + r * math_sin(angle)
			x, z = clampToMap(x, z)
			pts[i] = { x = x, z = z }
		else
			-- Polygons: pick one of the equal centre-to-edge triangles, then a uniform point in
			-- it, so every point lands inside the same rotated outline the shape mode draws.
			local rotRad = shapeRotation * math_pi / 180
			local step = 2 * math_pi / sides
			local a1 = rotRad + math_floor(math_random() * sides) * step
			local a2 = a1 + step
			local s = math_sqrt(math_random())
			local t = math_random()
			local u, v = s * (1 - t), s * t
			local x = cx + shapeRadius * (u * math_cos(a1) + v * math_cos(a2))
			local z = cz + shapeRadius * (u * math_sin(a1) + v * math_sin(a2))
			x, z = clampToMap(x, z)
			pts[i] = { x = x, z = z }
		end
	end
	return pts
end

-- ============================================================
-- Core Operations
-- ============================================================

-- Commander slope tolerance, cached: the modoption `startpos_max_slope` if set, else the
-- smallest moveDef.maxSlope among commander units (customParams flags or name), else 0.5.
-- Same "1 - cos(angle)" space as the 4th value of Spring.GetGroundNormal.
local _cachedCommanderMaxSlope = nil
local function getCommanderMaxSlope()
	if _cachedCommanderMaxSlope ~= nil then
		return _cachedCommanderMaxSlope or nil
	end
	local modOpt = Spring.GetModOptions and Spring.GetModOptions()
	if modOpt and tonumber(modOpt.startpos_max_slope) then
		_cachedCommanderMaxSlope = tonumber(modOpt.startpos_max_slope)
		return _cachedCommanderMaxSlope
	end
	local best = nil
	local function isCommander(ud)
		local cp = ud.customParams
		if not cp then
			return false
		end
		if cp.iscommander or cp.isCommander then
			return true
		end
		if cp.commander or cp.is_commander then
			return true
		end
		-- Fallback: the unit name says commander (commander, armcom, corcom, legcom)
		local n = ud.name and ud.name:lower()
		return n and (n:find("commander") or n:find("^armcom") or n:find("^corcom") or n:find("^legcom")) and true
			or false
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
	-- No grounded commander found (none tagged, or no moveDef): 0.5 is 60 degrees in 1-cos
	-- space, loose enough not to reject reasonable ground.
	_cachedCommanderMaxSlope = best or 0.5
	return _cachedCommanderMaxSlope
end

-- Ground slope at (x, z) in 1-cos space, the same domain as movedef.maxSlope.
local function getGroundSlopeAt(x, z)
	-- 4th return of GetGroundNormal is 1 - ny.
	local _, _, _, slope = Spring.GetGroundNormal(x, z, false)
	return slope or 0
end

local function isPlaceableForCommander(x, z)
	return getGroundSlopeAt(x, z) <= getCommanderMaxSlope()
end

local function addPosition(x, z, allyTeam, teamSlot)
	if #positions >= MAX_POSITIONS then
		return false
	end
	x, z = clampToMap(x, z)
	-- Reject ground too steep for the commander to spawn on.
	if not isPlaceableForCommander(x, z) then
		Echo(
			"[StartPos Tool] Skipped: slope exceeds commander tolerance at ("
				.. math_floor(x)
				.. ","
				.. math_floor(z)
				.. ")"
		)
		return false
	end
	local y = GetGroundHeight(x, z) or 0
	teamSlot = teamSlot or 1
	local playerIdx = (allyTeam - 1) * math_max(1, numTeamsPerAlly) + teamSlot
	positions[#positions + 1] = {
		x = x,
		z = z,
		y = y,
		allyTeam = allyTeam,
		teamSlot = teamSlot,
		playerIdx = playerIdx,
	}
	return true
end

-- Advance nextAllyTeam and nextTeamSlot to the next player per placement mode.
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

-- Pure role-cycling helper, kept apart from the position mutation so it can be tested alone.
local RoleCycle = {}

function RoleCycle.nextRole(currentRole, direction, roleOptions)
	direction = direction or 1
	local n = #roleOptions
	if n == 0 then
		return nil
	end
	local currentRoleIdx
	for i, r in ipairs(roleOptions) do
		if r == currentRole then
			currentRoleIdx = i
			break
		end
	end
	if not currentRoleIdx then
		-- No role assigned yet: forward starts at first, backward at last.
		return direction > 0 and roleOptions[1] or roleOptions[n]
	end
	if direction > 0 then
		if currentRoleIdx < n then
			return roleOptions[currentRoleIdx + 1]
		end
		-- Past either end clears the role, so cycling can always get back to blank.
		return nil
	else
		if currentRoleIdx > 1 then
			return roleOptions[currentRoleIdx - 1]
		end
		return nil
	end
end

function roleConfig.cyclePositionRole(idx, direction, roleOptions)
	local pos = positions[idx]
	if not pos then
		return nil
	end
	pos.role = RoleCycle.nextRole(pos.role, direction, roleOptions or roleConfig.options)
	return pos.role
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

-- Shape placement spreads evenly over every allyTeam x teamSlot pair, so a 4-ally, 2-team
-- shape of 8 places one of each.
local function placeShapePositions(cx, cz)
	local pts = generateShapePositions(cx, cz)
	local numAlly = math_max(1, numAllyTeams)
	local numSlot = math_max(1, numTeamsPerAlly)
	for i, pt in ipairs(pts) do
		local zeroIdx = i - 1
		local at, slot
		if placementMode == "sequential" then
			at = math_floor(zeroIdx / numSlot) % numAlly + 1
			slot = (zeroIdx % numSlot) + 1
		else
			at = (zeroIdx % numAlly) + 1
			slot = math_floor(zeroIdx / numAlly) % numSlot + 1
		end
		addPosition(pt.x, pt.z, at, slot)
	end
end

-- Whole shape on one allyTeam (one per symmetric copy); teamSlot still cycles so players
-- stay distinct.
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
			at = math_floor(zeroIdx / numSlot) % numAlly + 1
			slot = (zeroIdx % numSlot) + 1
		else
			at = (zeroIdx % numAlly) + 1
			slot = math_floor(zeroIdx / numAlly) % numSlot + 1
		end
		addPosition(pt.x, pt.z, at, slot)
	end
end

-- ============================================================
-- Startbox Operations
-- ============================================================

local function addStartboxVertex(x, z)
	-- The brush's grid snap applies to startbox vertices too.
	---@type table?
	local tb = WG.TerraformBrush
	local stb = tb and tb.getState and tb.getState() or nil
	if stb and stb.gridSnap and tb.snapWorld then
		x, z = tb.snapWorld(x, z, 0)
	end
	x, z = clampToMap(x, z)
	currentBoxVerts[#currentBoxVerts + 1] = { x = x, z = z }
end

-- Ally team is the box's list position, never a counter: the modoption format means order
-- (box 1 is allyTeam 0), and a delete cannot desync it. One box per team follows.
local function renumberBoxAllyTeams()
	for i = 1, #startboxes do
		startboxes[i].allyTeam = i
	end
end

local function finishStartbox()
	if #currentBoxVerts >= 3 then
		startboxes[#startboxes + 1] = {
			vertices = currentBoxVerts,
			allyTeam = #startboxes + 1,
		}
		renumberBoxAllyTeams()
		boxUndo.push("add", #startboxes, startboxes[#startboxes])
	end
	currentBoxVerts = {}
	drawingBox = false
end

-- Reduce a dense closed polyline to about targetCount control points, keeping the sharpest turns.
local function fitControlPoints(pts, targetCount)
	targetCount = targetCount or 8
	local n = #pts
	if n <= targetCount then
		local out = {}
		for i = 1, n do
			out[i] = { x = pts[i].x, z = pts[i].z }
		end
		return out
	end
	-- Curvature score per point: turning angle between (p-1 -> p) and (p -> p+1).
	local scored = {}
	for i = 1, n do
		local prev = pts[((i - 2) % n) + 1]
		local cur = pts[i]
		local nxt = pts[(i % n) + 1]
		local ax, az = cur.x - prev.x, cur.z - prev.z
		local bx, bz = nxt.x - cur.x, nxt.z - cur.z
		local la = math.sqrt(ax * ax + az * az) + 1e-9
		local lb = math.sqrt(bx * bx + bz * bz) + 1e-9
		local d = (ax * bx + az * bz) / (la * lb)
		if d > 1 then
			d = 1
		elseif d < -1 then
			d = -1
		end
		scored[#scored + 1] = { idx = i, score = math.acos(d) }
	end
	table.sort(scored, function(a, b)
		return a.score > b.score
	end)
	-- Pick top-K with minimum index spacing so handles don't clump.
	local picked = {}
	local minSpacing = math_max(1, math.floor(n / (targetCount * 2)))
	for _, s in ipairs(scored) do
		if #picked >= targetCount then
			break
		end
		local ok = true
		for _, pi in ipairs(picked) do
			local di = math.abs(s.idx - pi)
			if di > n / 2 then
				di = n - di
			end
			if di < minSpacing then
				ok = false
				break
			end
		end
		if ok then
			picked[#picked + 1] = s.idx
		end
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

-- The same module the game tessellates startbox anchors with, so the preview matches what
-- the match enforces vertex for vertex.
strengthEdit.spline = require("common/lib_spline")

-- Anchor ring in the {x, z, strength} shape lib_spline wants. Reused across calls: a control
-- drag retessellates on every mousemove.
function strengthEdit.buildRing(handles)
	local n = #handles
	for i = 1, n do
		local h = handles[i]
		local a = strengthEdit.scratch[i]
		if a then
			a[1], a[2], a[3] = h.x, h.z, h.strength or 0
		else
			strengthEdit.scratch[i] = { h.x, h.z, h.strength or 0 }
		end
	end
	for i = #strengthEdit.scratch, n + 1, -1 do
		strengthEdit.scratch[i] = nil
	end

	return strengthEdit.scratch
end

-- Rebuild a spline box's vertices from its controls, in place. Does not rebuild the fill:
-- callers invalidate it (_fillNeedsRebuild is never read).
local function retessellateSpline(box)
	if box.kind ~= "spline" or not box.controls then
		return
	end

	local ring = strengthEdit.spline.TessellateRing(strengthEdit.buildRing(box.controls))
	local out = box.vertices or {}
	for i = 1, #ring do
		local p = ring[i]
		local v = out[i]
		if v then
			v.x, v.z = p[1], p[2]
		else
			out[i] = { x = p[1], z = p[2] }
		end
	end
	for i = #out, #ring + 1, -1 do
		out[i] = nil
	end
	box.vertices = out
	box._fillNeedsRebuild = true
end

-- A polygon keeps its vertices as its anchors until a corner is first curved; only then does
-- it need a control ring with a derived outline. Axis-aligned rects never curve.
function strengthEdit.ensureCurvable(box)
	if box.kind == "spline" then
		return box.controls
	end
	if box.kind == "box" or not box.vertices or #box.vertices < 3 then
		return nil
	end

	box.controls = box.vertices
	box.vertices = {}
	box.kind = "spline"
	retessellateSpline(box)

	return box.controls
end

-- Strength 0 is stored as absent, as the shared startbox schema writes it.
function strengthEdit.applyOne(handle, s)
	if s < 0 then
		s = 0
	elseif s > 1 then
		s = 1
	end
	handle.strength = (s > 0) and s or nil
end

function strengthEdit.setVertex(box, vi, s)
	local handles = strengthEdit.ensureCurvable(box)
	if not handles or not handles[vi] then
		return false
	end
	strengthEdit.applyOne(handles[vi], s)
	retessellateSpline(box)
	invalidateBoxFill(box)

	return true
end

function strengthEdit.setBox(box, s)
	local handles = strengthEdit.ensureCurvable(box)
	if not handles then
		return false
	end
	for i = 1, #handles do
		strengthEdit.applyOne(handles[i], s)
	end
	retessellateSpline(box)
	invalidateBoxFill(box)

	return true
end

local function removeLastStartbox()
	if #startboxes > 0 then
		boxUndo.push("remove", #startboxes, startboxes[#startboxes])
		freeBoxFillList(startboxes[#startboxes])
		table.remove(startboxes, #startboxes)
		renumberBoxAllyTeams()
	end
end

local function clearAllStartboxes()
	strengthEdit.selBox = nil
	strengthEdit.selVert = nil
	strengthEdit.dragging = false
	for i = 1, #startboxes do
		freeBoxFillList(startboxes[i])
	end
	startboxes = {}
	-- Startbox entries index into the list just emptied, so drop them rather than let Ctrl+Z
	-- act on stale indices. Clearing is not itself undoable.
	for i = #undoHistory, 1, -1 do
		if undoHistory[i].mode == "startbox" then
			table.remove(undoHistory, i)
		end
	end
	boxUndo.redo = {}
	currentBoxVerts = {}
	drawingBox = false
end

function boxUndo.snap(box)
	if not box then
		return nil
	end
	local anchors = box.controls or box.vertices or {}
	local out = { kind = box.kind, allyTeam = box.allyTeam, anchors = {} }
	for k = 1, #anchors do
		local a = anchors[k]
		out.anchors[k] = { x = a.x, z = a.z, strength = a.strength }
	end

	return out
end

function boxUndo.build(snap)
	local anchors = {}
	for k = 1, #snap.anchors do
		local a = snap.anchors[k]
		anchors[k] = { x = a.x, z = a.z, strength = a.strength }
	end
	local box = { kind = snap.kind, allyTeam = snap.allyTeam }
	if snap.kind == "spline" then
		box.controls = anchors
		box.vertices = {}
		retessellateSpline(box)
	else
		box.vertices = anchors
	end

	return box
end

-- op is what the user just did, so undo knows how to reverse it: "add" drops the box at idx,
-- "remove" puts it back, "edit" swaps the stored anchors in.
function boxUndo.push(op, idx, box)
	undoHistory[#undoHistory + 1] = {
		mode = "startbox",
		op = op,
		idx = idx,
		box = boxUndo.snap(box),
	}
	boxUndo.redo = {}
end

-- A drag fires MouseMove continuously, so the snapshot is taken once on press and only
-- committed on release if the gesture actually changed something. One Ctrl+Z per gesture.
function boxUndo.begin(idx)
	boxUndo.pending = { idx = idx, box = boxUndo.snap(startboxes[idx]) }
end

function boxUndo.commit()
	local pend = boxUndo.pending
	boxUndo.pending = nil
	if not pend or not pend.box then
		return
	end
	-- A click that only selects a handle must not leave a no-op entry behind, or Ctrl+Z
	-- appears to do nothing.
	local now = boxUndo.snap(startboxes[pend.idx])
	if now and #now.anchors == #pend.box.anchors then
		local same = now.kind == pend.box.kind
		for k = 1, #now.anchors do
			local a = now.anchors[k]
			local b = pend.box.anchors[k]
			if not a or not b or a.x ~= b.x or a.z ~= b.z or a.strength ~= b.strength then
				same = false
				break
			end
		end
		if same then
			return
		end
	end
	undoHistory[#undoHistory + 1] = {
		mode = "startbox",
		op = "edit",
		idx = pend.idx,
		box = pend.box,
	}
	boxUndo.redo = {}
end

-- Applies one entry and returns its mirror, so undo and redo share this and the caller just
-- moves the mirror onto the other stack.
function boxUndo.apply(entry)
	local mirror = { mode = "startbox", op = entry.op, idx = entry.idx }
	if entry.op == "add" then
		mirror.box = boxUndo.snap(startboxes[entry.idx])
		mirror.op = "remove"
		if startboxes[entry.idx] then
			freeBoxFillList(startboxes[entry.idx])
			table.remove(startboxes, entry.idx)
		end
	elseif entry.op == "remove" then
		mirror.op = "add"
		local at = entry.idx
		if at < 1 then
			at = 1
		elseif at > #startboxes + 1 then
			at = #startboxes + 1
		end
		mirror.idx = at
		table.insert(startboxes, at, boxUndo.build(entry.box))
	else
		mirror.box = boxUndo.snap(startboxes[entry.idx])
		if startboxes[entry.idx] then
			freeBoxFillList(startboxes[entry.idx])
			startboxes[entry.idx] = boxUndo.build(entry.box)
		end
	end
	renumberBoxAllyTeams()

	return mirror
end

-- 0-200 normalised integers, the space the modoption and maps-metadata both use.
function boxExport.toNorm(v, size)
	local n = math_floor(v * 200 / math_max(1, size) + 0.5)
	if n < 0 then
		n = 0
	elseif n > 200 then
		n = 200
	end

	return n
end

-- Anchors, never the tessellated ring: the game re-tessellates from these through the same
-- lib_spline this tool previews with. Strength is snapped to 0.025 and omitted at zero,
-- which the schema reads as a sharp corner.
function boxExport.arrangement()
	local sizeX, sizeZ = Game.mapSizeX, Game.mapSizeZ
	local out = {}
	for bi = 1, #startboxes do
		local box = startboxes[bi]
		-- Not getEditHandles: this runs above its declaration. The only thing it adds is a nil
		-- for rect kinds, and box.vertices is the right answer for those anyway.
		local anchors = box.controls or box.vertices
		local poly = {}
		if box.kind == "box" and #anchors >= 3 then
			-- Axis-aligned rects ship as the 2-point shorthand every consumer already handles.
			local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
			for k = 1, #anchors do
				local a = anchors[k]
				if a.x < minX then
					minX = a.x
				end
				if a.x > maxX then
					maxX = a.x
				end
				if a.z < minZ then
					minZ = a.z
				end
				if a.z > maxZ then
					maxZ = a.z
				end
			end
			poly[1] = { x = boxExport.toNorm(minX, sizeX), y = boxExport.toNorm(minZ, sizeZ) }
			poly[2] = { x = boxExport.toNorm(maxX, sizeX), y = boxExport.toNorm(maxZ, sizeZ) }
		else
			for k = 1, #anchors do
				local a = anchors[k]
				local pt = { x = boxExport.toNorm(a.x, sizeX), y = boxExport.toNorm(a.z, sizeZ) }
				-- Snap first, then test: a strength small enough to round to zero must be omitted
				-- rather than written as an explicit zero.
				local st = a.strength and (math_floor(a.strength * 40 + 0.5) / 40)
				if st and st > 0 then
					pt.strength = st
				end
				poly[k] = pt
			end
		end
		if #poly >= 2 then
			out[#out + 1] = { poly = poly }
		end
	end

	return out
end

--- Encodes a table (startbox arrangement or suggestions) as a bSet value: JSON, zlib, base64.
--- @param data table
--- @return string|nil value the base64 encoded value, or nil on failure
--- @return string|nil err error message if encoding failed
local function encodeBSetValue(data)
	if not data then
		return nil, "no data"
	end
	if not Json then
		return nil, "Json unavailable; cannot encode bSet."
	end
	local ok, raw = pcall(Json.encode, data)
	if not ok or not raw then
		return nil, "Failed to encode bSet JSON."
	end
	local packed = VFS.ZlibCompress(raw)
	if not packed then
		return nil, "Failed to compress bSet payload."
	end
	local b64 = VFS.Include("common/luaUtilities/base64.lua")
	return (b64.Encode(packed):gsub("=+$", ""))
end

function boxExport.encode()
	local arrangement = boxExport.arrangement()
	if #arrangement == 0 then
		return nil
	end

	local value, err = encodeBSetValue({ startboxes = arrangement })
	if not value then
		return nil
	end
	return value, #arrangement
end

-- The value is pasted into lobby chat and can be long, so the echo reports its length
-- rather than printing it; the clipboard carries the command.
local function copyStartboxOverride()
	local value, boxes = boxExport.encode()
	local mapSuggestions, _ = roleConfig.buildSuggestionsData()
	local mapSuggestionsEncoded = mapSuggestions and encodeBSetValue(mapSuggestions)

	if not value and not mapSuggestionsEncoded then
		Echo("[StartPos Tool] No startboxes or suggestions to copy.")
		return false
	end

	local clipboard = ""
	local msg = ""

	if value then
		clipboard = "!bset mapmetadata_startbox_override " .. value
		msg = string.format("[StartPos Tool] Copied !bSet for %d startbox(es), %d chars of value.", boxes, #value)
	end

	if mapSuggestionsEncoded then
		if clipboard ~= "" then
			clipboard = clipboard .. "\n"
			msg = msg .. " +"
		end
		clipboard = clipboard .. "!bset mapmetadata_startpos " .. mapSuggestionsEncoded
		msg = msg .. string.format(" suggestions %d chars.", #mapSuggestionsEncoded)
	end

	Spring.SetClipboard(clipboard)
	Echo(msg)

	return true
end

local function exportSuggestions(name)
	local data, err = roleConfig.buildSuggestionsData()
	if not data then
		Echo("[StartPos Tool] No positions to export: " .. (err or "unknown"))
		return false
	end

	roleConfig.saveSuggestions(name)
	roleConfig.saveSuggestionsBSet(name)

	local value, err2 = encodeBSetValue(data)
	if value then
		Echo(string.format("[StartPos Tool] Exported suggestions (bSet %d chars, JSON written).", #value))
	else
		Echo("[StartPos Tool] Exported suggestions (JSON written, bSet encode failed: " .. (err2 or "unknown") .. ").")
	end

	return true
end

local function findNearestBoxVertex(wx, wz)
	for bi, box in ipairs(startboxes) do
		if box.kind == "box" then
			-- Rect corners are handles as well as its edges; the drag keeps the rect axis-aligned.
			for vi, v in ipairs(box.vertices) do
				if distSq(wx, wz, v.x, v.z) < VERTEX_PICK_DIST_SQ then
					return bi, vi
				end
			end
		elseif box.kind == "spline" and box.controls then
			-- Splines are edited through their controls, not the dense tessellated vertices.
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

-- Crossing-number point-in-polygon test on the XZ plane, for any box kind's vertex list.
local function pointInPolygon(wx, wz, verts)
	local n = verts and #verts or 0
	if n < 3 then
		return false
	end
	local inside = false
	local j = n
	for i = 1, n do
		local vi, vj = verts[i], verts[j]
		if ((vi.z > wz) ~= (vj.z > wz)) and (wx < (vj.x - vi.x) * (wz - vi.z) / ((vj.z - vi.z) + 1e-9) + vi.x) then
			inside = not inside
		end
		j = i
	end
	return inside
end

-- Topmost box containing (wx, wz), for body drag. Reverse order: the newest box draws on top.
local function findBoxContaining(wx, wz)
	for bi = #startboxes, 1, -1 do
		local box = startboxes[bi]
		if box.vertices and pointInPolygon(wx, wz, box.vertices) then
			return bi
		end
	end
	return nil
end

-- Nearest edge of a "box"-kind rect to (wx, wz). Returns bi and "L", "R", "T" (min Z) or
-- "B" (max Z).
local function findNearestBoxEdge(wx, wz)
	local EDGE_PICK_DIST = 55 -- world units from edge line
	for bi, box in ipairs(startboxes) do
		if box.kind == "box" and #box.vertices == 4 then
			local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
			for _, v in ipairs(box.vertices) do
				if v.x < minX then
					minX = v.x
				end
				if v.x > maxX then
					maxX = v.x
				end
				if v.z < minZ then
					minZ = v.z
				end
				if v.z > maxZ then
					maxZ = v.z
				end
			end
			-- Only near the rect: its bounds grown by the pick distance.
			if
				wx >= minX - EDGE_PICK_DIST
				and wx <= maxX + EDGE_PICK_DIST
				and wz >= minZ - EDGE_PICK_DIST
				and wz <= maxZ + EDGE_PICK_DIST
			then
				local dL = math.abs(wx - minX) -- left   edge (constant X = minX)
				local dR = math.abs(wx - maxX) -- right  edge
				local dT = math.abs(wz - minZ) -- top    edge (min Z)
				local dB = math.abs(wz - maxZ) -- bottom edge
				local best = EDGE_PICK_DIST
				local which = nil
				if wz >= minZ - EDGE_PICK_DIST and wz <= maxZ + EDGE_PICK_DIST then
					if dL < best then
						best = dL
						which = "L"
					end
					if dR < best then
						best = dR
						which = "R"
					end
				end
				if wx >= minX - EDGE_PICK_DIST and wx <= maxX + EDGE_PICK_DIST then
					if dT < best then
						best = dT
						which = "T"
					end
					if dB < best then
						best = dB
						which = "B"
					end
				end
				if which then
					return bi, which
				end
			end
		end
	end
	return nil, nil
end

local function isPolygonKind(box)
	return box.kind == nil or box.kind == "polygon"
end

-- Editable handles of a box (polygon: vertices, spline: controls). Nil for "box"-kind rects,
-- which resize by edge instead.
local function getEditHandles(box)
	if isPolygonKind(box) then
		return box.vertices
	end
	if box.kind == "spline" then
		return box.controls
	end
	return nil
end

-- Outward direction for the strength gizmo: anchor centroid -> anchor, so the gizmo always
-- points away from the box body and never crosses it.
function strengthEdit.axis(box, vi)
	local handles = getEditHandles(box)
	local v = handles and handles[vi]
	if not v or #handles < 3 then
		return nil
	end

	local cx, cz = 0, 0
	for i = 1, #handles do
		cx = cx + handles[i].x
		cz = cz + handles[i].z
	end
	cx, cz = cx / #handles, cz / #handles

	local dx, dz = v.x - cx, v.z - cz
	local len = math.sqrt(dx * dx + dz * dz)
	if len < 1 then
		dx, dz, len = 1, 0, 1
	end

	return v.x, v.z, dx / len, dz / len
end

function strengthEdit.knob(box, vi)
	local vx, vz, ux, uz = strengthEdit.axis(box, vi)
	if not vx then
		return nil
	end
	local handles = getEditHandles(box)
	local s = (handles[vi].strength or 0) * strengthEdit.GIZMO_LEN

	return vx + ux * s, vz + uz * s, vx, vz, ux, uz
end

-- The gizmo lives outside DrawWorld, which sits on Lua's 60-upvalue ceiling.
-- Gizmo height, shared by drawing and the hit test so the knob is picked where it is drawn.
function strengthEdit.gizmoY(box, vi)
	local kx, kz, vx, vz, ux, uz = strengthEdit.knob(box, vi)
	if not kx then
		return nil
	end

	local ex, ez = vx + ux * strengthEdit.GIZMO_LEN, vz + uz * strengthEdit.GIZMO_LEN
	local gy = math_max(GetGroundHeight(vx, vz) or 0, GetGroundHeight(ex, ez) or 0)

	return math_max(gy, GetGroundHeight(kx, kz) or 0) + 48
end

-- Picked in screen space because the knob floats: a ground trace would hit the spot below
-- it, which at shallow camera angles is far from where it appears.
function strengthEdit.knobHit(box, vi, mx, my)
	local kx, kz = strengthEdit.knob(box, vi)
	local gy = kx and strengthEdit.gizmoY(box, vi)
	if not gy or not mx then
		return false
	end

	local sx, sy, sz = WorldToScreenCoords(kx, gy, kz)
	if not sz or sz <= 0 or sz >= 1 then
		return false
	end
	local dx, dy = mx - sx, my - sy

	return (dx * dx + dy * dy) <= 18 * 18
end

-- Strength from the cursor's place along the track as drawn on screen, for the same reason
-- as knobHit: the ground cursor drifts from the floating knob.
function strengthEdit.fromMouse(box, vi, mx, my)
	local kx, kz, vx, vz, ux, uz = strengthEdit.knob(box, vi)
	local gy = kx and strengthEdit.gizmoY(box, vi)
	if not gy or not mx then
		return nil
	end

	local ex, ez = vx + ux * strengthEdit.GIZMO_LEN, vz + uz * strengthEdit.GIZMO_LEN
	local ax, ay, az = WorldToScreenCoords(vx, gy, vz)
	local bx, by, bz = WorldToScreenCoords(ex, gy, ez)
	if not az or not bz or az <= 0 or az >= 1 or bz <= 0 or bz >= 1 then
		return nil
	end

	local dx, dy = bx - ax, by - ay
	local lenSq = dx * dx + dy * dy
	if lenSq < 1 then
		return nil
	end

	return ((mx - ax) * dx + (my - ay) * dy) / lenSq
end

function strengthEdit.draw(box, bi)
	if strengthEdit.selBox ~= bi or not strengthEdit.selVert then
		return
	end

	local kx, kz, vx, vz, ux, uz = strengthEdit.knob(box, strengthEdit.selVert)
	if not kx then
		return
	end

	local ex, ez = vx + ux * strengthEdit.GIZMO_LEN, vz + uz * strengthEdit.GIZMO_LEN
	-- One height for the whole track, clear of the ground under it, so it reads as a straight
	-- ruler instead of draping over the slope.
	local gy = strengthEdit.gizmoY(box, strengthEdit.selVert)
	if not gy then
		return
	end

	-- Drawn without depth so a hill between the camera and the anchor cannot bury it.
	glDepthTest(false)

	glColor(0, 0, 0, 0.55)
	glLineWidth(6.0)
	glBeginEnd(GL_LINES, function()
		glVertex(vx, gy, vz)
		glVertex(ex, gy, ez)
	end)
	glColor(1, 1, 1, 0.85)
	glLineWidth(2.5)
	glBeginEnd(GL_LINES, function()
		glVertex(vx, gy, vz)
		glVertex(ex, gy, ez)
	end)

	-- Stem down to the anchor, so a track floating over uneven ground still reads as its own.
	glColor(1, 1, 1, 0.35)
	glLineWidth(1.5)
	glBeginEnd(GL_LINES, function()
		glVertex(vx, gy, vz)
		glVertex(vx, (GetGroundHeight(vx, vz) or 0) + 4, vz)
	end)

	local hot = strengthEdit.hoverKnob or strengthEdit.dragging
	local kr = worldRadiusForScreenPx(kx, kz, hot and 15 or 10)
	glColor(0, 0, 0, 0.60)
	glBeginEnd(GL_TRIANGLE_FAN, function()
		glVertex(kx, gy, kz)
		for s = 0, 18 do
			local a = (s / 18) * 2 * math.pi
			glVertex(kx + math_cos(a) * kr * 1.4, gy, kz + math_sin(a) * kr * 1.4)
		end
	end)
	glColor(1, 1, 1, hot and 1.0 or 0.95)
	glBeginEnd(GL_TRIANGLE_FAN, function()
		glVertex(kx, gy, kz)
		for s = 0, 18 do
			local a = (s / 18) * 2 * math.pi
			glVertex(kx + math_cos(a) * kr, gy, kz + math_sin(a) * kr)
		end
	end)
	if hot then
		-- Ring drawn flat at the gizmo height, not on the ground, so it tracks the knob.
		glColor(1, 1, 1, 0.55)
		glLineWidth(2.0)
		glBeginEnd(GL_LINE_LOOP, function()
			for s = 0, 22 do
				local a = (s / 22) * 2 * math.pi
				glVertex(kx + math_cos(a) * kr * 1.7, gy, kz + math_sin(a) * kr * 1.7)
			end
		end)
	end

	glDepthTest(true)

	glColor(1, 1, 1, 0.75)
	glLineWidth(2.0)
	glDrawGroundCircle(vx, GetGroundHeight(vx, vz) or 0, vz, worldRadiusForScreenPx(vx, vz, 26), 24)
end

-- Edge-midpoint ghost handle of a polygon or spline box, for inserting a new anchor.
-- Returns box index, edge index (its start anchor) and the midpoint, or nil when no
-- midpoint is within VERTEX_PICK_DIST_SQ.
local function findNearestPolygonEdgeMid(wx, wz)
	local bestD = VERTEX_PICK_DIST_SQ
	local bestBi = nil
	local bestEi = nil
	local bestMx = nil
	local bestMz = nil
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
					bestBi = bi
					bestEi = i
					bestMx = mx
					bestMz = mz
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

local function saveStartPositions(name, explicitPath)
	local filename = explicitPath
	if not filename then
		Spring.CreateDir(SAVE_DIR)
		filename = SAVE_DIR .. (name or getMapName()) .. ".lua"
	end
	local lines = {}
	lines[#lines + 1] = "-- Start Positions Config"
	lines[#lines + 1] = "-- Map: " .. getMapName()
	lines[#lines + 1] = "-- Generated by Start Positions Tool"
	lines[#lines + 1] = ""
	lines[#lines + 1] = "local startPositions = {"
	for i, pos in ipairs(positions) do
		lines[#lines + 1] = string.format(
			"  [%d] = { x = %d, z = %d, allyTeam = %d, teamSlot = %d%s },",
			i,
			math_floor(pos.x),
			math_floor(pos.z),
			pos.allyTeam,
			pos.teamSlot or 1,
			pos.role and (", role = " .. string.format("%q", pos.role)) or ""
		)
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

local function loadStartPositions(name, explicitPath)
	local filename = explicitPath or (SAVE_DIR .. (name or getMapName()) .. ".lua")
	local ok, data = pcall(function()
		return VFS.Include(filename, {}, VFS.RAW_FIRST)
	end)
	if ok and data then
		clearAllPositions() -- also clears undoHistory, so a load is a clean slate
		for i, pos in ipairs(data) do
			if addPosition(pos.x, pos.z, pos.allyTeam or i, pos.teamSlot or 1) and pos.role then
				positions[#positions].role = pos.role
			end
		end
		Echo("[StartPos Tool] Loaded start positions from: " .. filename)
		return true
	else
		Echo("[StartPos Tool] No saved config found: " .. filename)
		return false
	end
end

function roleConfig.buildSuggestionsData()
	if #positions == 0 then
		return nil, "no positions"
	end

	local pointIdForIdx = {}
	for i = 1, #positions do
		pointIdForIdx[i] = "P" .. i
	end

	local allyTeamSet = {}
	for _, pos in ipairs(positions) do
		allyTeamSet[pos.allyTeam] = true
	end

	local allyTeamIds = {}
	for at in pairs(allyTeamSet) do
		allyTeamIds[#allyTeamIds + 1] = at
	end
	table.sort(allyTeamIds)

	local byAlly = {}
	for _, at in ipairs(allyTeamIds) do
		byAlly[at] = {}
	end
	for idx, pos in ipairs(positions) do
		table.insert(byAlly[pos.allyTeam], { idx = idx, pos = pos })
	end
	for _, at in ipairs(allyTeamIds) do
		table.sort(byAlly[at], function(a, b)
			return a.pos.teamSlot < b.pos.teamSlot
		end)
	end

	local jsonPositions = {}
	for i, pos in ipairs(positions) do
		jsonPositions[pointIdForIdx[i]] = {
			x = math_floor(pos.x),
			y = math_floor(pos.z),
		}
	end

	local sides = {}
	local playersPerTeam = 0
	for _, at in ipairs(allyTeamIds) do
		local starts = {}
		for _, entry in ipairs(byAlly[at]) do
			local pos = entry.pos
			local startEntry = { spawnPoint = pointIdForIdx[entry.idx] }
			if pos.role and pos.role ~= "" then
				startEntry.role = pos.role
			end
			starts[#starts + 1] = startEntry
		end
		sides[#sides + 1] = { starts = starts }
		if #starts > playersPerTeam then
			playersPerTeam = #starts
		end
	end

	return {
		positions = jsonPositions,
		team = {
			{
				teamCount = #allyTeamIds,
				playersPerTeam = math_max(1, playersPerTeam),
				sides = sides,
			},
		},
	}
end

function roleConfig.saveSuggestions(name, explicitPath)
	local data, err = roleConfig.buildSuggestionsData()
	if not data then
		Echo("[StartPos Tool] Cannot export suggestions: " .. (err or "unknown error"))
		return false
	end
	if not Json then
		Echo("[StartPos Tool] Json unavailable; cannot encode suggestions.")
		return false
	end
	local ok, encoded = pcall(Json.encode, data)
	if not ok or not encoded then
		Echo("[StartPos Tool] Failed to encode suggestions JSON.")
		return false
	end
	Spring.CreateDir(roleConfig.saveDir)
	local filename = explicitPath or (roleConfig.saveDir .. (name or getMapName()) .. "_rowy.json")
	local file = io.open(filename, "w")
	if file then
		file:write(encoded)
		file:close()
		Echo("[StartPos Tool] Saved start position suggestions to: " .. filename)
		return true
	end
	Echo("[StartPos Tool] ERROR: Could not write to: " .. filename)
	return false
end

-- Writes the suggestions as a ready-to-paste `!bset mapmetadata_startpos` command.
function roleConfig.saveSuggestionsBSet(name, explicitPath)
	local data, err = roleConfig.buildSuggestionsData()
	if not data then
		Echo("[StartPos Tool] Cannot export bSet: " .. (err or "unknown error"))
		return false
	end
	local value, err2 = encodeBSetValue(data)
	if not value then
		Echo("[StartPos Tool] Cannot export bSet: " .. (err2 or "unknown error"))
		return false
	end
	Spring.CreateDir(roleConfig.saveDir)
	local filename = explicitPath or (roleConfig.saveDir .. (name or getMapName()) .. "_bSet.txt")
	local file = io.open(filename, "w")
	if file then
		file:write("!bset mapmetadata_startpos " .. value)
		file:close()
		Echo("[StartPos Tool] Saved bSet command to: " .. filename)
		return true
	end
	Echo("[StartPos Tool] ERROR: Could not write bSet to: " .. filename)
	return false
end

local function saveStartboxes(name, explicitPath)
	local filename = explicitPath
	if not filename then
		Spring.CreateDir(STARTBOX_SAVE_DIR)
		filename = STARTBOX_SAVE_DIR .. (name or getMapName()) .. ".lua"
	end
	local lines = {}
	lines[#lines + 1] = "-- Startbox Config"
	lines[#lines + 1] = "-- Map: " .. getMapName()
	lines[#lines + 1] = "-- Generated by Start Positions Tool"
	lines[#lines + 1] = ""
	lines[#lines + 1] = "local startboxes = {"
	for i, box in ipairs(startboxes) do
		lines[#lines + 1] = string.format("  [%d] = {", i)
		lines[#lines + 1] = string.format("    allyTeam = %d,", box.allyTeam)
		lines[#lines + 1] = string.format("    kind = %q,", box.kind or "polygon")
		-- Anchors, never the tessellated ring: a curve cannot be recovered from the ring.
		-- Strength is omitted when zero, matching the shared schema.
		lines[#lines + 1] = "    anchors = {"
		local anchors = getEditHandles(box) or box.vertices
		for _, v in ipairs(anchors) do
			local s = v.strength
			if s and s > 0 then
				lines[#lines + 1] =
					string.format("      { x = %d, z = %d, strength = %.3f },", math_floor(v.x), math_floor(v.z), s)
			else
				lines[#lines + 1] = string.format("      { x = %d, z = %d },", math_floor(v.x), math_floor(v.z))
			end
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

local function loadStartboxes(name, explicitPath)
	local filename = explicitPath or (STARTBOX_SAVE_DIR .. (name or getMapName()) .. ".lua")
	local ok, data = pcall(function()
		return VFS.Include(filename, {}, VFS.RAW_FIRST)
	end)
	if ok and data then
		clearAllStartboxes()
		for i, box in ipairs(data) do
			-- Older saves hold `vertices` instead of `anchors`; they had no curvature, so
			-- loading them as plain polygons is faithful.
			local anchors = box.anchors
			if anchors and box.kind ~= "box" then
				startboxes[i] = {
					controls = anchors,
					vertices = {},
					kind = "spline",
					allyTeam = box.allyTeam or i,
				}
				retessellateSpline(startboxes[i])
			else
				-- Axis-aligned rects never curve, so their anchors are their vertices.
				local verts = box.vertices or anchors
				startboxes[i] = {
					vertices = verts,
					allyTeam = box.allyTeam or i,
					kind = box.kind,
				}
			end
		end
		renumberBoxAllyTeams()
		Echo("[StartPos Tool] Loaded startboxes from: " .. filename)
		return true
	else
		Echo("[StartPos Tool] No saved startbox config found: " .. filename)
		return false
	end
end

local function saveAll(name)
	saveStartPositions(name)
	saveStartboxes(name)
end

-- ============================================================
-- Activate / Deactivate / State
-- ============================================================

local function activate(mode)
	active = true
	subMode = mode or "express"
end

local function deactivate()
	active = false
	dragging = false
	dragIdx = nil
	drawingBox = false
end

local function setSubMode(mode)
	if mode == "express" or mode == "shape" or mode == "startbox" or mode == "roles" then
		subMode = mode
	end
end

local function setShape(shape)
	if shape == "circle" or shape == "square" or shape == "hexagon" or shape == "octagon" or shape == "triangle" then
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
	if nextAllyTeam > numAllyTeams then
		nextAllyTeam = 1
	end
end

local function setNumTeamsPerAlly(n)
	numTeamsPerAlly = math_max(1, math_min(MAX_TEAMS_PER_ALLY, n))
	if nextTeamSlot > numTeamsPerAlly then
		nextTeamSlot = 1
	end
end

local function togglePlacementMode()
	placementMode = (placementMode == "roundrobin") and "sequential" or "roundrobin"
	return placementMode
end

local function setStartboxMode(m)
	if m == "polygon" or m == "box" or m == "freedraw" then
		startboxMode = m
		-- Drop any shape half drawn in the previous mode.
		currentBoxVerts = {}
		drawingBox = false
		boxRectActive = false
		boxRectStartX, boxRectStartZ, boxRectEndX, boxRectEndZ = nil, nil, nil, nil
		freeDrawActive = false
		freeDrawPts = {}
	end
end

-- Chaikin corner cutting on a closed polygon: each iteration doubles the point count.
-- The default of 2 is smooth enough without too many points.
local function smoothClosedPolygon(pts, iterations)
	local out = pts
	for _ = 1, (iterations or 2) do
		local smoothed = {}
		local n = #out
		if n < 3 then
			return out
		end
		for i = 1, n do
			local p0 = out[i]
			local p1 = out[(i % n) + 1]
			smoothed[#smoothed + 1] = { x = 0.75 * p0.x + 0.25 * p1.x, z = 0.75 * p0.z + 0.25 * p1.z }
			smoothed[#smoothed + 1] = { x = 0.25 * p0.x + 0.75 * p1.x, z = 0.25 * p0.z + 0.75 * p1.z }
		end
		out = smoothed
	end
	return out
end

-- Drop points closer than minDistSq to the last kept one (after smoothing).
local function decimatePoints(pts, minDistSq)
	if #pts < 3 then
		return pts
	end
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
	-- In startbox submode the ally-team count is the number of boxes; the panel shows it as
	-- dynamic, so the slider value would be stale.
	local allyCount = numAllyTeams
	if subMode == "startbox" and #startboxes > 0 then
		allyCount = #startboxes
	end

	return {
		active = active,
		subMode = subMode,
		positions = positions,
		numAllyTeams = allyCount,
		numTeamsPerAlly = numTeamsPerAlly,
		placementMode = placementMode,
		totalPlayers = allyCount * numTeamsPerAlly,
		shapeType = shapeType,
		shapeRadius = shapeRadius,
		shapeRotation = shapeRotation,
		shapeCount = shapeCount,
		startboxes = startboxes,
		startboxMode = startboxMode,
	}
end

-- ============================================================
-- Mouse Handlers
-- ============================================================

function widget:MousePress(mx, my, button)
	if not active then
		return false
	end

	-- The measure tool and the symmetry origin drag get the mouse first.
	do
		---@type table?
		local tb = WG.TerraformBrush
		local stb = tb and tb.getState and tb.getState() or nil
		if stb and stb.measureActive then
			return false
		end
		if stb and stb.symmetryActive then
			if stb.symmetryPlacingOrigin or stb.symmetryHoveringOrigin or stb.symmetryDraggingOrigin then
				return false
			end
		end
	end

	local wx, wz = getWorldMousePosition()
	if not wx then
		return false
	end

	if subMode == "express" then
		if button == 1 then
			-- LMB on a marker arms a drag; elsewhere it places.
			local nearIdx = findNearestPosition(wx, wz)
			if nearIdx then
				dragIdx = nearIdx
				dragStartX = mx
				dragStartY = my
				dragging = false
				local p = positions[nearIdx]
				dragFrom = { pos = p, x = p.x, z = p.z, y = p.y }
				return true
			end
			-- With symmetry on, each placed copy takes the next player in the rotation; a copy
			-- refused (too steep, or the cap) passes its player on to the next copy.
			do
				---@type table?
				local tb = WG.TerraformBrush
				local stb = tb and tb.getState and tb.getState() or nil
				local prevNext = nextAllyTeam
				local prevNextSlot = nextTeamSlot
				local prevCount = #positions
				if stb and stb.symmetryActive and tb.getSymmetricPositions then
					local copies = tb.getSymmetricPositions(wx, wz, 0)
					for _, p in ipairs(copies) do
						if addPosition(p.x, p.z, nextAllyTeam, nextTeamSlot) then
							advanceNextPlayer()
						end
					end
				elseif addPosition(wx, wz, nextAllyTeam, nextTeamSlot) then
					advanceNextPlayer()
				end
				local added = #positions - prevCount
				if added > 0 then
					undoHistory[#undoHistory + 1] = {
						mode = subMode,
						count = added,
						prevNextAllyTeam = prevNext,
						prevNextTeamSlot = prevNextSlot,
					}
				end
			end
			return true
		elseif button == 3 then
			-- RMB undoes the last placement. Take the newest placement entry, not the newest
			-- entry: startbox entries share the stack and have no count, and drag entries
			-- ("move") are for Ctrl+Z only.
			local at
			for i = #undoHistory, 1, -1 do
				if (undoHistory[i].mode or "express") ~= "startbox" and undoHistory[i].op ~= "move" then
					at = i
					break
				end
			end
			local entry = at and undoHistory[at] or nil
			if entry and at then
				for _ = 1, (entry.count or 0) do
					if #positions > 0 then
						positions[#positions] = nil
					end
				end
				nextAllyTeam = entry.prevNextAllyTeam or 1
				nextTeamSlot = entry.prevNextTeamSlot or 1
				table.remove(undoHistory, at)
			end
			if #positions == 0 then
				nextAllyTeam = 1
				nextTeamSlot = 1
			end
			return true
		end
	elseif subMode == "shape" then
		if button == 1 then
			---@type table?
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
					mode = subMode,
					count = added,
					prevNextAllyTeam = prevNext,
					prevNextTeamSlot = prevNextSlot,
				}
			end
			return true
		elseif button == 3 then
			removeNearestPosition(wx, wz)
			return true
		end
	elseif subMode == "startbox" then
		if button == 1 then
			-- The selected anchor's strength knob wins over vertex picking; it sits outside the
			-- box, so it cannot hide anything else worth grabbing.
			if strengthEdit.selBox and strengthEdit.selVert and startboxes[strengthEdit.selBox] then
				if strengthEdit.knobHit(startboxes[strengthEdit.selBox], strengthEdit.selVert, mx, my) then
					boxUndo.begin(strengthEdit.selBox)
					strengthEdit.dragging = true
					return true
				end
			end

			-- Pick order: vertex or control, edge midpoint (insert), rect edge, box body, then draw.
			local bi, vi = findNearestBoxVertex(wx, wz)
			if bi and vi then
				boxUndo.begin(bi)
				boxDragIdx = vi
				boxDragBoxIdx = bi
				dragStartX = mx
				dragStartY = my
				dragging = false
				return true
			end
			-- The ghost handle inserts an anchor on that edge and starts dragging it at once.
			local pbi, pei, pmx, pmz = findNearestPolygonEdgeMid(wx, wz)
			if pbi and pei then
				local box = startboxes[pbi]
				local handles = box and getEditHandles(box)
				if handles then
					boxUndo.begin(pbi)
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
			local ebi, edge = findNearestBoxEdge(wx, wz)
			if ebi and edge then
				boxEdgeDrag = { bi = ebi, edge = edge }
				dragStartX = mx
				dragStartY = my
				dragging = false
				return true
			end

			local containBi = findBoxContaining(wx, wz)
			if containBi then
				boxBodyDrag = { bi = containBi, lastX = wx, lastZ = wz }
				dragStartX = mx
				dragStartY = my
				dragging = false
				return true
			end

			if startboxMode == "box" then
				-- Press starts the rectangle, release finishes it.
				local sx, sz = wx, wz
				---@type table?
				local tb = WG.TerraformBrush
				local stb = tb and tb.getState and tb.getState() or nil
				if stb and stb.gridSnap and tb.snapWorld then
					sx, sz = tb.snapWorld(wx, wz, 0)
				end
				boxRectActive = true
				boxRectStartX = sx
				boxRectStartZ = sz
				boxRectEndX = sx
				boxRectEndZ = sz
				dragStartX, dragStartY = mx, my
				return true
			elseif startboxMode == "freedraw" then
				-- MouseMove appends the points.
				freeDrawActive = true
				freeDrawPts = { { x = wx, z = wz } }
				dragStartX, dragStartY = mx, my
				return true
			else
				-- Polygon: each click adds a vertex, RMB finishes.
				if not drawingBox then
					drawingBox = true
					currentBoxVerts = {}
				end
				addStartboxVertex(wx, wz)
				return true
			end
		elseif button == 3 then
			-- RMB on a polygon vertex or spline control deletes it (3 must remain). Checked first
			-- so pruning a vertex never drops the whole box.
			local hitBox = nil -- box whose corner was clicked but cannot lose it (rect, or 3 left)
			do
				local dbi, dvi = findNearestBoxVertex(wx, wz)
				if dbi and dvi then
					hitBox = dbi
					local box = startboxes[dbi]
					local handles = box and getEditHandles(box)
					if handles and #handles > 3 then
						boxUndo.push("edit", dbi, box)
						table.remove(handles, dvi)
						if box.kind == "spline" then
							retessellateSpline(box)
						end
						invalidateBoxFill(box)
						return true
					end
				end
			end
			-- Otherwise: finish the polygon, cancel a rect or free-draw, remove the box whose
			-- corner was clicked, or remove the last box.
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
			elseif hitBox and hitBox < #startboxes then
				boxUndo.push("remove", hitBox, startboxes[hitBox])
				freeBoxFillList(startboxes[hitBox])
				table.remove(startboxes, hitBox)
				renumberBoxAllyTeams()
				-- The strength knob selection points into the list: follow the shift.
				if strengthEdit.selBox == hitBox then
					strengthEdit.selBox = nil
					strengthEdit.selVert = nil
				elseif strengthEdit.selBox and strengthEdit.selBox > hitBox then
					strengthEdit.selBox = strengthEdit.selBox - 1
				end
			else
				removeLastStartbox()
			end
			return true
		end
	elseif subMode == "roles" then
		if button == 1 then
			local nearIdx = findNearestPosition(wx, wz)
			if nearIdx then
				roleConfig.cyclePositionRole(nearIdx)
			end
			return true
		elseif button == 3 then
			local nearIdx = findNearestPosition(wx, wz)
			if nearIdx then
				roleConfig.cyclePositionRole(nearIdx, -1)
			end
			return true
		end
	end

	return false
end

function widget:MouseMove(mx, my, dx, dy, button)
	if not active then
		return false
	end

	if strengthEdit.dragging and strengthEdit.selBox and strengthEdit.selVert then
		-- No ground trace: the knob floats, so a cursor over sky is still a valid drag.
		local box = startboxes[strengthEdit.selBox]
		if box then
			local s = strengthEdit.fromMouse(box, strengthEdit.selVert, mx, my)
			if s then
				-- Ctrl drives every anchor at once, the same meaning Ctrl+A has.
				local _, ctrlHeld = Spring.GetModKeyState()
				if ctrlHeld then
					strengthEdit.setBox(box, s)
				else
					strengthEdit.setVertex(box, strengthEdit.selVert, s)
				end
			end
		end
		return true
	end

	if subMode == "express" and dragIdx then
		local moved = (mx - dragStartX) ^ 2 + (my - dragStartY) ^ 2
		if moved > DRAG_THRESHOLD_SQ then
			dragging = true
		end
		if dragging then
			local wx, wz = getWorldMousePosition()
			if wx and positions[dragIdx] then
				local cx, cz = clampToMap(wx, wz)
				-- Silently refuse ground too steep for the commander.
				if isPlaceableForCommander(cx, cz) then
					positions[dragIdx].x, positions[dragIdx].z = cx, cz
					positions[dragIdx].y = GetGroundHeight(cx, cz) or 0
				end
			end
			return true
		end
	end

	if subMode == "startbox" and boxDragIdx then
		local moved = (mx - dragStartX) ^ 2 + (my - dragStartY) ^ 2
		if moved > DRAG_THRESHOLD_SQ then
			dragging = true
		end
		if dragging then
			isDraggingBox = true
			pendingFillRebuildIdx = boxDragBoxIdx
			local wx, wz = getWorldMousePosition()
			local box = wx and startboxes[boxDragBoxIdx] or nil
			if box then
				if box.kind == "spline" and box.controls then
					local v = box.controls[boxDragIdx]
					if v then
						v.x, v.z = clampToMap(wx, wz)
						retessellateSpline(box)
					end
				elseif box.kind == "box" and #box.vertices == 4 then
					-- Rect corner drag: the opposite corner stays fixed, a minimum size stops the
					-- rect collapsing, and all 4 corners are rewritten in CCW order:
					-- 1=(minX,minZ), 2=(maxX,minZ), 3=(maxX,maxZ), 4=(minX,maxZ).
					local cx, cz = clampToMap(wx, wz)
					local i = boxDragIdx
					local opp = ((i + 1) % 4) + 1 -- 1<->3, 2<->4
					local ox, oz = box.vertices[opp].x, box.vertices[opp].z
					local MIN_SIZE = 50
					if cx > ox then
						cx = math_max(cx, ox + MIN_SIZE)
					else
						cx = math_min(cx, ox - MIN_SIZE)
					end
					if cz > oz then
						cz = math_max(cz, oz + MIN_SIZE)
					else
						cz = math_min(cz, oz - MIN_SIZE)
					end
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

	-- Startbox body drag: move every vertex and spline control by the world delta.
	if subMode == "startbox" and boxBodyDrag then
		local moved = (mx - dragStartX) ^ 2 + (my - dragStartY) ^ 2
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
				-- Clamp the delta against the bounds of vertices and controls together, so the
				-- shape stops rigid at the map edge; clamping per vertex would squash it.
				local mapX, mapZ = Game.mapSizeX, Game.mapSizeZ
				local minX, maxX = math.huge, -math.huge
				local minZ, maxZ = math.huge, -math.huge
				if box.vertices then
					for _, v in ipairs(box.vertices) do
						if v.x < minX then
							minX = v.x
						end
						if v.x > maxX then
							maxX = v.x
						end
						if v.z < minZ then
							minZ = v.z
						end
						if v.z > maxZ then
							maxZ = v.z
						end
					end
				end
				if box.controls then
					for _, v in ipairs(box.controls) do
						if v.x < minX then
							minX = v.x
						end
						if v.x > maxX then
							maxX = v.x
						end
						if v.z < minZ then
							minZ = v.z
						end
						if v.z > maxZ then
							maxZ = v.z
						end
					end
				end
				if minX ~= math.huge then
					if dwx < -minX then
						dwx = -minX
					end
					if dwx > mapX - maxX then
						dwx = mapX - maxX
					end
					if dwz < -minZ then
						dwz = -minZ
					end
					if dwz > mapZ - maxZ then
						dwz = mapZ - maxZ
					end
				end
				-- Advance the origin only by the applied delta, so the box stays at the edge
				-- while the cursor keeps moving outward.
				boxBodyDrag.lastX = boxBodyDrag.lastX + dwx
				boxBodyDrag.lastZ = boxBodyDrag.lastZ + dwz
				if box.vertices then
					for _, v in ipairs(box.vertices) do
						v.x = v.x + dwx
						v.z = v.z + dwz
					end
				end
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

	-- Startbox rect edge drag (resize).
	if subMode == "startbox" and boxEdgeDrag then
		local moved = (mx - dragStartX) ^ 2 + (my - dragStartY) ^ 2
		if moved > DRAG_THRESHOLD_SQ then
			dragging = true
		end
		if dragging then
			isDraggingBox = true
			pendingFillRebuildIdx = boxEdgeDrag.bi
			local wx, wz = getWorldMousePosition()
			local box = wx and startboxes[boxEdgeDrag.bi]
			if box and box.vertices and #box.vertices == 4 then
				local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
				for _, v in ipairs(box.vertices) do
					if v.x < minX then
						minX = v.x
					end
					if v.x > maxX then
						maxX = v.x
					end
					if v.z < minZ then
						minZ = v.z
					end
					if v.z > maxZ then
						maxZ = v.z
					end
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
				box.vertices[1].x, box.vertices[1].z = minX, minZ
				box.vertices[2].x, box.vertices[2].z = maxX, minZ
				box.vertices[3].x, box.vertices[3].z = maxX, maxZ
				box.vertices[4].x, box.vertices[4].z = minX, maxZ
				invalidateBoxFill(box)
			end
			return true
		end
	end

	-- Startbox rect being drawn.
	if subMode == "startbox" and boxRectActive then
		local wx, wz = getWorldMousePosition()
		if wx then
			---@type table?
			local tb = WG.TerraformBrush
			local stb = tb and tb.getState and tb.getState() or nil
			if stb and stb.gridSnap and tb.snapWorld then
				wx, wz = tb.snapWorld(wx, wz, 0)
			end
			boxRectEndX = wx
			boxRectEndZ = wz
		end
		return true
	end

	-- Startbox free-draw: sample points at a minimum spacing.
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
	if not active then
		return false
	end

	if subMode == "express" and dragIdx then
		-- A drag that moved the position is one undo step. The entry holds the position
		-- itself, not its index, so it stays right whatever is removed later.
		local p = positions[dragIdx]
		if dragging and dragFrom and p and dragFrom.pos == p and (p.x ~= dragFrom.x or p.z ~= dragFrom.z) then
			undoHistory[#undoHistory + 1] = {
				mode = "express",
				op = "move",
				pos = p,
				x = dragFrom.x,
				z = dragFrom.z,
				y = dragFrom.y,
			}
		end
		dragFrom = nil
		dragIdx = nil
		dragging = false
		return true
	end

	if strengthEdit.dragging then
		strengthEdit.dragging = false
		boxUndo.commit()
		return true
	end

	-- Release for every startbox drag (vertex, edge, body): run the fill rebuild that
	-- ensureBoxFillList deferred during the drag.
	if subMode == "startbox" and (boxDragIdx or boxEdgeDrag or boxBodyDrag) then
		-- Press and release on a handle without moving is a selection, not a drag.
		if boxDragIdx and boxDragBoxIdx and not dragging then
			strengthEdit.selBox = boxDragBoxIdx
			strengthEdit.selVert = boxDragIdx
		end
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
		boxUndo.commit()
		return true
	end

	-- Startbox rect finished on release (4 corners, CCW).
	if subMode == "startbox" and boxRectActive and button == 1 then
		boxRectActive = false
		if boxRectStartX and boxRectEndX then
			local x1, x2 = math_min(boxRectStartX, boxRectEndX), math_max(boxRectStartX, boxRectEndX)
			local z1, z2 = math_min(boxRectStartZ, boxRectEndZ), math_max(boxRectStartZ, boxRectEndZ)
			-- Minimum size, so a stray click makes no box.
			if (x2 - x1) >= 50 and (z2 - z1) >= 50 then
				currentBoxVerts = {
					{ x = x1, z = z1 },
					{ x = x2, z = z1 },
					{ x = x2, z = z2 },
					{ x = x1, z = z2 },
				}
				drawingBox = true
				finishStartbox()
				-- Mark it an axis-aligned rect: edge and corner drags only, never curved.
				local added = startboxes[#startboxes]
				if added then
					added.kind = "box"
				end
			end
		end
		boxRectStartX, boxRectStartZ, boxRectEndX, boxRectEndZ = nil, nil, nil, nil
		return true
	end

	-- Startbox free-draw finished on release: smooth (Chaikin), decimate, fit a spline.
	if subMode == "startbox" and freeDrawActive and button == 1 then
		freeDrawActive = false
		if #freeDrawPts >= 4 then
			local smoothed = smoothClosedPolygon(freeDrawPts, 2)
			smoothed = decimatePoints(smoothed, 50 * 50)
			if #smoothed >= 3 then
				-- One control per ~400 units of perimeter, clamped to [6, 24].
				local perim = 0
				for i = 1, #smoothed do
					local a = smoothed[i]
					local b = smoothed[(i % #smoothed) + 1]
					local dx, dz = b.x - a.x, b.z - a.z
					perim = perim + math_sqrt(dx * dx + dz * dz)
				end
				local targetCtrls = math_floor(perim / 400 + 0.5)
				if targetCtrls < 6 then
					targetCtrls = 6
				end
				if targetCtrls > 24 then
					targetCtrls = 24
				end
				local controls = fitControlPoints(smoothed, targetCtrls)
				-- A drawn outline is smooth by intent, so every control starts fully curved;
				-- the strength gizmo sharpens single corners.
				for _, c in ipairs(controls) do
					c.strength = 1
				end
				startboxes[#startboxes + 1] = {
					vertices = {},
					controls = controls,
					kind = "spline",
					allyTeam = #startboxes + 1,
				}
				retessellateSpline(startboxes[#startboxes])
				renumberBoxAllyTeams()
				boxUndo.push("add", #startboxes, startboxes[#startboxes])
			end
		end
		freeDrawPts = {}
		return true
	end

	return false
end

function widget:MouseWheel(up, value)
	if not active then
		return false
	end

	local altHeld, ctrlHeld, _, _ = Spring.GetModKeyState()

	if subMode == "shape" or subMode == "express" then
		if altHeld then
			-- Alt+Scroll rotates, in the brush's angle-snap step when that is on.
			local step = 5
			---@type table?
			local tb = WG.TerraformBrush
			local tbs = tb and tb.getState and tb.getState() or nil
			if tbs and tbs.angleSnap and (tbs.angleSnapStep or 0) > 0 then
				step = tbs.angleSnapStep
			end
			local delta = up and step or -step
			setRotation(shapeRotation + delta)
			return true
		elseif ctrlHeld then
			-- Ctrl+Scroll resizes.
			local delta = up and RADIUS_STEP or -RADIUS_STEP
			setRadius(shapeRadius + delta)
			return true
		end
	end

	return false
end

function widget:KeyPress(key, mods, isRepeat)
	if not active then
		return false
	end
	-- Ctrl+A: give every anchor in the selected box the selected anchor's strength.
	if key == 97 and mods.ctrl and strengthEdit.selBox and strengthEdit.selVert then -- 97 = 'a'
		local box = startboxes[strengthEdit.selBox]
		local handles = box and getEditHandles(box)
		if handles and handles[strengthEdit.selVert] then
			boxUndo.push("edit", strengthEdit.selBox, box)
			strengthEdit.setBox(box, handles[strengthEdit.selVert].strength or 0)
			return true
		end
	end

	-- Ctrl+Z undoes, Ctrl+Shift+Z redoes, as elsewhere in the editor. Only entries from the
	-- current submode are eligible, so one submode never rewinds the other.
	if key == 122 and mods.ctrl then -- 122 = 'z'
		local isUndo = not mods.shift
		local fromStack = isUndo and undoHistory or boxUndo.redo
		local toStack = isUndo and boxUndo.redo or undoHistory
		local at
		for i = #fromStack, 1, -1 do
			local e = fromStack[i]
			if (e.mode or "express") == subMode then
				-- A drag entry whose position was taken back since is dropped, not spent.
				local live = e.op ~= "move"
				if not live then
					for _, p in ipairs(positions) do
						if p == e.pos then
							live = true
							break
						end
					end
				end
				if live then
					at = i
					break
				end
				table.remove(fromStack, i)
			end
		end
		if not at then
			return true
		end

		local entry = fromStack[at]
		table.remove(fromStack, at)
		if not entry then
			return true
		end
		if entry.mode == "startbox" then
			table.insert(toStack, boxUndo.apply(entry))
		elseif entry.op == "move" then
			-- A drag puts the position back where the drag started. No redo, like placements.
			entry.pos.x, entry.pos.z, entry.pos.y = entry.x, entry.z, entry.y
		else
			-- Positions rewind by count and restore the rotation counters. They get no redo.
			for _ = 1, (entry.count or 0) do
				if #positions > 0 then
					positions[#positions] = nil
				end
			end
			nextAllyTeam = entry.prevNextAllyTeam or 1
			nextTeamSlot = entry.prevNextTeamSlot or 1
		end

		return true
	end
	return false
end

-- ============================================================
-- Drawing
-- ============================================================

-- Fake ground glow: 5 concentric ground circles, alpha fading outward.
local function drawSoftDisc(px, pz, radius, r, g, b, coreAlpha, segments)
	segments = segments or 28
	for i = 1, 5 do
		local t = i / 5
		local rr = radius * t
		local a = coreAlpha * (1 - t * 0.7)
		glColor(r, g, b, a)
		glDrawGroundCircle(px, 0, pz, rr, segments)
	end
end

-- Ground-hugging fill mesh for a polygon (a subdivided fan around the centroid), compiled
-- into a display list. Cached on the box so drawing does not sample ground heights and
-- allocate every frame, which on large boxes can push Lua memory to its limit.
local function buildPolygonFillList(verts, lift, cellSize)
	local n = #verts
	if n < 3 then
		return nil
	end
	local cx, cz = 0, 0
	for i = 1, n do
		cx = cx + verts[i].x
		cz = cz + verts[i].z
	end
	cx, cz = cx / n, cz / n
	return glCreateList(function()
		glBeginEnd(GL_TRIANGLES, function()
			-- One flat scratch buffer for every fan. Row ri holds ri+1 vertices as (px, py, pz);
			-- vertex j of row ri starts at (ri*(ri+1)/2 + j) * 3.
			local rowBuf = {}
			for i = 1, n do
				local a1 = verts[i]
				local b1 = verts[(i % n) + 1]
				local eAB = math_sqrt((b1.x - a1.x) * (b1.x - a1.x) + (b1.z - a1.z) * (b1.z - a1.z))
				local eCA = math_sqrt((a1.x - cx) * (a1.x - cx) + (a1.z - cz) * (a1.z - cz))
				local eCB = math_sqrt((b1.x - cx) * (b1.x - cx) + (b1.z - cz) * (b1.z - cz))
				local N = math_max(1, math.ceil(math_max(eAB, eCA, eCB) / cellSize))
				local invN = 1 / N
				for ri = 0, N do
					local tC = 1 - ri * invN
					local rowBase = ri * (ri + 1) * 0.5 -- (ri*(ri+1))/2 vertices before this row
					for j = 0, ri do
						local wA, wB
						if ri == 0 then
							wA, wB = 0, 0
						else
							wA = (ri - j) * invN
							wB = j * invN
						end
						local px = tC * cx + wA * a1.x + wB * b1.x
						local pz = tC * cz + wA * a1.z + wB * b1.z
						local py = (GetGroundHeight(px, pz) or 0) + lift
						local k = (rowBase + j) * 3
						rowBuf[k + 1] = px
						rowBuf[k + 2] = py
						rowBuf[k + 3] = pz
					end
				end
				for ri = 0, N - 1 do
					local rUBase = ri * (ri + 1) * 0.5
					local rDBase = (ri + 1) * (ri + 2) * 0.5
					-- stylua: ignore start
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
					-- stylua: ignore end
				end
			end
		end)
	end)
end

-- Returns the box's fill display list, rebuilding it only when marked dirty.
local BOX_FILL_CELL = 20 -- world units per tessellation cell (lower = higher fidelity)
local BOX_FILL_LIFT = 2
local BOX_FILL_DRAG_INTERVAL = 4 -- during drag, rebuild list at most every Nth draw frame
ensureBoxFillList = function(box)
	if box._fillList and not box._fillDirty then
		return box._fillList
	end
	-- During a drag, shapes over 12 vertices keep the stale fill until MouseRelease (the fan
	-- subdivision is O(N^2)). Smaller ones rebuild every few frames with a coarser cell, so
	-- the fill still follows the drag.
	local verts = box.vertices
	local nv = verts and #verts or 0
	if isDraggingBox and box._fillList then
		if nv > 12 then
			return box._fillList
		end
		-- Throttled: each rebuild allocates a scratch buffer and a new display list. About
		-- 15 Hz at 60 fps still reads as live.
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
	box._fillDirty = isDraggingBox -- final crisp rebuild on release
	box._fillNeedsRebuild = false
	if not isDraggingBox then
		box._fillLastFrame = nil
	end
	return box._fillList
end

invalidateBoxFill = function(box)
	if box then
		box._fillDirty = true
	end
end

freeBoxFillList = function(box)
	if box and box._fillList then
		glDeleteList(box._fillList)
		box._fillList = nil
		box._fillDirty = true
	end
end

-- arcCount evenly spaced arcs around a circle, drawn as thick ground ribbons (triangle
-- strips between an inner and outer radius) so they read as chunky segments.
local function drawArcSegments(px, pz, radius, r, g, b, alpha, rotationRad, arcCount, arcFrac, segmentsPerArc)
	local slotStep = (2 * math_pi) / arcCount
	local arcSpan = slotStep * arcFrac
	local stepInArc = arcSpan / segmentsPerArc
	local halfW = radius * 0.085 -- ribbon half-thickness (as fraction of radius)
	local rInner = radius - halfW
	local rOuter = radius + halfW
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

-- Vertical beam above the start position: stacked line segments fading upward.
local function drawBeam(px, pz, r, g, b, alphaBase)
	local gy = GetGroundHeight(px, pz) or 0
	local steps = 6
	local beamHeight = 280
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

-- Team-tinted commander icon billboarded above the marker. It scales with camera distance
-- (clamped) so it stays readable zoomed out without ballooning up close.
local spGetCameraPosition = Spring.GetCameraPosition
local function drawCommanderBillboard(px, pz, r, g, b, alpha, iconPath, hovered)
	local gy = (GetGroundHeight(px, pz) or 0)
	-- 0.8 base, then 10% smaller per player-count tier (>16, >32, >64) to limit overlap.
	local playerScale = 0.8
	local totalPlayers = (numAllyTeams or 2) * (numTeamsPerAlly or 1)
	if totalPlayers > 16 then
		playerScale = playerScale * 0.9
	end
	if totalPlayers > 32 then
		playerScale = playerScale * 0.9
	end
	if totalPlayers > 64 then
		playerScale = playerScale * 0.9
	end
	local baseSize = (hovered and 52 or 48) * playerScale
	-- 1.0x at a camera distance of 2000 units.
	local cx, cy, cz = spGetCameraPosition()
	local dx, dy, dz = cx - px, cy - (gy + 110), cz - pz
	local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
	local scale = dist / 2000
	if scale < 0.6 then
		scale = 0.6
	end
	if scale > 4.0 then
		scale = 4.0
	end
	local iconSize = baseSize * scale
	local lift = 110 -- height above ground
	glPushMatrix()
	glTranslate(px, gy + lift, pz)
	glBillboard()
	glTexture(iconPath)
	glColor(r, g, b, alpha)
	-- Larger additive glow quad behind the icon.
	glBlending(GL_SRC_ALPHA, GL_ONE)
	glColor(r, g, b, alpha * 0.35)
	local gs = iconSize * 1.35
	glTexRect(-gs, -gs, gs, gs)
	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	glColor(r, g, b, alpha)
	glTexRect(-iconSize, -iconSize, iconSize, iconSize)
	glTexture(false)
	glPopMatrix()
end

-- Four small ground circles at the cardinal points: the drag hint on a hovered marker.
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

-- Placed start position marker: glow, inner ring, slow rotating arcs, beam, commander icon.
-- Kept calm on purpose: barely any pulse, slow rotation.
local function drawStartPosMarker(px, pz, color, alpha, iconPath, hovered, phase)
	local a = alpha or 1.0
	local r, g, b = color[1], color[2], color[3]

	-- Ground glow, barely pulsing.
	local pulse = 0.5 + 0.5 * math_sin(phase * 0.5)
	local glowMul = hovered and 1.6 or 1.0
	drawSoftDisc(px, pz, MARKER_RADIUS * (0.96 + 0.04 * pulse), r, g, b, 0.09 * a * glowMul, 20)

	-- Steady outer ring on hover.
	if hovered then
		glColor(1, 1, 1, 0.55 * a)
		glLineWidth(2.5)
		glDrawGroundCircle(px, 0, pz, MARKER_RADIUS * 1.18, 40)
	end

	glColor(r, g, b, 0.35 * a)
	glLineWidth(1.0)
	glDrawGroundCircle(px, 0, pz, MARKER_RADIUS * 0.55, 28)

	local rot = phase * 0.25
	drawArcSegments(px, pz, MARKER_RADIUS, r, g, b, (hovered and 0.85 or 0.65) * a, rot, 3, 0.66, 10)

	drawBeam(px, pz, r, g, b, (hovered and 0.30 or 0.18) * a)

	drawCommanderBillboard(px, pz, r, g, b, (hovered and 1.0 or 0.90) * a, iconPath, hovered)

	if hovered then
		drawDragHintDots(px, pz, MARKER_RADIUS, r, g, b, 0.7 * a)
	end
end

-- Lighter marker for previews: no beam, no hint dots, a smaller fixed-size icon.
local function drawPreviewMarker(px, pz, color, alpha, iconPath, phase)
	local a = alpha or 1.0
	local r, g, b = color[1], color[2], color[3]
	drawSoftDisc(px, pz, MARKER_RADIUS * 0.85, r, g, b, 0.08 * a, 16)
	glLineWidth(1.8)
	local rot = phase * 0.4
	drawArcSegments(px, pz, MARKER_RADIUS, r, g, b, 0.55 * a, rot, 3, 0.66, 8)
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
	-- Hover detection: drives the cursor and the highlighted marker or handle.
	hoverPosIdx = nil
	hoverBoxIdx = nil
	hoverVertIdx = nil
	strengthEdit.hoverKnob = false
	hoverBoxEdge = nil
	hoverPolyEdge = nil
	if not active then
		if WG.StartPosTool then
			WG.StartPosTool.hoveringDraggable = false
		end
		return
	end
	-- Mid-drag the cursor stays on "move".
	if dragIdx or boxDragIdx or boxEdgeDrag then
		if WG.StartPosTool then
			WG.StartPosTool.hoveringDraggable = true
		end
		return
	end

	local wx, wz = getWorldMousePosition()
	if wx then
		if subMode == "express" or subMode == "roles" then
			local bestIdx, bestDist = nil, DRAGGABLE_DIST_SQ
			for i, pos in ipairs(positions) do
				local d = distSq(wx, wz, pos.x, pos.z)
				if d < bestDist then
					bestDist = d
					bestIdx = i
				end
			end
			hoverPosIdx = bestIdx
		elseif subMode == "startbox" then
			-- Knob first, as in MousePress, so the highlight shows what a click would grab.
			local selBox = strengthEdit.selBox and startboxes[strengthEdit.selBox]
			if selBox and strengthEdit.selVert then
				local hmx, hmy = GetMouseState()
				if strengthEdit.knobHit(selBox, strengthEdit.selVert, hmx, hmy) then
					strengthEdit.hoverKnob = true
				end
			end
			if not strengthEdit.hoverKnob then
				hoverBoxIdx, hoverVertIdx = findNearestBoxVertex(wx, wz)
			end
			if not strengthEdit.hoverKnob and not hoverBoxIdx then
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

	local shouldMove = (hoverPosIdx ~= nil)
		or (hoverVertIdx ~= nil)
		or (hoverBoxEdge ~= nil)
		or (hoverPolyEdge ~= nil)
		or strengthEdit.hoverKnob
	if WG.StartPosTool then
		WG.StartPosTool.hoveringDraggable = shouldMove
	end
end

function widget:DrawWorld()
	if not active then
		return
	end

	local drawFrame = GetDrawFrame() or 0
	local phase = drawFrame * 0.04 -- ~2.4 rad/sec @ 60fps

	local wx, wz = getWorldMousePosition()
	-- Share this pass's mouse trace with DrawScreenEffects through the widget table:
	-- DrawWorld is at Lua 5.1's 60-upvalue limit, so no new file-level locals.
	self.frameTraceX, self.frameTraceZ, self.frameTraceDF = wx, wz, drawFrame
	do
		---@type table?
		local tb2 = WG.TerraformBrush
		local st2 = tb2 and tb2.getState and tb2.getState()
		if st2 and (st2.symmetryHoveringOrigin or st2.symmetryDraggingOrigin) then
			wx = nil
			wz = nil
		end
	end

	for i, pos in ipairs(positions) do
		local pIdx = pos.playerIdx or pos.allyTeam
		local color = getColorForPlayer(pIdx)
		local iconPath = COMMANDER_ICONS[((pIdx - 1) % #COMMANDER_ICONS) + 1]
		local hovered = (hoverPosIdx == i) or (dragIdx == i)
		drawStartPosMarker(pos.x, pos.z, color, 1.0, iconPath, hovered, phase + i * 0.6)
	end

	-- Shape mode: outline and preview markers at the cursor.
	if subMode == "shape" and wx then
		local previewPts = generateShapePositions(wx, wz)
		glColor(1, 1, 1, 0.22)
		glLineWidth(1.5)
		local gy = GetGroundHeight(wx, wz) or 0

		local sides = ({
			circle = 0,
			square = 4,
			triangle = 3,
			hexagon = 6,
			octagon = 8,
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
				at = math_floor(zeroIdx / numSlot) % numAlly + 1
				slot = (zeroIdx % numSlot) + 1
			else
				at = (zeroIdx % numAlly) + 1
				slot = math_floor(zeroIdx / numAlly) % numSlot + 1
			end
			local pIdx = (at - 1) * numSlot + slot
			local color = getColorForPlayer(pIdx)
			local iconPath = COMMANDER_ICONS[((pIdx - 1) % #COMMANDER_ICONS) + 1]
			drawPreviewMarker(pt.x, pt.z, color, 0.55, iconPath, phase + i * 0.4)
		end
	end

	-- Express mode: ghost preview of the next position (and its symmetric copies).
	if subMode == "express" and wx and not dragIdx and hoverPosIdx == nil then
		---@type table?
		local tb = WG.TerraformBrush
		local stb = tb and tb.getState and tb.getState() or nil
		local numSlot = math_max(1, numTeamsPerAlly)
		local numAlly = math_max(1, numAllyTeams)
		local baseIdx = (nextAllyTeam - 1) * numSlot + (nextTeamSlot or 1)
		-- Gray over ground too steep for the commander, so the preview reads as disabled.
		local function tintForPlace(x, z, col)
			if isPlaceableForCommander(x, z) then
				return col
			end
			local lum = 0.299 * col[1] + 0.587 * col[2] + 0.114 * col[3]
			lum = lum * 0.6
			return { lum, lum, lum }
		end
		if stb and stb.symmetryActive and tb.getSymmetricPositions then
			local copies = tb.getSymmetricPositions(wx, wz, 0)
			-- Walk the rotation the way the click will: each placeable copy takes the next player
			-- (the same step as advanceNextPlayer), a refused one passes its player on.
			local ally, slot = nextAllyTeam, nextTeamSlot or 1
			for k, p in ipairs(copies) do
				local pIdx = (ally - 1) * numSlot + slot
				local color = getColorForPlayer(pIdx)
				local iconPath = COMMANDER_ICONS[((pIdx - 1) % #COMMANDER_ICONS) + 1]
				drawPreviewMarker(p.x, p.z, tintForPlace(p.x, p.z, color), 0.5, iconPath, phase + k * 0.5)
				if isPlaceableForCommander(p.x, p.z) then
					if placementMode == "sequential" then
						slot = slot + 1
						if slot > numSlot then
							slot = 1
							ally = (ally % numAlly) + 1
						end
					else
						ally = ally + 1
						if ally > numAlly then
							ally = 1
							slot = (slot % numSlot) + 1
						end
					end
				end
			end
		else
			local color = getColorForPlayer(baseIdx)
			local iconPath = COMMANDER_ICONS[((baseIdx - 1) % #COMMANDER_ICONS) + 1]
			drawPreviewMarker(wx, wz, tintForPlace(wx, wz, color), 0.55, iconPath, phase)
		end
	end

	-- Startboxes: translucent fill from the cached display list, outline, then handles.
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
					local v = verts[i]
					local vn = verts[(i % #verts) + 1]
					local segLen = math_sqrt((vn.x - v.x) ^ 2 + (vn.z - v.z) ^ 2)
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
				-- Edge resize handles: a pair of arrow tips straddling each edge, pointing out
				-- and in along its normal.
				local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
				for _, v in ipairs(verts) do
					if v.x < minX then
						minX = v.x
					end
					if v.x > maxX then
						maxX = v.x
					end
					if v.z < minZ then
						minZ = v.z
					end
					if v.z > maxZ then
						maxZ = v.z
					end
				end
				local midEdges = {
					-- edge -> midpoint, outward normal (nx, nz), tangent (tx, tz)
					L = { x = minX, z = (minZ + maxZ) * 0.5, nx = -1, nz = 0, tx = 0, tz = 1 },
					R = { x = maxX, z = (minZ + maxZ) * 0.5, nx = 1, nz = 0, tx = 0, tz = 1 },
					T = { x = (minX + maxX) * 0.5, z = minZ, nx = 0, nz = -1, tx = 1, tz = 0 },
					B = { x = (minX + maxX) * 0.5, z = maxZ, nx = 0, nz = 1, tx = 1, tz = 0 },
				}
				for name, mp in pairs(midEdges) do
					local isHover = (hoverBoxEdge and hoverBoxEdge.bi == bi and hoverBoxEdge.edge == name)
					-- Constant pixel size at any zoom.
					local sizePx = isHover and 22 or 16
					local size = worldRadiusForScreenPx(mp.x, mp.z, sizePx)
					local half = size * 0.55 -- half-base along the edge tangent
					local gap = size * 0.35 -- clearance from the edge line so tips don't overlap
					local rim = worldRadiusForScreenPx(mp.x, mp.z, 1.5) -- 1.5px dark rim halo
					-- signNormal 1 is the tip outside the rect, -1 the one inside. The base sits
					-- `gap` off the edge, the apex `size` further out; `expand` grows it for the rim.
					local function emitTip(signNormal, expand)
						local sz = size + (expand or 0)
						local hf = half + (expand or 0)
						local gp = math_max(0, gap - (expand or 0))
						local bcx = mp.x + signNormal * gp * mp.nx
						local bcz = mp.z + signNormal * gp * mp.nz
						local apx = bcx + signNormal * sz * mp.nx
						local apz = bcz + signNormal * sz * mp.nz
						local b1x = bcx + mp.tx * hf
						local b1z = bcz + mp.tz * hf
						local b2x = bcx - mp.tx * hf
						local b2z = bcz - mp.tz * hf
						local apy = (GetGroundHeight(apx, apz) or 0) + 6
						local b1y = (GetGroundHeight(b1x, b1z) or 0) + 6
						local b2y = (GetGroundHeight(b2x, b2z) or 0) + 6
						glVertex(apx, apy, apz)
						glVertex(b1x, b1y, b1z)
						glVertex(b2x, b2y, b2z)
					end
					-- Dark rim: a slightly larger triangle behind the colored fill.
					glColor(0, 0, 0, isHover and 0.85 or 0.70)
					glBeginEnd(GL_TRIANGLES, function()
						emitTip(1, rim)
						emitTip(-1, rim)
					end)
					glColor(color[1], color[2], color[3], isHover and 1.0 or 0.92)
					glBeginEnd(GL_TRIANGLES, function()
						emitTip(1, 0)
						emitTip(-1, 0)
					end)
					if isHover then
						glColor(1, 1, 1, 0.75)
						glLineWidth(2.0)
						local function outlineTip(signNormal)
							local bcx = mp.x + signNormal * gap * mp.nx
							local bcz = mp.z + signNormal * gap * mp.nz
							local apx = bcx + signNormal * size * mp.nx
							local apz = bcz + signNormal * size * mp.nz
							local b1x = bcx + mp.tx * half
							local b1z = bcz + mp.tz * half
							local b2x = bcx - mp.tx * half
							local b2z = bcz - mp.tz * half
							local apy = (GetGroundHeight(apx, apz) or 0) + 7
							local b1y = (GetGroundHeight(b1x, b1z) or 0) + 7
							local b2y = (GetGroundHeight(b2x, b2z) or 0) + 7
							glBeginEnd(GL_LINE_LOOP, function()
								glVertex(apx, apy, apz)
								glVertex(b1x, b1y, b1z)
								glVertex(b2x, b2y, b2z)
							end)
						end
						outlineTip(1)
						outlineTip(-1)
					end
				end
				-- Corner handles: resize from a corner, the rect stays axis-aligned.
				for vi, v in ipairs(verts) do
					local vy = GetGroundHeight(v.x, v.z) or 0
					local isHoverVert = (hoverBoxIdx == bi and hoverVertIdx == vi)
					local rPx = isHoverVert and 22 or 14
					local vertR = worldRadiusForScreenPx(v.x, v.z, rPx)
					local rim = worldRadiusForScreenPx(v.x, v.z, 1.5)
					local cy = vy + 5
					local segs = 22
					glBeginEnd(GL_TRIANGLE_FAN, function()
						glColor(0, 0, 0, isHoverVert and 0.85 or 0.70)
						glVertex(v.x, cy - 0.1, v.z)
						for s = 0, segs do
							local a = (s / segs) * 2 * math_pi
							glVertex(v.x + math_cos(a) * (vertR + rim), cy - 0.1, v.z + math_sin(a) * (vertR + rim))
						end
					end)
					glBeginEnd(GL_TRIANGLE_FAN, function()
						glColor(color[1], color[2], color[3], isHoverVert and 1.0 or 0.92)
						glVertex(v.x, cy, v.z)
						for s = 0, segs do
							local a = (s / segs) * 2 * math_pi
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
					local rPx = isHoverVert and 22 or 14
					local vertR = worldRadiusForScreenPx(v.x, v.z, rPx)
					local rim = worldRadiusForScreenPx(v.x, v.z, 1.5)
					local cy = vy + 5
					local segs = 22
					glBeginEnd(GL_TRIANGLE_FAN, function()
						glColor(0, 0, 0, isHoverVert and 0.85 or 0.70)
						glVertex(v.x, cy - 0.1, v.z)
						for s = 0, segs do
							local a = (s / segs) * 2 * math_pi
							glVertex(v.x + math_cos(a) * (vertR + rim), cy - 0.1, v.z + math_sin(a) * (vertR + rim))
						end
					end)
					glBeginEnd(GL_TRIANGLE_FAN, function()
						glColor(color[1], color[2], color[3], isHoverVert and 1.0 or 0.92)
						glVertex(v.x, cy, v.z)
						for s = 0, segs do
							local a = (s / segs) * 2 * math_pi
							glVertex(v.x + math_cos(a) * vertR, cy, v.z + math_sin(a) * vertR)
						end
					end)
					if isHoverVert then
						glColor(1, 1, 1, 0.55)
						glLineWidth(2.0)
						glDrawGroundCircle(v.x, vy, v.z, vertR + worldRadiusForScreenPx(v.x, v.z, 4), 24)
					end
				end
				strengthEdit.draw(box, bi)
				-- Ghost handle at the hovered edge midpoint (click inserts an anchor there).
				if hoverPolyEdge and hoverPolyEdge.bi == bi then
					local gmx, gmz = hoverPolyEdge.x, hoverPolyEdge.z
					local gy = GetGroundHeight(gmx, gmz) or 0
					glColor(color[1], color[2], color[3], 0.55)
					glDrawGroundCircle(gmx, gy, gmz, 28, 14)
					glColor(1, 1, 1, 0.55)
					glLineWidth(1.5)
					glDrawGroundCircle(gmx, gy, gmz, 36, 18)
				end
				-- Spline: faint control polygon behind the curve.
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

	-- Polygon being drawn, with a rubber band to the cursor.
	if drawingBox and #currentBoxVerts > 0 then
		local color = getColorForAllyTeam(#startboxes + 1)
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

	-- Rect being drawn (startboxMode == "box").
	if subMode == "startbox" and boxRectActive and boxRectStartX and boxRectEndX then
		local color = getColorForAllyTeam(#startboxes + 1)
		local x1, x2 = math_min(boxRectStartX, boxRectEndX), math_max(boxRectStartX, boxRectEndX)
		local z1, z2 = math_min(boxRectStartZ, boxRectEndZ), math_max(boxRectStartZ, boxRectEndZ)
		glColor(color[1], color[2], color[3], 0.75)
		glLineWidth(2.5)
		glBeginEnd(GL_LINE_LOOP, function()
			local y = GetGroundHeight(x1, z1) or 0
			glVertex(x1, y + 6, z1)
			y = GetGroundHeight(x2, z1) or 0
			glVertex(x2, y + 6, z1)
			y = GetGroundHeight(x2, z2) or 0
			glVertex(x2, y + 6, z2)
			y = GetGroundHeight(x1, z2) or 0
			glVertex(x1, y + 6, z2)
		end)
		-- Second, fainter outline closer to the ground.
		glColor(color[1], color[2], color[3], 0.18)
		glLineWidth(1.0)
		glBeginEnd(GL_LINE_LOOP, function()
			local y = GetGroundHeight(x1, z1) or 0
			glVertex(x1, y + 3, z1)
			y = GetGroundHeight(x2, z1) or 0
			glVertex(x2, y + 3, z1)
			y = GetGroundHeight(x2, z2) or 0
			glVertex(x2, y + 3, z2)
			y = GetGroundHeight(x1, z2) or 0
			glVertex(x1, y + 3, z2)
		end)
	end

	-- Free-draw path in progress.
	if subMode == "startbox" and freeDrawActive and #freeDrawPts >= 2 then
		local color = getColorForAllyTeam(#startboxes + 1)
		glColor(color[1], color[2], color[3], 0.85)
		glLineWidth(2.2)
		glBeginEnd(GL_LINE_STRIP, function()
			for _, p in ipairs(freeDrawPts) do
				local gy = GetGroundHeight(p.x, p.z) or 0
				glVertex(p.x, gy + 5, p.z)
			end
		end)
		-- Mark the start, where the outline will close.
		local first = freeDrawPts[1]
		local gy = GetGroundHeight(first.x, first.z) or 0
		glColor(1, 1, 1, 0.8)
		glDrawGroundCircle(first.x, gy, first.z, 24, 14)
	end

	glColor(1, 1, 1, 1)
	glLineWidth(1.0)
end

-- Screen center and pixel radius of a world circle at (wx, wz).
-- Returns sx, sy, radiusPx, true; nil when off screen.
local function getScreenMarker(wx, wz, worldRadius)
	local gy = GetGroundHeight(wx, wz) or 0
	local cx, cy, cz = WorldToScreenCoords(wx, gy, wz)
	if not cz or cz <= 0 or cz >= 1 then
		return nil
	end
	local ex, ey = WorldToScreenCoords(wx + worldRadius, gy, wz)
	local screenR = math_sqrt((ex - cx) * (ex - cx) + (ey - cy) * (ey - cy))
	return cx, cy, screenR, true
end

-- World radius at (wx, wz) that comes out `screenPx` pixels on screen. Falls back to
-- screenPx itself when the point is off screen.
worldRadiusForScreenPx = function(wx, wz, screenPx)
	local gy = GetGroundHeight(wx, wz) or 0
	local sx0, sy0, sz0 = WorldToScreenCoords(wx, gy, wz)
	if not sz0 or sz0 <= 0 or sz0 >= 1 then
		return screenPx
	end
	local probe = 100
	local sxe, sye = WorldToScreenCoords(wx + probe, gy, wz)
	if not sxe then
		return screenPx
	end
	local pxPerWorld = math_sqrt((sxe - sx0) * (sxe - sx0) + (sye - sy0) * (sye - sy0)) / probe
	if pxPerWorld < 0.0001 then
		return screenPx
	end
	return screenPx / pxPerWorld
end

-- Screen pixels between a marker's top and its badge.
local LABEL_PAD = 18

local glGetTextWidth = gl.GetTextWidth

-- Screen-space badge: dark card, colored left bar, "Team N" label and an optional role row.
-- (cx, cy) is the bottom center; returns the card height.
local function drawScreenBadge(cx, cy, color, allyTeamNum, fontSize, hovered, role)
	local padX, padY = 14, 10
	local barW = 5
	local gap = 10
	local label = "Team " .. tostring(allyTeamNum)

	-- gl.GetTextWidth returns a width per unit of font size.
	local function measure(s, sz)
		local w = glGetTextWidth and glGetTextWidth(s) or (#s * 0.55)
		return w * sz
	end
	local bigSize = fontSize
	local roleSize = math.floor(fontSize * 0.65)
	local roleH = role and (roleSize * 1.18 + 4) or 0
	local textW = measure(label, bigSize)
	if role then
		textW = math_max(textW, measure(role, roleSize))
	end
	local w = barW + gap + textW + padX * 2
	local h = bigSize * 1.18 + roleH + padY * 2
	local bx = cx - w * 0.5
	local by = cy

	-- stylua: ignore start
	-- Card background: a rect with chamfered corners (octagon fan).
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

	-- White frame on hover.
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

	glColor(color[1], color[2], color[3], 1.0)
	glBeginEnd(GL_TRIANGLE_FAN, function()
		glVertex(bx + padX,          by + padY)
		glVertex(bx + padX + barW,   by + padY)
		glVertex(bx + padX + barW,   by + h - padY)
		glVertex(bx + padX,          by + h - padY)
	end)

	-- Faint team-color tint behind the text.
	glColor(color[1], color[2], color[3], hovered and 0.22 or 0.12)
	glBeginEnd(GL_TRIANGLE_FAN, function()
		glVertex(bx + padX + barW + 1, by + padY)
		glVertex(bx + w - padX,        by + padY)
		glVertex(bx + w - padX,        by + h - padY)
		glVertex(bx + padX + barW + 1, by + h - padY)
	end)
	-- stylua: ignore end

	-- Labels: drop shadow, then a brightened team color.
	local textX = bx + padX + barW + gap
	local textY = by + padY + roleH -- screen y grows upward: "Team N" sits above the role row
	glColor(0, 0, 0, 0.90)
	glText(label, textX + 2, textY + 2, bigSize, "o")
	glColor(
		math_min(1, color[1] * 0.55 + 0.45),
		math_min(1, color[2] * 0.55 + 0.45),
		math_min(1, color[3] * 0.55 + 0.45),
		1.0
	)
	glText(label, textX, textY, bigSize, "o")

	if role then
		glColor(0, 0, 0, 0.90)
		glText(role, textX + 2, by + padY + 2, roleSize, "o")
		glColor(color[1], color[2], color[3], 0.95)
		glText(role, textX, by + padY, roleSize, "o")
	end
	return h
end

function widget:DrawScreenEffects()
	if not active then
		return
	end

	-- A badge above each placed position.
	for i, pos in ipairs(positions) do
		local sx, sy, sr, vis = getScreenMarker(pos.x, pos.z, MARKER_RADIUS)
		if vis then
			local pIdx = pos.playerIdx or pos.allyTeam
			local color = getColorForPlayer(pIdx)
			local badgeY = sy + sr + LABEL_PAD
			local fontSize = 32
			local hovered = (hoverPosIdx == i) or (dragIdx == i)
			drawScreenBadge(sx, badgeY, color, pos.allyTeam, fontSize, hovered, pos.role)
		end
	end

	-- Startbox badges sit above the box's top vertex on screen, not on the centroid, where
	-- they would cover the body-drag area. The centroid is the fallback.
	for _, box in ipairs(startboxes) do
		if #box.vertices >= 3 then
			local bestSx, bestSy, bestVis
			for _, v in ipairs(box.vertices) do
				local vy = GetGroundHeight(v.x, v.z) or 0
				local sx, sy, sz = WorldToScreenCoords(v.x, vy, v.z)
				if sz and sz > 0 and sz < 1 then
					if (not bestSy) or sy > bestSy then -- screen y grows upward; max sy = top of screen
						bestSy = sy
						bestSx = sx
						bestVis = true
					end
				end
			end
			if not bestVis then
				-- Every vertex off screen: try the centroid.
				local ccx, ccz = 0.0, 0.0
				for _, v in ipairs(box.vertices) do
					ccx = ccx + v.x
					ccz = ccz + v.z
				end
				ccx = ccx / #box.vertices
				ccz = ccz / #box.vertices
				local ccy = GetGroundHeight(ccx, ccz) or 0
				local sx, sy, sz = WorldToScreenCoords(ccx, ccy, ccz)
				if sz and sz > 0 and sz < 1 then
					bestSx, bestSy, bestVis = sx, sy, true
				end
			end
			if bestVis then
				local color = getColorForAllyTeam(box.allyTeam)
				drawScreenBadge(bestSx, bestSy + 28, color, box.allyTeam, 26, false)
			end
		end
	end

	-- Shape preview labels.
	if subMode == "shape" then
		-- Reuse DrawWorld's mouse trace from this frame. Read through self and Spring: this
		-- function is near the upvalue limit too.
		local wx, wz
		if self.frameTraceDF == (Spring.GetDrawFrame() or 0) then
			wx, wz = self.frameTraceX, self.frameTraceZ
		else
			wx, wz = getWorldMousePosition()
		end
		if wx then
			local previewPts = generateShapePositions(wx, wz)
			local numAlly = math_max(1, numAllyTeams)
			local numSlot = math_max(1, numTeamsPerAlly)
			for i, pt in ipairs(previewPts) do
				local zeroIdx = i - 1
				local at, slot
				if placementMode == "sequential" then
					at = math_floor(zeroIdx / numSlot) % numAlly + 1
					slot = (zeroIdx % numSlot) + 1
				else
					at = (zeroIdx % numAlly) + 1
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
		activate = activate,
		deactivate = deactivate,
		getState = getState,
		hoveringDraggable = false,
		setSubMode = setSubMode,
		setShape = setShape,
		setRadius = setRadius,
		setRotation = setRotation,
		setShapeCount = setShapeCount,
		setNumAllyTeams = setNumAllyTeams,
		setNumTeamsPerAlly = setNumTeamsPerAlly,
		togglePlacementMode = togglePlacementMode,
		setStartboxMode = setStartboxMode,
		clearAllPositions = clearAllPositions,
		addPosition = addPosition,
		placeRandomPositions = placeRandomPositions,
		saveStartPositions = saveStartPositions,
		loadStartPositions = loadStartPositions,
		saveStartboxes = saveStartboxes,
		copyStartboxOverride = copyStartboxOverride,
		exportSuggestions = exportSuggestions,
		loadStartboxes = loadStartboxes,
		saveAll = saveAll,
		clearAllStartboxes = clearAllStartboxes,
		cyclePositionRole = roleConfig.cyclePositionRole,
		buildSuggestionsData = roleConfig.buildSuggestionsData,
		encodeBSetValue = encodeBSetValue,
		addStartboxVertex = addStartboxVertex,
		finishStartbox = finishStartbox,
		encodeStartboxes = boxExport.encode,
	}
end

function widget:Shutdown()
	WG.StartPosTool = nil
	for i = 1, #startboxes do
		freeBoxFillList(startboxes[i])
	end
end
