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

-- Springsettings
-- RadarPreviewAlliedCoverage (0/1, default on): also draw the coverage of all allied radars (from the engine's radar map)
-- RadarPreviewBackground (0/1, default on): draw a background sheet under the cubes
-- RadarPreviewMinimap (0/1, default on): also fill the coverage on the minimap (and the PIP minimap)
-- RadarPreviewStyle (default 1): 1 = cubes on a faint background sheet, 1 = sheet only: no cubes, a more
--   opaque sheet and outline, with the spulses and the sweep drawn on it as smooth gradient rings (SHEET_* tunables)
-- RadarPreviewAnimations (0/1, default on): enable/disable animations
-- RadarPreviewSweep (0/1, default on): draw the rotating sweep (only when animations are on)

------------------------------------------------------------------------------------------------
-- How it works
--  0. Mip pass (once a second while shown): rebuilds the engine's radar-mip-level heightmap
--     (radarMipLevel from modrules, 3 => 64 elmo cells) from the corner heightmap.
--  1. Coverage pass (only when the emitter's cell or bucketed height changes): replicates the
--     engine's radar LOS (LosMap.cpp: midpoint-circle disk, rays, CastLos angle test) per radar cell.
--  2. Smoothing pass (every frame, a few thousand texels): a ping-ponged state texture eases towards
--     the coverage, so cubes rise/sink smoothly instead of popping while dragging.
--  3. Minimap pass (DrawInMiniMap, RadarPreviewMinimap setting): a flat, outlined fill of the same coverage on the minimap.
--  4. Cube pass: one instanced draw of a unit cube per cube of the NxN block inside each radar cell
--     (CUBES_PER_CELL by radarMipLevel, cube size as a fraction of the spacing). The vertex shader looks up
--     the radar cell the cube is in, samples the heightmap and animates the cube; the fragment shader
--     does per-face shading and zoom-independent edge lines. Only cells under the screen's ground
--     footprint are drawn; flat shapes draw a single quad per cell. Optionally (LOD_MAX_INSTANCES) the
--     grid thins to double spacing when more cubes than that would be on screen.
------------------------------------------------------------------------------------------------

-- Tunables
-- Cubes are laid out as an NxN block centered inside every radar cell (cell size = 8 << radarMipLevel elmo);
-- N by radarMipLevel, so the look stays consistent when the game's radar resolution changes.
local CUBES_PER_CELL = { [1] = 1, [2] = 1, [3] = 2, [4] = 3 }
local CUBE_FILL = 0.18 -- cube width as a fraction of the cube spacing (spacing = radar cell size / N)
local CUBE_SINK = 2 -- elmos the cube base is pushed below ground, so cubes never float on slopes
local CUBE_SHAPE = "tile" -- default shape, see CUBE_SHAPES; switch at runtime with WG.radarPreview.setShape(name)
local CUBE_SHAPES = {
	-- height at full coverage as a multiple of the cube width, lift of the top face above ground (elmo),
	-- conform = top face tilts with the terrain
	tile = { height = 0.2, lift = 0, conform = 0 },
	flat = { height = 0, lift = 1.5, conform = 1 }, -- flat square
}
local LIFT_PER_DISTANCE = 0.001 -- extra lift per elmo of camera distance, keeps flat shapes above the terrain LOD mesh
local COVERAGE_SMOOTH = false -- true: blend coverage between radar cells (prettier), false: exact engine cells (blocky)
local ALLIED_COVERAGE_POLL_SECONDS = 2 -- how often the RadarPreviewAlliedCoverage / RadarPreviewBackground settings are re-read
local BACKGROUND_LIFT = 2.0 -- elmos the background sheet (RadarPreviewBackground configint, default on) floats above the terrain
local COVERAGE_REFRESH_SECONDS = 1.0 -- periodic heightmap/coverage rebuild so terraforming shows up
local SMOOTH_RATE = 14 -- 1/s, how fast the cubes follow coverage changes (higher = snappier)
local SMOOTH_RATE_DRAG = 60 -- 1/s, used while the placement preview is dragged across radar cells, so cubes keep up with the cursor
local LOD_MAX_INSTANCES = 0 -- > 0: thin the grid to double spacing once more cubes than this are on screen (cubes visibly fill in/out with zoom; try 50000 on integrated graphics)
local FOOTPRINT_MARGIN = 48 -- elmos of slack around the screen's ground footprint
local MAX_RADIUS_CELLS = 256 -- sanity limit of the radar radius in cells (coverage texture and ray table size)
local RAY_SSBO_BINDING = 5 -- shader storage binding of the per-radius ray table (4, 6, 7 are used elsewhere in BAR)

-- With deferred map/model rendering the cubes are occluded via the g-buffer depths (terrain and units)
-- instead of the depth buffer, so grass and other widget geometry drawn with depth writes can't hide them.
local hasMapDepth = Spring.GetConfigString("AllowDeferredMapRendering") == "1"
local hasModelDepth = hasMapDepth and Spring.GetConfigString("AllowDeferredModelRendering") == "1"

local shaderConfig = {
	TERRAIN_DEPTH_TEST = hasMapDepth and 1 or 0,
	MODEL_DEPTH_TEST = hasModelDepth and 1 or 0,
	ALLIED_COLOR = "vec3(0.35, 0.62, 0.50)", -- cubes covered only by other allied radars
	ALLIED_ALPHA = 0.55, -- their opacity relative to the previewed radar's cubes
	BACKGROUND_COLOR = "vec3(0.10, 0.45, 0.28)", -- background sheet under the cubes (RadarPreviewBackground setting)
	BACKGROUND_ALPHA = 0.14,
	SHEET_COLOR = "vec3(0.22, 0.85, 0.50)", -- RadarPreviewStyle 1 (sheet only): color of the sheet (the cubes' BASE_COLOR)
	SHEET_PULSE_COLOR = "vec3(0.55, 1.00, 0.7)", -- RadarPreviewStyle 1: color the rings and the sweep blend the sheet towards
	SHEET_BACKGROUND_ALPHA = 0.2, -- RadarPreviewStyle 1 (sheet only): opacity of the sheet (doubles inside the rings/sweep)
	SHEET_OUTLINE_ALPHA = 0.4, -- RadarPreviewStyle 1: opacity of the OUTLINE_COLOR border of the sheet
	SHEET_RING_STRENGTH = 0.8, -- RadarPreviewStyle 1: how much the gradient rings brighten the sheet (PULSE_SPACING/SPEED/POWER shape them)
	MINIMAP_ALPHA = 0.33, -- opacity of the coverage fill on the minimap (RadarPreviewMinimap setting), BASE_COLOR / ALLIED_COLOR
	MINIMAP_OUTLINE_ALPHA = 0.4, -- opacity of the OUTLINE_COLOR border on the minimap around the previewed radar's coverage
	MINIMAP_ALLIED_OUTLINE_ALPHA = 0.25, -- opacity of that border around cells covered only by other allied radars
	MINIMAP_OUTLINE_WIDTH = 2, -- minimap outline width in pixels at 1080p, scaled with the screen's vertical resolution
	OUTLINE_COLOR = "vec3(0.45, 1.00, 0.57)", -- outline along the border with uncovered radar cells
	OUTLINE_ALPHA = 0.24,
	OUTLINE_WIDTH = 2, -- outline width in pixels at 1080p, scaled with the screen's vertical resolution (0.8 = 2 px on a 2721 px tall screen)
	MIN_COVERAGE = 0.04, -- cubes below this (smoothed) coverage are not drawn
	SWEEP_SPEED = 0.11, -- radar sweep revolutions per second
	SWEEP_TRAIL = 30.0, -- degrees: the trail fades out this far behind the sweep's leading edge
	SWEEP_BEAM = 9.0, -- degrees: width of the bright leading edge
	SWEEP_STRENGTH = 0.55, -- how much the sweep brightens/raises cubes
	SPAWN_SPEED = 5.0, -- radar ranges per second the spawn ripple travels outward
	SPAWN_BUMP = 0.25, -- width of the overshoot behind the ripple front, in radar ranges
	PULSE_SPACING = 180.0, -- elmos between the outward travelling wave rings
	PULSE_SPEED = 85.0, -- elmos per second the rings travel
	PULSE_POWER = 4.5, -- higher = narrower rings
	PULSE_STRENGTH = 1.5, -- how much the rings raise/brighten cubes
	PULSE_SYMMETRIC = 1, -- 1: rings fade in and out (smooth bell), 0: sharp leading edge that fades out behind it
	EDGE_STRENGTH = 0.12, -- how much cubes at the coverage boundary (next to an uncovered radar cell) brighten; 0 disables
	RIM_STRENGTH = 0.22, -- how much the outermost ring of cubes brightens; 0 disables
	TILE_MAX_TILT = 20.0, -- degrees: flat tiles follow the terrain slope up to this angle
	TILE_CLIFF_START = 35.0, -- degrees: terrain steeper than this starts flattening the tiles again
	TILE_CLIFF_END = 55.0, -- degrees: terrain steeper than this gets flat tiles (cliffs)
	BASE_COLOR = "vec3(0.22, 0.85, 0.50)",
	HIGHLIGHT_COLOR = "vec3(0.65, 1.00, 0.80)",
	BASE_ALPHA = 0.5,
	LINE_ALPHA = 0.5, -- opacity of the cube edge lines
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

-- derived cube grid: N cubes per radar cell edge (fallback: about one cube per 13 elmo)
local CUBES_PER_CELL_EDGE = CUBES_PER_CELL[RADAR_MIP_LEVEL] or math.max(1, math.floor(RADAR_CELL / 13 + 0.5))
local CUBE_SPACING = RADAR_CELL / CUBES_PER_CELL_EDGE -- elmos between cube centers
local CUBE_WIDTH = CUBE_FILL * CUBE_SPACING -- elmos
local MAP_CELLS_X = math.floor(Game.mapSizeX / RADAR_CELL) -- radar cells of the whole map
local MAP_CELLS_Z = math.floor(Game.mapSizeZ / RADAR_CELL)
local MAP_CUBES_X = MAP_CELLS_X * CUBES_PER_CELL_EDGE -- cube grid size of the whole map
local MAP_CUBES_Z = MAP_CELLS_Z * CUBES_PER_CELL_EDGE

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
local spGetGlobalLos = Spring.GetGlobalLos
local spGetSpectatingState = Spring.GetSpectatingState
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
local spGetTeamList = Spring.GetTeamList
local spGetTeamUnits = Spring.GetTeamUnits
local spGetUnitSensorRadius = Spring.GetUnitSensorRadius
local spGetUnitIsActive = Spring.GetUnitIsActive
local spGetUnitIsStunned = Spring.GetUnitIsStunned
local getCurrentMiniMapRotationOption = VFS.Include("luaui/Include/minimap_utils.lua").getCurrentMiniMapRotationOption

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
			if radiusCells > MAX_RADIUS_CELLS then
				spEcho("Sensor Ranges Radar Preview: " .. unitDef.name .. " radar radius clamped to " .. MAX_RADIUS_CELLS .. " cells")
				radiusCells = MAX_RADIUS_CELLS
			end
			radarDefs[-unitDefID] = {
				radiusCells = radiusCells,
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
local minimapShader = nil
local passVAO = nil
local cubeVAO = nil
local tileVAO = nil -- just the top face, for flat shapes (6x fewer triangles, 2x fewer vertices)
local CUBE_INDEX_COUNT = 36 -- 6 faces x 2 triangles x 3 vertices
local TILE_INDEX_COUNT = 6

local mipTex = nil -- radar-cell heightmap of the whole map
local mipUpdatedAt = -mathHuge
local alliedTex = nil -- map-wide union of the allied radars' coverage, only used under global LOS / full view
local alliedUpdatedAt = -mathHuge
local alliedRadars = {} -- reused scratch list of { bx, bz, radius, losHeight }
local alliedRadarCount = 0
-- live values of the RadarPreview* configint settings (one table: DrawWorld is at Lua 5.1's 60 upvalue limit)
local settings = {
	allied = false, -- RadarPreviewAlliedCoverage
	background = true, -- RadarPreviewBackground
	minimap = true, -- RadarPreviewMinimap
	style = 0, -- RadarPreviewStyle: 0 = cubes, 1 = sheet only
	animations = true, -- RadarPreviewAnimations: sweep and pulse rings
	sweep = true, -- RadarPreviewSweep: the rotating sweep (only when animations are on)
}
local alliedConfigCheckedAt = -mathHuge
local sets = {} -- radius in cells -> coverage/state textures and grid dimensions
local mousepos = { 0, 0, 0 }
local selectedRadarUnitID = false
local shape = CUBE_SHAPES[CUBE_SHAPE] or CUBE_SHAPES.cube

-- per-frame bookkeeping
local lastDrawFrame = -10
local lastDrawTime = 0
local lastRadius = nil
local spawnStart = 0
local cellMovedAt = -mathHuge -- last time the previewed emitter moved to another radar cell

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
		coverageAbsolute = { 0 },
		passRect = { -1, -1, 1, 1 },
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
		radarInfoTex = 4,
	},
	uniformFloat = {
		radarcenter_range = { 0, 0, 0, 2000 },
		gridParams = { RADAR_CELL, 1, CUBE_SPACING, CUBES_PER_CELL_EDGE },
		lookupParams = { 0, 0, 1, 0 },
		shapeParams = { CUBE_WIDTH, 6, CUBE_SINK, 0 },
		animParams = { 0, 0, 0, 0 },
		windowParams = { 0, 0, 1, 1 },
		modeParams = { 0, 0, 0, 0 },
	},
	shaderConfig = shaderConfig,
}

local minimapShaderCache = {
	vssrcpath = "LuaUI/Shaders/sensor_ranges_radar_preview_minimap.vert.glsl",
	fssrcpath = "LuaUI/Shaders/sensor_ranges_radar_preview_minimap.frag.glsl",
	shaderName = "radarPreviewMinimap GL4",
	uniformInt = {
		coverageTex = 0,
		radarInfoTex = 1,
		targetTex = 2,
	},
	uniformFloat = {
		discParams = { 0, 0, 1, 0 },
		mapParams = { MAP_CELLS_X, MAP_CELLS_Z, 0, 0 },
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
	-- shader storage buffers are allocated in 64 byte (4 x vec4) units and the upload must fill them
	local entries = listOffset
	while entries % 4 ~= 0 do
		for _ = 1, 4 do
			data[#data + 1] = 0
		end
		entries = entries + 1
	end
	return data, entries -- vec4 entries
end

local function makeSet(radiusCells)
	local coverageCells = 2 * radiusCells + 1
	local stateFilter = COVERAGE_SMOOTH and GL.LINEAR or GL.NEAREST
	local set = {
		radius = radiusCells,
		N = coverageCells, -- coverage texels per side
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
		minimapAlliedTex = nil, -- set by DrawWorld for DrawInMiniMap: allied radar map to blend in (alliedTex / "$info:radar"), nil = off
	}
	if not (set.target and set.state[1] and set.state[2]) then
		return nil
	end

	local rayData, rayEntries = buildRayData(radiusCells)
	set.raySSBO = gl.GetVBO(GL.SHADER_STORAGE_BUFFER, false)
	if not set.raySSBO then
		return nil
	end
	-- LuaVBO shader storage buffers use std140 vec4 attributes: with size = 4 one element is 4 x vec4 = 64 bytes
	-- and the upload consumes 16 floats per element, so the entry count is padded to a multiple of 4 above
	set.raySSBO:Define(rayEntries / 4, { { id = 0, name = "rayData", size = 4 } })
	set.raySSBO:Upload(rayData)
	return set
end

local function deleteTextures()
	for _, set in pairs(sets) do
		if set then
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
	end
	sets = {}
	if mipTex then
		gl.DeleteTexture(mipTex)
		mipTex = nil
	end
	if alliedTex then
		gl.DeleteTexture(alliedTex)
		alliedTex = nil
	end
end

-- coverage/ray-table set for a radius in cells, created on demand (allied radar units of any size)
local function getSet(radiusCells)
	local set = sets[radiusCells]
	if set == nil then
		set = makeSet(radiusCells) or false
		sets[radiusCells] = set
	end
	return set or nil
end

local function initgl4()
	-- Files added to the game archive while a game is running are invisible to the VFS (the .sdd file
	-- list is indexed at game start), and CheckShaderUpdates silently returns nil for missing sources.
	local caches = { mipShaderCache, coverageShaderCache, smoothShaderCache, cubeShaderCache, minimapShaderCache }
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
	minimapShader = LuaShader.CheckShaderUpdates(minimapShaderCache)
	if not minimapShader then
		goodbye("Failed to compile " .. minimapShaderCache.shaderName)
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
	alliedTex = makeDataTexture(MAP_CELLS_X, MAP_CELLS_Z, GL_R16F, GL.NEAREST)
	if not alliedTex then
		goodbye("Failed to create the allied radar coverage texture")
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

local function readConfig()
	settings.allied = Spring.GetConfigInt("RadarPreviewAlliedCoverage", 1) ~= 0
	settings.background = Spring.GetConfigInt("RadarPreviewBackground", 1) ~= 0
	settings.minimap = Spring.GetConfigInt("RadarPreviewMinimap", 1) ~= 0
	settings.style = Spring.GetConfigInt("RadarPreviewStyle", 1)
	settings.animations = Spring.GetConfigInt("RadarPreviewAnimations", 1) ~= 0
	settings.sweep = Spring.GetConfigInt("RadarPreviewSweep", 0) ~= 0
end

function widget:Update()
	local now = osClock()
	if now - alliedConfigCheckedAt > ALLIED_COVERAGE_POLL_SECONDS then
		alliedConfigCheckedAt = now
		readConfig()
	end
end

function widget:Initialize()
	if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end
	if not initgl4() then
		return
	end
	readConfig()
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
	for _, shader in ipairs({ mipShader, coverageShader, smoothShader, cubeShader, minimapShader }) do
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

-- Which cubes to draw this frame: the radar disc's cubes (absolute cube grid indices, CUBES_PER_CELL_EDGE
-- per radar cell) clipped to the screen footprint. With LOD_MAX_INSTANCES the grid blends to double
-- spacing once more cubes than that would be on screen (far zoom).
-- Returns x0, z0, cellsX, cellsZ, stride, lodBlend.
local function getCubeWindow(set, bx, bz, camX, camY, camZ)
	local n = CUBES_PER_CELL_EDGE
	local radius = set.radius
	local x0, x1 = (bx - radius) * n, (bx + radius + 1) * n - 1
	local z0, z1 = (bz - radius) * n, (bz + radius + 1) * n - 1
	if settings.allied then -- allied coverage can be anywhere on the map; uncovered cubes exit the vertex shader early
		x0, x1, z0, z1 = 0, MAP_CUBES_X - 1, 0, MAP_CUBES_Z - 1
	end
	local minX, maxX, minZ, maxZ = getScreenFootprint(camX, camY, camZ)
	if minX then
		local margin = mathCeil(FOOTPRINT_MARGIN / CUBE_SPACING)
		x0 = mathMax(x0, mathFloor(minX / CUBE_SPACING) - margin)
		x1 = mathMin(x1, mathFloor(maxX / CUBE_SPACING) + margin)
		z0 = mathMax(z0, mathFloor(minZ / CUBE_SPACING) - margin)
		z1 = mathMin(z1, mathFloor(maxZ / CUBE_SPACING) + margin)
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

-- Allied radar units the engine would give radar coverage (ILosType::UpdateUnit: finished, activated,
-- not stunned, emitter above its own cell), with their emitter cell, radius in cells and bucketed height.
local function collectAlliedRadars()
	local count = 0
	local teams = spGetTeamList(spGetMyAllyTeamID())
	for t = 1, #teams do
		local units = spGetTeamUnits(teams[t])
		for u = 1, #units do
			local unitID = units[u]
			local radarRadius = spGetUnitSensorRadius(unitID, "radar")
			if radarRadius and radarRadius > 0 and spGetUnitIsActive(unitID) and not spGetUnitIsStunned(unitID) then
				local radiusCells = mathFloor(mathFloor(radarRadius / SQUARE_SIZE) / 2 ^ RADAR_MIP_LEVEL)
				if radiusCells >= 1 and radiusCells <= MAX_RADIUS_CELLS then
					local _, _, _, mx, my, mz = spGetUnitPosition(unitID, true)
					local unitDefID = spGetUnitDefID(unitID)
					local emitHeight = (unitDefID and UnitDefs[unitDefID].radarEmitHeight) or 0
					local losHeight = (mathFloor(mathMax(my + emitHeight, 0) / HEIGHT_BUCKET) + 0.5) * HEIGHT_BUCKET
					local bx, bz = mathFloor(mx / RADAR_CELL), mathFloor(mz / RADAR_CELL)
					local cellCenterX = (bx + 0.5) * RADAR_CELL + SQUARE_SIZE * 0.5
					local cellCenterZ = (bz + 0.5) * RADAR_CELL + SQUARE_SIZE * 0.5
					if losHeight > spGetGroundHeight(cellCenterX, cellCenterZ) then
						count = count + 1
						local radar = alliedRadars[count]
						if not radar then
							radar = {}
							alliedRadars[count] = radar
						end
						radar.bx, radar.bz, radar.radius, radar.losHeight = bx, bz, radiusCells, losHeight
					end
				end
			end
		end
	end
	alliedRadarCount = count
end

-- Renders the union of the collected radars' coverage into alliedTex (one texel per radar cell): each
-- radar draws just its disc's rectangle with the exact coverage shader, MAX-blended over the others.
local function drawAlliedUnion()
	gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
	gl.Blending(GL.ONE, GL.ONE)
	gl.BlendEquation(GL.MAX)
	coverageShader:Activate()
	coverageShader:SetUniform("coverageAbsolute", 1)
	local sx, sz = 2 / MAP_CELLS_X, 2 / MAP_CELLS_Z
	for i = 1, alliedRadarCount do
		local radar = alliedRadars[i]
		local set = getSet(radar.radius)
		if set then
			set.raySSBO:BindBufferRange(RAY_SSBO_BINDING)
			coverageShader:SetUniform("losParams", radar.bx, radar.bz, radar.radius, radar.losHeight)
			coverageShader:SetUniform(
				"passRect",
				(radar.bx - radar.radius) * sx - 1,
				(radar.bz - radar.radius) * sz - 1,
				(radar.bx + radar.radius + 1) * sx - 1,
				(radar.bz + radar.radius + 1) * sz - 1
			)
			passVAO:DrawArrays(GL.TRIANGLES)
		end
	end
	coverageShader:SetUniform("coverageAbsolute", 0)
	coverageShader:SetUniform("passRect", -1, -1, 1, 1)
	coverageShader:Deactivate()
	gl.BlendEquation(GL.FUNC_ADD)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
end

function widget:DrawWorld()
	local cmdID
	if selectedRadarUnitID then
		-- verify every frame, not just on SelectionChanged: the unit may be gone or no longer selected
		local unitDefID = spGetUnitDefID(selectedRadarUnitID)
		if not unitDefID or not Spring.IsUnitSelected(selectedRadarUnitID) then
			selectedRadarUnitID = false
			return
		end
		cmdID = -unitDefID
	else
		cmdID = select(2, spGetActiveCommand())
		if cmdID == nil or cmdID >= 0 then
			-- before game start builds are queued through the pregame build widget, not via an active command.
			-- Only while the game hasn't started: that widget keeps its picked unit after GameStart, which would
			-- otherwise leave the preview stuck to the cursor with nothing selected.
			if Spring.GetGameFrame() > 0 then
				return
			end
			local pregameBuild = WG["pregame-build"]
			local pregameDefID = pregameBuild and pregameBuild.getPreGameDefID and pregameBuild.getPreGameDefID()
			if not pregameDefID then
				return
			end
			cmdID = -pregameDefID
		end
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
		-- Hovering a PIP (or the PIP-minimap: WG.pip_minimap is the same object as WG.pipN)
		-- maps to the world position under the cursor in that view, not the ground behind it
		local wx, wz
		for pipNumber = 0, 4 do
			local pipApi = WG["pip" .. pipNumber]
			if pipApi and pipApi.ScreenToWorld then
				wx, wz = pipApi.ScreenToWorld(mx, my)
				if wx and wz then
					break
				end
			end
		end
		local px, py, pz
		if wx and wz then
			px, py, pz = wx, spGetGroundHeight(wx, wz), wz
		else
			-- useMiniMap=true: over the engine minimap, trace through it instead of the world behind it
			local _, coords = spTraceScreenRay(mx, my, true, true)
			if coords then
				px, py, pz = coords[1], coords[2], coords[3]
			end
		end
		-- nothing under the cursor (sky) or a spot outside the map: nothing can be built there, so no preview
		-- (checked before snapping, as Pos2BuildPos can pull an off-map position back onto the edge)
		if not px or px < 0 or pz < 0 or px > Game.mapSizeX or pz > Game.mapSizeZ then
			return
		end
		mousepos = { px, py, pz }
		-- snap to the build grid the way the placement itself is snapped (build facing included), so the
		-- preview is computed for the spot the radar will actually stand on, not the raw cursor position
		-- (globals on purpose: DrawWorld is at Lua 5.1's 60 upvalue limit)
		local sx, sy, sz = Spring.Pos2BuildPos(-cmdID, mousepos[1], mousepos[2], mousepos[3], Spring.GetBuildFacing())
		if sx then
			mousepos = { sx, sy, sz }
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
	local cx, cz = mousepos[1], mousepos[3] -- center of the animations; the cube grid itself is world-fixed

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
		if shiftX ~= 0 or shiftZ ~= 0 then
			cellMovedAt = now
		end
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
	-- while the placement preview is being dragged across radar cells the cubes must keep up with the cursor
	local smoothRate = (not selectedRadarUnitID and (now - cellMovedAt) < 0.3) and SMOOTH_RATE_DRAG or SMOOTH_RATE
	smoothShader:SetUniform("smoothParams", shiftX, shiftZ, 1 - mathExp(-dt * smoothRate), fresh and 1 or 0)
	gl.RenderToTexture(nextTex, drawPass)
	smoothShader:Deactivate()
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	-- 2b. under global LOS or spectator full view the engine's radar map covers everything, so union the
	-- coverage of the allied radar units ourselves instead (exact, refreshed once a second)
	local manualAllied = false
	if settings.allied then
		local _, fullView = spGetSpectatingState()
		manualAllied = fullView or spGetGlobalLos() or false
		if manualAllied and (now - alliedUpdatedAt) > COVERAGE_REFRESH_SECONDS then
			collectAlliedRadars()
			gl.Texture(0, mipTex)
			gl.RenderToTexture(alliedTex, drawAlliedUnion)
			alliedUpdatedAt = now
		end
	end
	-- for DrawInMiniMap, which draws this set (sets[lastRadius], coverage in set.state[set.cur]) in the same frame
	-- (kept on the set: DrawWorld is at Lua 5.1's 60 upvalue limit, so no new file locals may be referenced here)
	set.minimapAlliedTex = settings.allied and (manualAllied and alliedTex or "$info:radar") or nil

	-- 3. the cubes
	local camX, camY, camZ = spGetCameraPosition()
	local dx, dy, dz = camX - cx, camY - midY, camZ - cz
	local camDist = mathSqrt(dx * dx + dy * dy + dz * dz)
	local x0, z0, cellsX, cellsZ, stride, lodBlend = getCubeWindow(set, bx, bz, camX, camY, camZ)
	if cellsX > 0 and cellsZ > 0 then
		gl.Texture(0, "$heightmap")
		gl.Texture(1, nextTex)
		if settings.allied then
			-- the engine's radar map of our ally team (one texel per radar cell), or our own union of the
			-- allied radars when the engine map is all-covering (global LOS / spectator full view)
			gl.Texture(4, manualAllied and alliedTex or "$info:radar")
		end
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
		cubeShader:SetUniform("gridParams", RADAR_CELL, set.N, CUBE_SPACING, CUBES_PER_CELL_EDGE)
		cubeShader:SetUniform("lookupParams", bx, bz, radius, settings.allied and 1 or 0)
		cubeShader:SetUniform("animParams", now, now - spawnStart, lodBlend, shape.conform)
		cubeShader:SetUniform("windowParams", x0, z0, cellsX, stride)
		local sheetOnly = settings.style == 1
		local animations = settings.animations and 1 or 0
		local sweep = settings.sweep and 1 or 0
		cubeShader:SetUniform("modeParams", 0, 0, animations, sweep)
		if settings.background or sheetOnly then
			-- background sheet under the cubes, outlined along the border with uncovered cells. In the sheet-only
			-- style it is the whole preview: no cubes, and the fragment shader draws the rings and the sweep on it
			cubeShader:SetUniform("modeParams", 1, sheetOnly and 1 or 0, animations, sweep)
			cubeShader:SetUniform("shapeParams", CUBE_WIDTH, 0, CUBE_SINK, BACKGROUND_LIFT + camDist * LIFT_PER_DISTANCE)
			tileVAO:DrawElements(GL.TRIANGLES, TILE_INDEX_COUNT, 0, cellsX * cellsZ, 0)
			cubeShader:SetUniform("modeParams", 0, 0, animations, sweep)
		end
		if not sheetOnly then
			cubeShader:SetUniform("shapeParams", CUBE_WIDTH, shape.height * CUBE_WIDTH, CUBE_SINK, shape.lift + camDist * LIFT_PER_DISTANCE)
			if shape.height > 0 then
				cubeVAO:DrawElements(GL.TRIANGLES, CUBE_INDEX_COUNT, 0, cellsX * cellsZ, 0)
			else
				tileVAO:DrawElements(GL.TRIANGLES, TILE_INDEX_COUNT, 0, cellsX * cellsZ, 0)
			end
		end
		cubeShader:Deactivate()
		gl.Culling(false)
		gl.DepthTest(false)
		gl.Texture(2, false)
		gl.Texture(3, false)
		gl.Texture(4, false)
	end

	gl.Texture(0, false)
	gl.Texture(1, false)
end

-- Flat fill of the previewed (and allied) radar coverage on the minimap, outlined at uncovered cells. Also
-- reached through the PIP minimap, which forwards this callin with its viewport remapped. Only draws while
-- DrawWorld is drawing: the engine renders its minimap texture from Game::Update, before DrawWorld and at its
-- own refresh rate, so the previous draw frame has to count as current here.
function widget:DrawInMiniMap()
	if not settings.minimap or spGetDrawFrame() - lastDrawFrame > 1 then
		return
	end
	local set = sets[lastRadius]
	if not set then
		return
	end

	gl.DepthTest(false)
	gl.Culling(false)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	gl.Texture(0, set.state[set.cur]) -- smoothed coverage: the fill
	if set.minimapAlliedTex then
		gl.Texture(1, set.minimapAlliedTex)
	end
	gl.Texture(2, set.target) -- exact engine coverage: the outline
	minimapShader:Activate()
	minimapShader:SetUniform("discParams", set.bx, set.bz, set.radius, set.minimapAlliedTex and 1 or 0)
	local _, vsy = spGetViewGeometry()
	minimapShader:SetUniform(
		"mapParams",
		Game.mapSizeX / RADAR_CELL,
		Game.mapSizeZ / RADAR_CELL,
		getCurrentMiniMapRotationOption() or 0,
		shaderConfig.MINIMAP_OUTLINE_WIDTH * (vsy or 1080) / 1080 -- outline width in pixels
	)
	passVAO:DrawArrays(GL.TRIANGLES)
	minimapShader:Deactivate()
	gl.Texture(0, false)
	gl.Texture(1, false)
	gl.Texture(2, false)
end
