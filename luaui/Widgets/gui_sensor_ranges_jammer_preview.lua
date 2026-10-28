local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Sensor Ranges Jammer Preview",
		desc = "Engine-accurate jammer coverage, drawn as a sheet over the terrain while placing or selecting a jammer, and of enemy jammers (GL4)",
		author = "Floris",
		date = "2026.10.06",
		license = "GNU GPL v2",
		layer = 0,
		enabled = true,
	}
end

-- Springsettings
-- JammerPreviewAlwaysShow (0/1, default on): always draw the coverage of all allied jammers, not only while placing or selecting one
-- JammerPreviewAlliedCoverage (0/1, default on): while previewing a jammer, also draw the coverage of all allied jammers
-- JammerPreviewMinimap (0/1, default on): also fill the coverage on the minimap (and the PIP minimap)
-- JammerPreviewEnemyCoverage (0/1, default on): also draw the coverage of enemy jammers, whenever jammer coverage is shown
-- SensorPreviewCircles (0/1, default on, shared with the radar preview): draw the coverage as circles at the jammers'
--   ranges instead of the engine's radar cells (CIRCLE_* tunables below); the minimap keeps the cells

------------------------------------------------------------------------------------------------
-- Jammer coverage ignores the terrain: the engine jams a disc of radar cells (radarMipLevel from modrules,
-- 2 => 32 elmo cells) around the cell of the jammer's mid position, with the radius rounded down to whole cells
-- (CLosMap::AddCircle in rts/Sim/Misc/LosMap.cpp). This draws exactly those cells:
--  1. Disc pass: the previewed jammer's disc, and the union of the allied jammers' discs over the whole map,
--     each re-rendered only when it changes.
--  2. Smoothing pass: eases the shown disc towards the new one, so dragging the preview fades instead of popping.
--  3. Sheet pass: projects the coverage onto the terrain. Drawn over the coverage's screen area, every pixel
--     rebuilds its world position from the map g-buffer depth and takes the coverage of its radar cell.
--  4. Minimap pass (JammerPreviewMinimap setting): a flat, outlined fill of the same coverage on the minimap.
-- A selected jammer that does not jam right now (switched off, stunned, paused, unpaid or unfinished) still shows
-- its range, faintly.
-- Spectators with full view see every allyteam's jammers (gaia's excepted) as allied, as gui_jammed_units.lua
-- highlights every allyteam's units for them.
-- Enemy jammers (JammerPreviewEnemyCoverage) get their own union, drawn under the allied one in other colors. One in
-- sight is drawn while it jams. A building that goes out of sight is presumed to keep jamming at its spot, as the
-- engine's ghost of it (or gui_ghostsite's, still unfinished) stands there, until it shows on radar (a jamming jammer
-- hides itself), its spot is in sight without it, or a radar contact of its allyteam shows so deep inside its coverage
-- that the radar error can't explain it (separateJammers: an allyteam's jammers hide only its own units).
-- Circle mode (SensorPreviewCircles) draws circles at the jammers' ranges instead, shrunk to lie (nearly) all in
-- jammed cells: the previewed one per pixel, the allied ones from a distance field the disc pass renders.
-- The pass vertex, smoothing and minimap shaders are shared with gui_sensor_ranges_radar_preview.lua.
------------------------------------------------------------------------------------------------

-- Tunables
local SETTINGS_POLL_SECONDS = 2 -- how often the JammerPreview* settings are re-read
local ALLIED_POLL_SECONDS = 0.2 -- how often the allied (and enemy) jammers are checked for changes while their coverage is shown
local ENEMY_PROBE_SECONDS = 1 -- how often a jamming enemy jammer's coverage is searched for radar contacts that disprove it
local ENEMY_DISPROVED_SECONDS = 5 -- how long an enemy jammer in sight stays hidden after a radar contact disproved it
local RADAR_CONTACT_SLACK = 8 -- elmos a radar contact must lie deeper inside an enemy jammer's coverage than the radar error
local SMOOTH_RATE = 14 -- 1/s, how fast the sheet follows coverage changes (higher = snappier)
local SMOOTH_RATE_DRAG = 60 -- 1/s, used while the placement preview is dragged across radar cells, so the sheet keeps up with the cursor
local SMOOTH_SETTLE_SECONDS = 1 -- after this long without a change the shown coverage has settled and is no longer eased
local MAX_RADIUS_CELLS = 256 -- sanity limit of the jammer radius in cells
local OUTLINE_DASHES = 4 -- stipple density of the outline: dashes per radar cell side, centred on the cell corners
local OUTLINE_DASH_SPEED = 6 -- elmos per second the stipple travels clockwise around the coverage, 0 = still
-- circle mode (SensorPreviewCircles): how far a jammer's circle shrinks from its nominal range (0) towards the largest
-- circle that lies in jammed radar cells everywhere (1); in between, a unit inside the circle is jammed nearly always
local CIRCLE_SAFETY = 0.75
-- circle mode: mobile jammers' circles jump along with the engine's radar cell like the real coverage (true), or
-- follow the unit smoothly (false)
local CIRCLE_SNAP = false ---@type boolean
-- circle mode: up to this many allied circles get exact edges and a stipple; beyond, their edges come from a distance
-- field one texel per radar cell (slightly polygonal up close) and their outline is solid
local MAX_ALLIED_CIRCLES = 64
-- The coverage fades out with the camera distance (FADE_START, FADE_END below), except while a jammer is placed or
-- selected. Players outside the LOS view (L) keep it unfaded, like the radar, sonar and LOS range lines.
local NO_FADE_WITHOUT_LOS_VIEW = true

-- The sheet is projected through the map g-buffer depth; units and features are left out via the model g-buffer
-- depth. BAR turns both on (luaintro/springconfig.lua).
local hasMapDepth = Spring.GetConfigString("AllowDeferredMapRendering") == "1"
local hasModelDepth = hasMapDepth and Spring.GetConfigString("AllowDeferredModelRendering") == "1"

-- Engine sensor model (rts/Sim/Misc/LosHandler.cpp, LosMap.cpp)
local RADAR_MIP_LEVEL = 2 -- modrules sensors.los.radarMipLevel; overridden below when the file can be read
do
	local modrules = VFS.LoadFile("gamedata/modrules.lua")
	local mip = modrules and modrules:match("radarMipLevel%s*=%s*(%d+)")
	if mip then
		RADAR_MIP_LEVEL = tonumber(mip) or RADAR_MIP_LEVEL
	end
end

local SQUARE_SIZE = 8
local RADAR_CELL = SQUARE_SIZE * 2 ^ RADAR_MIP_LEVEL -- elmos per radar cell
local MAP_CELLS_X = math.floor(Game.mapSizeX / RADAR_CELL) -- radar cells of the whole map
local MAP_CELLS_Z = math.floor(Game.mapSizeZ / RADAR_CELL)
local engineRequiresUpkeep = Game.sensorsRequireUpkeep == true -- sensors.requireUpkeep: unpaid units lose their sensors

local shaderConfig = {
	MODEL_DEPTH_TEST = hasModelDepth and 1 or 0,
	RADAR_CELL_SIZE = RADAR_CELL,
	MAP_CELLS_X = MAP_CELLS_X,
	MAP_CELLS_Z = MAP_CELLS_Z,
	SHEET_COLOR = "vec3(0.90, 0.22, 0.20)", -- color of the previewed jammer's coverage, on the sheet and the minimap
	ALLIED_COLOR = "vec3(0.62, 0.35, 0.33)", -- cells covered only by other allied jammers
	ALLIED_ALPHA = 0.85, -- their opacity relative to the previewed jammer's cells
	OUTLINE_COLOR = "vec3(1.00, 0.32, 0.22)", -- stippled outline along the border with uncovered radar cells
	SHEET_ALPHA = 0.17, -- opacity of the sheet
	SHEET_OUTLINE_ALPHA = 0.8, -- opacity of the dashes of the OUTLINE_COLOR border of the sheet
	OUTLINE_GAP_ALPHA = 0.3, -- opacity of that border between its dashes, relative to the dashes
	OUTLINE_WIDTH = 1.2, -- outline width in pixels at 1080p, scaled with the screen's vertical resolution
	OUTLINE_WORLD_WIDTH = 0.89, -- elmos added to the outline width, so it gets a little thicker when zoomed in
	OUTLINE_THIN_START = 3000, -- elmos from the camera where the outline starts thinning
	OUTLINE_THIN_END = 8000, -- elmos from the camera where it has thinned to OUTLINE_THIN_SCALE
	OUTLINE_THIN_SCALE = 0.6, -- outline width at OUTLINE_THIN_END and further, relative to its full width
	OUTLINE_MIN_WIDTH = 1.0, -- screen pixels (not scaled with the resolution) the thinning stops at
	FADE_START = 4000, -- elmos from the camera where the coverage starts fading out
	FADE_END = 8000, -- elmos from the camera where it is gone
	OFFMAP_OUTLINE_FADE = 50, -- elmos past the map's edge over which the outline fades out (there is no fill there)
	OUTLINE_DASHES = OUTLINE_DASHES,
	MINIMAP_ALPHA = 0.33, -- opacity of the coverage fill on the minimap, SHEET_COLOR / ALLIED_COLOR
	MINIMAP_OUTLINE_ALPHA = 0.4, -- opacity of the OUTLINE_COLOR border on the minimap around the previewed jammer's coverage
	MINIMAP_ALLIED_OUTLINE_ALPHA = 0.25, -- opacity of that border around cells covered only by other allied jammers
	MINIMAP_OUTLINE_WIDTH = 2, -- minimap outline width in pixels at 1080p, scaled with the screen's vertical resolution
	INACTIVE_ALPHA = 0.5, -- fill opacity of a selected jammer that does not jam (off, stunned, paused or unpaid), relative to a jamming one's
	INACTIVE_OUTLINE_ALPHA = 0.4, -- opacity of its outline, relative to a jamming one's
	MIN_COVERAGE = 0.04, -- cells fainter than this are not drawn
	SPAWN_SPEED = 18.0, -- jammer ranges per second the spawn ripple travels outward
	MAX_ALLIED_CIRCLES = MAX_ALLIED_CIRCLES,
	CIRCLE_SDF_RANGE = 128, -- circle mode: elmos either side of the allied circles' edge their distance field covers
	CIRCLE_SDF_SLACK = 8, -- circle mode: elmos a mobile jammer's circle moves before that field is re-rendered (exact edges cover it)
}

-- the enemy jammers' coverage is drawn by the same sheet and minimap shaders, as their "allied" coverage in these colors
local enemyShaderConfig = {} ---@type table<string, any>
for key, value in pairs(shaderConfig) do
	enemyShaderConfig[key] = value
end
enemyShaderConfig.ALLIED_COLOR = "vec3(0.55, 0.25, 0.45)" -- fill of the enemy jammers' coverage
enemyShaderConfig.OUTLINE_COLOR = "vec3(0.90, 0.4, 0.45)" -- its stippled outline

-- Localized functions for performance
local mathFloor = math.floor
local mathCeil = math.ceil
local mathMin = math.min
local mathMax = math.max
local mathExp = math.exp
local mathAbs = math.abs
local mathHuge = math.huge
local osClock = os.clock

-- Localized Spring API for performance
local spEcho = Spring.Echo
local spGetUnitDefID = Spring.GetUnitDefID
local spGetActiveCommand = Spring.GetActiveCommand
local spGetMouseState = Spring.GetMouseState
local spTraceScreenRay = Spring.TraceScreenRay
local spWorldToScreenCoords = Spring.WorldToScreenCoords
local spGetUnitPosition = Spring.GetUnitPosition
local spGetGroundHeight = Spring.GetGroundHeight
local spGetCameraPosition = Spring.GetCameraPosition
local spGetCameraDirection = Spring.GetCameraDirection
local spGetGroundExtremes = Spring.GetGroundExtremes
local spGetViewGeometry = Spring.GetViewGeometry
local spGetDrawFrame = Spring.GetDrawFrame
local spGetGameFrame = Spring.GetGameFrame
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
local spGetTeamList = Spring.GetTeamList
local spGetTeamUnits = Spring.GetTeamUnits
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetUnitTeam = Spring.GetUnitTeam
local spGetSpectatingState = Spring.GetSpectatingState
local spGetMapDrawMode = Spring.GetMapDrawMode
local spGetUnitSensorRadius = Spring.GetUnitSensorRadius
local spGetUnitIsActive = Spring.GetUnitIsActive
local spGetUnitIsStunned = Spring.GetUnitIsStunned
local spGetUnitIsUpkeepPaid = Spring.GetUnitIsUpkeepPaid
local spGetUnitLosState = Spring.GetUnitLosState
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spGetUnitRadius = Spring.GetUnitRadius
local spGetAllUnits = Spring.GetAllUnits
local spGetRadarErrorParams = Spring.GetRadarErrorParams
local spIsPosInLos = Spring.IsPosInLos
local spIsUnitSelected = Spring.IsUnitSelected
local spPos2BuildPos = Spring.Pos2BuildPos
local spGetBuildFacing = Spring.GetBuildFacing
local getCurrentMiniMapRotationOption = require("luaui/Include/minimap_utils").getCurrentMiniMapRotationOption

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable
local GL_R8 = 0x8229
local GL_R16F = 0x822D
local ENEMY_UNITS = Spring.ENEMY_UNITS

-- ILosType::GetRadius: (radius / SQUARE_SIZE) >> radarMipLevel, integer arithmetic
local function radiusToCells(radius)
	return mathMin(mathFloor(mathFloor(radius / SQUARE_SIZE) / 2 ^ RADAR_MIP_LEVEL), MAX_RADIUS_CELLS)
end

-- ILosType::PosToSquare: int(pos / cell size), truncated toward zero
local function worldToCell(v)
	local cell = v / RADAR_CELL
	return cell >= 0 and mathFloor(cell) or mathCeil(cell)
end

-- Radius in cells -> elmos from the emitter to the nearest radar cell its disc leaves unjammed, measured from the
-- center of the emitter's cell (inset 0.5), or from anywhere in that cell (inset 1: a unit moves around in it). By
-- default as the circle mode's circles are placed: at the cell's center when they snap to it. The nearest unjammed
-- cells are the first ones past each row MidpointCircleAlgoPerLine fills, as in sensor_ranges_jammer_preview_disc.frag.glsl.
local safeRadii = { [0.5] = {}, [1] = {} } ---@type table<number, table<integer, number|nil>>
---@param radiusCells integer
---@param inset number?
---@return number
local function safeCircleRadius(radiusCells, inset)
	inset = inset or (CIRCLE_SNAP and 0.5 or 1)
	local cache = safeRadii[inset]
	local safe = cache[radiusCells]
	if safe then
		return safe
	end
	local widths = {}
	local x, y, decisionOver2 = radiusCells, 0, 1 - radiusCells
	while x >= y do
		widths[y] = mathMax(widths[y] or -1, x)
		if decisionOver2 <= 0 then
			y = y + 1
			decisionOver2 = decisionOver2 + 2 * y + 1
		else
			if x ~= y then
				widths[x] = mathMax(widths[x] or -1, y)
			end
			y = y + 1
			x = x - 1
			decisionOver2 = decisionOver2 + 2 * (y - x) + 1
		end
	end
	local nearest = mathHuge
	for row = 0, radiusCells + 1 do
		local column = (row <= radiusCells) and ((widths[row] or -1) + 1) or 0
		local dx, dz = mathMax(column - inset, 0.0), mathMax(row - inset, 0.0)
		nearest = mathMin(nearest, (dx * dx + dz * dz) ^ 0.5)
	end
	safe = nearest * RADAR_CELL
	cache[radiusCells] = safe
	return safe
end

-- circle mode: a jammer's circle radius for its range in elmos and in cells
local function circleRadius(range, radiusCells)
	return range - CIRCLE_SAFETY * mathMax(range - safeCircleRadius(radiusCells), 0)
end

-- circle mode: a jammer's circle center for its emitter (mid) position
local function circleCenter(x, z)
	if CIRCLE_SNAP then
		return (worldToCell(x) + 0.5) * RADAR_CELL, (worldToCell(z) + 0.5) * RADAR_CELL
	end
	return x, z
end

-- unitDefID -> jammer parameters of every unit type with a radar jammer
local jammerDefs = {} ---@type table<number, table>
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.radarDistanceJam and unitDef.radarDistanceJam > 0 then
		local dims = Spring.GetUnitDefDimensions(unitDefID)
		jammerDefs[unitDefID] = {
			unitDefID = unitDefID,
			range = unitDef.radarDistanceJam,
			radiusCells = radiusToCells(unitDef.radarDistanceJam),
			midX = (dims and dims.midx) or 0, -- model mid position offset, the jammer emits from the unit's mid position
			midZ = (dims and dims.midz) or 0,
			mobile = unitDef.canMove == true,
		}
	end
end

local discShader ---@type LuaShader
local smoothShader ---@type LuaShader
local passVAO ---@type VAO

local sets = {} ---@type table<number, table|false> -- radius in cells -> textures of the previewed disc
local jammerUnits = {} ---@type table<UnitID, table> -- units with a radar jammer and their jammerDefs entry, filtered to the local ally team when collected
local selectedJammerUnitID = false ---@type UnitID|false
local gaiaTeamID = Spring.GetGaiaTeamID()
local spectating = false
local fullview = false -- spectating with full view: every allyteam's jammers count as allied

-- live values of the JammerPreview* configint settings
local settings = {
	alwaysShow = true, -- JammerPreviewAlwaysShow
	alliedCoverage = true, -- JammerPreviewAlliedCoverage
	enemyCoverage = true, -- JammerPreviewEnemyCoverage
	minimap = true, -- JammerPreviewMinimap
	circles = Spring.GetConfigInt("SensorPreviewCircles", 1) ~= 0, -- SensorPreviewCircles
}
local settingsCheckedAt = -mathHuge

-- A coverage layer: the union of a set of jammers' coverage, as last rendered into its textures, which are re-rendered
-- only when it changes, and the shaders that draw it
---@class JammerCoverageLayer
---@field collect fun(layer: JammerCoverageLayer, now: number) lists the covering jammers with appendJammer
---@field tex string union of the jammers' coverage, one texel per radar cell of the map
---@field sdfTex string? circle mode: distance field of the jammers' circles, same layout
---@field sdfValid boolean sdfTex was rendered in circle mode
---@field count integer covering jammers; -1 until the first check, so the texture gets cleared
---@field cells number[] emitter cell x, cell z, radius in cells per covering jammer
---@field scratch number[]
---@field circles number[] circle mode: circle center x, z and radius (elmos) per covering jammer
---@field circleScratch number[]
---@field sdfCircles number[] `circles` as sdfTex was last rendered with
---@field circleData number[] `circles` for the sheet's exact edges and stipple, empty past MAX_ALLIED_CIRCLES
---@field circleDataVersion integer bumped whenever circleData changes, so the sheet shader only gets it uploaded then
---@field uploadedCircleDataVersion integer
---@field mobileUnits UnitID[] circle mode: the covering mobile jammers, whose circles follow them between checks
---@field mobileSlots integer[] their circle's index in `circles`
---@field x0 number bounding rectangle of the union in radar cells
---@field z0 number
---@field x1 number
---@field z1 number
---@field checkedAt number
---@field shownFrame integer last draw frame it was shown
---@field sheetShader LuaShader
---@field minimapShader LuaShader

---@return JammerCoverageLayer
local function newLayer()
	return { ---@diagnostic disable-line: missing-fields, return-type-mismatch -- textures, shaders and collect are set later
		sdfValid = false,
		count = -1,
		cells = {},
		scratch = {},
		circles = {},
		circleScratch = {},
		sdfCircles = {},
		circleData = {},
		circleDataVersion = 0,
		uploadedCircleDataVersion = -1,
		mobileUnits = {},
		mobileSlots = {},
		x0 = mathHuge,
		z0 = mathHuge,
		x1 = -mathHuge,
		z1 = -mathHuge,
		checkedAt = -mathHuge,
		shownFrame = -10,
	}
end
local allied = newLayer() -- the allied jammers' coverage (every allyteam's in full view)
local enemy = newLayer() -- the enemy jammers' coverage, as far as it is known
local layers = { allied, enemy }

-- Enemy jammers in sight, and jammer buildings that went out of sight (ghosts): unitID -> what is known of it.
-- Tracked through one allyteam's view while enemy coverage is wanted, see updateEnemyTracking.
local enemyJammers = {} ---@type table<UnitID, table>
local enemyViewAllyTeamID = false ---@type integer|false|nil -- the allyteam whose view they were recorded through, nil while not tracked
local enemyCallIns = true -- UnitEnteredLos and UnitLeftLos are on

-- the previewed jammer
local preview = {
	frame = -10, -- last draw frame it was drawn
	time = 0,
	radius = nil,
	x = 0, -- emitter world position
	z = 0,
	spawnStart = 0.0,
	movedAt = -mathHuge, -- last time the emitter moved to another radar cell
	inactive = 0.0, -- 0 while the previewed jammer jams, 1 while it does not, eased in between
	circleX = 0.0, -- circle mode: its circle's center and radius (elmos)
	circleZ = 0.0,
	circleRadius = 0.0,
	appearedAt = 0.0, -- circle mode: when it appeared, for its fade-in
}

-- what DrawWorld drew, for DrawInMiniMap
local minimapFrame = -10
local minimapSet ---@type table?
local minimapAllied = false
local minimapEnemy = false
local minimapInactive = 0.0
-- the last draw frame DrawWorld drew coverage, for WG.jammerPreview.isCoverageShown()
local coverageShownFrame = -10

-- the camera distance fade of the coverage
local distanceFade = {
	strength = 1.0, -- 1: it fades out with the camera distance, 0: it doesn't, eased in between
	frame = -10, -- last draw frame it was eased
	time = 0,
}

local passVsPath = "LuaUI/Shaders/sensor_ranges_radar_preview_pass.vert.glsl"

local discShaderCache = {
	vssrcpath = passVsPath,
	fssrcpath = "LuaUI/Shaders/sensor_ranges_jammer_preview_disc.frag.glsl",
	shaderName = "jammerPreviewDisc GL4",
	uniformFloat = {
		discParams = { 0, 0, 1, 0 },
		passRect = { -1, -1, 1, 1 },
	},
	shaderConfig = shaderConfig,
}

local smoothShaderCache = {
	vssrcpath = passVsPath,
	fssrcpath = "LuaUI/Shaders/sensor_ranges_radar_preview_smooth.frag.glsl",
	shaderName = "jammerPreviewSmooth GL4",
	uniformInt = {
		prevTex = 0,
		targetTex = 1,
	},
	uniformFloat = {
		smoothParams = { 0, 0, 1, 1 },
	},
	shaderConfig = shaderConfig,
}

local sheetShaderCache = {
	vssrcpath = passVsPath,
	fssrcpath = "LuaUI/Shaders/sensor_ranges_jammer_preview.frag.glsl",
	shaderName = "jammerPreviewSheet GL4",
	uniformInt = {
		mapDepths = 0,
		modelDepths = hasModelDepth and 1 or nil,
		coverageTex = 2,
		alliedTex = 3,
		targetTex = 4,
		alliedSdfTex = 5,
	},
	uniformFloat = {
		previewParams = { 0, 0, -1, 0 },
		previewInactive = 0,
		stippleOffset = 0,
		circleMode = 0,
		circleParams = { 0, 0, 0, 1 },
		alliedCircleCount = 0,
		emitterXZ = { 0, 0 },
		alliedParams = { 0, 0 },
		fadeStrength = 1,
		passRect = { -1, -1, 1, 1 },
	},
	shaderConfig = shaderConfig,
}

local minimapShaderCache = {
	vssrcpath = "LuaUI/Shaders/sensor_ranges_radar_preview_minimap.vert.glsl",
	fssrcpath = "LuaUI/Shaders/sensor_ranges_radar_preview_minimap.frag.glsl",
	shaderName = "jammerPreviewMinimap GL4",
	uniformInt = {
		coverageTex = 0,
		radarInfoTex = 1,
		targetTex = 2,
	},
	uniformFloat = {
		discParams = { 0, 0, -1, 0 },
		inactiveParams = { 0, 1, 1 },
		mapParams = { MAP_CELLS_X, MAP_CELLS_Z, 0, 0 },
	},
	shaderConfig = shaderConfig,
}

-- a shader cache compiling the same sources with the enemy colors (the cache keeps its own compile state)
local function enemyShaderCache(cache, shaderName)
	local copy = {}
	for key, value in pairs(cache) do
		copy[key] = value
	end
	copy.shaderName, copy.shaderConfig = shaderName, enemyShaderConfig
	return copy
end
local enemySheetShaderCache = enemyShaderCache(sheetShaderCache, "jammerPreviewEnemySheet GL4")
local enemyMinimapShaderCache = enemyShaderCache(minimapShaderCache, "jammerPreviewEnemyMinimap GL4")

local function goodbye(reason)
	spEcho("Sensor Ranges Jammer Preview widget exiting with reason: " .. reason)
	widgetHandler:RemoveWidget()
end

local function makeDataTexture(sizeX, sizeY, format, filter)
	return gl.CreateTexture(sizeX, sizeY, {
		format = format,
		fbo = true,
		min_filter = filter or GL.NEAREST,
		mag_filter = filter or GL.NEAREST,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
	})
end

local function deleteSetTextures(set)
	for _, tex in ipairs({ set.target, set.state[1], set.state[2] }) do
		gl.DeleteTexture(tex)
	end
end

-- textures of the previewed disc for a radius in cells, created on demand: the exact disc and the smoothed
-- coverage (ping-ponged), (2 * radius + 1)^2 texels around the emitter's cell
local function getSet(radiusCells)
	local set = sets[radiusCells]
	if set == nil then
		local size = 2 * radiusCells + 1
		set = {
			radius = radiusCells,
			target = makeDataTexture(size, size, GL_R16F),
			state = { makeDataTexture(size, size, GL_R16F), makeDataTexture(size, size, GL_R16F) },
			cur = 1,
			bx = nil, -- emitter cell of the rendered disc
			bz = nil,
			changedAt = -mathHuge, -- when the disc was last rendered
		}
		if not (set.target and set.state[1] and set.state[2]) then
			deleteSetTextures(set)
			set = false
		end
		sets[radiusCells] = set
	end
	return set or nil
end

local function deleteTextures()
	for _, set in pairs(sets) do
		if set then
			deleteSetTextures(set)
		end
	end
	sets = {}
	for _, layer in ipairs(layers) do
		for _, tex in ipairs({ layer.tex, layer.sdfTex }) do
			gl.DeleteTexture(tex)
		end
		layer.tex, layer.sdfTex = nil, nil
	end
end

local function initgl4()
	if not hasMapDepth then
		goodbye("AllowDeferredMapRendering is off, the coverage is projected through the map depth buffer")
		return false
	end
	-- Files added to the game archive while a game is running are invisible to the VFS (the .sdd file
	-- list is indexed at game start), and CheckShaderUpdates silently returns nil for missing sources.
	local caches = {
		discShaderCache,
		smoothShaderCache,
		sheetShaderCache,
		minimapShaderCache,
		enemySheetShaderCache,
		enemyMinimapShaderCache,
	}
	for _, cache in ipairs(caches) do
		for _, path in ipairs({ cache.vssrcpath, cache.fssrcpath }) do
			if not VFS.FileExists(path) then
				goodbye("shader source not found: " .. path .. " (new files need a game restart to show up in the VFS)")
				return false
			end
		end
	end

	local shaders = {}
	for i, cache in ipairs(caches) do
		---@diagnostic disable-next-line: call-non-callable, need-check-nil
		shaders[i] = LuaShader.CheckShaderUpdates(cache)
		if not shaders[i] then
			goodbye("Failed to compile " .. cache.shaderName)
			return false
		end
	end
	discShader, smoothShader = shaders[1], shaders[2]
	allied.sheetShader, allied.minimapShader = shaders[3], shaders[4]
	enemy.sheetShader, enemy.minimapShader = shaders[5], shaders[6]

	local vao = InstanceVBOTable.fillVAOSlots(InstanceVBOTable.MakeTexRectVAO())
	if not vao then
		goodbye("Failed to create the jammer preview VAO")
		return false
	end
	passVAO = vao

	for _, layer in ipairs(layers) do
		local tex = makeDataTexture(MAP_CELLS_X, MAP_CELLS_Z, GL_R8)
		local sdfTex = makeDataTexture(MAP_CELLS_X, MAP_CELLS_Z, GL_R16F, GL.LINEAR)
		if not (tex and sdfTex) then
			goodbye("Failed to create the jammer coverage textures")
			return false
		end
		layer.tex, layer.sdfTex = tex, sdfTex
	end
	return true
end

local updateEnemyTracking ---@type fun() -- defined with the enemy jammers below

local function readConfig()
	settings.alwaysShow = Spring.GetConfigInt("JammerPreviewAlwaysShow", 1) ~= 0
	settings.alliedCoverage = Spring.GetConfigInt("JammerPreviewAlliedCoverage", 1) ~= 0
	settings.enemyCoverage = Spring.GetConfigInt("JammerPreviewEnemyCoverage", 1) ~= 0
	settings.minimap = Spring.GetConfigInt("JammerPreviewMinimap", 1) ~= 0
	local circles = Spring.GetConfigInt("SensorPreviewCircles", 1) ~= 0
	if circles ~= settings.circles then
		settings.circles = circles
		for _, layer in ipairs(layers) do
			layer.sdfValid = false
			layer.checkedAt = -mathHuge
		end
	end
	updateEnemyTracking()
end

function widget:Update()
	local now = osClock()
	if now - settingsCheckedAt > SETTINGS_POLL_SECONDS then
		settingsCheckedAt = now
		readConfig()
	end
end

local function trackUnit(unitID, unitDefID)
	local def = jammerDefs[unitDefID]
	-- gaia's units are not highlighted as jammed either
	jammerUnits[unitID] = (def and spGetUnitTeam(unitID) ~= gaiaTeamID) and def or nil
end

local function scanAlliedUnits()
	local spec, fullView = spGetSpectatingState()
	spectating, fullview = spec, fullView
	jammerUnits = {}
	local teams = fullview and spGetTeamList() or spGetTeamList(spGetMyAllyTeamID())
	for _, teamID in ipairs(teams or {}) do
		for _, unitID in ipairs(spGetTeamUnits(teamID) or {}) do
			trackUnit(unitID, spGetUnitDefID(unitID))
		end
	end
	allied.checkedAt = -mathHuge
end

function widget:UnitCreated(unitID, unitDefID)
	trackUnit(unitID, unitDefID)
end

-- Enemy jammer in sight: recorded live; anything else the unitID stood for is forgotten (IDs get reused)
local function trackEnemy(unitID)
	enemyJammers[unitID] = nil
	local unitDefID = spGetUnitDefID(unitID)
	local def = unitDefID and jammerDefs[unitDefID]
	if not (def and enemyViewAllyTeamID) or def.radiusCells < 1 then
		return
	end
	local allyTeamID = spGetUnitAllyTeam(unitID)
	if not allyTeamID or allyTeamID == enemyViewAllyTeamID or spGetUnitTeam(unitID) == gaiaTeamID then
		return
	end
	local x, y, z, mx, my, mz = spGetUnitPosition(unitID, true)
	if not (x and mx) then
		return
	end
	enemyJammers[unitID] = {
		def = def,
		allyTeam = allyTeamID,
		x = mx, -- emitter (mid) position, where its coverage is centered
		z = mz,
		baseX = x, -- base position, the engine's ghost of a building vanishes once it is in sight
		baseY = y,
		baseZ = z,
		-- fully submerged units also need sonar to be seen, LOS on their spot proves nothing; and in water, sonar may
		-- show a unit its radar jammer hides
		underwater = my + (spGetUnitRadius(unitID) or 0) < 0,
		inWater = spGetGroundHeight(x, z) < 0,
		ghost = false, -- out of sight, at its last known spot
		disprovedAt = -mathHuge, -- when a radar contact last showed inside its coverage
		probedAt = -mathHuge, -- when its coverage was last searched for radar contacts
	}
	enemy.checkedAt = -mathHuge
end

-- Ghosts outlive a reload of the widget through its config data: the engine shows Lua nothing of a building out of
-- sight. These fields of a record are kept as they are.
local GHOST_FIELDS = { "allyTeam", "x", "z", "baseX", "baseY", "baseZ", "underwater", "inWater" }
local savedGhosts ---@type table? -- config data with ghosts to restore, see widget:SetConfigData

local function currentGameID()
	return Game.gameID or Spring.GetGameRulesParam("GameID")
end

-- adds the saved ghosts, when they were recorded through this view, to those in sight
local function restoreGhosts(viewAllyTeamID)
	if not (savedGhosts and savedGhosts.viewAllyTeamID == viewAllyTeamID and type(savedGhosts.ghosts) == "table") then
		return
	end
	local now = osClock()
	for _, saved in ipairs(savedGhosts.ghosts) do
		local def = jammerDefs[saved.unitDefID]
		local unitID = saved.unitID --[[@as UnitID]]
		if def and type(unitID) == "number" and not enemyJammers[unitID] then
			local jammer = {
				def = def,
				ghost = true,
				disprovedAt = saved.disproved and now or -mathHuge,
				probedAt = -mathHuge,
			}
			for _, field in ipairs(GHOST_FIELDS) do
				jammer[field] = saved[field]
			end
			if type(jammer.x) == "number" and type(jammer.baseX) == "number" then
				enemyJammers[unitID] = jammer
			end
		end
	end
end

-- Enemy jammers are tracked while their coverage is wanted, through the view of one allyteam: a player's, or the one
-- a spectator without full view follows. A change of view starts over from the units in sight.
updateEnemyTracking = function()
	local viewAllyTeamID = (settings.enemyCoverage and not fullview) and spGetMyAllyTeamID() or nil
	if viewAllyTeamID == enemyViewAllyTeamID then
		return
	end
	enemyViewAllyTeamID = viewAllyTeamID
	local tracking = viewAllyTeamID ~= nil
	if tracking ~= enemyCallIns then
		enemyCallIns = tracking
		for _, callIn in ipairs({ "UnitEnteredLos", "UnitLeftLos", "TeamDied" }) do
			if tracking then
				widgetHandler:UpdateCallIn(callIn)
			else
				widgetHandler:RemoveCallIn(callIn)
			end
		end
	end
	enemyJammers = {}
	if tracking then
		for _, unitID in ipairs(spGetAllUnits() or {}) do
			if spGetUnitIsActive(unitID) ~= nil then -- in sight
				trackEnemy(unitID)
			end
		end
		restoreGhosts(viewAllyTeamID)
	end
	savedGhosts = nil
	enemy.checkedAt = -mathHuge
end

function widget:UnitGiven(unitID, unitDefID)
	trackUnit(unitID, unitDefID)
	enemyJammers[unitID] = nil
end

function widget:UnitDestroyed(unitID)
	jammerUnits[unitID] = nil
	enemyJammers[unitID] = nil
end

function widget:PlayerChanged()
	scanAlliedUnits()
	updateEnemyTracking()
end

function widget:UnitEnteredLos(unitID)
	trackEnemy(unitID)
end

-- A building stays as a ghost at its spot; where a mobile jammer went is unknown
function widget:UnitLeftLos(unitID)
	local jammer = enemyJammers[unitID]
	if jammer then
		if jammer.def.mobile then
			enemyJammers[unitID] = nil
		else
			jammer.ghost = true
			-- a radar contact disproving it while in sight only carries over while recent, it was seen jamming since
			if osClock() - jammer.disprovedAt >= ENEMY_DISPROVED_SECONDS then
				jammer.disprovedAt = -mathHuge
			end
		end
		enemy.checkedAt = -mathHuge
	end
end

-- an allyteam with no team left has no jammers left
function widget:TeamDied(teamID)
	local allyTeamID = Spring.GetTeamAllyTeamID(teamID)
	for _, otherTeamID in ipairs(spGetTeamList(allyTeamID) or {}) do
		if otherTeamID ~= teamID and not select(3, Spring.GetTeamInfo(otherTeamID, false)) then
			return
		end
	end
	for unitID, jammer in pairs(enemyJammers) do
		if jammer.allyTeam == allyTeamID then
			enemyJammers[unitID] = nil
		end
	end
	enemy.checkedAt = -mathHuge
end

-- Whether the engine lets the unit's jammer work: on, not stunned and, with the sensors.requireUpkeep modrule,
-- its upkeep paid (a game-side pause zeroes the radius instead)
local function isJamming(unitID)
	return spGetUnitIsActive(unitID)
		and not spGetUnitIsStunned(unitID)
		and (not engineRequiresUpkeep or spGetUnitIsUpkeepPaid(unitID))
end

-- values and mobile jammers appendJammer listed so far in the check of a layer (updateLayer)
local collectedValues, collectedMobile = 0, 0

-- Appends a covering jammer to the lists of the layer being checked: its emitter cell and radius in cells to
-- layer.scratch, and in circle mode its circle's center x, z and radius to layer.circleScratch, listing it in
-- layer.mobileUnits when it moves
local function appendJammer(layer, unitID, mx, mz, range, radiusCells, mobile)
	local out, n = layer.scratch, collectedValues
	out[n + 1], out[n + 2], out[n + 3] = worldToCell(mx), worldToCell(mz), radiusCells
	if settings.circles then
		local circles = layer.circleScratch
		circles[n + 1], circles[n + 2] = circleCenter(mx, mz)
		circles[n + 3] = circleRadius(range, radiusCells)
		if mobile then
			collectedMobile = collectedMobile + 1
			layer.mobileUnits[collectedMobile], layer.mobileSlots[collectedMobile] = unitID, n + 1
		end
	end
	collectedValues = n + 3
end

-- Allied jammers the engine gives coverage (ILosType::UpdateUnit: finished, activated, not stunned), appended to the
-- layer's lists
local function collectAlliedJammers(layer)
	local myAllyTeamID = spGetMyAllyTeamID()
	for unitID, def in pairs(jammerUnits) do
		local allyTeamID = spGetUnitAllyTeam(unitID)
		if allyTeamID == nil or (allyTeamID ~= myAllyTeamID and not fullview) then -- gone, or given away
			jammerUnits[unitID] = nil
		elseif isJamming(unitID) then
			local range = spGetUnitSensorRadius(unitID, "radarJammer") or 0
			local radiusCells = radiusToCells(range)
			if radiusCells >= 1 then
				local _, _, _, mx, _, mz = spGetUnitPosition(unitID, true)
				if mx then
					appendJammer(layer, unitID, mx, mz, range, radiusCells, def.mobile)
				end
			end
		end
	end
end

-- whether a unit shows on radar, out of sight (GetUnitLosState bits: 1 = LOS_INLOS, 2 = LOS_INRADAR)
local function onRadarOnly(unitID)
	local los = spGetUnitLosState(unitID, nil, true) --[[@as integer?]]
	return los ~= nil and los % 2 == 0 and los % 4 >= 2
end

-- whether the ground within `margin` elmos of x, z dips under water, where sonar may show units radar can't
local function nearWater(x, z, margin)
	return mathMin(
		spGetGroundHeight(x, z),
		spGetGroundHeight(x - margin, z - margin),
		spGetGroundHeight(x + margin, z - margin),
		spGetGroundHeight(x - margin, z + margin),
		spGetGroundHeight(x + margin, z + margin)
	) < 0
end

-- Whether a radar contact of the enemy jammer's allyteam shows so deep inside its coverage that the jammer would hide
-- it if it jammed, however far the radar error displaces the contact: an allyteam's jammers hide its own units
-- (separateJammers), wherever the jammer's emitter lies in its radar cell
local function radarContactInside(unitID, jammer)
	local def = jammer.def
	local radarError = spGetRadarErrorParams(enemyViewAllyTeamID --[[@as integer]]) or 0
	local margin = radarError + RADAR_CONTACT_SLACK
	if def.mobile then
		margin = margin + RADAR_CELL -- the engine may move its coverage up to half a second late
	end
	local reach = safeCircleRadius(def.radiusCells, 1) - margin
	if reach <= 0 then
		return false
	end
	-- the query takes mid positions, the engine jams by base position
	local contacts = spGetUnitsInCylinder(jammer.x, jammer.z, reach + RADAR_CONTACT_SLACK, ENEMY_UNITS) or {}
	for i = 1, #contacts do
		local contactID = contacts[i]
		if contactID ~= unitID and spGetUnitAllyTeam(contactID) == jammer.allyTeam and onRadarOnly(contactID) then
			local x, _, z = spGetUnitPosition(contactID) -- base position, displaced by the radar error
			if x then
				local dx, dz = x - jammer.x, z - jammer.z
				if dx * dx + dz * dz <= reach * reach and not nearWater(x, z, margin) then
					return true
				end
			end
		end
	end
	return false
end

-- Whether an enemy jammer jams as far as can be told, updating what is known of it; forgets it once it is gone. One in
-- sight jams while on, finished and not stunned. A ghost is presumed to, unless it shows on radar (a jamming jammer
-- hides itself) or its spot is in sight without it. Either does not once a radar contact disproves it: for
-- ENEMY_DISPROVED_SECONDS while in sight (it may be switched back on), until seen again as a ghost.
local function enemyJamming(unitID, jammer, now)
	if jammer.ghost then
		if not jammer.underwater and spIsPosInLos(jammer.baseX, jammer.baseY, jammer.baseZ) then
			enemyJammers[unitID] = nil -- gone, or it would be in sight
			return false
		end
		if jammer.disprovedAt > -mathHuge or (not jammer.inWater and onRadarOnly(unitID)) then
			return false
		end
	else
		local active = spGetUnitIsActive(unitID)
		local allyTeamID = spGetUnitAllyTeam(unitID)
		if active == nil or allyTeamID == nil or allyTeamID == enemyViewAllyTeamID then
			enemyJammers[unitID] = nil -- died in sight (which fires no LOS callin), or became allied
			return false
		end
		jammer.allyTeam = allyTeamID
		if not active or spGetUnitIsStunned(unitID) or now - jammer.disprovedAt < ENEMY_DISPROVED_SECONDS then
			return false
		end
		if jammer.def.mobile then
			local _, _, _, mx, _, mz = spGetUnitPosition(unitID, true)
			if mx then
				jammer.x, jammer.z = mx, mz
			end
		end
	end
	if now - jammer.probedAt >= ENEMY_PROBE_SECONDS then
		jammer.probedAt = now
		if radarContactInside(unitID, jammer) then
			jammer.disprovedAt = now
			return false
		end
	end
	return true
end

-- Enemy jammers that jam as far as can be told (enemyJamming), appended to the layer's lists
local function collectEnemyJammers(layer, now)
	for unitID, jammer in pairs(enemyJammers) do
		if enemyJamming(unitID, jammer, now) then
			local def = jammer.def
			appendJammer(layer, unitID, jammer.x, jammer.z, def.range, def.radiusCells, def.mobile)
		end
	end
end

allied.collect = collectAlliedJammers
enemy.collect = collectEnemyJammers

-- Renders the union of a layer's jammers' discs into its texture: each draws just its disc's rectangle
local function drawUnion(layer)
	gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
	local cells = layer.cells
	local sx, sz = 2 / MAP_CELLS_X, 2 / MAP_CELLS_Z
	discShader:Activate()
	for i = 1, layer.count * 3, 3 do
		local bx, bz, radius = cells[i], cells[i + 1], cells[i + 2]
		discShader:SetUniform("discParams", bx, bz, radius, 1)
		discShader:SetUniform(
			"passRect",
			(bx - radius) * sx - 1,
			(bz - radius) * sz - 1,
			(bx + radius + 1) * sx - 1,
			(bz + radius + 1) * sz - 1
		)
		passVAO:DrawArrays(GL.TRIANGLES)
	end
	discShader:SetUniform("passRect", -1, -1, 1, 1)
	discShader:Deactivate()
end

-- Circle mode: renders a layer's jammers' circles into its sdfTex, each over the rectangle its distance field
-- reaches, MAX-blended into their union
local function drawCircles(layer)
	gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
	gl.Blending(GL.ONE, GL.ONE)
	gl.BlendEquation(GL.MAX)
	local circles = layer.circles
	local sx, sz = 2 / Game.mapSizeX, 2 / Game.mapSizeZ
	discShader:Activate()
	for i = 1, layer.count * 3, 3 do
		local x, z, radius = circles[i], circles[i + 1], circles[i + 2]
		local reach = radius + shaderConfig.CIRCLE_SDF_RANGE + RADAR_CELL
		discShader:SetUniform("discParams", x, z, radius, 2)
		discShader:SetUniform(
			"passRect",
			(x - reach) * sx - 1,
			(z - reach) * sz - 1,
			(x + reach) * sx - 1,
			(z + reach) * sz - 1
		)
		passVAO:DrawArrays(GL.TRIANGLES)
	end
	discShader:SetUniform("passRect", -1, -1, 1, 1)
	discShader:Deactivate()
	gl.BlendEquation(GL.FUNC_ADD)
	gl.Blending(false)
end

-- Circle mode: whether a layer's sdfTex no longer holds its circles closely enough. While the sheet has the circle
-- list, which gives it exact edges within CIRCLE_SDF_SLACK more of the field's edges, a circle may move that far first.
local function sdfStale(layer)
	local circles = layer.circles
	local rendered = layer.sdfCircles
	local values = layer.count * 3
	if not layer.sdfValid or #rendered ~= values then
		return true
	end
	local slack = (#layer.circleData > 0) and shaderConfig.CIRCLE_SDF_SLACK or 0
	for i = 1, values, 3 do
		local dx, dz = circles[i] - rendered[i], circles[i + 1] - rendered[i + 1]
		if circles[i + 2] ~= rendered[i + 2] or dx * dx + dz * dz > slack * slack then
			return true
		end
	end
	return false
end

-- Circle mode: re-renders a layer's sdfTex when it is stale
local function refreshSdf(layer)
	if layer.sdfTex and sdfStale(layer) then
		gl.RenderToTexture(layer.sdfTex, drawCircles, layer)
		local circles, rendered, values = layer.circles, layer.sdfCircles, layer.count * 3
		for i = 1, values do
			rendered[i] = circles[i]
		end
		for i = values + 1, #rendered do
			rendered[i] = nil
		end
		layer.sdfValid = true
	end
end

-- Circle mode between checks: moves a layer's covering mobile jammers' circles (and the sheet's circle list) along
-- with their units. Returns whether any of them moved.
---@return boolean
local function moveCircles(layer)
	local circles, data = layer.circles, layer.circleData
	local mobileUnits, mobileSlots = layer.mobileUnits, layer.mobileSlots
	local listed = #data > 0
	local moved = false
	for i = 1, #mobileUnits do
		local _, _, _, mx, _, mz = spGetUnitPosition(mobileUnits[i], true)
		if mx then
			local slot = mobileSlots[i]
			local x, z = circleCenter(mx, mz)
			if x ~= circles[slot] or z ~= circles[slot + 1] then
				circles[slot], circles[slot + 1] = x, z
				if listed then
					data[slot], data[slot + 1] = x, z
					layer.circleDataVersion = layer.circleDataVersion + 1
				end
				moved = true
			end
		end
	end
	return moved
end

-- Re-renders a layer's coverage when a jammer turned on or off, moved to another cell or changed its range, and in
-- circle mode when a circle moved. Between checks only the mobile jammers' smoothly moving circles are updated.
local function updateLayer(layer, now, force)
	if not force and now - layer.checkedAt < ALLIED_POLL_SECONDS then
		if settings.circles and not CIRCLE_SNAP and #layer.mobileUnits > 0 and moveCircles(layer) then
			refreshSdf(layer)
		end
		return
	end
	layer.checkedAt = now
	local cells, previous = layer.scratch, layer.cells
	local circles, previousCircles = layer.circleScratch, layer.circles
	collectedValues, collectedMobile = 0, 0
	layer.collect(layer, now)
	local mobileUnits, mobileSlots = layer.mobileUnits, layer.mobileSlots
	for i = collectedMobile + 1, #mobileUnits do -- so `#` works
		mobileUnits[i], mobileSlots[i] = nil, nil
	end
	local count = collectedValues / 3
	local changed = count ~= layer.count
	if not changed then
		for i = 1, count * 3 do
			if cells[i] ~= previous[i] then
				changed = true
				break
			end
		end
	end
	local circlesChanged = settings.circles and (changed or not layer.sdfValid)
	if settings.circles and not circlesChanged then
		for i = 1, count * 3 do
			if circles[i] ~= previousCircles[i] then
				circlesChanged = true
				break
			end
		end
	end

	if changed then
		layer.cells, layer.scratch, layer.count = cells, previous, count
		local x0, z0, x1, z1 = mathHuge, mathHuge, -mathHuge, -mathHuge
		for i = 1, count * 3, 3 do
			local radius = cells[i + 2]
			x0, x1 = mathMin(x0, cells[i] - radius), mathMax(x1, cells[i] + radius)
			z0, z1 = mathMin(z0, cells[i + 1] - radius), mathMax(z1, cells[i + 1] + radius)
		end
		layer.x0, layer.z0, layer.x1, layer.z1 = x0, z0, x1, z1
		gl.RenderToTexture(layer.tex, drawUnion, layer)
	end
	if circlesChanged then
		layer.circles, layer.circleScratch = circles, previousCircles
		local data, n = layer.circleData, (count <= MAX_ALLIED_CIRCLES) and count * 3 or 0
		for i = 1, n do
			data[i] = circles[i]
		end
		for i = n + 1, #data do
			data[i] = nil
		end
		layer.circleDataVersion = layer.circleDataVersion + 1
		refreshSdf(layer)
	end
end

-- The jammer being previewed right now: its jammerDefs entry and the selected unit (nil while placing one), or nil.
-- Evaluated live by every draw callin rather than cached, so nothing can outlive the command / selection it came from.
local function previewSource()
	if selectedJammerUnitID then
		-- verify every frame, not just on SelectionChanged: the unit may be gone or no longer selected
		local unitDefID = spGetUnitDefID(selectedJammerUnitID)
		local def = unitDefID and jammerDefs[unitDefID]
		if def and spIsUnitSelected(selectedJammerUnitID) then
			return def, selectedJammerUnitID
		end
		selectedJammerUnitID = false
		return nil
	end

	local _, cmdID = spGetActiveCommand()
	local unitDefID ---@type number?
	if cmdID and cmdID < 0 then
		unitDefID = -cmdID
	elseif spGetGameFrame() <= 0 then
		-- before game start builds are queued through the pregame build widget, not via an active command
		local pregameBuild = WG["pregame-build"]
		unitDefID = pregameBuild and pregameBuild.getPreGameDefID and pregameBuild.getPreGameDefID()
	end
	local def = unitDefID and jammerDefs[unitDefID]
	if def and def.radiusCells >= 1 then
		return def, nil
	end
	return nil
end

-- World position under the cursor: through a PIP window, the minimap or the world view; nil on the sky or off the map
local function cursorWorldPos()
	local mx, my = spGetMouseState()
	-- Hovering a PIP (or the PIP-minimap: WG.pip_minimap is the same object as WG.pipN)
	-- maps to the world position under the cursor in that view, not the ground behind it
	for pipNumber = 0, 4 do
		local pipApi = WG["pip" .. pipNumber]
		if pipApi and pipApi.ScreenToWorld then
			local wx, wz = pipApi.ScreenToWorld(mx, my)
			if wx and wz then
				if wx < 0 or wz < 0 or wx > Game.mapSizeX or wz > Game.mapSizeZ then
					return nil
				end
				return wx, spGetGroundHeight(wx, wz), wz
			end
		end
	end
	-- useMiniMap=true: over the engine minimap, trace through it instead of the world behind it
	local _, coords = spTraceScreenRay(mx, my, true, true)
	if not coords or coords[1] < 0 or coords[3] < 0 or coords[1] > Game.mapSizeX or coords[3] > Game.mapSizeZ then
		return nil
	end
	return coords[1], coords[2], coords[3]
end

-- x, z of the mid position of a building placed at x, z with the given facing (CSolidObject::GetObjectSpacePos,
-- buildings are upright: frontdir is the facing's direction and rightdir = (-frontdir.z, frontdir.x))
local function placedMidPos(def, x, z, facing)
	if facing == 1 then
		return x + def.midZ, z + def.midX
	elseif facing == 2 then
		return x + def.midX, z - def.midZ
	elseif facing == 3 then
		return x - def.midZ, z - def.midX
	end
	return x - def.midX, z + def.midZ
end

-- The previewed jammer's radius in cells, the world x, z of its emitter (the unit's mid position), 1 when it does not
-- jam right now (0 when it does or is being placed) and its range in elmos, or nil
local function getPreview()
	local def, unitID = previewSource()
	if not def then
		return nil
	end
	if unitID then
		local _, _, _, mx, _, mz = spGetUnitPosition(unitID, true)
		if not mx then
			return nil
		end
		local range = spGetUnitSensorRadius(unitID, "radarJammer") or 0
		local radiusCells = radiusToCells(range)
		local jamming = radiusCells >= 1 and isJamming(unitID)
		if radiusCells < 1 then
			range, radiusCells = def.range, def.radiusCells -- a game-side pause zeroes the radius
		end
		if radiusCells < 1 then
			return nil
		end
		return radiusCells, mx, mz, jamming and 0 or 1, range
	end

	local x, y, z = cursorWorldPos()
	if not x then
		return nil
	end
	-- snap to the build grid the way the placement itself is snapped (build facing included), so the preview
	-- is computed for the spot the jammer will actually stand on, not the raw cursor position
	local facing = spGetBuildFacing()
	local buildX, _, buildZ = spPos2BuildPos(def.unitDefID, x, y, z, facing)
	local midX, midZ = placedMidPos(def, buildX, buildZ, facing)
	return def.radiusCells, midX, midZ, 0, def.range
end

local function drawPass()
	passVAO:DrawArrays(GL.TRIANGLES)
end

local function drawClearedPass()
	gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
	passVAO:DrawArrays(GL.TRIANGLES)
end

-- Disc and smoothing passes of the previewed jammer. Returns its texture set, nil if it could not be created.
local function preparePreview(radius, range, emitterX, emitterZ, inactive, alreadyShown, now, drawFrame)
	local set = getSet(radius)
	if not set then
		return nil
	end

	-- a gap in draw frames or another radius means the preview just (re)appeared
	local fresh = (drawFrame - preview.frame > 1) or (preview.radius ~= radius)
	local dt = fresh and 0 or mathMin(now - preview.time, 0.1)
	if fresh then
		preview.spawnStart = now - (alreadyShown and 60 or 0) -- coverage already on screen doesn't spread out again
		preview.inactive = inactive
		preview.appearedAt = now
	end
	preview.frame, preview.time, preview.radius = drawFrame, now, radius
	preview.x, preview.z = emitterX, emitterZ
	preview.inactive = preview.inactive + (inactive - preview.inactive) * (1 - mathExp(-dt * SMOOTH_RATE))
	preview.circleX, preview.circleZ = circleCenter(emitterX, emitterZ)
	preview.circleRadius = circleRadius(range, radius)

	local bx, bz = worldToCell(emitterX), worldToCell(emitterZ)
	-- cells the emitter moved since the last frame
	local moved = set.bx and not fresh
	local shiftX = moved and bx - set.bx or 0
	local shiftZ = moved and bz - set.bz or 0
	if shiftX ~= 0 or shiftZ ~= 0 then
		preview.movedAt = now
	end
	if fresh or set.bx ~= bx or set.bz ~= bz then
		if selectedJammerUnitID then
			allied.checkedAt = -mathHuge -- a selected jammer's allied coverage moves along with it, in the same frame
		end
		discShader:Activate()
		discShader:SetUniform("discParams", bx, bz, radius, 0)
		gl.RenderToTexture(set.target, drawClearedPass)
		discShader:Deactivate()
		set.bx, set.bz, set.changedAt = bx, bz, now
	end

	-- ease the shown coverage towards the disc (ping-pong between the two state textures); the previous state
	-- is read shifted by the emitter's move, so cells stay put in the world. Once it has settled, it stays.
	if now - set.changedAt < SMOOTH_SETTLE_SECONDS then
		local prevTex = set.state[set.cur]
		set.cur = 3 - set.cur
		gl.Texture(0, prevTex)
		gl.Texture(1, set.target)
		smoothShader:Activate()
		local smoothRate = (not selectedJammerUnitID and (now - preview.movedAt) < 0.3) and SMOOTH_RATE_DRAG
			or SMOOTH_RATE
		smoothShader:SetUniform("smoothParams", shiftX, shiftZ, 1 - mathExp(-dt * smoothRate), fresh and 1 or 0)
		gl.RenderToTexture(set.state[set.cur], drawPass)
		smoothShader:Deactivate()
		gl.Texture(0, false)
		gl.Texture(1, false)
	end
	return set
end

-- Clip-space rectangle of the screen area that can show a rectangle of radar cells: the screen bounds of its box from
-- the lowest to the highest ground, clipped to the screen. The whole screen when the box reaches behind the camera.
local function getScreenRect(x0, z0, x1, z1)
	local minY, maxY = spGetGroundExtremes()
	minY, maxY = mathMax(minY or 0, 0), mathMax(maxY or 0, 0) -- below 0 the sheet lies on the water surface
	local camX, camY, camZ = spGetCameraPosition()
	local dirX, dirY, dirZ = spGetCameraDirection()
	local vsx, vsy = spGetViewGeometry()
	local left, bottom, right, top = mathHuge, mathHuge, -mathHuge, -mathHuge
	for corner = 0, 7 do
		local x, y, z = x0, minY, z0
		if corner % 2 == 1 then
			x = x1 + 1
		end
		if corner % 4 >= 2 then
			z = z1 + 1
		end
		if corner >= 4 then
			y = maxY
		end
		x, z = x * RADAR_CELL, z * RADAR_CELL
		if (x - camX) * dirX + (y - camY) * dirY + (z - camZ) * dirZ < 1 then
			return -1, -1, 1, 1
		end
		local sx, sy = spWorldToScreenCoords(x, y, z)
		left, right = mathMin(left, sx), mathMax(right, sx)
		bottom, top = mathMin(bottom, sy), mathMax(top, sy)
	end
	-- a pixel of slack for the outline's anti-aliasing
	return mathMax((left - 1) / vsx * 2 - 1, -1),
		mathMax((bottom - 1) / vsy * 2 - 1, -1),
		mathMin((right + 1) / vsx * 2 - 1, 1),
		mathMin((top + 1) / vsy * 2 - 1, 1)
end

-- radar cells past the map's edge the circle mode's outline can reach while it fades out (OFFMAP_OUTLINE_FADE)
local OFFMAP_MARGIN_CELLS = mathCeil(shaderConfig.OFFMAP_OUTLINE_FADE / RADAR_CELL) + 1

-- The camera distance fade's strength this frame: none while a jammer is previewed, as placing or selecting one needs
-- its coverage at any zoom, nor for a player outside the LOS view (NO_FADE_WITHOUT_LOS_VIEW). Eased, so the coverage
-- doesn't pop in or out when that changes.
local function updateDistanceFade(previewing, now, drawFrame)
	local target = 1
	if previewing or (NO_FADE_WITHOUT_LOS_VIEW and not spectating and spGetMapDrawMode() ~= "los") then
		target = 0
	end
	local fade = distanceFade
	if drawFrame - fade.frame > 1 then
		fade.strength = target -- (re)appearing: nothing to ease from
	else
		local step = 1 - mathExp(-mathMin(now - fade.time, 0.1) * SMOOTH_RATE)
		fade.strength = fade.strength + (target - fade.strength) * step
		if mathAbs(target - fade.strength) < 0.001 then
			fade.strength = target
		end
	end
	fade.frame, fade.time = drawFrame, now
	return fade.strength
end

-- true when the camera is so far above the ground that the fade hides all of the coverage
local function fadedOut(strength)
	if strength < 1 then
		return false
	end
	local _, camY = spGetCameraPosition()
	local _, initMaxHeight, _, maxHeight = spGetGroundExtremes()
	return camY - mathMax(maxHeight or initMaxHeight or 0, 0) >= shaderConfig.FADE_END
end

-- The sheet of a coverage layer, with the previewed disc (`set`) over it: one pass over their screen area that
-- projects it onto the terrain
local function drawSheet(layer, set, showLayer, now)
	local x0, z0, x1, z1 = mathHuge, mathHuge, -mathHuge, -mathHuge
	if set then
		x0, z0, x1, z1 = set.bx - set.radius, set.bz - set.radius, set.bx + set.radius, set.bz + set.radius
	end
	if showLayer and layer.count > 0 then
		x0, z0 = mathMin(x0, layer.x0), mathMin(z0, layer.z0)
		x1, z1 = mathMax(x1, layer.x1), mathMax(z1, layer.z1)
	end
	-- a circle reaches up to two cells past its disc, and its outline fades out a little past the map's edge
	local margin = 0
	if settings.circles then
		x0, z0, x1, z1 = x0 - 2, z0 - 2, x1 + 2, z1 + 2
		margin = OFFMAP_MARGIN_CELLS
	end
	x0, z0 = mathMax(x0, -margin), mathMax(z0, -margin)
	x1, z1 = mathMin(x1, MAP_CELLS_X - 1 + margin), mathMin(z1, MAP_CELLS_Z - 1 + margin)
	if x1 < x0 or z1 < z0 then
		return
	end
	local left, bottom, right, top = getScreenRect(x0, z0, x1, z1)
	if right <= left or top <= bottom then
		return -- off screen
	end

	gl.Texture(0, "$map_gbuffer_zvaltex")
	if hasModelDepth then
		gl.Texture(1, "$model_gbuffer_zvaltex")
	end
	if set then
		gl.Texture(2, set.state[set.cur])
		gl.Texture(4, set.target) -- exact coverage: the outline follows it without the smoothing's delay
	end
	if showLayer then
		gl.Texture(3, layer.tex)
		if settings.circles and layer.sdfTex then
			gl.Texture(5, layer.sdfTex)
		end
	end
	local sheetShader = layer.sheetShader
	sheetShader:Activate()
	sheetShader:SetUniform("circleMode", settings.circles and 1 or 0)
	if settings.circles then
		local fadeIn = 1 - mathExp(-(now - preview.appearedAt) * SMOOTH_RATE)
		sheetShader:SetUniform(
			"circleParams",
			preview.circleX,
			preview.circleZ,
			set and preview.circleRadius or 0,
			fadeIn
		)
		local circleValues = #layer.circleData
		if circleValues > 0 and layer.uploadedCircleDataVersion ~= layer.circleDataVersion then
			sheetShader:SetUniformFloatArray("alliedCircles", layer.circleData)
			layer.uploadedCircleDataVersion = layer.circleDataVersion
		end
		sheetShader:SetUniform("alliedCircleCount", circleValues / 3)
	end
	if set then
		sheetShader:SetUniform("previewParams", set.bx, set.bz, set.radius, now - preview.spawnStart)
	else
		sheetShader:SetUniform("previewParams", 0, 0, -1, 0)
	end
	sheetShader:SetUniform("previewInactive", set and preview.inactive or 0)
	sheetShader:SetUniform("emitterXZ", preview.x, preview.z)
	-- the layer's coverage fades in with the preview, unless it is always shown
	local layerOpacity = settings.alwaysShow and 1 or mathMin((now - preview.spawnStart) * 4, 1)
	sheetShader:SetUniform("alliedParams", showLayer and 1 or 0, layerOpacity)
	sheetShader:SetUniform("fadeStrength", distanceFade.strength)
	sheetShader:SetUniform("stippleOffset", (now * OUTLINE_DASH_SPEED / RADAR_CELL) % 1)
	sheetShader:SetUniform("passRect", left, bottom, right, top)
	passVAO:DrawArrays(GL.TRIANGLES)
	sheetShader:Deactivate()
	for unit = 0, 5 do
		gl.Texture(unit, false)
	end
end

function widget:DrawWorld()
	if Spring.IsGUIHidden() or (WG.topbar and WG.topbar.showingQuit()) then
		return
	end
	local radius, emitterX, emitterZ, inactive, range = getPreview()
	local showAllied = settings.alwaysShow or (radius ~= nil and settings.alliedCoverage)
	if not (radius or showAllied) then
		return
	end
	local showEnemy = enemyViewAllyTeamID and true or false -- tracked while enemy coverage is wanted

	local now = osClock()
	local drawFrame = spGetDrawFrame()
	gl.DepthTest(false)
	gl.Culling(false)
	gl.Blending(false)
	local set
	if radius then
		-- a selected allied jammer that jams was already drawn with the always shown allied coverage
		local alreadyShown = settings.alwaysShow and inactive == 0 and jammerUnits[selectedJammerUnitID] ~= nil
		set = preparePreview(radius, range or 0, emitterX, emitterZ, inactive or 0, alreadyShown, now, drawFrame)
	end
	-- check right away when a layer's coverage (re)appears, it may be stale
	if showAllied then
		updateLayer(allied, now, drawFrame - allied.shownFrame > 1)
		allied.shownFrame = drawFrame
	end
	if showEnemy then
		updateLayer(enemy, now, drawFrame - enemy.shownFrame > 1)
		enemy.shownFrame = drawFrame
	end
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	-- zoomed out too far for any of it to show: the minimap still draws it
	if not fadedOut(updateDistanceFade(radius ~= nil, now, drawFrame)) then
		coverageShownFrame = drawFrame
		if showEnemy then
			drawSheet(enemy, nil, true, now)
		end
		drawSheet(allied, set, showAllied, now)
	end
	minimapFrame, minimapSet, minimapInactive = drawFrame, set, preview.inactive
	minimapAllied, minimapEnemy = showAllied, showEnemy
end

-- A coverage layer's minimap pass, with the previewed disc (`set`) over it
local function drawMinimapLayer(layer, set, showLayer)
	if set then
		gl.Texture(0, set.state[set.cur]) -- smoothed coverage: the fill
		gl.Texture(2, set.target) -- exact engine coverage: the outline
	end
	if showLayer then
		gl.Texture(1, layer.tex)
	end
	local minimapShader = layer.minimapShader
	minimapShader:Activate()
	if set then
		minimapShader:SetUniform("discParams", set.bx, set.bz, set.radius, showLayer and 1 or 0)
	else
		minimapShader:SetUniform("discParams", 0, 0, -1, 1)
	end
	minimapShader:SetUniform(
		"inactiveParams",
		set and minimapInactive or 0,
		shaderConfig.INACTIVE_ALPHA,
		shaderConfig.INACTIVE_OUTLINE_ALPHA
	)
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

-- Flat fill of the previewed, allied and enemy jammer coverage on the minimap, outlined at uncovered cells. Also
-- reached through the PIP minimap, which forwards this callin with its viewport remapped. Only draws while
-- DrawWorld is drawing: the engine renders its minimap texture from Game::Update, before DrawWorld and at its
-- own refresh rate, so the previous draw frame has to count as current here.
function widget:DrawInMiniMap()
	if not settings.minimap or spGetDrawFrame() - minimapFrame > 1 then
		return
	end
	-- the live check keeps the preview on the minimap from outliving its command / selection
	local set = minimapSet
	if set and not previewSource() then
		set = nil
	end
	local shown = settings.alwaysShow or set ~= nil
	local showAllied = minimapAllied and shown
	local showEnemy = minimapEnemy and shown and enemy.count > 0
	if not (set or showAllied or showEnemy) then
		return
	end

	gl.DepthTest(false)
	gl.Culling(false)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	if showEnemy then
		drawMinimapLayer(enemy, nil, true)
	end
	if set or showAllied then
		drawMinimapLayer(allied, set, showAllied)
	end
end

function widget:SelectionChanged(sel)
	selectedJammerUnitID = false
	if #sel == 1 and jammerDefs[spGetUnitDefID(sel[1])] then
		selectedJammerUnitID = sel[1]
	end
end

function widget:Initialize()
	-- no shader support (headless), or no fog of war, which leaves jammers nothing to hide
	if not gl.CreateShader or Spring.GetModOptions().disable_fogofwar then
		widgetHandler:RemoveWidget()
		return
	end
	if not initgl4() then
		return
	end
	scanAlliedUnits()
	readConfig() -- after the scan, which tells whether there is full view
	widget:SelectionChanged(Spring.GetSelectedUnits())
	WG.jammerPreview = {
		-- whether coverage (allied or previewed) was drawn this draw frame or the last one, for gui_jammed_units.lua
		isCoverageShown = function()
			return spGetDrawFrame() - coverageShownFrame <= 1
		end,
	}
end

function widget:Shutdown()
	WG.jammerPreview = nil
	deleteTextures()
	for _, shader in ipairs({ discShader, smoothShader }) do
		shader:Delete()
	end
	for _, layer in ipairs(layers) do
		layer.sheetShader:Delete()
		layer.minimapShader:Delete()
	end
end

-- the ghosts, for the next load of the widget (restoreGhosts)
function widget:GetConfigData()
	local ghosts = {}
	for unitID, jammer in pairs(enemyJammers) do
		if jammer.ghost then
			local saved =
				{ unitID = unitID, unitDefID = jammer.def.unitDefID, disproved = jammer.disprovedAt > -mathHuge }
			for _, field in ipairs(GHOST_FIELDS) do
				saved[field] = jammer[field]
			end
			ghosts[#ghosts + 1] = saved
		end
	end
	return {
		gameID = currentGameID(),
		frame = spGetGameFrame(),
		viewAllyTeamID = enemyViewAllyTeamID or nil,
		ghosts = ghosts,
	}
end

-- Only before Initialize, and only later in the same game: the unit IDs must still be those units. A rejoining client
-- loads at frame 0 and gets its ghosts back from the catch-up simulation's LOS callins.
function widget:SetConfigData(data)
	local gameID = currentGameID()
	if
		enemyViewAllyTeamID == false
		and gameID ~= nil
		and data.gameID == gameID
		and spGetGameFrame() >= (data.frame or mathHuge)
	then
		savedGhosts = data
	end
end
