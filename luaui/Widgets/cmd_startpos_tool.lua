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
local glBillboard     = gl.Billboard
local glText          = gl.Text
local glBeginEnd      = gl.BeginEnd
local glVertex        = gl.Vertex
local GL_LINE_LOOP    = GL.LINE_LOOP
local GL_LINE_STRIP   = GL.LINE_STRIP
local GL_LINES        = GL.LINES

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
local MAX_POSITIONS       = 16     -- max allyteams
local SAVE_DIR            = "Terraform Brush/StartPositions/"
local STARTBOX_SAVE_DIR   = "Terraform Brush/Startboxes/"
local VERTEX_PICK_DIST_SQ = 60*60  -- world distance^2 to pick a startbox vertex

-- Team colors matching game_autocolors.lua FFA palette (0-1 float RGBA)
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
}

-- ============================================================
-- State
-- ============================================================
local active     = false
local subMode    = "express"  -- "express" | "shape" | "startbox"
local positions  = {}         -- { {x=, z=, allyTeam=}, ... }
local nextAllyTeam = 1        -- next allyteam to place in express mode
local numAllyTeams = 2        -- configurable count

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
local drawingBox     = false
local currentBoxVerts = {}
local boxDragIdx     = nil  -- which vertex is being dragged
local boxDragBoxIdx  = nil  -- which box
local nextBoxAllyTeam = 1

-- Drag state
local dragging       = false
local dragIdx        = nil  -- which position index is being dragged
local dragStartX     = nil
local dragStartY     = nil  -- screen coords at mouse-down
local mouseDownWorldX = nil
local mouseDownWorldZ = nil

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

local function addPosition(x, z, allyTeam)
	if #positions >= MAX_POSITIONS then return false end
	x, z = clampToMap(x, z)
	local y = GetGroundHeight(x, z) or 0
	positions[#positions + 1] = {x = x, z = z, y = y, allyTeam = allyTeam}
	return true
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
end

local function placeShapePositions(cx, cz)
	local pts = generateShapePositions(cx, cz)
	for i, pt in ipairs(pts) do
		local at = ((i - 1) % numAllyTeams) + 1
		addPosition(pt.x, pt.z, at)
	end
end

-- Place all shape positions assigning every slot to the same allyTeam (used by symmetric copies).
local function placeShapePositionsForTeam(cx, cz, allyTeam)
	local pts = generateShapePositions(cx, cz)
	for _, pt in ipairs(pts) do
		addPosition(pt.x, pt.z, allyTeam)
	end
end

local function placeRandomPositions(cx, cz)
	local pts = generateRandomPositions(cx, cz)
	for i, pt in ipairs(pts) do
		local at = ((i - 1) % numAllyTeams) + 1
		addPosition(pt.x, pt.z, at)
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

local function removeLastStartbox()
	if #startboxes > 0 then
		table.remove(startboxes, #startboxes)
		if nextBoxAllyTeam > 1 then
			nextBoxAllyTeam = nextBoxAllyTeam - 1
		end
	end
end

local function clearAllStartboxes()
	startboxes = {}
	currentBoxVerts = {}
	drawingBox = false
	nextBoxAllyTeam = 1
end

local function findNearestBoxVertex(wx, wz)
	for bi, box in ipairs(startboxes) do
		for vi, v in ipairs(box.vertices) do
			if distSq(wx, wz, v.x, v.z) < VERTEX_PICK_DIST_SQ then
				return bi, vi
			end
		end
	end
	return nil, nil
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
		lines[#lines + 1] = string.format("  [%d] = { x = %d, z = %d, allyTeam = %d },", i, math_floor(pos.x), math_floor(pos.z), pos.allyTeam)
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
		clearAllPositions()
		for i, pos in ipairs(data) do
			addPosition(pos.x, pos.z, pos.allyTeam or i)
		end
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
	numAllyTeams = math_max(2, math_min(MAX_POSITIONS, n))
end

local function getState()
	return {
		active       = active,
		subMode      = subMode,
		positions    = positions,
		numAllyTeams = numAllyTeams,
		nextAllyTeam = nextAllyTeam,
		shapeType    = shapeType,
		shapeRadius  = shapeRadius,
		shapeRotation = shapeRotation,
		shapeCount   = shapeCount,
		startboxes   = startboxes,
		drawingBox   = drawingBox,
		currentBoxVerts = currentBoxVerts,
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
				if stb and stb.symmetryActive and tb.getSymmetricPositions then
					local copies = tb.getSymmetricPositions(wx, wz, 0)
					for k, p in ipairs(copies) do
						local at = ((nextAllyTeam - 1 + k - 1) % numAllyTeams) + 1
						addPosition(p.x, p.z, at)
					end
					nextAllyTeam = ((nextAllyTeam - 1 + #copies) % numAllyTeams) + 1
				elseif addPosition(wx, wz, nextAllyTeam) then
					nextAllyTeam = (nextAllyTeam % numAllyTeams) + 1
				end
			end
			return true
		elseif button == 3 then
			-- RMB: Remove nearest position
			if removeNearestPosition(wx, wz) then
				-- Adjust nextAllyTeam if needed
				if #positions == 0 then
					nextAllyTeam = 1
				end
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
			if stb and stb.symmetryActive and tb.getSymmetricPositions then
				local copies = tb.getSymmetricPositions(sx, sz, shapeRotation)
				if copies and #copies > 0 then
					for k, p in ipairs(copies) do
						local at = ((nextAllyTeam - 1 + k - 1) % numAllyTeams) + 1
						placeShapePositionsForTeam(p.x, p.z, at)
					end
					nextAllyTeam = ((nextAllyTeam - 1 + #copies) % numAllyTeams) + 1
				else
					placeShapePositions(sx, sz)
				end
			else
				placeShapePositions(sx, sz)
			end
			return true
		elseif button == 3 then
			-- RMB: Remove nearest
			removeNearestPosition(wx, wz)
			return true
		end

	elseif subMode == "startbox" then
		if button == 1 then
			-- Check for vertex drag first
			local bi, vi = findNearestBoxVertex(wx, wz)
			if bi and vi then
				boxDragIdx = vi
				boxDragBoxIdx = bi
				dragStartX = mx
				dragStartY = my
				dragging = false
				return true
			end
			-- Start/continue drawing a box
			if not drawingBox then
				drawingBox = true
				currentBoxVerts = {}
			end
			addStartboxVertex(wx, wz)
			return true
		elseif button == 3 then
			-- RMB: Finish current box or remove last box
			if drawingBox and #currentBoxVerts >= 3 then
				finishStartbox()
			elseif not drawingBox then
				removeLastStartbox()
			else
				-- Cancel current drawing
				currentBoxVerts = {}
				drawingBox = false
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
				positions[dragIdx].x, positions[dragIdx].z = clampToMap(wx, wz)
				positions[dragIdx].y = GetGroundHeight(wx, wz) or 0
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
			local wx, wz = getWorldMousePosition()
			if wx and startboxes[boxDragBoxIdx] then
				local v = startboxes[boxDragBoxIdx].vertices[boxDragIdx]
				if v then
					v.x, v.z = clampToMap(wx, wz)
				end
			end
			return true
		end
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

	if subMode == "startbox" and boxDragIdx then
		boxDragIdx = nil
		boxDragBoxIdx = nil
		dragging = false
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

-- ============================================================
-- Drawing
-- ============================================================

-- Helper: draw a sleek start-position marker (outer ring + inner pip + subtle fill)
local function drawStartPosMarker(px, pz, color, alpha)
	local gy = GetGroundHeight(px, pz) or 0
	local a = alpha or 1.0

	-- Subtle filled disc
	glColor(color[1], color[2], color[3], 0.12 * a)
	glDrawGroundCircle(px, gy, pz, MARKER_RADIUS, MARKER_SEGMENTS)

	-- Bright outer ring
	glColor(color[1], color[2], color[3], 0.85 * a)
	glLineWidth(3.0)
	glDrawGroundCircle(px, gy, pz, MARKER_RADIUS, MARKER_SEGMENTS)

	-- Thin secondary ring (gives depth)
	glColor(color[1], color[2], color[3], 0.35 * a)
	glLineWidth(1.0)
	glDrawGroundCircle(px, gy, pz, MARKER_RADIUS * 0.72, MARKER_SEGMENTS)

	-- Central pip
	glColor(color[1], color[2], color[3], 0.95 * a)
	glLineWidth(2.0)
	glDrawGroundCircle(px, gy, pz, MARKER_RADIUS * 0.18, 12)
end

function widget:DrawWorld()
	if not active then return end

	local wx, wz = getWorldMousePosition()

	-- Draw placed start positions
	for i, pos in ipairs(positions) do
		local color = getColorForAllyTeam(pos.allyTeam)
		drawStartPosMarker(pos.x, pos.z, color, 1.0)
	end

	-- Draw shape preview in shape mode
	if subMode == "shape" and wx then
		local previewPts = generateShapePositions(wx, wz)
		-- Shape radius outline (dashed feel via thin + transparent)
		glColor(1, 1, 1, 0.18)
		glLineWidth(1.0)
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

		-- Draw preview markers
		for i, pt in ipairs(previewPts) do
			local at = ((i - 1) % numAllyTeams) + 1
			local color = getColorForAllyTeam(at)
			drawStartPosMarker(pt.x, pt.z, color, 0.55)
		end
	end

	-- Draw express mode cursor indicator
	if subMode == "express" and wx and not dragIdx then
		local tb = WG.TerraformBrush
		local stb = tb and tb.getState and tb.getState() or nil
		if stb and stb.symmetryActive and tb.getSymmetricPositions then
			-- Show ghost rings for all symmetric copies, each colored by its assigned team
			local copies = tb.getSymmetricPositions(wx, wz, 0)
			for k, p in ipairs(copies) do
				local at = ((nextAllyTeam - 1 + k - 1) % numAllyTeams) + 1
				local color = getColorForAllyTeam(at)
				local gy = GetGroundHeight(p.x, p.z) or 0
				glColor(color[1], color[2], color[3], 0.30)
				glLineWidth(2.0)
				glDrawGroundCircle(p.x, gy, p.z, MARKER_RADIUS, MARKER_SEGMENTS)
				glColor(color[1], color[2], color[3], 0.15)
				glLineWidth(1.0)
				glDrawGroundCircle(p.x, gy, p.z, MARKER_RADIUS * 0.18, 12)
			end
		else
			local color = getColorForAllyTeam(nextAllyTeam)
			local gy = GetGroundHeight(wx, wz) or 0
			-- Ghost ring at cursor
			glColor(color[1], color[2], color[3], 0.30)
			glLineWidth(2.0)
			glDrawGroundCircle(wx, gy, wz, MARKER_RADIUS, MARKER_SEGMENTS)
			glColor(color[1], color[2], color[3], 0.15)
			glLineWidth(1.0)
			glDrawGroundCircle(wx, gy, wz, MARKER_RADIUS * 0.18, 12)
		end
	end

	-- Draw startboxes
	for _, box in ipairs(startboxes) do
		local color = getColorForAllyTeam(box.allyTeam)
		local verts = box.vertices
		if #verts >= 3 then
			-- Draw polygon outline
			glColor(color[1], color[2], color[3], 0.7)
			glLineWidth(2.5)
			glBeginEnd(GL_LINE_LOOP, function()
				for _, v in ipairs(verts) do
					local gy = GetGroundHeight(v.x, v.z) or 0
					glVertex(v.x, gy + 5, v.z)
				end
			end)
			-- Draw filled with transparency
			glColor(color[1], color[2], color[3], 0.12)
			glBeginEnd(GL_LINE_LOOP, function()
				for _, v in ipairs(verts) do
					local gy = GetGroundHeight(v.x, v.z) or 0
					glVertex(v.x, gy + 3, v.z)
				end
			end)
			-- Draw vertex markers
			for _, v in ipairs(verts) do
				local vy = GetGroundHeight(v.x, v.z) or 0
				glColor(color[1], color[2], color[3], 0.9)
				glDrawGroundCircle(v.x, vy, v.z, 30, 12)
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
		-- Draw vertex dots
		for _, v in ipairs(currentBoxVerts) do
			local gy = GetGroundHeight(v.x, v.z) or 0
			glColor(color[1], color[2], color[3], 0.8)
			glDrawGroundCircle(v.x, gy, v.z, 30, 12)
		end
		-- Line from last vertex to mouse
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

-- Minimum screen-space padding between marker top and text bottom
local LABEL_PAD = 6

function widget:DrawScreenEffects()
	if not active then return end

	-- Draw position labels on screen
	for i, pos in ipairs(positions) do
		local sx, sy, sr, vis = getScreenMarker(pos.x, pos.z, MARKER_RADIUS)
		if vis then
			local color = getColorForAllyTeam(pos.allyTeam)
			local atLabel   = "Team " .. pos.allyTeam
			local nameLabel = "Player " .. i .. " (" .. getTeamName(pos.allyTeam) .. ")"
			-- Position text above the marker's screen-space top edge
			local baseY = sy + sr + LABEL_PAD
			-- Shadow
			glColor(0, 0, 0, 0.8)
			glText(nameLabel, sx + 1, baseY - 1, 18, "cn")
			glText(atLabel, sx + 1, baseY + 17, 28, "cn")
			-- Foreground
			glColor(color[1] * 0.7 + 0.3, color[2] * 0.7 + 0.3, color[3] * 0.7 + 0.3, 0.85)
			glText(nameLabel, sx, baseY, 18, "cn")
			glColor(color[1], color[2], color[3], 1.0)
			glText(atLabel, sx, baseY + 18, 28, "cn")
		end
	end

	-- Draw startbox allyteam labels (centroid, no marker radius to dodge)
	for _, box in ipairs(startboxes) do
		if #box.vertices >= 3 then
			local cx, cz = 0, 0
			for _, v in ipairs(box.vertices) do
				cx = cx + v.x
				cz = cz + v.z
			end
			cx = cx / #box.vertices
			cz = cz / #box.vertices
			local cy = GetGroundHeight(cx, cz) or 0
			local bsx, bsy, bsz = WorldToScreenCoords(cx, cy, cz)
			if bsz and bsz > 0 and bsz < 1 then
				local color = getColorForAllyTeam(box.allyTeam)
				local atLabel = "Team " .. box.allyTeam
				local nameLabel = getTeamName(box.allyTeam) .. " Box"
				glColor(0, 0, 0, 0.8)
				glText(nameLabel, bsx + 1, bsy - 1, 16, "cn")
				glText(atLabel, bsx + 1, bsy + 15, 24, "cn")
				glColor(color[1] * 0.7 + 0.3, color[2] * 0.7 + 0.3, color[3] * 0.7 + 0.3, 0.85)
				glText(nameLabel, bsx, bsy, 16, "cn")
				glColor(color[1], color[2], color[3], 1.0)
				glText(atLabel, bsx, bsy + 16, 24, "cn")
			end
		end
	end

	-- Draw shape preview labels
	if subMode == "shape" then
		local wx, wz = getWorldMousePosition()
		if wx then
			local previewPts = generateShapePositions(wx, wz)
			for i, pt in ipairs(previewPts) do
				local at = ((i - 1) % numAllyTeams) + 1
				local psx, psy, psr, pvis = getScreenMarker(pt.x, pt.z, MARKER_RADIUS * 0.72)
				if pvis then
					local color = getColorForAllyTeam(at)
					local label = "Team " .. at
					local baseY = psy + psr + LABEL_PAD
					glColor(0, 0, 0, 0.6)
					glText(label, psx + 1, baseY - 1, 22, "cn")
					glColor(color[1], color[2], color[3], 0.7)
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
		setSubMode          = setSubMode,
		setShape            = setShape,
		setRadius           = setRadius,
		setRotation         = setRotation,
		setShapeCount       = setShapeCount,
		setNumAllyTeams     = setNumAllyTeams,
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
end
