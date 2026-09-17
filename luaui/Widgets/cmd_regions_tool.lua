function widget:GetInfo()
	return {
		name = "Regions Tool",
		desc = "Draw the map's regions: start areas and positions, mex regions, and whatever other types modules contribute",
		author = "PtaQ",
		date = "2026",
		license = "GPL v2",
		layer = 1000000,
		enabled = false,
		handler = true,
	}
end

-- Spring API Caching
local Spring = Spring
local Echo = Spring.Echo
local GetMouseState = Spring.GetMouseState
local TraceScreenRay = Spring.TraceScreenRay
local GetGroundHeight = Spring.GetGroundHeight
local GetMapSize = Spring.GetMapSize or function()
	return Game.mapSizeX, Game.mapSizeZ
end
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

-- Commander icons cycled by allyteam index — adds visual variety & "2026" faction flavor
local COMMANDER_ICONS = {
	"icons/armcom.png",
	"icons/corcom.png",
	"icons/legcom.png",
}

local DRAGGABLE_DIST_SQ = 120 * 120 -- world distance² inside which cursor becomes "move"

local math_floor = math.floor
local math_sqrt = math.sqrt
local math_sin = math.sin
local math_cos = math.cos
local math_pi = math.pi
local math_max = math.max
local math_min = math.min

-- Constants
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
local REGIONS_SAVE_DIR = "Terraform Brush/Regions/"
local VERTEX_PICK_DIST_SQ = 60 * 60 -- world distance^2 to pick a startbox vertex

-- Team colors matching game_autocolors.lua FFA palette (0-1 float RGBA); extended past 16 for 256-player support
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

-- State
local active = false
local subMode = "express" -- "express" | "shape" | "startbox"
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
local R = {
	type = "start",
	strategy = "express",
	placing = "points",
	selectedIdx = nil,
	selectedStart = nil,
	pendingVertex = nil,
	category = "start",
	drawForTeam = nil,
	geometry = "point",
	editMode = "select",
	radial = nil,
	radialPending = {},
	radialHistory = {},
	pending = {},
	error = "",
	revision = 0,
	COLOR = { 0.35, 0.85, 1.0, 1.0 },
}
R.api = VFS.Include("modules/regions/api.lua") ---@type RegionsApi
local StartPlacement = VFS.Include("modules/start/lib/placement.lua") ---@type StartPlacement
local StartExport = VFS.Include("modules/start/lib/export.lua") ---@type StartExport
local MexHull = VFS.Include("modules/transfer/mex_splitting/hull.lua") ---@type MexRegionsHull
R.ORDER, R.TYPES = R.api.Types()
R.CATEGORY_ORDER = R.ORDER
R.CATEGORIES = {}
for _, key in ipairs(R.ORDER) do
	local kind = R.TYPES[key]
	local placesPoints = false
	for _, g in ipairs(kind.geometries) do
		placesPoints = placesPoints or g == "point"
	end
	R.CATEGORIES[key] = { key = key, label = kind.label, type = key, placing = placesPoints and "points" or "area" }
end
local startboxes = {}
-- Forward declarations for cached-fill-list helpers defined further down in the drawing section.
-- Needed because removeLastStartbox / clearAllStartboxes / drag handlers reference them from
-- this upper part of the file.
-- Forward declarations (defined further down); typed so the calls that sit
-- above the definitions are not read as calls on nil.
---@type fun(box: any): any
local ensureBoxFillList
---@type fun(box: any)
local invalidateBoxFill
---@type fun(box: any)
local freeBoxFillList
-- Forward decl: world radius needed for a constant on-screen pixel size at (wx, wz).
-- Used by DrawWorld for handles/arrows so they keep size while zooming. Defined alongside
-- getScreenMarker further down in the rendering section.
---@type fun(wx: number, wz: number, screenPx: number): number
local worldRadiusForScreenPx
local startboxMode = "polygon" -- "polygon" | "box" | "freedraw"
local drawingBox = false
local currentBoxVerts = {}
local boxDragIdx = nil -- which vertex is being dragged
local boxDragBoxIdx = nil -- which box
local boxEdgeDrag = nil -- { bi = <box index>, edge = "L"/"R"/"T"/"B" } for box-kind edge drag
local hoverBoxEdge = nil -- { bi, edge } for hover highlight of the edge currently under cursor
-- Anchor selected for curvature editing. Clicking a handle (press and release without
-- moving) selects it and raises a gizmo along its outward normal; dragging along that
-- gizmo sets the anchor strength between 0 and 1.
-- Curvature editing hangs off one table rather than a dozen file-level locals: the main
-- chunk of this widget sits on Lua's 200-local ceiling and each new one costs a slot.
-- selBox / selVert (the selected anchor: box index, vertex index) are assigned
-- below rather than listed here: a `= nil` in the constructor makes the
-- analyzer read them as never set.
local strengthEdit = {
	dragging = false,
	GIZMO_LEN = 240, -- world units from anchor to the strength-1 end of the gizmo
	scratch = {}, -- reused anchor ring, see buildRing
}
-- Whole-box drag (mouse pressed inside a startbox body, not on a handle/edge). Records the
-- world-space cursor delta between frames and offsets every vertex (and spline control point
-- when applicable). Separate from vertex-drag so hover hit-tests stay simple.
local boxBodyDrag = nil -- { bi = <box index>, lastX = <world x>, lastZ = <world z> }
-- Set true whenever a startbox vertex / edge / body drag is in progress. Used by
-- ensureBoxFillList to defer the expensive fill-list rebuild until MouseRelease.
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

-- Hover state (drives cursor + marker highlight)
local hoverPosIdx = nil -- index of position currently hovered (express mode)
local hoverBoxIdx = nil -- which startbox is being vertex-hovered
local hoverVertIdx = nil
-- Polygon edge-midpoint hover: shows a "ghost" handle at the middle of a polygon edge
-- so the user can click/hold there to insert a new vertex (which immediately becomes a
-- live drag handle). { bi, edgeIdx, x, z } — edgeIdx is index of the edge's start vertex.
local hoverPolyEdge = nil

-- Undo history: each entry = { count=N, prevNextAllyTeam=M }
-- Means: the last N entries in `positions` were added in one action;
-- restoring removes them and rewinds nextAllyTeam to M.
local undoHistory = {}
-- Startbox undo/redo. Entries carry the submode that produced them because start positions
-- and startboxes coexist: Ctrl+Z in one must not reach into the other's work. Startbox
-- entries snapshot just the box they touch, which avoids needing an inverse for every
-- operation (a vertex drag has none once insert and delete exist too). Functions are
-- assigned further down, after retessellateSpline is in scope.
local boxUndo = { redo = {} }
-- Override-modoption export. Libs are pulled in on first use rather than at include time:
-- this runs on a button press, and the widget is at Lua's file-local ceiling.
local boxExport = {}

-- Helper Functions

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
function R.color(box, bi)
	if R.validate().byRegion[box] then
		return R.INVALID
	end
	local team = box.team or (R.type == "start" and bi) or nil
	return team and getColorForAllyTeam(team) or R.COLOR
end

function R.nextColor()
	local team = (R.type == "start" and R.areaTarget()) or R.pending.team
	return team and getColorForAllyTeam(team) or R.COLOR
end

function R.list(typeKey)
	local out = R.api.All(typeKey)
	if typeKey == "start" then
		table.sort(out, function(a, b)
			return (a.team or 0) < (b.team or 0)
		end)
	end
	return out
end

function R.refresh()
	startboxes = R.list(R.type)
end

function R.start(team)
	for _, region in ipairs(R.api.All("start")) do
		if region.team == team then
			return region
		end
	end
	return nil
end

function R.viewIndexOf(region)
	for i, other in ipairs(startboxes) do
		if other == region then
			return i
		end
	end
	return nil
end

function R.add(box, at)
	box.type = box.type or R.type
	local before = at and startboxes[at]
	R.api.Put(box, before and before.id) -- the store gives it an id, unless it already has one
	R.refresh()
	return box
end

function R.removeAt(idx)
	local box = startboxes[idx]
	if not box then
		return nil
	end
	R.api.Remove(box.id)
	R.refresh()
	return box
end

-- The replacement takes the old region's place in the store: its id, and its position in the order.
function R.replaceAt(idx, box)
	local old = startboxes[idx]
	if not old then
		return nil
	end
	local all = R.api.All()
	local nextId = nil
	for i, region in ipairs(all) do
		if region == old then
			nextId = all[i + 1] and all[i + 1].id
		end
	end
	box.type = old.type
	box.id = old.id
	R.api.Remove(old.id)
	R.api.Put(box, nextId)
	R.refresh()
	return old
end

function R.clear(typeKey)
	for _, region in ipairs(R.api.Clear(typeKey)) do
		freeBoxFillList(region)
	end
	R.refresh()
end

function R.fieldDefs(typeKey)
	local kind = R.TYPES[typeKey or R.type]
	return kind and kind.fields or {}
end

function R.fieldValues(box)
	local out = {}
	for _, field in ipairs(R.fieldDefs(box.type)) do
		out[field.key] = box[field.key]
	end
	return out
end

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

-- Shape Position Generation

local function shapeParams()
	return { shape = shapeType, radius = shapeRadius, count = shapeCount, rotation = shapeRotation }
end

local function generateShapePositions(cx, cz)
	return StartPlacement.Shape(cx, cz, shapeParams(), Game.mapSizeX, Game.mapSizeZ)
end

local function generateRandomPositions(cx, cz)
	return StartPlacement.Random(cx, cz, shapeParams(), Game.mapSizeX, Game.mapSizeZ)
end

-- Core Operations

-- The slope a commander can spawn on, in the space Spring.GetGroundNormal reports it; start's to decide.
local commanderMaxSlope = nil
local function isPlaceableForCommander(x, z)
	commanderMaxSlope = commanderMaxSlope
		or StartPlacement.CommanderMaxSlope(UnitDefs, Spring.GetModOptions and Spring.GetModOptions() or nil)
	local _, _, _, slope = Spring.GetGroundNormal(x, z, false)
	return (slope or 0) <= commanderMaxSlope
end

local function addPosition(x, z, allyTeam, teamSlot)
	if #positions >= MAX_POSITIONS then
		return false
	end
	x, z = clampToMap(x, z)
	-- Reject commander-unspawnable spots (ground too steep for the commander's movedef).
	-- Transferable across Recoil games via customParams.iscommander on UnitDefs; override
	-- via modOption `startpos_max_slope`.
	if not isPlaceableForCommander(x, z) then
		Echo(
			"[Regions] Skipped: slope exceeds commander tolerance at (" .. math_floor(x) .. "," .. math_floor(z) .. ")"
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
	R.bump()
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
	R.bump()
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
	R.bump()
	positions = {}
	nextAllyTeam = 1
	nextTeamSlot = 1
	undoHistory = {}
end

-- Shape/random placement: always distribute evenly across all allyteam×teamSlot combinations
-- so a 4-ally × 2-team shape of 8 places yields one of each.
local function placeShapePositions(cx, cz)
	for i, pt in ipairs(generateShapePositions(cx, cz)) do
		addPosition(pt.x, pt.z, StartPlacement.SlotFor(i, numAllyTeams, numTeamsPerAlly, placementMode))
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
	for i, pt in ipairs(generateRandomPositions(cx, cz)) do
		addPosition(pt.x, pt.z, StartPlacement.SlotFor(i, numAllyTeams, numTeamsPerAlly, placementMode))
	end
end

-- Startbox Operations

local function addStartboxVertex(x, z)
	-- Honour the shared brush "instruments": when the grid-snap toggle is on,
	-- snap polygon vertices to the same world grid the shape/express placement
	-- paths use, so the Snap instrument actually affects startbox drawing.
	---@type table?
	local tb = WG.TerraformBrush
	local stb = tb and tb.getState and tb.getState() or nil
	if stb and stb.gridSnap and tb.snapWorld then
		x, z = tb.snapWorld(x, z, 0)
	end
	x, z = clampToMap(x, z)
	currentBoxVerts[#currentBoxVerts + 1] = { x = x, z = z }
end

-- Ally team is the box's position in the list, never a running counter: that is what the
-- modoption format means by order (box 1 is allyTeam 0) and it makes a delete impossible to
-- desync. One box per team falls out of it.
local function renumberBoxAllyTeams()
	for i, box in ipairs(R.list("start")) do
		box.allyTeam = i
		box.team = i
	end
	R.refresh()
end

function R.bump()
	R.revision = R.revision + 1
end

function R.pendingCandidate(vertices)
	local candidate = { type = R.type, vertices = vertices }
	for _, field in ipairs(R.fieldDefs()) do
		local value = R.pending[field.key]
		if value == "" then
			value = nil
		end
		candidate[field.key] = value
	end
	if R.type == "start" and candidate.team == nil then
		candidate.team = R.areaTarget()
	end
	return candidate
end

---@param box table a region already in the store
---@return integer idx its index in the layer
function R.stampNew(box)
	local candidate = R.pendingCandidate(box.vertices)
	for _, field in ipairs(R.fieldDefs()) do
		box[field.key] = candidate[field.key]
		-- The next region starts with a clear form, except what was picked from a list: the same team, usually.
		if not field.picks then
			R.pending[field.key] = nil
		end
	end
	box.tags = box.tags or {}
	if R.type == "start" then
		local existing = R.start(box.team)
		if existing and existing ~= box then
			freeBoxFillList(existing)
			R.api.Remove(existing.id)
		end
		box.allyTeam = box.team
		R.drawForTeam = nil
		R.selectedStart = box.team
	end
	R.error = ""
	renumberBoxAllyTeams()
	R.selectedIdx = R.viewIndexOf(box)
	R.newIdx = R.selectedIdx
	R.bump()
	return R.selectedIdx
end

---@param strength number|nil anchor strength for the new polygon; nil keeps a plain ring
local function finishStartbox(strength)
	if #currentBoxVerts >= 3 then
		local box = {}
		if strength ~= nil then
			box.kind = "spline"
			box.controls = {}
			for i, v in ipairs(currentBoxVerts) do
				box.controls[i] = { x = v.x, z = v.z, strength = strength }
			end
			box.vertices = {}
			R.tessellate(box)
		else
			box.vertices = currentBoxVerts
		end
		R.add(box)
		local idx = R.stampNew(box)
		boxUndo.push("add", idx, box)
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

-- Closed centripetal Catmull-Rom tessellation. Writes into `out` (reused when provided) and
-- truncates to the required length. Returning a fresh table each mousemove during drag was
-- the dominant source of GC pressure -> LuaRAM warnings on large freedraw splines.
-- The game tessellates startbox anchors through this same module, so a preview built with
-- it matches what the match will enforce vertex for vertex.
strengthEdit.spline = VFS.Include("common/lib_spline.lua")

-- Refresh tessellated vertices for a spline-kind startbox after its controls have changed.
-- Mutates box.vertices in place and only flags a *pending* fill rebuild — the actual fill
-- display list is regenerated on drag release (see isDraggingBox gate in ensureBoxFillList).
-- Anchor ring in the {x, z, strength} shape strengthEdit.spline wants. Reused across calls: a control
-- drag retessellates on every mousemove and this sits on that path.
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
R.tessellate = retessellateSpline

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

-- Strength 0 is stored as absent, which is what the schema and Rowy both write.
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
		R.removeAt(#startboxes)
		if R.selectedIdx and not startboxes[R.selectedIdx] then
			R.selectedIdx = nil
		end
		R.bump()
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
	for k in pairs(startboxes) do
		startboxes[k] = nil
	end
	R.selectedIdx = nil
	R.bump()
	-- Entries indexed into the list we just emptied are not reversible, so drop them rather
	-- than let Ctrl+Z act on stale positions. Clearing is not itself undoable.
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
	out.type = box.type
	out.id = box.id
	out.fields = R.fieldValues(box)
	if box.tags then
		out.tags = {}
		for k = 1, #box.tags do
			out.tags[k] = box.tags[k]
		end
	end
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
	box.type = snap.type
	box.id = snap.id
	for key, value in pairs(snap.fields or {}) do
		box[key] = value
	end
	if snap.tags then
		box.tags = {}
		for k = 1, #snap.tags do
			box.tags[k] = snap.tags[k]
		end
	end
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
		region = R.type,
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
	local edited = startboxes[pend.idx]
	if edited and R.api then
		local problems = R.api.Check(R.type, edited, startboxes, false)
		if problems[1] then
			freeBoxFillList(edited)
			startboxes[pend.idx] = boxUndo.build(pend.box)
			R.error = problems[1]
			R.bump()
			return
		end
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
			R.removeAt(entry.idx)
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
		R.add(boxUndo.build(entry.box), at)
	else
		mirror.box = boxUndo.snap(startboxes[entry.idx])
		if startboxes[entry.idx] then
			freeBoxFillList(startboxes[entry.idx])
			R.replaceAt(entry.idx, boxUndo.build(entry.box))
		end
	end
	renumberBoxAllyTeams()

	return mirror
end

function boxExport.encode()
	local arrangement = StartExport.Arrangement(R.list("start"), Game.mapSizeX, Game.mapSizeZ)
	if #arrangement == 0 then
		return nil
	end

	-- Json is a LuaUI global (luaui/system.lua). Including the module directly fails in this
	-- sandbox: it opens with `local base = _G`, and _G is not exposed here.
	if not Json then
		Echo("[Regions] Json unavailable; cannot encode.")
		return nil
	end
	boxExport.b64 = boxExport.b64 or VFS.Include("common/luaUtilities/base64.lua")
	local ok, raw = pcall(Json.encode, { startboxes = arrangement })
	if not ok or not raw then
		return nil
	end
	local packed = VFS.ZlibCompress(raw)
	if not packed then
		return nil
	end

	return (boxExport.b64.Encode(packed):gsub("=+$", "")), #arrangement
end

-- The value is only useful pasted into lobby chat, and the server truncates that, so the
-- length is reported alongside it rather than left for the user to discover.
local function copyStartboxOverride()
	local value, boxes = boxExport.encode()
	if not value then
		Echo("[Regions] No startboxes to copy.")
		return false
	end

	Spring.SetClipboard("!bSet mapmetadata_startbox_override " .. value)
	Echo(string.format("[Regions] Copied !bSet for %d startbox(es), %d chars of value.", boxes, #value))

	return true
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
			-- Only consider an edge if cursor is within the perpendicular span of that edge.
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
				-- Left/right edges only valid within Z span
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
				-- Top/bottom edges only valid within X span
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

-- Polygon-kind boxes (kind == nil or "polygon") expose an edge-midpoint "ghost" handle for
-- inserting a new vertex. Returns box index, edge index (= start-vertex index), and the
-- midpoint world coords; nil if no edge mid is within VERTEX_PICK_DIST_SQ of the cursor.
local function isPolygonKind(box)
	return box.kind == nil or box.kind == "polygon"
end

-- Returns the editable-handle list for a box (polygon: vertices; spline: controls). Nil for
-- "box"-kind axis-aligned rects (those use edge resize, not handle insertion).
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

-- Lifted out of DrawWorld: that function sits right on Lua's 60-upvalue ceiling, and the
-- gizmo's own references were enough to push it over.
-- The height the gizmo floats at. Shared with the hit test: if these ever computed it
-- separately, the knob would be pickable somewhere other than where it is drawn.
function strengthEdit.gizmoY(box, vi)
	local kx, kz, vx, vz, ux, uz = strengthEdit.knob(box, vi)
	if not kx then
		return nil
	end

	local ex, ez = vx + ux * strengthEdit.GIZMO_LEN, vz + uz * strengthEdit.GIZMO_LEN
	local gy = math_max(GetGroundHeight(vx, vz) or 0, GetGroundHeight(ex, ez) or 0)

	return math_max(gy, GetGroundHeight(kx, kz) or 0) + 48
end

-- Picked in screen space because the knob floats: tracing the cursor to the ground would
-- test against its shadow, which is not where it appears at any shallow camera angle.
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

-- Strength from where the cursor sits along the track as drawn. Projecting the ground
-- cursor onto the world axis instead would drift from the floating knob by the same offset
-- that made picking wrong.
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
	-- One height for the whole track, clear of the tallest ground beneath it, so the gizmo
	-- reads as a straight ruler instead of draping over whatever slope it crosses.
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

	-- Stem down to the anchor, so a track floating above uneven ground still reads as its.
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

-- Save / Load

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
	lines[#lines + 1] = "-- Generated by Regions Tool"
	lines[#lines + 1] = ""
	lines[#lines + 1] = "local startPositions = {"
	for i, pos in ipairs(positions) do
		lines[#lines + 1] = string.format(
			"  [%d] = { x = %d, z = %d, allyTeam = %d, teamSlot = %d },",
			i,
			math_floor(pos.x),
			math_floor(pos.z),
			pos.allyTeam,
			pos.teamSlot or 1
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
		Echo("[Regions] Saved start positions to: " .. filename)
		R.say("Saved start positions to " .. filename)
		return true
	else
		Echo("[Regions] ERROR: Could not write to: " .. filename)
		return false
	end
end

local function loadStartPositions(name, explicitPath)
	local filename = explicitPath or (SAVE_DIR .. (name or getMapName()) .. ".lua")
	local ok, data = pcall(function()
		return VFS.Include(filename, nil, VFS.RAW_FIRST)
	end)
	if ok and data then
		clearAllPositions() -- also clears undoHistory
		for i, pos in ipairs(data) do
			addPosition(pos.x, pos.z, pos.allyTeam or i, pos.teamSlot or 1)
		end
		undoHistory = {} -- load is a clean slate
		Echo("[Regions] Loaded start positions from: " .. filename)
		return true
	else
		Echo("[Regions] No saved config found: " .. filename)
		return false
	end
end

local function listSavedConfigs()
	local files = VFS.DirList(SAVE_DIR, "*.lua", VFS.RAW_FIRST)
	local names = {}
	for _, f in ipairs(files or {}) do
		local name = f:match("([^/\\]+)%.lua$")
		if name then
			names[#names + 1] = name
		end
	end
	return names
end

-- Start Script Generation

local STARTSCRIPT_SAVE_DIR = "Terraform Brush/StartScripts/"

---@param opts table|nil mapname, playerName, aiShortName, aiVersion, startpostype, modoptions
---@return string|nil script
local function generateStartScript(opts)
	opts = opts or {}
	local script = StartExport.StartScript(R.list("start"), Game.mapSizeX, Game.mapSizeZ, {
		mapName = opts.mapname or getMapName(),
		playerName = opts.playerName,
		aiShortName = opts.aiShortName,
		aiVersion = opts.aiVersion,
		startPosType = opts.startpostype,
		modOptions = opts.modoptions,
	})
	if not script then
		Echo("[Regions] No startboxes to export.")
	end
	return script
end

local function saveStartScript(name, opts)
	local script = generateStartScript(opts)
	if not script then
		return false
	end

	Spring.CreateDir(STARTSCRIPT_SAVE_DIR)
	local filename = STARTSCRIPT_SAVE_DIR .. (name or getMapName()) .. ".txt"

	local file = io.open(filename, "w")
	if file then
		file:write(script)
		file:close()
		Echo("[Regions] Saved start script to: " .. filename)
		return true
	else
		Echo("[Regions] ERROR: Could not write to: " .. filename)
		return false
	end
end

-- Activate / Deactivate / State

function R.geometriesFor(typeKey)
	local kind = R.TYPES[typeKey]
	local out = {}
	for _, g in ipairs(kind and kind.geometries or {}) do
		if g == "point" then
			out[#out + 1] = "point"
		elseif g == "polygon" then
			out[#out + 1] = "square"
			out[#out + 1] = "polygon"
			local finder = WG.resource_spot_finder
			if finder and finder.metalSpotsList and not finder.isMetalMap and #finder.metalSpotsList > 0 then
				out[#out + 1] = "mexes"
			end
		end
	end
	return out
end

function R.spotsInRadial()
	local finder = WG.resource_spot_finder
	local spots = finder and finder.metalSpotsList or {}
	local inside = {}
	local rad = R.radial
	if not rad then
		return inside
	end
	for _, spot in ipairs(spots) do
		if (spot.x - rad.cx) ^ 2 + (spot.z - rad.cz) ^ 2 <= rad.r * rad.r then
			inside[#inside + 1] = spot
		end
	end
	return inside
end

function R.selected(spot)
	for _, s in ipairs(R.radialPending) do
		if s == spot then
			return true
		end
	end
	return false
end

function R.nearestSpot(mx, my)
	local wx, wz = getWorldMousePosition()
	if not wx then
		return nil
	end
	local finder = WG.resource_spot_finder
	local best, bestD = nil, 90 * 90
	for _, spot in ipairs(finder and finder.metalSpotsList or {}) do
		local d = (spot.x - wx) ^ 2 + (spot.z - wz) ^ 2
		if d < bestD then
			best, bestD = spot, d
		end
	end
	return best
end

function R.gesture(spots, removing)
	local before = {}
	for i, s in ipairs(R.radialPending) do
		before[i] = s
	end
	local set = {}
	for _, s in ipairs(R.radialPending) do
		set[s] = true
	end
	for _, s in ipairs(spots) do
		set[s] = not removing or nil
	end
	local after = {}
	for _, s in ipairs(before) do
		if set[s] then
			after[#after + 1] = s
			set[s] = nil
		end
	end
	for _, s in ipairs(spots) do
		if set[s] then
			after[#after + 1] = s
			set[s] = nil
		end
	end
	if #after == #before then
		return
	end
	R.radialHistory[#R.radialHistory + 1] = before
	R.radialPending = after
	R.error = ""
	R.bump()
end

function R.ungesture()
	local before = table.remove(R.radialHistory)
	if not before then
		return false
	end
	R.radialPending = before
	R.bump()
	return true
end

function R.closeSelection()
	local gathered = R.radialPending
	if #gathered == 0 then
		return false
	end
	local hull = R.hullFor(gathered)
	if not hull then
		R.error = "no hull fits around those spots"
		R.bump()
		return false
	end
	for i, v in ipairs(hull) do
		local x, z = clampToMap(v.x, v.z)
		hull[i] = { x = x, z = z }
	end
	currentBoxVerts = hull
	drawingBox = true
	finishStartbox(1)
	R.radialPending = {}
	R.radialHistory = {}
	return true
end

-- The ring the Mexes tool closes around the picked spots: their hull, padded by an extractor's reach and a half.
function R.hullFor(points)
	return MexHull.Around(points, (Game.extractorRadius or 80) * 1.5)
end

function R.applyMode()
	local allowed = R.geometriesFor(R.type)
	local ok = false
	for _, g in ipairs(allowed) do
		ok = ok or g == R.geometry
	end
	if not ok then
		R.geometry = allowed[1] or "polygon"
	end
	R.refresh()
	if R.editMode == "select" then
		R.placing = (R.geometry == "point") and "points" or "area"
		subMode = "startbox"
		startboxMode = "polygon"
	elseif R.geometry == "point" then
		R.placing = "points"
		subMode = "express"
	else
		R.placing = "area"
		subMode = "startbox"
		startboxMode = (R.geometry == "square") and "box" or (R.geometry == "mexes") and "radial" or "polygon"
	end
	R.radial = nil
	R.radialPending = {}
	R.radialHistory = {}
	currentBoxVerts = {}
	drawingBox = false
	boxRectActive = false
	boxRectStartX, boxRectStartZ, boxRectEndX, boxRectEndZ = nil, nil, nil, nil
	freeDrawActive = false
	freeDrawPts = {}
	R.pendingVertex = nil
	strengthEdit.selBox, strengthEdit.selVert = nil, nil
	if R.selectedIdx and not startboxes[R.selectedIdx] then
		R.selectedIdx = nil
	end
	R.bump()
end

function R.setType(t)
	if R.TYPES[t] and t ~= R.type then
		R.type = t
		R.selectedIdx = nil
		R.error = ""
		R.applyMode()
	end
end

function R.setCategory(key)
	local cat = R.CATEGORIES[key]
	if not cat then
		return
	end
	R.category = key
	if cat.type ~= R.type then
		R.selectedIdx = nil
		R.error = ""
		R.drawForTeam = nil
		R.geometry = R.geometriesFor(cat.type)[1] or "polygon"
	end
	R.type = cat.type
	if R.type ~= "start" and R.pending.team == nil and R.selectedStart then
		R.pending.team = R.selectedStart
	end
	R.applyMode()
end

function R.setEditMode(mode)
	if mode == "select" or mode == "create" then
		R.editMode = mode
		R.applyMode()
	end
end

function R.setGeometry(g)
	if g == "point" or g == "square" or g == "polygon" or g == "mexes" then
		R.geometry = g
		R.applyMode()
	end
end

function R.drawArea(allyTeam)
	if R.type ~= "start" or not allyTeam then
		return false
	end
	R.error = ""
	R.drawForTeam = allyTeam
	R.selectedStart = allyTeam
	if R.geometry == "point" then
		R.geometry = "polygon"
	end
	R.applyMode()
	return true
end

function R.cancelArea()
	R.drawForTeam = nil
	R.bump()
end

function R.areaTarget()
	local n = 0
	for _, box in ipairs(R.list("start")) do
		if box.team then
			n = n + 1
		end
	end
	if R.drawForTeam then
		return math.min(R.drawForTeam, n + 1)
	end
	if R.pending.team then
		return math.min(R.pending.team, n + 1)
	end
	if R.selectedStart and not R.start(R.selectedStart) and R.selectedStart <= n + 1 then
		return R.selectedStart
	end
	return n + 1
end

function R.removeArea(allyTeam)
	if R.type ~= "start" or not R.start(allyTeam) then
		return false
	end
	local ok = R.remove(allyTeam)
	R.selectedStart = allyTeam
	R.bump()
	return ok
end

function R.setStrategy(st)
	if st == "express" or st == "shape" then
		R.strategy = st
		R.applyMode()
	end
end

function R.setPlacing(pl)
	if pl == "points" or pl == "area" then
		R.placing = pl
		R.applyMode()
	end
end

function R.seedMexRegions()
	if #R.list("mex_region") > 0 then
		return
	end
	-- The match's deal holds only the outline the game plays with, every point along every curve: the fallback for a
	-- layout that came from somewhere other than this tool's own file.
	local okDeal, Deal = pcall(VFS.Include, "modules/transfer/mex_splitting/deal.lua")
	local deal = okDeal and type(Deal) == "table" and Deal.Reader()(Spring) or nil
	if deal and deal.regions and #deal.regions > 0 then
		for _, region in ipairs(deal.regions) do
			local vertices = {}
			for i, v in ipairs(region.vertices) do
				vertices[i] = { x = v.x, z = v.z }
			end
			R.add({
				type = "mex_region",
				id = region.id,
				name = region.name,
				team = region.team,
				group = region.group,
				kind = "polygon",
				vertices = vertices,
				tags = {},
			})
		end
		Echo("[Regions] Opened on the match's " .. #deal.regions .. " mex region(s)")
	end
end

function R.seedFromMatch()
	if not R.seeded and #R.api.All() == 0 then
		-- The map maker's own file first: it holds every type, with the anchors they drew.
		R.load()
	end
	R.seedMexRegions()
	if R.seeded or #R.list("start") > 0 or #positions > 0 then
		return
	end
	R.seeded = true
	local ok, Start = pcall(VFS.Include, "modules/start/api.lua")
	if not ok or type(Start) ~= "table" then
		return
	end
	local current = Start.Current(Spring)
	for _, area in ipairs(current.areas) do
		local curved = false
		for _, a in ipairs(area.anchors) do
			curved = curved or (a.strength ~= nil and a.strength > 0)
		end
		local box = { type = "start", allyTeam = area.allyTeam, team = area.allyTeam, name = area.name, tags = {} }
		if curved then
			box.kind = "spline"
			box.controls = area.anchors
			box.vertices = {}
			retessellateSpline(box)
		else
			box.kind = "polygon"
			box.vertices = area.anchors
		end
		R.add(box)
	end
	renumberBoxAllyTeams()
	local slots = {}
	for _, pos in ipairs(current.positions) do
		slots[pos.allyTeam] = (slots[pos.allyTeam] or 0) + 1
		addPosition(pos.x, pos.z, pos.allyTeam, slots[pos.allyTeam])
	end
	if #current.areas > 0 or #current.positions > 0 then
		Echo(
			"[Regions] Opened on the match's starts: "
				.. #current.areas
				.. " area(s), "
				.. #current.positions
				.. " position(s)"
		)
	end
	R.bump()
end

local function activate(mode)
	active = true
	if mode == "express" or mode == "shape" then
		R.strategy = mode
	end
	R.seedFromMatch()
	R.applyMode()
	Echo("[Regions] Activated: " .. R.TYPES[R.type].label:upper() .. " / " .. R.strategy:upper())
end

local function deactivate()
	if active then
		Echo("[Regions] Deactivated")
	end
	active = false
	dragging = false
	dragIdx = nil
	drawingBox = false
end

local function setSubMode(mode)
	if mode == "express" or mode == "shape" then
		R.strategy = mode
		if R.type == "start" then
			R.placing = "points"
		end
		R.applyMode()
	elseif mode == "startbox" then
		R.type = "start"
		R.placing = "area"
		R.applyMode()
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
		if n < 3 then
			return out
		end
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

function R.select(idx)
	if idx == nil or startboxes[idx] then
		R.selectedIdx = idx
		if R.type == "start" then
			R.selectedStart = idx and startboxes[idx] and startboxes[idx].allyTeam or nil
		end
		R.bump()
	end
end

function R.selectStart(allyTeam)
	R.selectedStart = allyTeam
	R.selectedIdx = allyTeam and R.start(allyTeam) and allyTeam or nil
	R.bump()
end

function R.starts()
	local count = #R.list("start")
	local perTeam = {}
	for _, pos in ipairs(positions) do
		perTeam[pos.allyTeam] = (perTeam[pos.allyTeam] or 0) + 1
		if pos.allyTeam > count then
			count = pos.allyTeam
		end
	end
	local out = {}
	for allyTeam = 1, count do
		local box = R.start(allyTeam)
		out[allyTeam] = {
			allyTeam = allyTeam,
			positions = perTeam[allyTeam] or 0,
			hasBox = box ~= nil,
			name = box and box.name or nil,
			tags = box and box.tags or nil,
		}
	end
	return out
end

function R.startFacts(allyTeam)
	local box = R.start(allyTeam)
	local facts = box and R.facts(box) or {}
	local count, cx, cz = 0, 0, 0
	for _, pos in ipairs(positions) do
		if pos.allyTeam == allyTeam then
			count = count + 1
			cx, cz = cx + pos.x, cz + pos.z
		end
	end
	if not box then
		facts[#facts + 1] = { "Area", "none drawn" }
		if count > 0 then
			facts[#facts + 1] = { "Positions centre", string.format("%d, %d", cx / count, cz / count) }
		end
	end
	facts[#facts + 1] = { "Positions", tostring(count) }
	return facts
end

function R.setPendingField(key, value)
	for _, field in ipairs(R.fieldDefs()) do
		if field.key == key then
			if value == nil or value == "" then
				R.pending[key] = nil
			elseif field.kind == "integer" then
				R.pending[key] = tonumber(value)
			else
				R.pending[key] = value
			end
			R.error = ""
			R.bump()
			return true
		end
	end
	return false
end

function R.teamLabel(team)
	local start = team and R.start(team)
	return (start and start.name) or (team and ("Team " .. team)) or nil
end

function R.teamOptions()
	local out = {}
	for _, start in ipairs(R.starts()) do
		out[#out + 1] = { team = start.allyTeam, label = R.teamLabel(start.allyTeam) }
	end
	return out
end

function R.setField(key, value)
	local box = R.selectedIdx and startboxes[R.selectedIdx]
	local kind = R.TYPES[R.type]
	if not box or not kind then
		return false
	end
	local declared = nil
	for _, field in ipairs(kind.fields) do
		if field.key == key then
			declared = field
		end
	end
	if not declared then
		return false
	end
	value = value or ""
	if declared.kind == "integer" and value ~= "" then
		-- The one edit refused here: a number field is what the tool itself indexes by. Everything else the
		-- set validation reports on the region's row.
		if tonumber(value) == nil then
			R.error = declared.label .. " must be a number"
			R.bump()
			return false
		end
		value = tonumber(value)
	end
	box[key] = value ~= "" and value or nil
	R.error = ""
	R.bump()
	return true
end

function R.addTag(tag)
	local box = R.selectedIdx and startboxes[R.selectedIdx]
	tag = tag and tag:match("^%s*(.-)%s*$") or ""
	if not box or tag == "" then
		if R.type == "start" and R.selectedStart and not box then
			R.error = "draw this start's area first; tags live on it"
			R.bump()
		end
		return false
	end
	box.tags = box.tags or {}
	for _, existing in ipairs(box.tags) do
		if existing == tag then
			return false
		end
	end
	box.tags[#box.tags + 1] = tag
	R.bump()
	return true
end

function R.removeTag(index)
	local box = R.selectedIdx and startboxes[R.selectedIdx]
	if box and box.tags and box.tags[index] then
		table.remove(box.tags, index)
		R.bump()
		return true
	end
	return false
end

function R.remove(idx)
	local box = startboxes[idx]
	if not box then
		return false
	end
	boxUndo.push("remove", idx, box)
	freeBoxFillList(box)
	R.removeAt(idx)
	if R.type == "start" then
		renumberBoxAllyTeams()
	end
	R.selectedIdx = nil
	R.bump()
	return true
end

function R.factsFor(key, compute)
	if R.factsKey ~= key then
		R.factsKey = key
		R.factsValue = compute()
	end
	return R.factsValue
end

function R.startPositions()
	local starts = {}
	for _, pos in ipairs(positions) do
		starts[#starts + 1] = { allyTeam = pos.allyTeam, x = pos.x, z = pos.z }
	end
	return starts
end

function R.names()
	return R.api.Names(R.type, startboxes)
end

function R.facts(box)
	local verts = box.vertices or {}
	if #verts < 3 then
		return {}
	end
	local finder = WG.resource_spot_finder
	local spots = finder and not finder.isMetalMap and finder.metalSpotsList or nil
	local starts = R.startPositions()
	local candidate = R.fieldValues(box)
	candidate.type = box.type or R.type
	candidate.vertices = verts
	local lines = { { "Vertices", tostring(#verts) } }
	for _, line in ipairs(R.api.Describe(candidate, { spots = spots, starts = starts })) do
		lines[#lines + 1] = line
	end
	return lines
end

function R.suggestions()
	local out = {}
	for _, field in ipairs(R.fieldDefs()) do
		if field.suggest then
			local seen, values = {}, {}
			for _, region in ipairs(startboxes) do
				local value = region[field.key]
				if value ~= nil and not seen[value] then
					seen[value] = true
					values[#values + 1] = value
				end
			end
			table.sort(values)
			out[field.key] = values
		end
	end
	return out
end

-- What the regions module and the types' owners find wrong with each type's set of regions: one call per type over the
-- whole set as it stands, kept until the set changes. lines: every problem, printable; byRegion: a region's own
-- messages, for its row, its details and its outline; ofSet: the messages about a type's set as a whole.
R.INVALID = { 1.0, 0.25, 0.55, 1.0 }
R.validated = { revision = -1, positions = -1, count = -1, lines = {}, byRegion = {}, ofSet = {} }
function R.validate()
	local was = R.validated
	if was.revision == R.revision and was.positions == #positions and was.count == R.api.Revision() then
		return was
	end
	local finder = WG.resource_spot_finder
	local env = {
		spots = finder and not finder.isMetalMap and finder.metalSpotsList or nil,
		starts = R.startPositions(),
	}
	local lines, byRegion, ofSet = {}, {}, {}
	for _, typeKey in ipairs(R.ORDER) do
		local regions = R.list(typeKey)
		if #regions > 0 then
			for _, problem in ipairs(R.api.Problems(typeKey, env)) do
				lines[#lines + 1] = R.api.ProblemLine(problem)
				local region = problem.region
				if region then
					byRegion[region] = byRegion[region] or {}
					table.insert(byRegion[region], problem.message)
				else
					ofSet[typeKey] = ofSet[typeKey] or {}
					table.insert(ofSet[typeKey], { message = problem.message, at = problem.at })
				end
			end
		end
	end
	R.validated = {
		revision = R.revision,
		positions = #positions,
		count = R.api.Revision(),
		lines = lines,
		byRegion = byRegion,
		ofSet = ofSet,
	}
	return R.validated
end

-- Take the camera to where a problem of the set says to look.
-- Good news for the panel, shown until the regions next change.
function R.say(text)
	R.notice = { text = text, revision = R.revision }
end

function R.lookAt(x, z)
	if x and z then
		Spring.SetCameraTarget(x, Spring.GetGroundHeight(x, z) or 0, z, 0.6)
	end
end

function R.problemsState()
	local validated = R.validate()
	local byIndex, byTeam = {}, {}
	for i, region in ipairs(startboxes) do
		byIndex[i] = validated.byRegion[region]
		if region.team then
			byTeam[region.team] = validated.byRegion[region]
		end
	end
	return { ofSet = validated.ofSet[R.type] or {}, byIndex = byIndex, byTeam = byTeam }
end

function R.exportLayout()
	return R.api.ExportLayout(R.api.All(), Game.mapSizeX, Game.mapSizeZ)
end

function R.encodeLayout()
	if #R.api.All() == 0 then
		return nil
	end
	return R.api.EncodeLayout(R.exportLayout())
end

function R.copyLayout()
	local problems = R.validate().lines
	if problems[1] then
		for _, problem in ipairs(problems) do
			Echo("[Regions] " .. problem)
		end
		R.error = problems[1]
		R.bump()
		return false
	end
	local blob = R.encodeLayout()
	if not blob then
		R.error = "no regions to copy"
		R.bump()
		return false
	end
	Spring.SetClipboard(blob)
	R.error = ""
	R.bump()
	R.say("Layout copied to the clipboard")
	Echo("[Regions] Layout copied: paste it as the mex_regions_layout modoption")
	return true
end

function R.save(explicitPath)
	local count = #R.api.All()
	if count == 0 then
		Echo("[Regions] No regions to save.")
		return false, "no regions drawn"
	end
	if not explicitPath then
		Spring.CreateDir(REGIONS_SAVE_DIR)
		explicitPath = REGIONS_SAVE_DIR .. getMapName() .. ".lua"
	end
	local ok, reason = R.api.SaveEditorFile(explicitPath, getMapName())
	if not ok then
		Echo("[Regions] ERROR: " .. tostring(reason))
		return false, reason
	end
	Echo("[Regions] Saved regions to: " .. explicitPath)
	local problems = R.validate().lines
	for _, problem in ipairs(problems) do
		Echo("[Regions] Saved with a problem: " .. problem)
	end
	R.say(
		"Saved "
			.. count
			.. " region"
			.. (count == 1 and "" or "s")
			.. " to "
			.. explicitPath
			.. (
				#problems > 0
					and (", with " .. #problems .. " problem" .. (#problems == 1 and "" or "s") .. " still to fix")
				or ""
			)
	)
	return true
end

function R.load(explicitPath)
	explicitPath = explicitPath or (REGIONS_SAVE_DIR .. getMapName() .. ".lua")
	for _, region in ipairs(R.api.All()) do
		freeBoxFillList(region)
	end
	local regions, reason = R.api.LoadEditorFile(explicitPath)
	if not regions then
		Echo("[Regions] No saved regions found: " .. explicitPath .. (reason and (" (" .. reason .. ")") or ""))
		return false
	end
	for _, region in ipairs(regions) do
		region._fillNeedsRebuild = true
	end
	renumberBoxAllyTeams()
	R.refresh()
	R.selectedIdx = nil
	R.bump()
	Echo("[Regions] Loaded " .. #regions .. " region(s) from: " .. explicitPath)
	return true
end

function R.selectedRecord()
	if R.type == "start" and R.selectedStart then
		local box = R.start(R.selectedStart)
		return {
			idx = R.selectedIdx,
			type = R.type,
			team = R.selectedStart,
			hasBox = box ~= nil,
			fields = box and R.fieldValues(box) or { team = R.selectedStart },
			tags = box and box.tags or {},
			vertexCount = box and #box.vertices or 0,
			facts = R.factsFor("start:" .. R.selectedStart .. ":" .. R.revision .. ":" .. #positions, function()
				return R.startFacts(R.selectedStart)
			end),
		}
	end
	local box = R.selectedIdx and startboxes[R.selectedIdx]
	if not box then
		return nil
	end
	local named = R.names()[R.selectedIdx]
	return {
		idx = R.selectedIdx,
		type = R.type,
		team = box.team,
		hasBox = true,
		fields = R.fieldValues(box),
		derived = named and named.derived and { name = named.name } or nil,
		problems = R.validate().byRegion[box] or {},
		tags = box.tags or {},
		vertexCount = #box.vertices,
		facts = R.factsFor(R.type .. ":" .. R.selectedIdx .. ":" .. R.revision, function()
			return R.facts(box)
		end),
	}
end

local function getState()
	-- Startbox submode derives its ally-team count from the boxes drawn; the panel disables
	-- the slider there and shows it as dynamic, so reporting the stale slider value would lie.
	local allyCount = numAllyTeams
	local startCount = #R.list("start")
	if R.type == "start" and R.placing == "area" and startCount > 0 then
		allyCount = startCount
	end

	return {
		active = active,
		subMode = subMode,
		positions = positions,
		numAllyTeams = allyCount,
		numTeamsPerAlly = numTeamsPerAlly,
		nextAllyTeam = nextAllyTeam,
		nextTeamSlot = nextTeamSlot,
		placementMode = placementMode,
		totalPlayers = allyCount * numTeamsPerAlly,
		maxAllyTeams = MAX_ALLYTEAMS,
		maxTeamsPerAlly = MAX_TEAMS_PER_ALLY,
		maxPositions = MAX_POSITIONS,
		shapeType = shapeType,
		shapeRadius = shapeRadius,
		shapeRotation = shapeRotation,
		shapeCount = shapeCount,
		startboxes = startboxes,
		startboxMode = startboxMode,
		regionType = R.type,
		category = R.category,
		drawForTeam = R.drawForTeam,
		geometry = R.geometry,
		editMode = R.editMode,
		gatheredSpots = #R.radialPending,
		geometries = R.geometriesFor(R.type),
		areaTarget = R.type == "start" and R.placing == "area" and R.areaTarget() or nil,
		categories = R.CATEGORY_ORDER,
		categoryLabels = R.CATEGORIES,
		regionTypes = R.ORDER,
		regionTypeLabels = R.TYPES,
		strategy = R.strategy,
		placing = R.placing,
		regions = startboxes,
		names = R.names(),
		problems = R.problemsState(),
		selectedIdx = R.selectedIdx,
		selectedStart = R.selectedStart,
		starts = R.type == "start" and R.starts() or nil,
		selected = R.selectedRecord(),
		regionFields = R.fieldDefs(),
		pendingRegion = R.pending,
		teamOptions = R.teamOptions(),
		suggestions = R.suggestions(),
		regionError = R.error,
		regionNotice = (R.notice and R.notice.revision == R.revision) and R.notice.text or "",
		regionRevision = R.revision,
		drawingBox = drawingBox,
		currentBoxVerts = currentBoxVerts,
		boxRectActive = boxRectActive,
		freeDrawActive = freeDrawActive,
	}
end

-- Mouse Handlers

function widget:MousePress(mx, my, button)
	if not active then
		return false
	end

	-- Defer to measure tool when active
	do
		---@type table?
		local tb = WG.TerraformBrush
		local stb = tb and tb.getState and tb.getState() or nil
		if stb and stb.measureActive then
			return false
		end
		-- Defer to symmetry origin drag so terraform can grab the drag
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

	if button == 3 and drawingBox then
		if #currentBoxVerts >= 3 then
			finishStartbox(0)
		else
			currentBoxVerts = {}
			drawingBox = false
		end
		return true
	end

	if subMode == "express" then
		if button == 1 then
			do
				local nearIdx = findNearestPosition(wx, wz)
				local containBi = (not nearIdx) and findBoxContaining(wx, wz) or nil
				local team = (nearIdx and positions[nearIdx].allyTeam) or containBi
				if team and team ~= R.selectedStart then
					R.selectStart(team)
				end
			end
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
				---@type table?
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
						mode = subMode,
						count = added,
						prevNextAllyTeam = prevNext,
						prevNextTeamSlot = prevNextSlot,
					}
				end
			end
			return true
		elseif button == 3 then
			-- RMB: Undo last placement (remove most recently placed player/shape-batch).
			-- The history is shared with the startbox editor and its entries carry no
			-- count, so take the newest POSITION entry rather than the newest entry:
			-- after drawing boxes the top of the stack is a box edit, and rewinding by
			-- its missing count crashed the widget.
			local at
			for i = #undoHistory, 1, -1 do
				if (undoHistory[i].mode or "express") ~= "startbox" then
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
			-- LMB: Place positions using current shape at click location
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
			-- RMB: Remove nearest
			removeNearestPosition(wx, wz)
			return true
		end
	elseif subMode == "startbox" then
		if button == 1 then
			-- Strength gizmo of the selected anchor wins over vertex picking: it is deliberately
			-- placed outside the box so it cannot collide with anything else worth grabbing.
			if strengthEdit.selBox and strengthEdit.selVert and startboxes[strengthEdit.selBox] then
				if strengthEdit.knobHit(startboxes[strengthEdit.selBox], strengthEdit.selVert, mx, my) then
					boxUndo.begin(strengthEdit.selBox)
					strengthEdit.dragging = true
					return true
				end
			end

			-- Check for vertex drag first (polygon/freedraw boxes — placed boxes are always editable)
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
			-- Polygon edge-midpoint: clicking the ghost handle inserts a new vertex on that edge
			-- and immediately starts dragging it, so the user can place it where they want.
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
			-- Edge drag for axis-aligned "box"-kind startboxes (4 corners, no vertex handles).
			local ebi, edge = findNearestBoxEdge(wx, wz)
			if ebi and edge then
				boxEdgeDrag = { bi = ebi, edge = edge }
				dragStartX = mx
				dragStartY = my
				dragging = false
				return true
			end

			if R.editMode == "select" and R.type == "start" then
				local nearIdx = findNearestPosition(wx, wz)
				if nearIdx then
					R.selectStart(positions[nearIdx].allyTeam)
					dragIdx = nearIdx
					dragStartX = mx
					dragStartY = my
					dragging = false
					return true
				end
			end

			-- Body drag: if the click is inside an existing startbox (and not on any handle/edge
			-- per the checks above), start a whole-box translation so the user can reposition
			-- the entire polygon by grabbing it mid-area.
			local containBi = findBoxContaining(wx, wz)
			if containBi and R.editMode == "create" then
				R.selectedIdx = containBi
				if R.type == "start" then
					R.selectedStart = startboxes[containBi].allyTeam
				end
				R.bump()
			elseif containBi then
				R.selectedIdx = containBi
				if R.type == "start" then
					R.selectedStart = startboxes[containBi].allyTeam
				end
				R.bump()
				boxBodyDrag = { bi = containBi, lastX = wx, lastZ = wz }
				dragStartX = mx
				dragStartY = my
				dragging = false
				return true
			end

			if R.editMode == "select" then
				return true
			end
			if
				R.type ~= "start"
				and R.selectedIdx ~= nil
				and (startboxMode == "radial" or startboxMode == "polygon")
			then
				R.select(nil)
			end
			if startboxMode == "radial" then
				R.radial = { cx = wx, cz = wz, r = 0 }
				dragStartX, dragStartY = mx, my
				return true
			end
			if startboxMode == "box" then
				-- Drag rectangle: press to start, release to finish (like copy tool's box)
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
				-- Start a free-hand path; points appended during MouseMove
				freeDrawActive = true
				freeDrawPts = { { x = wx, z = wz } }
				dragStartX, dragStartY = mx, my
				return true
			else
				R.pendingVertex = { wx = wx, wz = wz, mx = mx, my = my }
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
			if #R.radialPending > 0 then
				R.closeSelection()
				return true
			end
			-- RMB: Finish current polygon OR cancel drag-rect / free-draw, else remove last placed box
			if startboxMode == "polygon" and drawingBox and #currentBoxVerts >= 3 then
				finishStartbox(0)
			elseif startboxMode == "polygon" and drawingBox then
				currentBoxVerts = {}
				drawingBox = false
			elseif boxRectActive then
				boxRectActive = false
				boxRectStartX, boxRectStartZ, boxRectEndX, boxRectEndZ = nil, nil, nil, nil
			elseif freeDrawActive then
				freeDrawActive = false
				freeDrawPts = {}
			elseif R.editMode == "create" then
				removeLastStartbox()
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
		-- No ground trace here on purpose: the knob floats, so a cursor over sky is still a
		-- legitimate drag position.
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

	if dragIdx then
		local moved = (mx - dragStartX) ^ 2 + (my - dragStartY) ^ 2
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
					-- Axis-aligned corner drag: move the dragged corner, then propagate its X/Z
					-- to its two neighbours so all 4 corners stay rectilinear (CCW order:
					-- 1=(minX,minZ), 2=(maxX,minZ), 3=(maxX,maxZ), 4=(minX,maxZ)).
					local cx, cz = clampToMap(wx, wz)
					local i = boxDragIdx
					-- Determine the diagonally-opposite corner (kept fixed) and enforce a
					-- minimum size so the rect can't collapse / invert during the drag.
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

	-- Startbox: whole-box body drag (translate every vertex + spline control by world delta).
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
				-- Clamp the delta against the union bbox of vertices+controls so the whole shape
				-- "docks" against the map edge instead of compressing (per-vertex clampToMap was
				-- crushing corners that crossed the boundary). This keeps the box rigid at edges.
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
				-- Recompute current bounds
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

	-- Startbox: freedraw sample accumulation
	if subMode == "startbox" and R.radial and button == 1 then
		local wx, wz = getWorldMousePosition()
		if wx then
			R.radial.r = math.sqrt((wx - R.radial.cx) ^ 2 + (wz - R.radial.cz) ^ 2)
		end
		return true
	end

	if subMode == "startbox" and R.pendingVertex and button == 1 then
		local pv = R.pendingVertex
		local ddx, ddy = mx - pv.mx, my - pv.my
		if ddx * ddx + ddy * ddy > 64 then
			R.pendingVertex = nil
			if not drawingBox then
				freeDrawActive = true
				freeDrawPts = { { x = pv.wx, z = pv.wz } }
			else
				addStartboxVertex(pv.wx, pv.wz)
			end
		end
		return true
	end

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

	if dragIdx then
		dragIdx = nil
		dragging = false
		return true
	end

	if strengthEdit.dragging then
		strengthEdit.dragging = false
		boxUndo.commit()
		return true
	end

	-- Consolidated release for all startbox drag kinds (vertex / edge / body). Trigger the
	-- deferred fill-list rebuild here so the translucent fill catches up after the user
	-- lets go. During the drag itself ensureBoxFillList returned the stale list to avoid
	-- O(N^2) rebuilds per mousemove.
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
				if added then
					added.kind = "box"
				end
			end
		end
		boxRectStartX, boxRectStartZ, boxRectEndX, boxRectEndZ = nil, nil, nil, nil
		return true
	end

	-- Startbox: finish freedraw on release — smooth via Chaikin, decimate, fit to spline
	if subMode == "startbox" and R.radial and button == 1 then
		local inside = R.spotsInRadial()
		local clicked = R.radial.r < 24
		R.radial = nil
		local _, _, _, shift = Spring.GetModKeyState()
		local alt = select(1, Spring.GetModKeyState())
		local removing = alt == true
		if clicked then
			inside = { R.nearestSpot(mx, my) }
			if not inside[1] then
				return true
			end
			removing = R.selected(inside[1])
		end
		R.gesture(inside, removing)
		return true
	end

	if subMode == "startbox" and R.pendingVertex and button == 1 then
		local pv = R.pendingVertex
		R.pendingVertex = nil
		if not drawingBox then
			drawingBox = true
			currentBoxVerts = {}
		end
		addStartboxVertex(pv.wx, pv.wz)
		return true
	end

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
					perim = perim + math_sqrt(dx * dx + dz * dz)
				end
				local targetCtrls = math_floor(perim / 400 + 0.5)
				if targetCtrls < 6 then
					targetCtrls = 6
				end
				if targetCtrls > 24 then
					targetCtrls = 24
				end
				-- Fit a minimal set of control points from the smoothed trace, then store as
				-- a spline-kind box so the user can reshape via curve handles (not raw verts).
				local controls = fitControlPoints(smoothed, targetCtrls)
				-- A drawn outline is smooth by intent, so every fitted handle starts fully curved.
				-- Sharpening individual corners afterwards is what the strength gizmo is for.
				for _, c in ipairs(controls) do
					c.strength = 1
				end
				local box = R.add({ vertices = {}, controls = controls, kind = "spline" })
				local idx = R.stampNew(box)
				retessellateSpline(box)
				boxUndo.push("add", idx, box)
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

	local altHeld, ctrlHeld, _, shiftHeld = Spring.GetModKeyState()

	if subMode == "shape" or subMode == "express" then
		if altHeld then
			-- Alt+Scroll: rotate shape (snap to TB protractor step when angleSnap on)
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
			-- Ctrl+Scroll: resize shape
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
	if key == 27 and (drawingBox or boxRectActive or freeDrawActive or R.drawForTeam) then
		currentBoxVerts = {}
		drawingBox = false
		boxRectActive = false
		boxRectStartX, boxRectStartZ, boxRectEndX, boxRectEndZ = nil, nil, nil, nil
		freeDrawActive = false
		freeDrawPts = {}
		R.radialPending = {}
		R.radialHistory = {}
		return true
	end
	if key == 122 and mods.ctrl and not mods.shift and #R.radialHistory > 0 then
		R.ungesture()
		return true
	end
	-- Ctrl+Z: undo last placement
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

	-- Ctrl+Z undoes, Ctrl+Shift+Z redoes: the editor's convention (the clone tool and the
	-- terraform brush bind redo the same way). Only entries from the current submode are
	-- eligible: positions and startboxes coexist, so undoing in one submode must not
	-- silently rewind the other.
	if key == 122 and mods.ctrl then -- 122 = 'z'
		local isUndo = not mods.shift
		local fromStack = isUndo and undoHistory or boxUndo.redo
		local toStack = isUndo and boxUndo.redo or undoHistory
		local at
		for i = #fromStack, 1, -1 do
			if (fromStack[i].mode or "express") == subMode and (fromStack[i].region or "start") == R.type then
				at = i
				break
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
		else
			-- Positions rewind by count, the way they always have; the counter pair is
			-- restored from the snapshot rather than guessed at.
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

-- Drawing

-- Draw a polygon-fan disc (soft filled circle) on the ground using a vertical cylinder approximation.
-- We fake a ground-glow by stacking multiple DrawGroundCircle calls with decreasing alpha.
local function drawSoftDisc(px, pz, radius, r, g, b, coreAlpha, segments)
	segments = segments or 28
	-- 5 concentric filled rings — fake gradient glow
	for i = 1, 5 do
		local t = i / 5
		local rr = radius * t
		local a = coreAlpha * (1 - t * 0.7)
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
	if n < 3 then
		return nil
	end
	local cx, cz = 0, 0
	for i = 1, n do
		cx = cx + verts[i].x
		cz = cz + verts[i].z
	end
	cx, cz = cx / n, cz / n
	local MAX_STEPS = math_max(6, math.min(48, math_floor(math_sqrt(40000 / n))))
	local longest = 0
	for i = 1, n do
		local a1 = verts[i]
		local b1 = verts[(i % n) + 1]
		longest = math_max(
			longest,
			math_sqrt((b1.x - a1.x) ^ 2 + (b1.z - a1.z) ^ 2),
			math_sqrt((a1.x - cx) ^ 2 + (a1.z - cz) ^ 2)
		)
	end
	cellSize = math_max(cellSize, longest / MAX_STEPS)
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

-- Ensures box has a current fill display list; rebuilds only when marked dirty.
local BOX_FILL_CELL = 20 -- world units per tessellation cell (lower = higher fidelity)
local BOX_FILL_LIFT = 2
local BOX_FILL_DRAG_INTERVAL = 4 -- during drag, rebuild list at most every Nth draw frame
ensureBoxFillList = function(box)
	if box._fillList and not box._fillDirty then
		return box._fillList
	end
	-- During drag, large polygon/spline shapes (>12 verts) defer the expensive triangulation
	-- to MouseRelease — buildPolygonFillList does O(N^2) fan subdivision that can burn thousands
	-- of allocs per frame on a freedraw spline. Small shapes (boxes — 4 verts — and simple polys)
	-- rebuild every frame so the fill follows the drag in real time. We also coarsen the cell
	-- size during drag so even mid-size polys stay responsive.
	local verts = box.vertices
	local nv = verts and #verts or 0
	if isDraggingBox and box._fillList then
		if nv > 12 then
			return box._fillList
		end
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

-- Draw N evenly-spaced arcs (gaps between them) around a circle — animated rotating "landing ring".
-- Rendered as thick curved ribbons (triangle-strip bands between inner/outer radii) so they read
-- like chunky indicator segments rather than a thin stroke.
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

-- Vertical beam-of-light going up from the start position.
-- Drawn as stacked world-space line segments with decreasing alpha.
local function drawBeam(px, pz, r, g, b, alphaBase, pulseT)
	local gy = GetGroundHeight(px, pz) or 0
	local steps = 6
	local beamHeight = 280 -- fixed, no pulsing
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
	-- Distance-based scale: reference camera distance ~2000u → 1.0x
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
	drawSoftDisc(px, pz, MARKER_RADIUS * (0.96 + 0.04 * pulse), r, g, b, 0.09 * a * glowMul, 20)

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
	local rot = phase * 0.25 -- gentle slow spin
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
	hoverPosIdx = nil
	hoverBoxIdx = nil
	hoverVertIdx = nil
	strengthEdit.hoverKnob = false
	hoverBoxEdge = nil
	hoverPolyEdge = nil
	if not active then
		if WG.RegionsTool then
			WG.RegionsTool.hoveringDraggable = false
		end
		return
	end
	-- Don't steal cursor while a drag is in progress (cursor already correct)
	if dragIdx or boxDragIdx or boxEdgeDrag then
		if WG.RegionsTool then
			WG.RegionsTool.hoveringDraggable = true
		end
		return
	end

	local wx, wz = getWorldMousePosition()
	if wx then
		if subMode == "express" then
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
			-- Knob first, mirroring MousePress: it wins over vertex picking, so hover has to
			-- agree or the highlight would point at something the click will not hit.
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
	if WG.RegionsTool then
		WG.RegionsTool.hoveringDraggable = shouldMove
	end
end

function widget:DrawWorld()
	if not active then
		return
	end

	local drawFrame = GetDrawFrame() or 0
	local phase = drawFrame * 0.04 -- ~2.4 rad/sec @ 60fps

	local wx, wz = getWorldMousePosition()
	-- Share this draw pass's mouse trace with DrawScreenEffects via the widget
	-- table: DrawWorld is at LuaJIT's 60-upvalue limit, so no new module locals.
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

	-- Express mode: ghost-cursor preview of the next position (or all symmetric copies)
	if subMode == "express" and wx and not dragIdx and hoverPosIdx == nil then
		---@type table?
		local tb = WG.TerraformBrush
		local stb = tb and tb.getState and tb.getState() or nil
		local numSlot = math_max(1, numTeamsPerAlly)
		local numAlly = math_max(1, numAllyTeams)
		local baseIdx = (nextAllyTeam - 1) * numSlot + (nextTeamSlot or 1)
		-- Desaturated gray tint when the cursor is over terrain the commander can't spawn on
		-- (slope > unit moveDef.maxSlope). Makes the "click here" indicator read as disabled.
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

	for bi, box in ipairs(startboxes) do
		local color = R.color(box, bi)
		local verts = box.vertices
		local isSelected = (bi == R.selectedIdx)
		if #verts >= 3 then
			local listId = ensureBoxFillList(box)
			if listId then
				glColor(color[1], color[2], color[3], isSelected and 0.36 or 0.22)
				glCallList(listId)
			end
			glColor(color[1], color[2], color[3], 0.9)
			glLineWidth(isSelected and 4.5 or 2.5)
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
				-- Draw edge resize handles as pairs of arrow tips (filled triangles) straddling
				-- the edge and pointing in opposite directions along the edge's normal axis.
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
					-- edge name -> midpoint + outward-normal axis (nx/nz) + tangent (tx/tz)
					L = { x = minX, z = (minZ + maxZ) * 0.5, nx = -1, nz = 0, tx = 0, tz = 1 },
					R = { x = maxX, z = (minZ + maxZ) * 0.5, nx = 1, nz = 0, tx = 0, tz = 1 },
					T = { x = (minX + maxX) * 0.5, z = minZ, nx = 0, nz = -1, tx = 1, tz = 0 },
					B = { x = (minX + maxX) * 0.5, z = maxZ, nx = 0, nz = 1, tx = 1, tz = 0 },
				}
				for name, mp in pairs(midEdges) do
					local isHover = (hoverBoxEdge and hoverBoxEdge.bi == bi and hoverBoxEdge.edge == name)
					-- Constant-screen-px sizing so arrows stay readable at any zoom.
					local sizePx = isHover and 22 or 16
					local size = worldRadiusForScreenPx(mp.x, mp.z, sizePx)
					local half = size * 0.55 -- half-base along the edge tangent
					local gap = size * 0.35 -- clearance from the edge line so tips don't overlap
					local rim = worldRadiusForScreenPx(mp.x, mp.z, 1.5) -- 1.5px dark rim halo
					-- Two tips: one OUTSIDE the rect (apex pointing outward = +normal) and one
					-- INSIDE (apex pointing inward = -normal). Together they read as an
					-- up-and-down / left-and-right resize affordance across the edge.
					local function emitTip(signNormal, expand)
						-- Base center is offset `gap` off the edge along signNormal; apex is
						-- another `size` further along the same direction.
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
					-- Dark crisp rim (slightly inflated triangle behind the colored fill).
					glColor(0, 0, 0, isHover and 0.85 or 0.70)
					glBeginEnd(GL_TRIANGLES, function()
						emitTip(1, rim)
						emitTip(-1, rim)
					end)
					-- Flat solid color fill (matches handle disk styling).
					glColor(color[1], color[2], color[3], isHover and 1.0 or 0.92)
					glBeginEnd(GL_TRIANGLES, function()
						emitTip(1, 0)
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
				-- Corner handles for box-kind: draggable to resize from a corner (rect stays
				-- axis-aligned via the MouseMove drag handler).
				for vi, v in ipairs(verts) do
					local vy = GetGroundHeight(v.x, v.z) or 0
					local isHoverVert = (hoverBoxIdx == bi and hoverVertIdx == vi)
					local rPx = isHoverVert and 22 or 14
					local vertR = worldRadiusForScreenPx(v.x, v.z, rPx)
					local rim = worldRadiusForScreenPx(v.x, v.z, 1.5)
					local cy = vy + 5
					local segs = 22
					-- Dark crisp outline (matches arrow rim aesthetic).
					glBeginEnd(GL_TRIANGLE_FAN, function()
						glColor(0, 0, 0, isHoverVert and 0.85 or 0.70)
						glVertex(v.x, cy - 0.1, v.z)
						for s = 0, segs do
							local a = (s / segs) * 2 * math_pi
							glVertex(v.x + math_cos(a) * (vertR + rim), cy - 0.1, v.z + math_sin(a) * (vertR + rim))
						end
					end)
					-- Flat solid color disk (same color/alpha as the arrows).
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
		local color = R.nextColor()
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

	if subMode == "startbox" and #R.radialPending > 0 then
		local color = R.nextColor()
		glColor(color[1], color[2], color[3], 0.9)
		glLineWidth(2.5)
		for _, spot in ipairs(R.radialPending) do
			glDrawGroundCircle(spot.x, GetGroundHeight(spot.x, spot.z) or 0, spot.z, 46, 16)
		end
		if R.previewFor ~= R.radialPending then
			R.previewFor = R.radialPending
			R.previewRing = nil
			local preview = R.hullFor(R.radialPending)
			if preview and #preview >= 3 then
				local anchors = {}
				for i, v in ipairs(preview) do
					anchors[i] = { v.x, v.z, 1 }
				end
				R.previewRing = strengthEdit.spline.TessellateRing(anchors)
			end
		end
		if R.previewRing then
			glColor(color[1], color[2], color[3], 0.5)
			glLineWidth(2.0)
			glBeginEnd(GL_LINE_LOOP, function()
				for _, p in ipairs(R.previewRing) do
					glVertex(p[1], (GetGroundHeight(p[1], p[2]) or 0) + 5, p[2])
				end
			end)
		end
	end

	if subMode == "startbox" and R.radial and R.radial.r > 0 then
		local color = R.nextColor()
		local gy = GetGroundHeight(R.radial.cx, R.radial.cz) or 0
		glColor(color[1], color[2], color[3], 0.8)
		glLineWidth(2.0)
		glDrawGroundCircle(R.radial.cx, gy, R.radial.cz, R.radial.r, 48)
		for _, spot in ipairs(R.spotsInRadial()) do
			glDrawGroundCircle(spot.x, GetGroundHeight(spot.x, spot.z) or 0, spot.z, 40, 16)
		end
	end

	-- Draw drag-rect preview (startboxMode == "box")
	if subMode == "startbox" and boxRectActive and boxRectStartX and boxRectEndX then
		local color = R.nextColor()
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
		-- Light fill outline (second pass, fainter)
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

	-- Draw freedraw in-progress path
	if subMode == "startbox" and freeDrawActive and #freeDrawPts >= 2 then
		local color = R.nextColor()
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
	"Blue",
	"Red",
	"Green",
	"Yellow",
	"Fuchsia",
	"Cyan",
	"Orange",
	"Pink",
	"DkGreen",
	"Brown",
	"LtBlue",
	"DkRed",
	"Mint",
	"Amber",
	"Lavender",
	"Teal",
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
	if not cz or cz <= 0 or cz >= 1 then
		return nil
	end
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

-- Minimum screen-space padding between marker top and text bottom
local LABEL_PAD = 18

local glGetTextWidth = gl.GetTextWidth

-- Draw a sleek screen-space badge: colored left-bar + "Team N" label.
-- Uses filled quads via glBeginEnd + glText. "2026" aesthetic: minimal, high-contrast, CHUNKY.
local function drawScreenBadge(cx, cy, color, allyTeamNum, teamName, playerIdx, fontSize, hovered)
	local padX, padY = 14, 10
	local barW = 5
	local gap = 10
	local label = "Team " .. tostring(allyTeamNum)

	-- Measure text widths in pixels (gl.GetTextWidth returns factor to multiply by fontSize)
	local function measure(s, sz)
		local w = glGetTextWidth and glGetTextWidth(s) or (#s * 0.55)
		return w * sz
	end
	local bigSize = fontSize
	local textW = measure(label, bigSize)
	local w = barW + gap + textW + padX * 2
	local h = bigSize * 1.18 + padY * 2
	local bx = cx - w * 0.5
	local by = cy

	-- stylua: ignore start
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
	-- stylua: ignore end

	-- "Team N" label (shadow + color-bright)
	local textX = bx + padX + barW + gap
	local textY = by + padY
	glColor(0, 0, 0, 0.90)
	glText(label, textX + 2, textY + 2, bigSize, "o")
	glColor(
		math_min(1, color[1] * 0.55 + 0.45),
		math_min(1, color[2] * 0.55 + 0.45),
		math_min(1, color[3] * 0.55 + 0.45),
		1.0
	)
	glText(label, textX, textY, bigSize, "o")
end

function widget:DrawScreenEffects()
	if not active then
		return
	end

	-- Screen-space sleek badges for placed positions
	for i, pos in ipairs(positions) do
		local sx, sy, sr, vis = getScreenMarker(pos.x, pos.z, MARKER_RADIUS)
		if vis then
			local pIdx = pos.playerIdx or pos.allyTeam
			local color = getColorForPlayer(pIdx)
			local badgeY = sy + sr + LABEL_PAD
			local fontSize = 32 -- 2026 chunky
			local hovered = (hoverPosIdx == i) or (dragIdx == i)
			drawScreenBadge(sx, badgeY, color, pos.allyTeam, getTeamName(pIdx), pIdx, fontSize, hovered)
		end
	end

	if R.type ~= "start" then
		for bi, region in ipairs(startboxes) do
			local verts = region.vertices
			if #verts >= 3 then
				local cx, cz = 0, 0
				for _, v in ipairs(verts) do
					cx, cz = cx + v.x, cz + v.z
				end
				cx, cz = cx / #verts, cz / #verts
				local sx, sy, sz = WorldToScreenCoords(cx, GetGroundHeight(cx, cz) or 0, cz)
				if sz and sz > 0 and sz < 1 then
					local label = region.name or "?"
					if region.group then
						label = label .. " (" .. region.group .. ")"
					end
					if region.team then
						label = R.teamLabel(region.team) .. " · " .. label
					end
					local alpha = (bi == R.selectedIdx) and 1.0 or 0.75
					glColor(1, 1, 1, alpha)
					glText(label, sx, sy, (bi == R.selectedIdx) and 16 or 14, "cdo")
				end
			end
		end
	end

	for _, box in ipairs(R.type == "start" and startboxes or {}) do
		if #box.vertices >= 3 then
			-- Place the badge above the box's TOP screen edge so it doesn't sit on top of
			-- the body-drag affordance at the centroid. Find the smallest screen-y across
			-- the projected vertices, pick its X for horizontal anchoring, then offset up.
			local bestSx, bestSy, bestVis
			for _, v in ipairs(box.vertices) do
				local vy = GetGroundHeight(v.x, v.z) or 0
				local sx, sy, sz = WorldToScreenCoords(v.x, vy, v.z)
				if sz and sz > 0 and sz < 1 then
					if (not bestSy) or sy > bestSy then -- screen y grows downward; max sy = top of screen
						bestSy = sy
						bestSx = sx
						bestVis = true
					end
				end
			end
			if not bestVis then
				-- Fallback: centroid (e.g. all corners off-screen but center on-screen)
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
				drawScreenBadge(
					bestSx,
					bestSy + 28,
					color,
					box.allyTeam,
					getTeamName(box.allyTeam) .. " BOX",
					box.allyTeam,
					26,
					false
				)
			end
		end
	end

	-- Shape preview small badges
	if subMode == "shape" then
		-- Reuse DrawWorld's mouse trace from this draw pass when available
		-- (read via self/Spring globals: this function is near the upvalue limit)
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

-- Widget Interface

function widget:Initialize()
	WG.RegionsTool = {
		activate = activate,
		deactivate = deactivate,
		getState = getState,
		isActive = function()
			return active
		end,
		hoveringDraggable = false,
		setSubMode = setSubMode,
		setShape = setShape,
		setRadius = setRadius,
		setRotation = setRotation,
		setShapeCount = setShapeCount,
		setNumAllyTeams = setNumAllyTeams,
		setNumTeamsPerAlly = setNumTeamsPerAlly,
		setPlacementMode = setPlacementMode,
		togglePlacementMode = togglePlacementMode,
		setStartboxMode = setStartboxMode,
		setRegionType = R.setType,
		setCategory = R.setCategory,
		drawArea = R.drawArea,
		setGeometry = R.setGeometry,
		setEditMode = R.setEditMode,
		cancelArea = R.cancelArea,
		removeArea = R.removeArea,
		setStrategy = R.setStrategy,
		setPlacing = R.setPlacing,
		selectRegion = R.select,
		selectStart = R.selectStart,
		setPendingField = R.setPendingField,
		setRegionField = R.setField,
		addTag = R.addTag,
		removeTag = R.removeTag,
		removeRegion = R.remove,
		exportLayout = R.exportLayout,
		encodeLayout = R.encodeLayout,
		copyLayout = R.copyLayout,
		saveRegions = R.save,
		lookAt = R.lookAt,
		loadRegions = R.load,
		clearAllPositions = clearAllPositions,
		addPosition = addPosition,
		placeRandomPositions = placeRandomPositions,
		saveStartPositions = saveStartPositions,
		loadStartPositions = loadStartPositions,
		listSavedConfigs = listSavedConfigs,
		copyStartboxOverride = copyStartboxOverride,
		clearAllStartboxes = clearAllStartboxes,
		setVertexStrength = strengthEdit.setVertex,
		setBoxStrength = strengthEdit.setBox,
		finishStartbox = finishStartbox,
		generateStartScript = generateStartScript,
		saveStartScript = saveStartScript,
	}
end

function widget:Shutdown()
	WG.RegionsTool = nil
	for _, region in ipairs(R.api.All()) do
		freeBoxFillList(region)
	end
end
