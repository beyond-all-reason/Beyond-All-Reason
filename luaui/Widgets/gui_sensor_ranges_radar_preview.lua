local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Sensor Ranges Radar Preview",
		desc = "Engine-accurate radar coverage preview, drawn as an animated grid of cubes (GL4)",
		author = "Beherith",
		date = "2021.07.12",
		license = "GNU GPL v2",
		layer = 0,
		enabled = true,
	}
end

------------------------------------------------------------------------------------------------
-- How it works
--  0. Mip pass (once a second while shown): rebuilds the engine's radar-mip-level heightmap
--     (radarMipLevel from modrules, 3 => 64 elmo cells) from the corner heightmap.
--  1. Coverage pass (only when the emitter's cell or bucketed height changes): replicates the
--     engine's radar LOS (LosMap.cpp: midpoint-circle disk, rays, CastLos angle test) per radar cell.
--  2. Smoothing pass (every frame, a few thousand texels): a ping-ponged state texture eases towards
--     the coverage, so cubes rise/sink smoothly instead of popping while dragging.
--  3. Cube pass: one instanced draw of a unit cube per 16 elmo grid cell. The vertex shader looks up
--     the radar cell the cube is in, samples the heightmap and animates the cube; the fragment shader
--     does per-face shading and zoom-independent edge lines. Only cells under the screen's ground
--     footprint are drawn; flat shapes draw a single quad per cell. Optionally (LOD_MAX_INSTANCES) the
--     grid thins to double spacing when more cubes than that would be on screen.
------------------------------------------------------------------------------------------------

-- Tunables
local CUBE_SPACING = 13 -- elmos between cube centers; must divide the radar cell size
local CUBE_WIDTH = 4.8 -- elmos
local CUBE_SINK = 2 -- elmos the cube base is pushed below ground, so cubes never float on slopes
local CUBE_SHAPE = "tile" -- default shape, see CUBE_SHAPES; switch at runtime with WG.radarPreview.setShape(name)
local CUBE_SHAPES = {
	-- height at full coverage (elmo), lift of the top face above ground (elmo), conform = top face tilts with the terrain
	cube = { height = 6, lift = 0, conform = 0 },
	slab = { height = 3, lift = 0, conform = 0 },
	tile = { height = 0.5, lift = 0.5, conform = 0 },
	flat = { height = 0, lift = 1.5, conform = 1 }, -- flat square
}
local LIFT_PER_DISTANCE = 0.001 -- extra lift per elmo of camera distance, keeps flat shapes above the terrain LOD mesh
local COVERAGE_SMOOTH = false -- true: blend coverage between radar cells (prettier), false: exact engine cells (blocky)
local COVERAGE_REFRESH_SECONDS = 1.0 -- periodic heightmap/coverage rebuild so terraforming shows up
local SMOOTH_RATE = 14 -- 1/s, how fast the cubes follow coverage changes (higher = snappier)
local LOD_MAX_INSTANCES = 0 -- > 0: thin the grid to double spacing once more cubes than this are on screen (cubes visibly fill in/out with zoom; try 50000 on integrated graphics)
local FOOTPRINT_MARGIN = 48 -- elmos of slack around the screen's ground footprint
local MAX_RADIUS_CELLS = 160 -- sanity limit of the radar radius in cells (160 * 64 = 10240 elmo)
local RAY_SSBO_BINDING = 5 -- shader storage binding of the per-radius ray table (4, 6, 7 are used elsewhere in BAR)

-- With deferred map/model rendering the cubes are occluded via the g-buffer depths (terrain and units)
-- instead of the depth buffer, so grass and other widget geometry drawn with depth writes can't hide them.
local hasMapDepth = Spring.GetConfigString("AllowDeferredMapRendering") == "1"
local hasModelDepth = hasMapDepth and Spring.GetConfigString("AllowDeferredModelRendering") == "1"

local shaderConfig = {
	TERRAIN_DEPTH_TEST = hasMapDepth and 1 or 0,
	MODEL_DEPTH_TEST = hasModelDepth and 1 or 0,
	MIN_COVERAGE = 0.04, -- cubes below this (smoothed) coverage are not drawn
	SWEEP_SPEED = 0.11, -- radar sweep revolutions per second
	SWEEP_TRAIL = 30.0, -- degrees: the trail fades out this far behind the sweep's leading edge
	SWEEP_BEAM = 9.0, -- degrees: width of the bright leading edge
	SWEEP_STRENGTH = 0.55, -- how much the sweep brightens/raises cubes
	SPAWN_SPEED = 2.5, -- radar ranges per second the spawn ripple travels outward
	SPAWN_BUMP = 0.25, -- width of the overshoot behind the ripple front, in radar ranges
	PULSE_SPACING = 180.0, -- elmos between the outward travelling wave rings
	PULSE_SPEED = 90.0, -- elmos per second the rings travel
	PULSE_POWER = 4.5, -- higher = narrower rings
	PULSE_STRENGTH = 1.0, -- how much the rings raise/brighten cubes
	EDGE_STRENGTH = 0.15, -- how much cubes at the coverage boundary (next to an uncovered radar cell) brighten; 0 disables
	RIM_STRENGTH = 0.25, -- how much the outermost ring of cubes brightens; 0 disables
	TILE_MAX_TILT = 20.0, -- degrees: flat tiles follow the terrain slope up to this angle
	TILE_CLIFF_START = 35.0, -- degrees: terrain steeper than this starts flattening the tiles again
	TILE_CLIFF_END = 55.0, -- degrees: terrain steeper than this gets flat tiles (cliffs)
	BASE_COLOR = "vec3(0.22, 0.85, 0.50)",
	HIGHLIGHT_COLOR = "vec3(0.65, 1.00, 0.80)",
	BASE_ALPHA = 0.4,
	LINE_ALPHA = 0.4, -- opacity of the cube edge lines
}

-- Engine radar model (rts/Sim/Misc/LosHandler.cpp, LosMap.cpp)
local RADAR_MIP_LEVEL = 3 -- modrules sensors.los.radarMipLevel; overridden below when the file can be read
do
	local modrules = VFS.LoadFile("gamedata/modrules.lua")
	local mip = modrules and modrules:match("radarMipLevel%s*=%s*(%d+)")
	if mip then
		RADAR_MIP_LEVEL = tonumber(mip)
	end
end
local SQUARE_SIZE = 8
local RADAR_CELL = SQUARE_SIZE * 2 ^ RADAR_MIP_LEVEL -- elmos per radar cell
local HEIGHT_BUCKET = 2 ^ (RADAR_MIP_LEVEL + 2) -- emitter heights are quantized to buckets of this size

-- Localized functions for performance
local mathFloor = math.floor
local mathCeil = math.ceil
local mathMin = math.min
local mathMax = math.max
local mathExp = math.exp
local mathSqrt = math.sqrt
local mathHuge = math.huge
local osClock = os.clock

-- Localized Spring API for performance
local spGetUnitDefID = Spring.GetUnitDefID
local spEcho = Spring.Echo
local spGetActiveCommand = Spring.GetActiveCommand
local spGetMouseState = Spring.GetMouseState
local spTraceScreenRay = Spring.TraceScreenRay
local spGetPixelDir = Spring.GetPixelDir
local spGetUnitPosition = Spring.GetUnitPosition
local spGetGroundHeight = Spring.GetGroundHeight
local spGetCameraPosition = Spring.GetCameraPosition
local spGetGroundExtremes = Spring.GetGroundExtremes
local spGetViewGeometry = Spring.GetViewGeometry
local spGetDrawFrame = Spring.GetDrawFrame

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable
local GL_R16F = 0x822D
local GL_R32F = 0x822E
local GL_RG16F = 0x822F

-- cmdID (-unitDefID) -> radar parameters for buildable radar structures
local radarDefs = {}
do
	local referenceRange = (UnitDefNames.armrad and UnitDefNames.armrad.radarDistance) or 2100
	local minRange = referenceRange * 0.9
	for unitDefID, unitDef in pairs(UnitDefs) do
		if unitDef.isBuilding and unitDef.radarDistance and unitDef.radarDistance >= minRange then
			local dims = Spring.GetUnitDefDimensions(unitDefID)
			-- ILosType::GetRadius: (radarDistance / SQUARE_SIZE) >> radarMipLevel, integer arithmetic
			local radiusCells = mathFloor(mathFloor(unitDef.radarDistance / SQUARE_SIZE) / 2 ^ RADAR_MIP_LEVEL)
			radarDefs[-unitDefID] = {
				radiusCells = mathMin(radiusCells, MAX_RADIUS_CELLS),
				emitHeight = unitDef.radarEmitHeight or 0,
				midY = (dims and dims.midy) or 0, -- unit->midPos.y - unit->pos.y
			}
		end
	end
end

local mipShader = nil
local coverageShader = nil
local smoothShader = nil
local cubeShader = nil
local passVAO = nil
local cubeVAO = nil
local tileVAO = nil -- just the top face, for flat shapes (6x fewer triangles, 2x fewer vertices)
local CUBE_INDEX_COUNT = 36 -- 6 faces x 2 triangles x 3 vertices
local TILE_INDEX_COUNT = 6

local mipTex = nil -- radar-cell heightmap of the whole map
local mipUpdatedAt = -mathHuge
local sets = {} -- radius in cells -> coverage/state textures and grid dimensions
local mousepos = { 0, 0, 0 }
local selectedRadarUnitID = false
local shape = CUBE_SHAPES[CUBE_SHAPE] or CUBE_SHAPES.cube

-- per-frame bookkeeping
local lastDrawFrame = -10
local lastDrawTime = 0
local lastRadius = nil
local spawnStart = 0

local passVsPath = "LuaUI/Shaders/sensor_ranges_radar_preview_pass.vert.glsl"

local mipShaderCache = {
	vssrcpath = passVsPath,
	fssrcpath = "LuaUI/Shaders/sensor_ranges_radar_preview_mip.frag.glsl",
	shaderName = "radarPreviewMip GL4",
	uniformInt = {
		heightmapTex = 0,
	},
	uniformFloat = {
		mipParams = { 2 ^ RADAR_MIP_LEVEL, 0, 0, 0 },
	},
	shaderConfig = shaderConfig,
}

local coverageShaderCache = {
	vssrcpath = passVsPath,
	fssrcpath = "LuaUI/Shaders/sensor_ranges_radar_preview_coverage.frag.glsl",
	shaderName = "radarPreviewCoverage GL4",
	uniformInt = {
		mipHeightTex = 0,
	},
	uniformFloat = {
		losParams = { 0, 0, 1, 0 },
	},
	shaderConfig = shaderConfig,
}

local smoothShaderCache = {
	vssrcpath = passVsPath,
	fssrcpath = "LuaUI/Shaders/sensor_ranges_radar_preview_smooth.frag.glsl",
	shaderName = "radarPreviewSmooth GL4",
	uniformInt = {
		prevTex = 0,
		targetTex = 1,
	},
	uniformFloat = {
		smoothParams = { 0, 0, 1, 1 },
	},
	shaderConfig = shaderConfig,
}

local cubeShaderCache = {
	vssrcpath = "LuaUI/Shaders/sensor_ranges_radar_preview.vert.glsl",
	fssrcpath = "LuaUI/Shaders/sensor_ranges_radar_preview.frag.glsl",
	shaderName = "radarPreviewCubes GL4",
	uniformInt = {
		heightmapTex = 0,
		coverageTex = 1,
		mapDepths = hasMapDepth and 2 or nil,
		modelDepths = hasModelDepth and 3 or nil,
	},
	uniformFloat = {
		radarcenter_range = { 0, 0, 0, 2000 },
		gridParams = { RADAR_CELL, 1, CUBE_SPACING, 1 },
		lookupParams = { 0, 0, 1, 0 },
		shapeParams = { CUBE_WIDTH, 6, CUBE_SINK, 0 },
		animParams = { 0, 0, 0, 0 },
		windowParams = { 0, 0, 1, 1 },
	},
	shaderConfig = shaderConfig,
}

local function goodbye(reason)
	spEcho("Sensor Ranges Radar Preview widget exiting with reason: " .. reason)
	widgetHandler:RemoveWidget()
end

local function makeCubeVAO()
	local vertexVBO = gl.GetVBO(GL.ARRAY_BUFFER, false)
	local indexVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false)
	if not (vertexVBO and indexVBO) then
		return nil
	end

	-- unit cube: x,z in [-0.5, 0.5], y in [0, 1]; the 4th component is padding
	vertexVBO:Define(8, { { id = 0, name = "cubeVertex", size = 4 } })
	vertexVBO:Upload({
		-0.5, 0, -0.5, 0, --0
		0.5, 0, -0.5, 0, --1
		0.5, 0, 0.5, 0, --2
		-0.5, 0, 0.5, 0, --3
		-0.5, 1, -0.5, 0, --4
		0.5, 1, -0.5, 0, --5
		0.5, 1, 0.5, 0, --6
		-0.5, 1, 0.5, 0, --7
	})

	-- counter-clockwise seen from outside (front faces for GL.BACK culling)
	indexVBO:Define(CUBE_INDEX_COUNT)
	indexVBO:Upload({
		4, 7, 6, 4, 6, 5, -- top (+y)
		3, 2, 6, 3, 6, 7, -- +z
		1, 0, 4, 1, 4, 5, -- -z
		2, 1, 5, 2, 5, 6, -- +x
		0, 3, 7, 0, 7, 4, -- -x
		0, 1, 2, 0, 2, 3, -- bottom (-y), only visible when a cube overhangs a cliff
	})

	local vao = gl.GetVAO()
	if not vao then
		return nil
	end
	vao:AttachVertexBuffer(vertexVBO)
	vao:AttachIndexBuffer(indexVBO)
	return vao
end

-- Only the top face of the unit cube, used for flat shapes (height 0) where the sides are never visible
local function makeTileVAO()
	local vertexVBO = gl.GetVBO(GL.ARRAY_BUFFER, false)
	local indexVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false)
	if not (vertexVBO and indexVBO) then
		return nil
	end
	vertexVBO:Define(4, { { id = 0, name = "cubeVertex", size = 4 } })
	vertexVBO:Upload({
		-0.5, 1, -0.5, 0, --0
		0.5, 1, -0.5, 0, --1
		0.5, 1, 0.5, 0, --2
		-0.5, 1, 0.5, 0, --3
	})
	indexVBO:Define(TILE_INDEX_COUNT)
	indexVBO:Upload({ 0, 3, 2, 0, 2, 1 }) -- same winding as the cube's top face

	local vao = gl.GetVAO()
	if not vao then
		return nil
	end
	vao:AttachVertexBuffer(vertexVBO)
	vao:AttachIndexBuffer(indexVBO)
	return vao
end

local function makeDataTexture(sizeX, sizeY, format, filter)
	return gl.CreateTexture(sizeX, sizeY, {
		format = format,
		fbo = true,
		min_filter = filter,
		mag_filter = filter,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
	})
end

-- The engine's LOS rays for one radius (CLosTableHelper::GetLosRays in LosMap.cpp): rays from the
-- center to the midpoint-circle perimeter of the first quadrant, plus fill-in rays to every cell no
-- perimeter ray passes through (AddMissing). The other quadrants are rotations of these.
-- Returns a flat vec4 list for the coverage shader: a header of (list offset, ray count) per
-- first-quadrant cell, followed by the (targetX, targetY) of every ray through each cell.
local function buildRayData(radius)
	local function round(f)
		return mathFloor(f + 0.5)
	end
	local function getRay(xf, yf)
		local line = {}
		if xf > yf then
			local m = yf / xf
			for x = 1, xf do
				line[#line + 1] = { x, round(m * x) }
			end
		else
			local m = xf / yf
			for y = 1, yf do
				line[#line + 1] = { round(m * y), y }
			end
		end
		return line
	end

	-- GetCircleSurface: midpoint circle, first octant plus its mirror across the diagonal
	local circlePoints = {}
	local x, y, decisionOver2 = radius, 0, 1 - radius
	while x >= y do
		circlePoints[#circlePoints + 1] = { x, y }
		if y ~= x and y ~= 0 then
			circlePoints[#circlePoints + 1] = { y, x }
		end
		y = y + 1
		if decisionOver2 <= 0 then
			decisionOver2 = decisionOver2 + 2 * y + 1
		else
			x = x - 1
			decisionOver2 = decisionOver2 + 2 * (y - x) + 1
		end
	end
	local rays = {}
	for _, p in ipairs(circlePoints) do
		rays[#rays + 1] = getRay(p[1], p[2])
	end

	-- AddMissing
	local stride = radius + 1
	local covered = {}
	local function cover(line)
		for _, p in ipairs(line) do
			covered[p[2] * stride + p[1]] = true
		end
	end
	for _, line in ipairs(rays) do
		cover(line)
	end
	for i = #circlePoints, 1, -1 do
		local p = circlePoints[i]
		for a = p[1], mathMax(1, p[2]), -1 do
			if not covered[p[2] * stride + a] then
				rays[#rays + 1] = getRay(a, p[2])
				cover(rays[#rays])
			end
			if not covered[a * stride + p[2]] and not (p[2] == 0 and a == radius) then
				rays[#rays + 1] = getRay(p[2], a)
				cover(rays[#rays])
			end
		end
	end

	-- which rays pass through each cell
	local cellRays = {}
	for _, ray in ipairs(rays) do
		local target = ray[#ray]
		for _, p in ipairs(ray) do
			local key = p[2] * stride + p[1]
			local list = cellRays[key]
			if not list then
				list = {}
				cellRays[key] = list
			end
			list[#list + 1] = target
		end
	end
	local headerCount = stride * stride
	local data = {}
	local listOffset = headerCount
	for key = 0, headerCount - 1 do
		local count = cellRays[key] and #cellRays[key] or 0
		data[#data + 1] = listOffset
		data[#data + 1] = count
		data[#data + 1] = 0
		data[#data + 1] = 0
		listOffset = listOffset + count
	end
	for key = 0, headerCount - 1 do
		local list = cellRays[key]
		if list then
			for _, target in ipairs(list) do
				data[#data + 1] = target[1]
				data[#data + 1] = target[2]
				data[#data + 1] = 0
				data[#data + 1] = 0
			end
		end
	end
	return data, listOffset -- vec4 entries
end

local function makeSet(radiusCells)
	local coverageCells = 2 * radiusCells + 1
	local stateFilter = COVERAGE_SMOOTH and GL.LINEAR or GL.NEAREST
	local set = {
		radius = radiusCells,
		N = coverageCells, -- coverage texels per side
		M = 2 * mathCeil((radiusCells + 2) * RADAR_CELL / CUBE_SPACING) + 1, -- cube cells per side
		target = makeDataTexture(coverageCells, coverageCells, GL_R16F, GL.NEAREST),
		state = { -- R = smoothed coverage, G = smoothed boundary factor
			makeDataTexture(coverageCells, coverageCells, GL_RG16F, stateFilter),
			makeDataTexture(coverageCells, coverageCells, GL_RG16F, stateFilter),
		},
		cur = 1,
		bx = nil, -- emitter cell of the cached coverage
		bz = nil,
		losHeight = nil,
		computedAt = -mathHuge,
	}
	if not (set.target and set.state[1] and set.state[2]) then
		return nil
	end

	local rayData, rayEntries = buildRayData(radiusCells)
	set.raySSBO = gl.GetVBO(GL.SHADER_STORAGE_BUFFER, false)
	if not set.raySSBO then
		return nil
	end
	set.raySSBO:Define(rayEntries, { { id = 0, name = "rayData", size = 4 } })
	set.raySSBO:Upload(rayData)
	return set
end

local function deleteTextures()
	for _, set in pairs(sets) do
		if set.target then
			gl.DeleteTexture(set.target)
		end
		for i = 1, 2 do
			if set.state[i] then
				gl.DeleteTexture(set.state[i])
			end
		end
		if set.raySSBO then
			set.raySSBO:Delete()
		end
	end
	sets = {}
	if mipTex then
		gl.DeleteTexture(mipTex)
		mipTex = nil
	end
end

local function initgl4()
	-- Files added to the game archive while a game is running are invisible to the VFS (the .sdd file
	-- list is indexed at game start), and CheckShaderUpdates silently returns nil for missing sources.
	local caches = { mipShaderCache, coverageShaderCache, smoothShaderCache, cubeShaderCache }
	for _, cache in ipairs(caches) do
		for _, path in ipairs({ cache.vssrcpath, cache.fssrcpath }) do
			if not VFS.FileExists(path) then
				goodbye("shader source not found: " .. path .. " (new files need a game restart to show up in the VFS)")
				return false
			end
		end
	end

	mipShader = LuaShader.CheckShaderUpdates(mipShaderCache)
	if not mipShader then
		goodbye("Failed to compile " .. mipShaderCache.shaderName)
		return false
	end
	coverageShader = LuaShader.CheckShaderUpdates(coverageShaderCache)
	if not coverageShader then
		goodbye("Failed to compile " .. coverageShaderCache.shaderName)
		return false
	end
	smoothShader = LuaShader.CheckShaderUpdates(smoothShaderCache)
	if not smoothShader then
		goodbye("Failed to compile " .. smoothShaderCache.shaderName)
		return false
	end
	cubeShader = LuaShader.CheckShaderUpdates(cubeShaderCache)
	if not cubeShader then
		goodbye("Failed to compile " .. cubeShaderCache.shaderName)
		return false
	end

	passVAO = InstanceVBOTable.MakeTexRectVAO()
	cubeVAO = makeCubeVAO()
	tileVAO = makeTileVAO()
	if not (passVAO and cubeVAO and tileVAO) then
		goodbye("Failed to create the radar preview VAOs")
		return false
	end

	mipTex = makeDataTexture(
		mathFloor(Game.mapSizeX / RADAR_CELL),
		mathFloor(Game.mapSizeZ / RADAR_CELL),
		GL_R32F,
		GL.NEAREST
	)
	if not mipTex then
		goodbye("Failed to create the radar preview heightmap texture")
		return false
	end

	for _, def in pairs(radarDefs) do
		if not sets[def.radiusCells] then
			local set = makeSet(def.radiusCells)
			if not set then
				goodbye("Failed to create the radar preview coverage textures")
				return false
			end
			sets[def.radiusCells] = set
		end
	end
	return true
end

local function setShape(name)
	local newShape = CUBE_SHAPES[name]
	if not newShape then
		spEcho("Sensor Ranges Radar Preview: unknown shape '" .. tostring(name) .. "', use cube, slab or tile")
		return false
	end
	shape = newShape
	CUBE_SHAPE = name
	return true
end

function widget:Initialize()
	if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end
	if not initgl4() then
		return
	end
	WG.radarPreview = {
		setShape = setShape,
		getShape = function()
			return CUBE_SHAPE
		end,
	}
end

function widget:Shutdown()
	WG.radarPreview = nil
	deleteTextures()
	for _, shader in ipairs({ mipShader, coverageShader, smoothShader, cubeShader }) do
		shader:Delete()
	end
end

function widget:SelectionChanged(sel)
	selectedRadarUnitID = false
	if #sel == 1 then
		local unitDefID = spGetUnitDefID(sel[1])
		if unitDefID and radarDefs[-unitDefID] then
			selectedRadarUnitID = sel[1]
		end
	end
end

local function drawPass()
	passVAO:DrawArrays(GL.TRIANGLES)
end

-- Conservative world-space bounding rectangle of the ground the screen can see: the view frustum
-- clipped against the horizontal plane at the map's lowest height (bounding box of the camera and
-- the four corner rays' intersections with that plane). Terrain hits are deliberately not used, as
-- a corner ray stopping on a hill would exclude ground visible further along that screen edge.
-- Returns nil when a corner looks at or above the horizon (then everything gets drawn).
local function getScreenFootprint(camX, camY, camZ)
	if not spGetPixelDir then
		return nil
	end
	local vsx, vsy, vpx = spGetViewGeometry()
	local minHeight = spGetGroundExtremes()
	local planeY = mathMax(minHeight or 0, 0) - 8 -- cubes never go below water level minus their sink
	local minX, maxX, minZ, maxZ = camX, camX, camZ, camZ
	for corner = 0, 3 do
		-- CalcPixelDir wants window x (including the view offset) and top-left-origin y
		local sx = (vpx or 0) + ((corner % 2 == 1) and vsx or 0)
		local sy = (corner >= 2) and vsy or 0
		local dx, dy, dz = spGetPixelDir(sx, sy)
		if not dy or dy > -0.001 then
			return nil
		end
		local t = (planeY - camY) / dy
		if t < 0 then
			return nil
		end
		local px, pz = camX + dx * t, camZ + dz * t
		minX, maxX = mathMin(minX, px), mathMax(maxX, px)
		minZ, maxZ = mathMin(minZ, pz), mathMax(maxZ, pz)
	end
	return minX, maxX, minZ, maxZ
end

-- Which cube cells to draw this frame: the screen footprint clipped to the grid. With LOD_MAX_INSTANCES
-- the grid blends to double spacing once more cubes than that would be on screen (far zoom).
-- Returns x0, z0, cellsX, cellsZ, stride, lodBlend.
local function getCubeWindow(set, cx, cz, camX, camY, camZ)
	local M = set.M
	local half = (M - 1) * 0.5

	local x0, x1, z0, z1 = 0, M - 1, 0, M - 1
	local minX, maxX, minZ, maxZ = getScreenFootprint(camX, camY, camZ)
	if minX then
		local margin = mathCeil(FOOTPRINT_MARGIN / CUBE_SPACING)
		x0 = mathMax(0, mathFloor((minX - cx) / CUBE_SPACING + half) - margin)
		x1 = mathMin(M - 1, mathCeil((maxX - cx) / CUBE_SPACING + half) + margin)
		z0 = mathMax(0, mathFloor((minZ - cz) / CUBE_SPACING + half) - margin)
		z1 = mathMin(M - 1, mathCeil((maxZ - cz) / CUBE_SPACING + half) + margin)
	end
	if x1 < x0 or z1 < z0 then
		return 0, 0, 0, 0, 1, 0
	end

	local lodBlend = 0
	if LOD_MAX_INSTANCES > 0 then
		local fineInstances = (x1 - x0 + 1) * (z1 - z0 + 1)
		lodBlend = mathMin(mathMax((fineInstances - LOD_MAX_INSTANCES) / (0.5 * LOD_MAX_INSTANCES), 0), 1)
	end
	local stride = (lodBlend >= 1) and 2 or 1
	if stride == 2 then -- keep the coarse grid on even cells so it stays put in the world
		x0 = x0 - (x0 % 2)
		z0 = z0 - (z0 % 2)
	end
	local cellsX = mathFloor((x1 - x0) / stride) + 1
	local cellsZ = mathFloor((z1 - z0) / stride) + 1
	return x0, z0, cellsX, cellsZ, stride, lodBlend
end

function widget:DrawWorld()
	local cmdID
	if selectedRadarUnitID then
		local unitDefID = spGetUnitDefID(selectedRadarUnitID)
		if not unitDefID then
			selectedRadarUnitID = false
			return
		end
		cmdID = -unitDefID
	else
		cmdID = select(2, spGetActiveCommand())
		if cmdID == nil or cmdID >= 0 then
			return
		end -- not a build command
	end

	local def = radarDefs[cmdID]
	if not def then
		return
	end
	if Spring.IsGUIHidden() or (WG.topbar and WG.topbar.showingQuit()) then
		return
	end
	local set = sets[def.radiusCells]
	if not set then
		return
	end

	-- emitter position: the unit's midPos for an existing radar, the build spot + model mid height otherwise
	local midY
	if selectedRadarUnitID then
		local x, y, z, _, my = spGetUnitPosition(selectedRadarUnitID, true)
		if not x then
			return
		end
		mousepos = { x, y, z }
		midY = my or (y + def.midY)
	else
		local mx, my = spGetMouseState()
		local _, coords = spTraceScreenRay(mx, my, true)
		if coords then
			mousepos = { coords[1], coords[2], coords[3] }
		end
		midY = mathMax(0, spGetGroundHeight(mousepos[1], mousepos[3])) + def.midY
	end

	-- ILosType::GetHeight: max(midPos.y + radarEmitHeight, 0) quantized to the center of a height bucket
	local losHeight = (mathFloor(mathMax(midY + def.emitHeight, 0) / HEIGHT_BUCKET) + 0.5) * HEIGHT_BUCKET
	local bx = mathFloor(mousepos[1] / RADAR_CELL)
	local bz = mathFloor(mousepos[3] / RADAR_CELL)
	-- CLosMap::LosAdd: an emitter at or below the terrain at its own cell center sees nothing
	local cellCenterX = (bx + 0.5) * RADAR_CELL + SQUARE_SIZE * 0.5
	local cellCenterZ = (bz + 0.5) * RADAR_CELL + SQUARE_SIZE * 0.5
	if losHeight <= spGetGroundHeight(cellCenterX, cellCenterZ) then
		return
	end

	local radius = def.radiusCells
	local range = radius * RADAR_CELL
	local cx = mathFloor((mousepos[1] + CUBE_SPACING * 0.5) / CUBE_SPACING) * CUBE_SPACING
	local cz = mathFloor((mousepos[3] + CUBE_SPACING * 0.5) / CUBE_SPACING) * CUBE_SPACING

	-- frame bookkeeping: a gap in draw frames or a different radar means the preview just (re)appeared
	local now = osClock()
	local drawFrame = spGetDrawFrame()
	local fresh = (drawFrame - lastDrawFrame > 1) or (lastRadius ~= radius)
	local dt = fresh and 0 or mathMin(now - lastDrawTime, 0.1)
	if fresh then
		spawnStart = now
	end
	lastDrawFrame, lastDrawTime, lastRadius = drawFrame, now, radius

	gl.DepthTest(false)
	gl.Culling(false)
	gl.Blending(false)

	-- 0. radar-cell heightmap, refreshed periodically for terraform
	local refresh = (now - mipUpdatedAt) > COVERAGE_REFRESH_SECONDS
	if refresh then
		gl.Texture(0, "$heightmap")
		mipShader:Activate()
		gl.RenderToTexture(mipTex, drawPass)
		mipShader:Deactivate()
		mipUpdatedAt = now
	end

	-- 1. engine-style coverage, cached until the emitter cell or height bucket changes
	local shiftX, shiftZ = 0, 0
	if set.bx then
		shiftX = bx - set.bx
		shiftZ = bz - set.bz
	end
	if fresh or refresh or set.bx ~= bx or set.bz ~= bz or set.losHeight ~= losHeight then
		gl.Texture(0, mipTex)
		set.raySSBO:BindBufferRange(RAY_SSBO_BINDING)
		coverageShader:Activate()
		coverageShader:SetUniform("losParams", bx, bz, radius, losHeight)
		gl.RenderToTexture(set.target, drawPass)
		coverageShader:Deactivate()
		set.bx, set.bz, set.losHeight, set.computedAt = bx, bz, losHeight, now
	end

	-- 2. ease the displayed coverage towards the target (ping-pong between the two state textures)
	local prevTex = set.state[set.cur]
	set.cur = 3 - set.cur
	local nextTex = set.state[set.cur]
	gl.Texture(0, prevTex)
	gl.Texture(1, set.target)
	smoothShader:Activate()
	smoothShader:SetUniform("smoothParams", shiftX, shiftZ, 1 - mathExp(-dt * SMOOTH_RATE), fresh and 1 or 0)
	gl.RenderToTexture(nextTex, drawPass)
	smoothShader:Deactivate()
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	-- 3. the cubes
	local camX, camY, camZ = spGetCameraPosition()
	local dx, dy, dz = camX - cx, camY - midY, camZ - cz
	local camDist = mathSqrt(dx * dx + dy * dy + dz * dz)
	local x0, z0, cellsX, cellsZ, stride, lodBlend = getCubeWindow(set, cx, cz, camX, camY, camZ)
	if cellsX > 0 and cellsZ > 0 then
		gl.Texture(0, "$heightmap")
		gl.Texture(1, nextTex)
		if hasMapDepth then
			gl.Texture(2, "$map_gbuffer_zvaltex")
			if hasModelDepth then
				gl.Texture(3, "$model_gbuffer_zvaltex")
			end
			gl.DepthTest(false) -- occlusion is done in the fragment shader against the g-buffer depths
		else
			gl.DepthTest(GL.LEQUAL)
		end
		gl.DepthMask(false)
		gl.Culling(GL.BACK)
		cubeShader:Activate()
		cubeShader:SetUniform("radarcenter_range", cx, losHeight, cz, range)
		cubeShader:SetUniform("gridParams", RADAR_CELL, set.N, CUBE_SPACING, set.M)
		cubeShader:SetUniform("lookupParams", bx, bz, radius, 0)
		cubeShader:SetUniform("shapeParams", CUBE_WIDTH, shape.height, CUBE_SINK, shape.lift + camDist * LIFT_PER_DISTANCE)
		cubeShader:SetUniform("animParams", now, now - spawnStart, lodBlend, shape.conform)
		cubeShader:SetUniform("windowParams", x0, z0, cellsX, stride)
		if shape.height > 0 then
			cubeVAO:DrawElements(GL.TRIANGLES, CUBE_INDEX_COUNT, 0, cellsX * cellsZ, 0)
		else
			tileVAO:DrawElements(GL.TRIANGLES, TILE_INDEX_COUNT, 0, cellsX * cellsZ, 0)
		end
		cubeShader:Deactivate()
		gl.Culling(false)
		gl.DepthTest(false)
		gl.Texture(2, false)
		gl.Texture(3, false)
	end

	gl.Texture(0, false)
	gl.Texture(1, false)
end
