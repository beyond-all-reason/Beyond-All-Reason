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
---@type string[]
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
---@type table<integer, number[]>
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
local subMode = "express" ---@type "express"|"shape"|"startbox"
-- The start positions are the start regions' `positions`; `seats()` below is the tool's view over them.
local nextAllyTeam = 1 -- next allyteam in rotation
local nextTeamSlot = 1 -- next player slot within that allyteam
local numAllyTeams = 2 -- configurable count (ally teams)
local numTeamsPerAlly = 1 -- configurable count (players per ally)
local placementMode = "roundrobin" ---@type "roundrobin"|"sequential"

-- Shape placement state
local shapeType = "circle" ---@type "circle"|"square"|"hexagon"|"octagon"|"triangle"
local shapeRadius = 2000 ---@type number
local shapeRotation = 0 ---@type number
local shapeCount = 4 -- number of positions to place with shape

-- Startbox state
---@class RegionsToolState
---@field type RegionTypeKey
---@field strategy "express"|"shape"
---@field placing "points"|"area"
---@field selectedIdx integer|nil
---@field selectedStart integer|nil
---@field pendingVertex { wx: number, wz: number, mx: number, my: number }|nil
---@field category string
---@field geometry string
---@field editMode "select"|"create"
---@field radial { cx: number, cz: number, r: number }|nil
---@field radialPending table
---@field radialHistory table
---@field error string
---@field revision integer
---@field COLOR number[]
---@field [string] any
local R = {
	type = "start",
	strategy = "express",
	placing = "points",
	selectedIdx = nil,
	selectedStart = nil,
	pendingVertex = nil,
	category = "start",
	geometry = "point",
	editMode = "select",
	radial = nil,
	radialPending = {},
	radialHistory = {},
	error = "",
	revision = 0,
	COLOR = { 0.35, 0.85, 1.0, 1.0 },
}
R.api = require("modules/regions/api")
local Start = require("modules/start/api")
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
---@class EditorRegion what the tool draws: a region regions holds, or the form's copy of one
---@field id string|nil
---@field type RegionTypeKey
---@field vertices { x: number, z: number }[]
---@field kind "point"|"polygon"|"box"|"spline"|nil
---@field controls { x: number, z: number, strength: number|nil }[]|nil
---@field name string|nil
---@field team integer|nil
---@field group string|nil
---@field positions { x: number, z: number }[]|nil

---@class HeldRegion: EditorRegion a region regions holds, as the tool reads it
---@field id string

-- The form: the one region the tool edits, as its own copy, until it is committed whole. A region regions holds is
-- edited through a form opened on it; a new one is made in a form opened empty. Nothing else changes a region's
-- shape or fields, so every region in the list has checked out.
---@class EditorForm
---@field id string|nil the region it edits; nothing for a new one
---@field region EditorRegion the form's copy: what the tools draw into and the fields edit
---@field problems RegionProblem[] what regions said when the form was last submitted
---@field changed boolean edited since it was opened or last submitted
R.form = nil ---@type EditorForm|nil
-- What the last region made was given from a list (a team, usually): the next new form starts with it.
R.lastPicks = {}

---@param value any a region, or anything in one
---@return any a copy that shares nothing with it
function R.copyOf(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in pairs(value) do
		out[k] = R.copyOf(v)
	end
	return out
end

-- The problems regions gives back, one line each; and those that say where on the map they are.
---@param problems RegionProblem[]|nil
---@return string[]
function R.messages(problems)
	local out = {}
	for i, problem in ipairs(problems or {}) do
		out[i] = problem.message
	end
	return out
end

---@param refusals RegionRefusal[]|nil
---@param what string
function R.echoRefusals(refusals, what)
	for _, refusal in ipairs(refusals or {}) do
		local candidate = refusal.candidate or {}
		Echo(
			"[Regions] "
				.. what
				.. " "
				.. tostring(candidate.type)
				.. " "
				.. tostring(candidate.name or candidate.id or "")
				.. ": "
				.. table.concat(R.messages(refusal.problems), "; ")
		)
	end
end

-- One region changed and committed: the change is made to a copy, and regions takes the copy whole or not at all.
---@param region HeldRegion
---@param change fun(copy: EditorRegion)
---@return Region|nil
function R.commit(region, change)
	local copy = R.copyOf(region)
	change(copy)
	local held, problems = R.api.Update(region.id, copy)
	if held == nil then
		Echo("[Regions] " .. table.concat(R.messages(problems), "; "))
	end
	R.bump()
	return held
end

-- What regions holds, as the tool reads it: any field a type declares.
---@param typeKey RegionTypeKey|nil
---@return HeldRegion[]
function R.held(typeKey)
	return R.api.All(typeKey) --[[@as HeldRegion[] ]]
end

---@param typeKey RegionTypeKey
---@return HeldRegion[]
function R.admitted(typeKey)
	local out = {}
	for _, region in ipairs(R.held(typeKey)) do
		if typeKey ~= "start" or #region.vertices >= 3 then
			out[#out + 1] = region
		end
	end
	if typeKey == "start" then
		table.sort(out, function(a, b)
			return (a.team or 0) < (b.team or 0)
		end)
	end
	return out
end

local startboxes = {} ---@type EditorRegion[]
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
local startboxMode = "polygon" ---@type "polygon"|"box"|"freedraw"|"radial"
local drawingBox = false
local currentBoxVerts = {} ---@type { x: number, z: number }[]
local boxDragIdx = nil ---@type integer|nil
local boxDragBoxIdx = nil ---@type integer|nil
local boxEdgeDrag = nil ---@type { bi: integer, edge: string }|nil
local hoverBoxEdge = nil ---@type { bi: integer, edge: string }|nil
-- Anchor selected for curvature editing. Clicking a handle (press and release without
-- moving) selects it and raises a gizmo along its outward normal; dragging along that
-- gizmo sets the anchor strength between 0 and 1.
-- Curvature editing hangs off one table rather than a dozen file-level locals: the main
-- chunk of this widget sits on Lua's 200-local ceiling and each new one costs a slot.
-- selBox / selVert (the selected anchor: box index, vertex index) are assigned
-- below rather than listed here: a `= nil` in the constructor makes the
-- analyzer read them as never set.
---@class StrengthEdit
---@field dragging boolean
---@field GIZMO_LEN number
---@field scratch table
---@field [string] any
local strengthEdit = {
	dragging = false,
	GIZMO_LEN = 240, -- world units from anchor to the strength-1 end of the gizmo
	scratch = {}, -- reused anchor ring, see buildRing
}
-- Whole-box drag (mouse pressed inside a startbox body, not on a handle/edge). Records the
-- world-space cursor delta between frames and offsets every vertex (and spline control point
-- when applicable). Separate from vertex-drag so hover hit-tests stay simple.
local boxBodyDrag = nil ---@type { bi: integer, lastX: number, lastZ: number }|nil
-- Set true whenever a startbox vertex / edge / body drag is in progress. Used by
-- ensureBoxFillList to defer the expensive fill-list rebuild until MouseRelease.
local isDraggingBox = false
local pendingFillRebuildIdx = nil ---@type integer|nil
-- Box drag-rect (startboxMode == "box"): two corners, live-updated during drag
local boxRectStartX = nil ---@type number|nil
local boxRectStartZ = nil ---@type number|nil
local boxRectEndX = nil ---@type number|nil
local boxRectEndZ = nil ---@type number|nil
local boxRectActive = false
-- Free-draw state (startboxMode == "freedraw"): collect points with minimum spacing
local freeDrawPts = {} ---@type { x: number, z: number }[]
local freeDrawActive = false
local FREEDRAW_MIN_DIST_SQ = 40 * 40 -- minimum world distance between sample points

-- Drag state
local dragging = false
local dragIdx = nil ---@type integer|nil
local dragStartX = nil ---@type number|nil
local dragStartY = nil ---@type number|nil

-- Hover state (drives cursor + marker highlight)
local hoverPosIdx = nil ---@type integer|nil
local hoverBoxIdx = nil ---@type integer|nil
local hoverVertIdx = nil ---@type integer|nil
-- Polygon edge-midpoint hover: shows a "ghost" handle at the middle of a polygon edge
-- so the user can click/hold there to insert a new vertex (which immediately becomes a
-- live drag handle). { bi, edgeIdx, x, z } — edgeIdx is index of the edge's start vertex.
local hoverPolyEdge = nil ---@type table|nil

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
	local idx = (at % #TEAM_COLORS) + 1
	return TEAM_COLORS[idx]
end

-- Unique color per (allyTeam, teamSlot) pair — gives every player a distinct color
-- when multiple teams per allyteam are used. playerIdx = allyTeam*numTeamsPerAlly + teamSlot.
function R.color(box, bi)
	local failing = R.form and R.form.region == box and #R.form.problems > 0
	if failing or R.validate().byRegion[box] then
		return R.INVALID
	end
	local team = box.team or (R.type == "start" and bi - 1) or nil
	return team and getColorForAllyTeam(team) or R.COLOR
end

function R.nextColor()
	local team = R.form and R.form.region.team
	return team and getColorForAllyTeam(team) or R.COLOR
end

-- Only the form's region has handles: what the tools change is the form's copy, never a region regions holds.
---@param box EditorRegion|nil
---@return boolean
function R.editable(box)
	return box ~= nil and R.form ~= nil and R.form.region == box
end

-- The regions the area tools draw and pick by index: what regions holds of a type, with the form's copy standing in
-- for the region it edits, or after them when it is new. A start that is only its positions is not among them: it
-- is reached by team, through R.start, and its positions through seats().
function R.list(typeKey)
	local out = {}
	local form = R.form
	local placed = false
	for _, held in ipairs(R.held(typeKey)) do
		local region = held
		if form and form.id == held.id then
			region = form.region
			placed = true
		end
		if typeKey ~= "start" or (region.vertices ~= nil and #region.vertices >= 3) then
			out[#out + 1] = region
		end
	end
	if form and not placed and form.region.type == typeKey and #form.region.vertices >= 3 then
		out[#out + 1] = form.region
	end
	if typeKey == "start" then
		table.sort(out, function(a, b)
			return (a.team or 0) < (b.team or 0)
		end)
	end
	return out
end

function R.refresh()
	startboxes = R.list(R.type)
	R.selectedIdx = nil
	for i, region in ipairs(startboxes) do
		if R.editable(region) then
			R.selectedIdx = i
		end
	end
	R.selectedStart = R.form and R.form.region.type == "start" and R.form.region.team or nil
end

-- The regions whose handles answer the cursor, by their place in the list: the form's, or none.
---@return table<integer, EditorRegion>
function R.handles()
	local out = {} ---@type table<integer, EditorRegion>
	local box = R.selectedIdx and startboxes[R.selectedIdx]
	if box and R.editable(box) then
		out[R.selectedIdx] = box
	end
	return out
end

---@return HeldRegion|nil
function R.start(team)
	for _, region in ipairs(R.held("start")) do
		if region.team == team then
			return region
		end
	end
	return nil
end

---@class EditorSeat
---@field region HeldRegion
---@field i integer
---@field x number
---@field z number
---@field y number
---@field allyTeam integer
---@field teamSlot integer
---@field playerIdx integer

local seatsCache, seatsCacheKey = {}, ""
---@return EditorSeat[]
local function seats()
	local key = R.api.Revision() .. ":" .. R.revision
	if key ~= seatsCacheKey then
		seatsCacheKey = key
		seatsCache = {}
		for _, region in ipairs(R.held("start")) do
			for i, p in ipairs(region.positions or {}) do
				seatsCache[#seatsCache + 1] = {
					region = region,
					i = i,
					x = p.x,
					z = p.z,
					y = GetGroundHeight(p.x, p.z) or 0,
					allyTeam = region.team,
					teamSlot = i,
					playerIdx = (region.team or 0) * math_max(1, numTeamsPerAlly) + i,
				}
			end
		end
	end
	return seatsCache
end

-- A point start is where its one position is; an area keeps its shape whatever its positions do.
---@param region EditorRegion
local function keepShape(region)
	local positions = region.positions or {}
	if region.kind == "point" or (region.vertices ~= nil and #region.vertices < 3) then
		region.kind = "point"
		region.vertices = positions[1] and { { x = positions[1].x, z = positions[1].z } } or {}
	end
end

-- The fields a form edits; a points field is a tool's to keep, not a form's.
function R.fieldDefs(typeKey)
	local kind = R.TYPES[typeKey or R.type]
	local out = {}
	for _, field in ipairs(kind and kind.fields or {}) do
		if field.kind ~= "points" then
			out[#out + 1] = field
		end
	end
	return out
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
	return Start.Placement.Shape(cx, cz, shapeParams(), Game.mapSizeX, Game.mapSizeZ)
end

local function generateRandomPositions(cx, cz)
	return Start.Placement.Random(cx, cz, shapeParams(), Game.mapSizeX, Game.mapSizeZ)
end

-- Core Operations

-- The slope a commander can spawn on, in the space Spring.GetGroundNormal reports it; start's to decide.
local commanderMaxSlope = nil
local function isPlaceableForCommander(x, z)
	commanderMaxSlope = commanderMaxSlope
		or Start.Placement.CommanderMaxSlope(UnitDefs, Spring.GetModOptions and Spring.GetModOptions() or nil)
	local _, _, _, slope = Spring.GetGroundNormal(x, z, false)
	return (slope or 0) <= commanderMaxSlope
end

local function addPosition(x, z, allyTeam, teamSlot)
	if #seats() >= MAX_POSITIONS then
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
	local region = R.start(allyTeam)
	if not region then
		local created, problems = R.api.Create({
			type = "start",
			team = allyTeam,
			kind = "point",
			vertices = { { x = x, z = z } },
			positions = { { x = x, z = z } },
		})
		if created == nil then
			Echo("[Regions] " .. table.concat(R.messages(problems), "; "))
			return false
		end
		R.bump()
		return true
	end
	return R.commit(region, function(copy)
		copy.positions = copy.positions or {}
		local at = math_min(teamSlot or (#copy.positions + 1), #copy.positions + 1)
		table.insert(copy.positions, at, { x = x, z = z })
		keepShape(copy)
	end) ~= nil
end

-- Take the seat back: the position, and the point start it was when it was the last one.
---@param seat EditorSeat
local function removeSeat(seat)
	local region = seat.region
	local positions = R.copyOf(region.positions or {})
	table.remove(positions, seat.i)
	if #positions == 0 and #region.vertices < 3 then
		R.api.Delete(region.id)
		R.bump()
		return
	end
	R.commit(region, function(copy)
		copy.positions = #positions > 0 and positions or nil
		keepShape(copy)
	end)
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
	nextAllyTeam = ally --[[@as integer]]
	nextTeamSlot = slot --[[@as integer]]
end

local function removePosition(idx)
	local seat = seats()[idx]
	if not seat then
		return false
	end
	removeSeat(seat)
	return true
end

-- The last seat placed: the one the placement pointers would give again, one step back.
local function removeLastSeat()
	local all = seats()
	if #all == 0 then
		return
	end
	local last = all[#all]
	for _, seat in ipairs(all) do
		if seat.allyTeam == nextAllyTeam and seat.teamSlot == nextTeamSlot then
			last = seat
		end
	end
	removeSeat(last)
end

local function removeNearestPosition(wx, wz)
	local bestIdx = nil ---@type integer|nil
	local bestDist = CLICK_DISTANCE_SQ
	for i, pos in ipairs(seats()) do
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
	local bestIdx = nil ---@type integer|nil
	local bestDist = CLICK_DISTANCE_SQ
	for i, pos in ipairs(seats()) do
		local d = distSq(wx, wz, pos.x, pos.z)
		if d < bestDist then
			bestDist = d
			bestIdx = i
		end
	end
	return bestIdx
end

local function clearAllPositions()
	for _, region in ipairs(R.held("start")) do
		if #region.vertices < 3 then
			R.api.Delete(region.id)
		else
			R.commit(region, function(copy)
				copy.positions = nil
			end)
		end
	end
	R.bump()
	nextAllyTeam = 1
	nextTeamSlot = 1
	undoHistory = {}
end

-- Shape/random placement: always distribute evenly across all allyteam×teamSlot combinations
-- so a 4-ally × 2-team shape of 8 places yields one of each.
local function placeShapePositions(cx, cz)
	for i, pt in ipairs(generateShapePositions(cx, cz)) do
		addPosition(pt.x, pt.z, Start.Placement.SlotFor(i, numAllyTeams, numTeamsPerAlly, placementMode))
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
		addPosition(pt.x, pt.z, Start.Placement.SlotFor(i, numAllyTeams, numTeamsPerAlly, placementMode))
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
	if tb and stb and stb.gridSnap and tb.snapWorld then
		x, z = tb.snapWorld(x, z, 0)
	end
	x, z = clampToMap(x, z)
	currentBoxVerts[#currentBoxVerts + 1] = { x = x, z = z }
end

-- Ally team is the area's place among the areas, never a running counter: that is what the modoption format means
-- by order (area 1 is allyTeam 0). After an area goes, those after it move down a team, one commit each. A start that
-- is only its positions hands them to the area that takes its number, and goes first, so no two starts ever share a
-- team between commits: each area only moves down into a team no other start holds by then.
local function renumberBoxAllyTeams()
	local areas = R.admitted("start")
	local handed = {} ---@type table<HeldRegion, { x: number, z: number }[]>
	for _, region in ipairs(R.held("start")) do
		local area = #region.vertices < 3 and areas[(region.team or -1) + 1] or nil
		if area then
			R.api.Delete(region.id)
			handed[area] = handed[area] or {}
			for _, p in ipairs(region.positions or {}) do
				table.insert(handed[area], { x = p.x, z = p.z })
			end
		end
	end
	for i, area in ipairs(areas) do
		if area.team ~= i - 1 or handed[area] then
			R.commit(area, function(copy)
				copy.team = i - 1
				for _, p in ipairs(handed[area] or {}) do
					copy.positions = copy.positions or {}
					copy.positions[#copy.positions + 1] = p
				end
			end)
		end
	end
	R.refresh()
end

function R.bump()
	R.revision = R.revision + 1
end

-- The team a new start is given: the first no start holds.
---@return integer
function R.nextTeam()
	local taken = {}
	for _, region in ipairs(R.held("start")) do
		if region.team then
			taken[region.team] = true
		end
	end
	local team = 0
	while taken[team] do
		team = team + 1
	end
	return team
end

-- Open a form on a new region of the current type: empty, but for what was last picked from a list.
function R.openNew()
	R.closeForm()
	local region = { type = R.type, vertices = {} }
	for _, field in ipairs(R.fieldDefs()) do
		if field.picks then
			region[field.key] = R.lastPicks[field.key]
		end
	end
	if R.type == "start" then
		region.team = R.nextTeam()
	end
	R.form = { region = region, problems = {}, changed = false }
	R.error = ""
	R.applyMode()
end

-- Open a form on a region regions holds: the form edits its own copy until it is saved.
---@param id string
---@return boolean
function R.openEdit(id)
	local held = R.api.Get(id)
	if not held then
		return false
	end
	R.closeForm()
	R.type = held.type
	R.category = held.type
	R.form = { id = id, region = R.copyOf(held), problems = {}, changed = false }
	R.error = ""
	R.applyMode()
	return true
end

-- The form's edits are dropped, and what was drawn for it; regions holds what it held.
function R.closeForm()
	if R.form then
		freeBoxFillList(R.form.region)
		for i = #undoHistory, 1, -1 do
			if undoHistory[i].form then
				table.remove(undoHistory, i)
			end
		end
		boxUndo.redo = {}
	end
	R.form = nil
	strengthEdit.selBox, strengthEdit.selVert = nil, nil
	currentBoxVerts = {}
	drawingBox = false
	R.radialPending = {}
	R.radialHistory = {}
end

function R.cancelForm()
	R.closeForm()
	R.applyMode()
end

-- The form has been edited: what regions said of it before no longer describes it.
function R.touched()
	if R.form then
		R.form.changed = true
		R.form.problems = {}
		R.error = ""
	end
	R.bump()
end

-- Commit the form: a new region is created, an edited one updated, whole. What regions refuses stays in the form
-- with what is wrong with it. A new start for a team that is only its positions so far is that start's area.
---@return boolean
function R.submitForm()
	local form = R.form
	if not form then
		return false
	end
	local region = R.copyOf(form.region)
	local id = form.id
	local before = id and R.api.Get(id) or nil ---@type table|nil
	if id == nil and region.type == "start" then
		local seated = R.start(region.team)
		if seated and #seated.vertices < 3 then
			id, before = seated.id, seated
			region.positions = R.copyOf(seated.positions)
		end
	end
	local held, problems
	if id then
		held, problems = R.api.Update(id, region)
	else
		held, problems = R.api.Create(region)
	end
	if held == nil then
		form.problems = problems or {}
		form.changed = false
		R.bump()
		return false
	end
	for _, field in ipairs(R.fieldDefs(held.type)) do
		if field.picks then
			R.lastPicks[field.key] = held[field.key]
		end
	end
	if before then
		boxUndo.push("edit", before)
	else
		boxUndo.push("add", held)
	end
	R.closeForm()
	R.applyMode()
	R.say((before and "Saved " or "Created ") .. (R.TYPES[held.type] and R.TYPES[held.type].label:lower() or "region"))
	return true
end

-- Delete the region the form is on.
---@return boolean
function R.deleteForm()
	local form = R.form
	local held = form and form.id and R.api.Get(form.id)
	if not held then
		R.cancelForm()
		return false
	end
	boxUndo.push("remove", held)
	R.api.Delete(held.id)
	R.closeForm()
	if held.type == "start" then
		renumberBoxAllyTeams()
	end
	R.applyMode()
	R.bump()
	return true
end

-- A shape drawn with the tools: it becomes the form's, replacing what the form had drawn. Drawing with no form open
-- opens one on a new region.
---@param shape { vertices: { x: number, z: number }[], kind: string|nil, controls: table|nil }
function R.setFormShape(shape)
	if not R.form then
		R.openNew()
	end
	local form = R.form --[[@as EditorForm]]
	boxUndo.push("edit", form.region)
	freeBoxFillList(form.region)
	form.region.kind = shape.kind
	form.region.controls = shape.controls
	form.region.vertices = shape.vertices
	if shape.kind == "spline" then
		R.tessellate(form.region)
	end
	R.touched()
	R.refresh()
end

---@param strength number|nil
---@param kind "box"|nil
local function finishStartbox(strength, kind)
	if #currentBoxVerts >= 3 then
		if strength ~= nil then
			local controls = {}
			for i, v in ipairs(currentBoxVerts) do
				controls[i] = { x = v.x, z = v.z, strength = strength }
			end
			R.setFormShape({ kind = "spline", controls = controls, vertices = {} })
		else
			R.setFormShape({ kind = kind, vertices = currentBoxVerts })
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
strengthEdit.spline = require("common/lib_spline")

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
	invalidateBoxFill(box)
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

-- Clearing commits at once and is not undoable: what undo held of this type's regions goes with them.
local function clearAllStartboxes()
	R.closeForm()
	strengthEdit.dragging = false
	R.api.Clear(R.type)
	for i = #undoHistory, 1, -1 do
		if undoHistory[i].mode == "startbox" and (undoHistory[i].region or "start") == R.type then
			table.remove(undoHistory, i)
		end
	end
	boxUndo.redo = {}
	R.applyMode()
	R.bump()
end

function boxUndo.snap(box)
	if not box then
		return nil
	end
	local anchors = box.controls or box.vertices or {}
	local out = { kind = box.kind, team = box.team, anchors = {} }
	out.type = box.type
	out.id = box.id
	out.fields = R.fieldValues(box)
	out.positions = R.copyOf(box.positions)
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
	local box = { kind = snap.kind, team = snap.team }
	box.type = snap.type
	box.id = snap.id
	box.positions = R.copyOf(snap.positions)
	for key, value in pairs(snap.fields or {}) do
		box[key] = value
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

-- Two kinds of entry. One made while a form is open is the form's: it puts back the form's copy as it was, and goes
-- when the form closes. One made with no form open is a commit's: "add" deletes the region it made, "remove" makes it
-- again under its id, "edit" puts back what the region was; each is itself one commit.
---@param op "add"|"remove"|"edit"
---@param box table the region as it stands before the change; for "add", the region made
function boxUndo.push(op, box)
	local form = R.form and R.form.region == box and R.form or nil
	undoHistory[#undoHistory + 1] = {
		mode = "startbox",
		region = box.type or R.type,
		op = op,
		form = form,
		box = boxUndo.snap(box),
	}
	boxUndo.redo = {}
end

-- A drag fires MouseMove continuously, so the snapshot is taken once on press and only
-- committed on release if the gesture actually changed something. One Ctrl+Z per gesture.
function boxUndo.begin(idx)
	local box = startboxes[idx]
	if R.editable(box) then
		boxUndo.pending = { box = box, snap = boxUndo.snap(box) }
	end
end

function boxUndo.commit()
	local pend = boxUndo.pending
	boxUndo.pending = nil
	if not pend or not R.editable(pend.box) then
		return
	end
	-- A click that only selects a handle must not leave a no-op entry behind, or Ctrl+Z
	-- appears to do nothing.
	local now, before = boxUndo.snap(pend.box), pend.snap
	if now and before and #now.anchors == #before.anchors then
		local same = now.kind == before.kind
		for k = 1, #now.anchors do
			local a = now.anchors[k]
			local b = before.anchors[k]
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
		region = R.type,
		op = "edit",
		form = R.form,
		box = pend.snap,
	}
	boxUndo.redo = {}
	R.touched()
end

-- A region made again under a new id: the entries that name it by the old one name it by the new.
---@param from string
---@param to string
function boxUndo.renamed(from, to)
	for _, stack in ipairs({ undoHistory, boxUndo.redo }) do
		for _, entry in ipairs(stack) do
			if entry.mode == "startbox" and entry.box and entry.box.id == from then
				entry.box.id = to
			end
		end
	end
end

-- Applies an entry and returns the one that reverses it.
function boxUndo.apply(entry)
	local mirror = { mode = "startbox", region = entry.region, op = entry.op, form = entry.form }
	if entry.form then
		local form = entry.form
		mirror.box = boxUndo.snap(form.region)
		freeBoxFillList(form.region)
		form.region = boxUndo.build(entry.box)
		R.touched()
		R.refresh()
		return mirror
	end
	if entry.op == "add" then
		local held = R.api.Get(entry.box.id)
		mirror.op, mirror.box = "remove", boxUndo.snap(held)
		R.api.Delete(entry.box.id)
	elseif entry.op == "remove" then
		-- Made again as a new region: its id is regions' to give. The history still names the region by the id it
		-- had, so every entry that does is told the new one, or the next step back would look for a region that is gone.
		local made, problems = R.api.Create(boxUndo.build(entry.box))
		mirror.op, mirror.box = "add", boxUndo.snap(made) or entry.box
		if made == nil then
			Echo("[Regions] Undo: " .. table.concat(R.messages(problems), "; "))
		else
			boxUndo.renamed(entry.box.id, made.id)
		end
	else
		local held = R.api.Get(entry.box.id)
		mirror.box = boxUndo.snap(held)
		local put, problems = R.api.Update(entry.box.id, boxUndo.build(entry.box))
		if put == nil then
			Echo("[Regions] Undo: " .. table.concat(R.messages(problems), "; "))
		end
	end
	if entry.region == "start" then
		renumberBoxAllyTeams()
	end
	R.refresh()
	R.bump()

	return mirror
end

function boxExport.encode()
	local arrangement =
		Start.Export.Arrangement(R.admitted("start") --[[@as StartRegion[] ]], Game.mapSizeX, Game.mapSizeZ)
	if #arrangement == 0 then
		return nil
	end

	-- Json is a LuaUI global (luaui/system.lua). Including the module directly fails in this
	-- sandbox: it opens with `local base = _G`, and _G is not exposed here.
	if not Json then
		Echo("[Regions] Json unavailable; cannot encode.")
		return nil
	end
	boxExport.b64 = boxExport.b64 or require("common/luaUtilities/base64")
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
	for bi, box in pairs(R.handles()) do
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
	local EDGE_PICK_DIST = 55.0 -- world units from edge line
	for bi, box in pairs(R.handles()) do
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

	local cx, cz = 0.0, 0.0
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
	for bi, box in pairs(R.handles()) do
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

-- Start Script Generation

local STARTSCRIPT_SAVE_DIR = "Terraform Brush/StartScripts/"

---@param opts table|nil
---@return string|nil
local function generateStartScript(opts)
	opts = opts or {}
	local script =
		Start.Export.StartScript(R.admitted("start") --[[@as StartRegion[] ]], Game.mapSizeX, Game.mapSizeZ, {
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
	return R.api.Hull.Around(points, (Game.extractorRadius or 80) * 1.5)
end

-- The geometries the panel offers: a form draws a shape; the list places a start's positions, and nothing else.
---@return string[]
function R.geometryChoices()
	local out = {}
	for _, g in ipairs(R.geometriesFor(R.type)) do
		if (R.form ~= nil) ~= (g == "point") then
			out[#out + 1] = g
		end
	end
	return out
end

-- The list selects: a click on a region opens a form on it. For starts it also places positions, each one a commit.
-- A form draws and edits its own region's shape.
function R.applyMode()
	local allowed = R.geometryChoices()
	local ok = false
	for _, g in ipairs(allowed) do
		ok = ok or g == R.geometry
	end
	if not ok then
		R.geometry = allowed[1] or "polygon"
	end
	R.refresh()
	if R.form then
		R.placing = "area"
		subMode = "startbox"
		startboxMode = (R.geometry == "square") and "box" or (R.geometry == "mexes") and "radial" or "polygon"
	elseif R.type == "start" and R.editMode == "create" then
		R.placing = "points"
		subMode = R.strategy
	else
		R.placing = "area"
		subMode = "startbox"
		startboxMode = "polygon"
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
	R.bump()
end

function R.setType(t)
	if R.TYPES[t] and t ~= R.type then
		R.closeForm()
		R.type = t
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
		R.closeForm()
		R.error = ""
	end
	R.type = cat.type
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

-- A start's area goes and its positions stay: the start becomes a point where its first position is.
function R.removeArea()
	local form = R.form
	if not form or form.region.type ~= "start" then
		return false
	end
	boxUndo.push("edit", form.region)
	freeBoxFillList(form.region)
	form.region.kind = "point"
	form.region.controls = nil
	form.region.vertices = {}
	keepShape(form.region)
	R.touched()
	R.refresh()
	return true
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

---@param regions table[]
---@return integer created
function R.createAll(regions, what)
	local created, refused = 0, {}
	for _, region in ipairs(regions) do
		local made, problems = R.api.Create(R.copyOf(region))
		if made then
			created = created + 1
		else
			refused[#refused + 1] = { candidate = region, problems = problems }
		end
	end
	R.echoRefusals(refused, what)
	return created
end

function R.seedMexRegions()
	if #R.api.All("mex_region") > 0 then
		return
	end
	-- The match's deal carries the layout the game plays with, anchors and all: the fallback for a layout that came
	-- from somewhere other than this tool's own file.
	local okDeal, Deal = pcall(VFS.Include, "modules/transfer/mex_splitting/deal.lua")
	local deal = okDeal and type(Deal) == "table" and Deal.Reader(Game.mapSizeX, Game.mapSizeZ)(Spring) or nil
	if deal and deal.regions and #deal.regions > 0 then
		-- Read back as published, ids and all: the deal is keyed by them.
		local all = R.api.All()
		for _, region in ipairs(deal.regions) do
			all[#all + 1] = region
		end
		local _, refused = R.api.Load(all)
		R.echoRefusals(refused, "Left out the match's")
		Echo("[Regions] Opened on the match's " .. (#deal.regions - #refused) .. " mex region(s)")
		R.refresh()
	end
end

function R.seedFromMatch()
	if not R.seeded and #R.api.All() == 0 then
		-- The map maker's own file first: it holds every type, with the anchors they drew.
		R.load()
	end
	R.seedMexRegions()
	if R.seeded or #R.admitted("start") > 0 then
		return
	end
	R.seeded = true
	local current = Start.Current(Spring)
	R.createAll(current.areas, "Left out the match's")
	renumberBoxAllyTeams()
	local slots = {}
	for _, pos in ipairs(current.positions) do
		local allyTeam = pos.allyTeamID
		slots[allyTeam] = (slots[allyTeam] or 0) + 1
		addPosition(pos.x, pos.z, allyTeam, slots[allyTeam])
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

-- The list's row, or the region on the map, opened in a form.
function R.select(idx)
	local box = idx and startboxes[idx]
	if box and box.id then
		R.openEdit(box.id)
	elseif idx == nil then
		R.cancelForm()
	end
end

function R.selectStart(allyTeam)
	local start = allyTeam and R.start(allyTeam)
	if start then
		R.openEdit(start.id)
	end
end

function R.starts()
	local count = 0
	for _, region in ipairs(R.held("start")) do
		---@cast region +StartRegion
		count = math_max(count, (region.team or -1) + 1)
	end
	local out = {}
	for allyTeam = 0, count - 1 do
		local box = R.start(allyTeam)
		out[#out + 1] = {
			allyTeam = allyTeam,
			id = box and box.id or nil,
			positions = box and box.positions and #box.positions or 0,
			hasBox = box ~= nil and box.vertices ~= nil and #box.vertices >= 3,
			name = box and box.name or nil,
		}
	end
	return out
end

---@param box EditorRegion
function R.startFacts(box)
	local facts = R.facts(box)
	local count, cx, cz = 0, 0.0, 0.0
	for _, pos in ipairs(box.positions or {}) do
		count = count + 1
		cx, cz = cx + pos.x, cz + pos.z
	end
	if not (box.vertices and #box.vertices >= 3) then
		facts[#facts + 1] = { "Area", "none drawn" }
		if count > 0 then
			facts[#facts + 1] = { "Positions centre", string.format("%d, %d", cx / count, cz / count) }
		end
	end
	facts[#facts + 1] = { "Positions", tostring(count) }
	return facts
end

-- A field typed into the form: kept as typed, a number when it reads as one; regions says what is wrong on submit.
function R.setFormField(key, value)
	local form = R.form
	if not form then
		return false
	end
	for _, field in ipairs(R.fieldDefs(form.region.type)) do
		if field.key == key then
			if value == nil or value == "" then
				form.region[key] = nil
			elseif field.kind == "integer" then
				form.region[key] = tonumber(value) or value
			else
				form.region[key] = value
			end
			R.touched()
			return true
		end
	end
	return false
end

function R.teamLabel(team)
	local start = team and R.start(team)
	return (start and start.name) or (team and ("Team " .. (team + 1))) or nil
end

function R.teamOptions()
	local out = {}
	for _, start in ipairs(R.starts()) do
		out[#out + 1] = { team = start.allyTeam, label = R.teamLabel(start.allyTeam) }
	end
	return out
end

function R.factsFor(key, compute)
	if R.factsKey ~= key then
		R.factsKey = key
		R.factsValue = compute()
	end
	return R.factsValue
end

-- A name is regions' to give, over the list as it stands: the form's copy among what regions holds.
function R.names()
	return R.api.Names(R.type, startboxes --[[@as Region[] ]])
end

function R.facts(box)
	local verts = box.vertices or {}
	if #verts < 3 then
		return {}
	end
	local finder = WG.resource_spot_finder
	local spots = finder and not finder.isMetalMap and finder.metalSpotsList or nil
	local area = R.api.Geometry.Area(verts)
	local cx, cz = R.api.Geometry.Centroid(verts)
	local held = box
	local d = R.api.Describe(box, { spots = spots })
	local lines = { { "Vertices", tostring(#verts) } }
	if area > 0 then
		lines[#lines + 1] = { "Area", string.format("%.0f x %.0f elmos equivalent", math_sqrt(area), math_sqrt(area)) }
	end
	lines[#lines + 1] = { "Centre", string.format("%d, %d", cx, cz) }
	if d == nil or held == nil then
		return lines
	end
	if held.type == "start" then
		local s = d --[[@as StartDescription]]
		lines[#lines + 1] = { "Start", R.teamLabel(s.team) or tostring(s.team) }
		lines[#lines + 1] = { "Positions", tostring(#s.positions) }
	elseif held.type == "mex_region" then
		local m = d --[[@as MexRegionDescription]]
		lines[#lines + 1] = { "Group", tostring(m.group) }
		if m.spots then
			lines[#lines + 1] = {
				"Metal spots",
				m.spots .. (m.spots > 0 and string.format(" (%.1f metal/s with T1 mexes)", m.worth or 0) or ""),
			}
		end
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
R.validated = { revision = -1, count = -1, lines = {}, byRegion = {}, ofSet = {} }
function R.validate()
	local was = R.validated
	if was.revision == R.revision and was.count == R.api.Revision() then
		return was
	end
	local finder = WG.resource_spot_finder
	local starts = #R.held("start")
	---@type RegionMap
	local map = {
		spots = finder and not finder.isMetalMap and finder.metalSpotsList or nil,
		starts = starts > 0 and starts or nil,
	}
	local lines, byRegion, ofSet = {}, {}, {}
	for _, typeKey in ipairs(R.ORDER) do
		if #R.api.All(typeKey) > 0 then
			for _, problem in ipairs(R.api.Problems(typeKey, map)) do
				lines[#lines + 1] = R.api.ProblemLine(problem)
				if problem.region then
					byRegion[problem.region] = byRegion[problem.region] or {}
					table.insert(byRegion[problem.region], problem.message)
				else
					ofSet[typeKey] = ofSet[typeKey] or {}
					table.insert(ofSet[typeKey], { message = problem.message, at = problem.at })
				end
			end
		end
	end
	R.validated = {
		revision = R.revision,
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
		byIndex[i] = validated.byRegion[R.api.Get(region.id or "") or region]
	end
	for _, region in ipairs(R.held("start")) do
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

-- What is written is what regions holds: a form's edits are not in the file until the form is saved.
function R.save(explicitPath)
	local count = #R.api.All()
	local unsaved = R.form ~= nil and R.form.changed
	if count == 0 then
		Echo("[Regions] No regions to save.")
		return false, "no regions to save"
	end
	if not explicitPath then
		Spring.CreateDir(REGIONS_SAVE_DIR)
		explicitPath = REGIONS_SAVE_DIR .. getMapName() .. ".lua"
	end
	local ok, reason = R.api.SaveLayoutFile(explicitPath, Game.mapSizeX, Game.mapSizeZ, "Map: " .. getMapName())
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
			.. (unsaved and "; the open form's edits are not saved yet" or "")
			.. (
				#problems > 0
					and (", with " .. #problems .. " problem" .. (#problems == 1 and "" or "s") .. " still to fix")
				or ""
			)
	)
	return true
end

-- What the file holds replaces what regions holds; what does not check out is left out, and said.
function R.load(explicitPath)
	explicitPath = explicitPath or (REGIONS_SAVE_DIR .. getMapName() .. ".lua")
	if not VFS.FileExists(explicitPath, VFS.RAW_FIRST) then
		Echo("[Regions] No saved regions found: " .. explicitPath)
		return false
	end
	R.closeForm()
	local regions, reason, refused = R.api.LoadLayoutFile(explicitPath, Game.mapSizeX, Game.mapSizeZ)
	if not regions then
		Echo("[Regions] Could not load " .. explicitPath .. (reason and (": " .. reason) or ""))
		return false
	end
	for i = #undoHistory, 1, -1 do
		if undoHistory[i].mode == "startbox" then
			table.remove(undoHistory, i)
		end
	end
	boxUndo.redo = {}
	renumberBoxAllyTeams()
	R.applyMode()
	Echo("[Regions] Loaded " .. #regions .. " region(s) from: " .. explicitPath)
	R.echoRefusals(refused, "Left out")
	if refused and #refused > 0 then
		R.say("Loaded " .. #regions .. "; left out " .. #refused .. " that do not check out (see the chat for why)")
	end
	return true
end

-- The form, as the panel shows it.
function R.selectedRecord()
	local form = R.form
	if not form then
		return nil
	end
	local box = form.region
	local named = R.selectedIdx and R.names()[R.selectedIdx] or nil
	return {
		idx = R.selectedIdx,
		id = form.id,
		isNew = form.id == nil,
		changed = form.changed,
		type = box.type,
		team = box.team,
		hasBox = box.vertices ~= nil and #box.vertices >= 3,
		fields = R.fieldValues(box),
		derived = named and named.derived and { name = named.name } or nil,
		problems = R.messages(form.problems),
		vertexCount = #box.vertices,
		facts = R.factsFor(R.type .. ":" .. tostring(form.id) .. ":" .. R.revision, function()
			return box.type == "start" and R.startFacts(box) or R.facts(box)
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
		positions = seats(),
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
		geometry = R.geometry,
		editMode = R.editMode,
		gatheredSpots = #R.radialPending,
		geometries = R.geometryChoices(),
		view = R.form and "form" or "list",
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
				local prevCount = #seats()
				if tb and stb and stb.symmetryActive and tb.getSymmetricPositions then
					local copies = tb.getSymmetricPositions(wx, wz, 0)
					for _, p in ipairs(copies) do
						addPosition(p.x, p.z, nextAllyTeam, nextTeamSlot)
						advanceNextPlayer()
					end
				elseif addPosition(wx, wz, nextAllyTeam, nextTeamSlot) then
					advanceNextPlayer()
				end
				local added = #seats() - prevCount
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
					removeLastSeat()
				end
				nextAllyTeam = entry.prevNextAllyTeam or 1
				nextTeamSlot = entry.prevNextTeamSlot or 1
				table.remove(undoHistory, at)
			end
			if #seats() == 0 then
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
			if tb and stb and stb.gridSnap and tb.snapWorld then
				sx, sz = tb.snapWorld(wx, wz, shapeRotation)
			end
			local prevNext = nextAllyTeam
			local prevNextSlot = nextTeamSlot
			local prevCount = #seats()
			if tb and stb and stb.symmetryActive and tb.getSymmetricPositions then
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
			local added = #seats() - prevCount
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
				boxUndo.begin(ebi)
				boxEdgeDrag = { bi = ebi, edge = edge }
				dragStartX = mx
				dragStartY = my
				dragging = false
				return true
			end

			-- The list: a click on a start's position drags it, one commit per move; a click in a region opens a
			-- form on it. Nothing else is changed from the list.
			if not R.form then
				local nearIdx = R.type == "start" and findNearestPosition(wx, wz) or nil
				if nearIdx then
					dragIdx = nearIdx
					dragStartX = mx
					dragStartY = my
					dragging = false
					return true
				end
				local containBi = findBoxContaining(wx, wz)
				if containBi then
					R.select(containBi)
				end
				return true
			end

			-- Body drag: a click inside the form's region (and not on any handle/edge per the checks above) moves
			-- the whole of it.
			local containBi = findBoxContaining(wx, wz)
			if containBi and R.editable(startboxes[containBi]) then
				boxUndo.begin(containBi)
				boxBodyDrag = { bi = containBi, lastX = wx, lastZ = wz }
				dragStartX = mx
				dragStartY = my
				dragging = false
				return true
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
				if tb and stb and stb.gridSnap and tb.snapWorld then
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
					if box and handles and #handles > 3 then
						boxUndo.push("edit", box)
						table.remove(handles, dvi)
						if box.kind == "spline" then
							retessellateSpline(box)
						end
						invalidateBoxFill(box)
						R.touched()
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
			local seat = wx and seats()[dragIdx] or nil
			if wx and seat then
				local cx, cz = clampToMap(wx, wz)
				-- Only move if the new spot is commander-spawnable; else keep position (silent).
				if isPlaceableForCommander(cx, cz) and (seat.region.positions or {})[seat.i] then
					R.commit(seat.region, function(copy)
						copy.positions = copy.positions or {}
						copy.positions[seat.i] = { x = cx, z = cz }
						keepShape(copy)
					end)
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
			if tb and stb and stb.gridSnap and tb.snapWorld then
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
				-- An axis-aligned rectangle: edge-drag only, no vertex handles.
				finishStartbox(nil, "box")
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
				R.setFormShape({ vertices = {}, controls = controls, kind = "spline" })
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
	if key == 27 and not (drawingBox or boxRectActive or freeDrawActive or #R.radialPending > 0) and R.form then
		R.cancelForm()
		return true
	end
	if key == 27 and (drawingBox or boxRectActive or freeDrawActive or #R.radialPending > 0) then
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
			boxUndo.push("edit", box)
			strengthEdit.setBox(box, handles[strengthEdit.selVert].strength or 0)
			R.touched()
			return true
		end
	end

	-- Ctrl+Z undoes, Ctrl+Shift+Z redoes: the editor's convention (the clone tool and the
	-- terraform brush bind redo the same way).
	if key == 122 and mods.ctrl then -- 122 = 'z'
		R.step(not mods.shift)
		return true
	end
	return false
end

-- What regions said of the form's region, on the map: each problem where its shape says, else at the region's middle.
function R.drawProblemLabels()
	local form = R.form
	if not form or #form.problems == 0 then
		return
	end
	local verts = form.region.vertices or {}
	local cx, cz = 0.0, 0.0
	for _, v in ipairs(verts) do
		cx, cz = cx + v.x, cz + v.z
	end
	if #verts > 0 then
		cx, cz = cx / #verts, cz / #verts
	end
	local stacked = {} ---@type table<string, integer>
	for _, problem in ipairs(form.problems) do
		local at = problem.at or (#verts > 0 and { x = cx, z = cz }) or nil
		if at then
			local sx, sy, sz = WorldToScreenCoords(at.x, GetGroundHeight(at.x, at.z) or 0, at.z)
			if sx and sy and sz and sz > 0 and sz < 1 then
				local key = math_floor(sx) .. ":" .. math_floor(sy)
				local row = stacked[key] or 0
				stacked[key] = row + 1
				glColor(0, 0, 0, 0.8)
				glText(problem.message, sx + 1, sy - 1 - row * 18, 15, "cdo")
				glColor(R.INVALID[1], R.INVALID[2], R.INVALID[3], 1)
				glText(problem.message, sx, sy - row * 18, 15, "cdo")
			end
		end
	end
end

-- One step back, or forward again. Only entries from the current submode are eligible: positions and startboxes
-- coexist, so undoing in one submode must not silently rewind the other. With a form open, only the form's own.
---@param isUndo boolean
function R.step(isUndo)
	local fromStack = isUndo and undoHistory or boxUndo.redo
	local toStack = isUndo and boxUndo.redo or undoHistory
	local at
	for i = #fromStack, 1, -1 do
		local entry = fromStack[i]
		local here = (entry.mode or "express") == subMode and (entry.region or "start") == R.type
		if here and (entry.mode ~= "startbox" or entry.form == R.form) then
			at = i
			break
		end
	end
	if at == nil then
		return
	end
	local entry = table.remove(fromStack, at)
	if entry.mode == "startbox" then
		table.insert(toStack, boxUndo.apply(entry))
	else
		-- Positions rewind by count, the way they always have; the counter pair is
		-- restored from the snapshot rather than guessed at.
		for _ = 1, (entry.count or 0) do
			removeLastSeat()
		end
		nextAllyTeam = entry.prevNextAllyTeam or 1
		nextTeamSlot = entry.prevNextTeamSlot or 1
	end
end

function R.undo()
	R.step(true)
end

function R.redo()
	R.step(false)
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
	local cx, cz = 0.0, 0.0
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
-- The fills live beside the regions, never on them: a region regions holds is its own, and the copy that replaces it
-- on a commit is a new table. A fill whose region has left the list is freed on the next draw.
R.fills = {} ---@type table<table, { list: integer|nil, dirty: boolean|nil, lastFrame: integer|nil }>
ensureBoxFillList = function(box)
	local fill = R.fills[box]
	if not fill then
		fill = {}
		R.fills[box] = fill
	end
	if fill.list and not fill.dirty then
		return fill.list
	end
	-- During drag, large polygon/spline shapes (>12 verts) defer the expensive triangulation
	-- to MouseRelease — buildPolygonFillList does O(N^2) fan subdivision that can burn thousands
	-- of allocs per frame on a freedraw spline. Small shapes (boxes — 4 verts — and simple polys)
	-- rebuild every frame so the fill follows the drag in real time. We also coarsen the cell
	-- size during drag so even mid-size polys stay responsive.
	local verts = box.vertices
	local nv = verts and #verts or 0
	if isDraggingBox and fill.list then
		if nv > 12 then
			return fill.list
		end
		-- Throttle rebuild rate during drag so the GL display list isn't recreated every frame
		-- (each rebuild allocates ~N² entries in the row scratch buffer + one new GL list, which
		-- previously triggered the 1.2GB LuaRAM emergency GC during edge drags). Visually this
		-- is ~15Hz updates instead of ~60Hz — still reads as live without the alloc storm.
		local frame = GetDrawFrame and GetDrawFrame() or 0
		if fill.lastFrame and (frame - fill.lastFrame) < BOX_FILL_DRAG_INTERVAL then
			return fill.list
		end
		fill.lastFrame = frame
	end
	if fill.list then
		glDeleteList(fill.list)
		fill.list = nil
	end
	local cell = isDraggingBox and (BOX_FILL_CELL * 3) or BOX_FILL_CELL
	fill.list = buildPolygonFillList(verts, BOX_FILL_LIFT, cell)
	fill.dirty = isDraggingBox -- final crisp rebuild on release
	if not isDraggingBox then
		fill.lastFrame = nil
	end
	return fill.list
end

invalidateBoxFill = function(box)
	local fill = box and R.fills[box]
	if fill then
		fill.dirty = true
	end
end

freeBoxFillList = function(box)
	local fill = box and R.fills[box]
	if fill then
		if fill.list then
			glDeleteList(fill.list)
		end
		R.fills[box] = nil
	end
end

---@param drawn table[] the regions drawn this frame
function R.sweepFills(drawn)
	local keep = {}
	for _, box in ipairs(drawn) do
		keep[box] = true
	end
	for box in pairs(R.fills) do
		if not keep[box] then
			freeBoxFillList(box)
		end
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
			for i, pos in ipairs(seats()) do
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
	for i, pos in ipairs(seats()) do
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
		if tb and stb and stb.symmetryActive and tb.getSymmetricPositions then
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

	R.sweepFills(startboxes)
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
			if not R.editable(box) then
				-- Handles are the form's alone: a region regions holds is edited through a form opened on it.
			elseif box.kind == "box" and #verts == 4 then
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
---@type table<integer, string>
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
	local idx = (at % #TEAM_NAMES) + 1
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
	local label = "Team " .. tostring(allyTeamNum + 1)

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
	for i, pos in ipairs(seats()) do
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
				local cx, cz = 0.0, 0.0
				for _, v in ipairs(verts) do
					cx, cz = cx + v.x, cz + v.z
				end
				cx, cz = cx / #verts, cz / #verts
				local sx, sy, sz = WorldToScreenCoords(cx, GetGroundHeight(cx, cz) or 0, cz)
				if sz and sz > 0 and sz < 1 then
					local fields = region --[[@as table<string, any>]]
					local label = region.name or "?"
					if fields.group then
						label = label .. " (" .. fields.group .. ")"
					end
					if fields.team then
						label = R.teamLabel(fields.team) .. " · " .. label
					end
					local alpha = (bi == R.selectedIdx) and 1.0 or 0.75
					glColor(1, 1, 1, alpha)
					glText(label, sx, sy, (bi == R.selectedIdx) and 16 or 14, "cdo")
				end
			end
		end
	end

	R.drawProblemLabels()

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
				local color = getColorForAllyTeam(box.team)
				drawScreenBadge(
					bestSx,
					bestSy + 28,
					color,
					box.team,
					getTeamName(box.team) .. " BOX",
					box.team,
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
		setGeometry = R.setGeometry,
		setEditMode = R.setEditMode,
		removeArea = R.removeArea,
		setStrategy = R.setStrategy,
		setPlacing = R.setPlacing,
		selectRegion = R.select,
		selectStart = R.selectStart,
		openNew = R.openNew,
		openEdit = R.openEdit,
		setFormField = R.setFormField,
		submitForm = R.submitForm,
		cancelForm = R.cancelForm,
		deleteForm = R.deleteForm,
		exportLayout = R.exportLayout,
		encodeLayout = R.encodeLayout,
		copyLayout = R.copyLayout,
		saveRegions = R.save,
		lookAt = R.lookAt,
		loadRegions = R.load,
		clearAllPositions = clearAllPositions,
		addPosition = addPosition,
		placeRandomPositions = placeRandomPositions,
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
	for box in pairs(R.fills) do
		freeBoxFillList(box)
	end
end
