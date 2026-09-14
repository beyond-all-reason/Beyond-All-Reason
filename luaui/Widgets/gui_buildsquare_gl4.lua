--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    gui_buildsquare_gl4.lua
--  brief:   Example widget demonstrating DrawBuildSquare callin with GL4 rendering
--  author:  RecoilEngine contributors
--
--  Demonstrates:
--    - Using the DrawBuildSquare callin to receive per-cell build placement data
--    - Using Spring.SetEngineBuildSquareRendering(false) to replace engine rendering
--    - Using GL4 VAO/VBO/shader via raw engine API (gl.CreateShader, gl.GetVBO, gl.GetVAO)
--
--  License: GNU GPL, v2 or later
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name = "BuildSquare GL4",
		desc = "GL4 custom build placement grid rendering via DrawBuildSquare callin",
		author = "RecoilEngine contributors, Floris",
		date = "July 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Localized API

local glCreateShader = gl.CreateShader
local glDeleteShader = gl.DeleteShader
local glUseShader = gl.UseShader
local glGetShaderLog = gl.GetShaderLog
local glGetUniformLocation = gl.GetUniformLocation
local glUniform = gl.Uniform
local glUniformInt = gl.UniformInt
local glGetVBO = gl.GetVBO
local glGetVAO = gl.GetVAO
local glGetEngineUniformBufferDef = gl.GetEngineUniformBufferDef
local glDepthTest = gl.DepthTest
local glBlending = gl.Blending
local glTexture = gl.Texture
local glCulling = gl.Culling
local vfsDirList = VFS.DirList
local vfsLoadFile = VFS.LoadFile
local VFS_RAW_FIRST = VFS.RAW_FIRST
local spSetEngineBuildSquareRendering = Spring.SetEngineBuildSquareRendering or function() end
local spPos2BuildPos = Spring.Pos2BuildPos
local spGetGroundHeight = Spring.GetGroundHeight
local spGetWaterPlaneLevel = Spring.GetWaterPlaneLevel
local spGetGroundNormal = Spring.GetGroundNormal
local spGetGroundBlocked = Spring.GetGroundBlocked
local spGetFeatureDefID = Spring.GetFeatureDefID
local spGetUnitDefID = Spring.GetUnitDefID
local spGetMyPlayerID = Spring.GetMyPlayerID
local spGetMouseState = Spring.GetMouseState
local spTraceScreenRay = Spring.TraceScreenRay
local spGetBuildFacing = Spring.GetBuildFacing
local spTestBuildOrder = Spring.TestBuildOrder
local spGetActiveCommand = Spring.GetActiveCommand
local spGetTimer = Spring.GetTimer
local spDiffTimers = Spring.DiffTimers
local spGetDrawFrame = Spring.GetDrawFrame
local spGetGameFrame = Spring.GetGameFrame
local spGetMiniMapRotation = Spring.GetMiniMapRotation
local GL_ARRAY_BUFFER = GL.ARRAY_BUFFER
local GL_TRIANGLE_STRIP = GL.TRIANGLE_STRIP
local GL_LESS = GL.LESS
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA

local SQUARE_SIZE = 8
local BUILD_GRID_SIZE = SQUARE_SIZE * 2
local MAP_SIZE_X = Game.mapSizeX
local MAP_SIZE_Z = Game.mapSizeZ
local mathAbs = math.abs
local mathCeil = math.ceil

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Configuration

local ONLY_WHEN_BLOCKED = true -- when true, only show the extended cells when the building can't be placed
local OPEN_YARDMAP_ONLY_WHEN_BLOCKED = true
local CELL_DISTANCE = 2
local CORNER_RADIUS = 0.22
local STYLE_OPEN_YARDMAP_CELLS_AS_EXTENDED = true
local EXTENDED_CELLS = 0
local COMBINE_FOUR_CELLS = true
local COMBINE_VALID_FOOTPRINT_CELLS = true -- merge same-styled cells of a placeable footprint into blocks with a single outline
local FOLLOW_EXTRACTOR_SNAP = true -- draw the preview at the spot the extractor snap widget targets instead of at the cursor
local EXTENDED_ALPHA_NEAR = 0.1
local EXTENDED_ALPHA_FAR = 0.05
local FOOTPRINT_BOUNDARY_WIDTH = 0.22
local SHOW_INVALID_FOOTPRINT_BOUNDARY = false
local EXTENDED_STATUS_UPDATE_INTERVAL = 0.20
local TARGET_STATUS_CHECKS_PER_GAME_FRAME = 64
local TARGET_STATUS_CELLS_PER_GAME_FRAME = 512
local MAX_STATUS_CHECK_PERIOD = 10
local SIMPLIFIED_FOOTPRINTS_ENABLED = true
local SIMPLIFIED_OUTLINE_SCALE = 0.5
local SIMPLIFIED_CORNER_RADIUS_SCALE = 0.5 -- corner radius of simplified quads and merged blocks, relative to CORNER_RADIUS, at the reference footprint size
local SIMPLIFIED_SIZE_REFERENCE_CELLS = 6 -- footprint size (cells) at which the simplified corner radius and outline scales apply unchanged
local SIMPLIFIED_SIZE_FALLOFF = 0.55 -- corner radius and outline width vs footprint size: 0 = proportional, 1 = same for every size, in between = diminishing growth
local SIMPLIFIED_BUILDING_THRESHOLD = 384
local SIMPLIFIED_CELL_THRESHOLD = 8192
local MINIMUM_SCREEN_DIAMETER = 3.0
local SIMPLIFIED_MINIMAP_ENABLED = true
local MAX_MINIMAP_BUILDINGS = 16384
local MAX_BATCH_CELLS = 262144
local PREUNIT_PASS_ALPHA = 0.8 -- opacity multiplier of the base DrawWorldPreUnit pass
local OVERLAY_PASS_ENABLED = true -- redraw the squares in DrawWorld (on top of units) so they stay faintly visible when covered
local OVERLAY_PASS_ALPHA = 0.3 -- opacity multiplier of the DrawWorld overlay pass

local STATUS_BLOCKED = 0
local STATUS_OCCUPIED = 1
local STATUS_RECLAIMABLE = 2
local STATUS_OPEN = 3

local STATUS_COLORS = {
	[STATUS_BLOCKED] = { 1.0, 0.1, 0.3, 0.33 },
	[STATUS_OCCUPIED] = { 0.75, 1.0, 0.15, 0.33 },
	[STATUS_RECLAIMABLE] = { 0.40, 1.0, 0.20, 0.33 },
	[STATUS_OPEN] = { 0.70, 0.90, 0.10, 0.33 },
}
local VALID_FOOTPRINT_COLOR = { 0.0, 1.0, 0.3, 0.37 }
-- local STATUS_OUTLINE_COLORS = {
-- 	[STATUS_BLOCKED]     = { 0.85, 0.05, 0.15, 0.5 },
-- 	[STATUS_OCCUPIED]    = { 0.18, 0.25, 0.02, 0.7 },
-- 	[STATUS_RECLAIMABLE] = { 0.60, 1.00, 0.33, 0.7 },
-- 	[STATUS_OPEN]        = { 0.85, 1.00, 0.50, 0.7 },
-- }
local STATUS_OUTLINE_COLORS = {
	[STATUS_BLOCKED] = { 0.50, 0.05, 0.05, 0.4 },
	[STATUS_OCCUPIED] = { 0.66, 0.15, 0.05, 0.4 },
	[STATUS_RECLAIMABLE] = { 0.55, 0.20, 0.05, 0.4 },
	[STATUS_OPEN] = { 0.30, 0.30, 0.05, 0.4 },
}
local VALID_FOOTPRINT_OUTLINE_COLOR = { 0.66, 1.00, 0.66, 0.45 }
local INVALID_FOOTPRINT_BOUNDARY_COLOR = { 1.00, 0.15, 0.15, 0.4 }

local HEIGHT_OFFSET = 0.5
local PREGAME_STARTBOX_HEIGHT_OFFSET = 2.0

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- State

local shaderProgram = nil
local isMiniMapLoc = nil
local rotationMiniMapLoc = nil
local heightOffsetLoc = nil
local waterLevelLoc = nil
local alphaMultiplierLoc = nil
local quadVBO = nil
local batchInstanceVBO = nil
local batchVAO = nil
local minimapInstanceVBO = nil
local minimapVAO = nil
local geometryDataCaches = {}
local footprintDataCaches = {}
local batchInstanceData = {}
local batchInstanceDataLength = 0
local batchInstanceCount = 0
local minimapInstanceData = {}
local minimapInstanceDataLength = 0
local minimapInstanceCount = 0
local collectedPreviews = {}
local collectedPreviewCount = 0
local collectedDrawFrame = -1
local collectedBatchChanged = true
local residentBatchPreviewCount = 0

local extendedStatuses = {}
local sourceCellStatuses = {}
local sourceOpenYardmapFlags = {}
local sourceTerrainBlockedFlags = {}
local mergeCellKeys = {}
local mergeStyleColors = {}
local mergeStyleOutlineColors = {}
local mergeStyleAlphas = {}
local mergeStyleOutlineAlphas = {}
local mergeRectData = {}
local mergeOpenRects = {}
local styleColorIds = {}
local styleColorIdCount = 0
local candidateBuildHeights = {}
local candidateBuildHeightGenerations = {}
local candidateBuildHeightGeneration = 0
local MAX_PREVIEW_RENDER_CACHES = 512
local previewRenderCaches = {}
local previewRenderCacheCount = 0
local nextPreviewRenderCache = 1
local previewRenderCacheLookup = {}
local extendedCellsDrawFrame = -1
local overlayBatchDrawFrame = -1
local drawSquareCount = 0
local drawSquareCellCount = 0
local effectiveExtendedCells = EXTENDED_CELLS
local simplifiedFootprintMode = false
local buildSquareGameFrame = -1
local statusCheckPeriod = 1
local statusChecksEnabled = true
local statusCheckTargetPhase = 0
local orderedPreviewCaches = {}
local pregameStatuses = {}
local snapStatuses = {}
local pregameCancelledBuilds = {}

local MAX_CELLS = 4096

local function loadUnitYardmap(unitDef)
	local customParams = unitDef.customParams
	local yardmap = customParams and customParams.buildsquare_yardmap
	if yardmap then
		return yardmap
	end

	local sourceName = customParams and customParams.fromunit or unitDef.name
	local subfolder = customParams and customParams.subfolder
	local source
	if subfolder then
		local sourcePath = ("units/" .. subfolder .. "/" .. sourceName .. ".lua"):lower()
		source = vfsLoadFile(sourcePath, VFS_RAW_FIRST)
	end
	if not source then
		local files = vfsDirList("units/", sourceName .. ".lua", VFS_RAW_FIRST, true)
		local sourcePath = files[1] and files[1]:lower()
		source = sourcePath and vfsLoadFile(sourcePath, VFS_RAW_FIRST)
	end
	if not source then
		return nil
	end
	return source:match('[Yy][Aa][Rr][Dd][Mm][Aa][Pp]%s*=%s*"([^"]*)"')
		or source:match("[Yy][Aa][Rr][Dd][Mm][Aa][Pp]%s*=%s*'([^']*)'")
end

local function getOpenYardmapCells(unitDef, facing, xsize, zsize, yardmap)
	if not STYLE_OPEN_YARDMAP_CELLS_AS_EXTENDED or not yardmap then
		return nil
	end

	yardmap = yardmap:lower():gsub("%s+", "")
	local highResolution = yardmap:sub(1, 1) == "h"
	if highResolution then
		yardmap = yardmap:sub(2)
	end

	local sourceXsize = unitDef.xsize
	local sourceZsize = unitDef.zsize
	local yardmapXsize = highResolution and sourceXsize or sourceXsize / 2
	local openCells
	for zi = 0, zsize - 1 do
		for xi = 0, xsize - 1 do
			local sourceX, sourceZ
			if facing == 1 then
				sourceX = sourceXsize - zi - 1
				sourceZ = xi
			elseif facing == 2 then
				sourceX = sourceXsize - xi - 1
				sourceZ = sourceZsize - zi - 1
			elseif facing == 3 then
				sourceX = zi
				sourceZ = sourceZsize - xi - 1
			else
				sourceX = xi
				sourceZ = zi
			end
			if not highResolution then
				sourceX = math.floor(sourceX / 2)
				sourceZ = math.floor(sourceZ / 2)
			end

			local yardmapIndex = sourceZ * yardmapXsize + sourceX + 1
			if yardmap:sub(yardmapIndex, yardmapIndex) == "y" then
				openCells = openCells or {}
				openCells[zi * xsize + xi + 1] = true
			end
		end
	end
	return openCells
end

local function getFootprintData(unitDefID, facing)
	local unitCaches = footprintDataCaches[unitDefID]
	if not unitCaches then
		unitCaches = {}
		footprintDataCaches[unitDefID] = unitCaches
	end
	local footprint = unitCaches[facing]
	if footprint then
		return footprint
	end

	local ud = UnitDefs[unitDefID]
	if not ud then
		return nil
	end
	local xsize = ((facing % 2) == 0) and ud.xsize or ud.zsize
	local zsize = ((facing % 2) == 1) and ud.xsize or ud.zsize
	if not unitCaches.yardmapResolved then
		unitCaches.yardmap = loadUnitYardmap(ud)
		unitCaches.yardmapResolved = true
	end
	footprint = {
		xsize = xsize,
		zsize = zsize,
		halfXsize = math.floor(xsize / 2),
		halfZsize = math.floor(zsize / 2),
		cellCount = xsize * zsize,
		openYardmapCells = getOpenYardmapCells(ud, facing, xsize, zsize, unitCaches.yardmap),
	}
	unitCaches[facing] = footprint
	return footprint
end

local function appendCollectedPreview(renderCache)
	if collectedDrawFrame ~= extendedCellsDrawFrame then
		collectedPreviewCount = 0
		collectedDrawFrame = extendedCellsDrawFrame
		collectedBatchChanged = false
	end

	if renderCache.collectedDrawFrame == extendedCellsDrawFrame then
		drawSquareCount = drawSquareCount - 1
		drawSquareCellCount = drawSquareCellCount - (renderCache.sourceCellCount or renderCache.batchNumCells or 0)
		if renderCache.collectedColorRevision ~= renderCache.colorRevision then
			renderCache.collectedColorRevision = renderCache.colorRevision
			collectedBatchChanged = true
		end
		return
	end
	renderCache.collectedDrawFrame = extendedCellsDrawFrame

	collectedPreviewCount = collectedPreviewCount + 1
	if collectedPreviews[collectedPreviewCount] ~= renderCache then
		collectedBatchChanged = true
		collectedPreviews[collectedPreviewCount] = renderCache
	end
	if renderCache.collectedColorRevision ~= renderCache.colorRevision then
		renderCache.collectedColorRevision = renderCache.colorRevision
		collectedBatchChanged = true
	end
end

local function collectPreview(
	renderCache,
	originX,
	originZ,
	numCells,
	xsize,
	zsize,
	extendedCells,
	cellScale,
	simplified,
	merged
)
	appendCollectedPreview(renderCache)
	if
		renderCache.batchNumCells ~= numCells
		or renderCache.batchSimplified ~= simplified
		or renderCache.batchMerged ~= merged
		or renderCache.batchOriginX ~= originX
		or renderCache.batchOriginZ ~= originZ
		or renderCache.batchCellScale ~= cellScale
	then
		collectedBatchChanged = true
		renderCache.batchOriginX = originX
		renderCache.batchOriginZ = originZ
		renderCache.batchNumCells = numCells
		renderCache.batchXsize = xsize
		renderCache.batchZsize = zsize
		renderCache.batchExtendedCells = extendedCells
		renderCache.batchCellScale = cellScale
		renderCache.batchSimplified = simplified
		renderCache.batchMerged = merged
	end
end

local function getCellGeometry(xsize, zsize, extendedCells, cellScale)
	local xsizeCaches = geometryDataCaches[xsize]
	if not xsizeCaches then
		xsizeCaches = {}
		geometryDataCaches[xsize] = xsizeCaches
	end
	local zsizeCaches = xsizeCaches[zsize]
	if not zsizeCaches then
		zsizeCaches = {}
		xsizeCaches[zsize] = zsizeCaches
	end
	local extendedCellsCaches = zsizeCaches[extendedCells]
	if not extendedCellsCaches then
		extendedCellsCaches = {}
		zsizeCaches[extendedCells] = extendedCellsCaches
	end
	local geometryData = extendedCellsCaches[cellScale]
	if geometryData then
		return geometryData
	end

	tracy.ZoneBeginN("W:BuildSquare:BuildGeometry")
	geometryData = {}
	local dataIndex = 0
	for zi = -extendedCells, zsize + extendedCells - 1 do
		for xi = -extendedCells, xsize + extendedCells - 1 do
			local isFootprintCell = xi >= 0 and xi < xsize and zi >= 0 and zi < zsize
			local footprintEdges = 0
			if isFootprintCell then
				if xi == 0 then
					footprintEdges = footprintEdges + 1
				end
				if xi == xsize - 1 then
					footprintEdges = footprintEdges + 2
				end
				if zi == 0 then
					footprintEdges = footprintEdges + 4
				end
				if zi == zsize - 1 then
					footprintEdges = footprintEdges + 8
				end
			end

			dataIndex = dataIndex + 1
			geometryData[dataIndex] = xi * SQUARE_SIZE * cellScale
			dataIndex = dataIndex + 1
			geometryData[dataIndex] = zi * SQUARE_SIZE * cellScale
			dataIndex = dataIndex + 1
			geometryData[dataIndex] = footprintEdges
		end
	end
	extendedCellsCaches[cellScale] = geometryData
	tracy.ZoneEnd()
	return geometryData
end

local function beginBuildSquareDrawFrame(drawFrame)
	if drawFrame ~= extendedCellsDrawFrame then
		effectiveExtendedCells = drawSquareCount <= 1 and EXTENDED_CELLS or 0
		simplifiedFootprintMode = SIMPLIFIED_FOOTPRINTS_ENABLED
			and (drawSquareCount >= SIMPLIFIED_BUILDING_THRESHOLD or drawSquareCellCount >= SIMPLIFIED_CELL_THRESHOLD)
		statusCheckPeriod = math.min(
			MAX_STATUS_CHECK_PERIOD,
			math.max(
				1,
				math.ceil(drawSquareCount / TARGET_STATUS_CHECKS_PER_GAME_FRAME),
				math.ceil(drawSquareCellCount / TARGET_STATUS_CELLS_PER_GAME_FRAME)
			)
		)
		local gameFrame = spGetGameFrame()
		statusChecksEnabled = gameFrame ~= buildSquareGameFrame
		buildSquareGameFrame = gameFrame
		statusCheckTargetPhase = gameFrame % statusCheckPeriod
		extendedCellsDrawFrame = drawFrame
		drawSquareCount = 0
		drawSquareCellCount = 0
	end
	return drawFrame
end

local function getEffectiveExtendedCells()
	if extendedCellsDrawFrame < 0 then
		beginBuildSquareDrawFrame(spGetDrawFrame())
	end
	drawSquareCount = drawSquareCount + 1
	return effectiveExtendedCells, buildSquareGameFrame, statusCheckPeriod, drawSquareCount, simplifiedFootprintMode
end

local function getPredictedCellStatus(unitDef, worldX, worldZ, buildHeight)
	if worldX < 0 or worldZ < 0 or worldX >= MAP_SIZE_X or worldZ >= MAP_SIZE_Z then
		return STATUS_BLOCKED, STATUS_OPEN
	end

	local groundHeight = spGetGroundHeight(worldX, worldZ)
	local minWaterDepth = unitDef.minWaterDepth
	local maxWaterDepth = unitDef.maxWaterDepth
	if groundHeight < -maxWaterDepth or groundHeight > -minWaterDepth then
		return STATUS_BLOCKED, STATUS_OPEN
	end

	if not (unitDef.floatOnWater and groundHeight <= 0) then
		if unitDef.isImmobile then
			if mathAbs(buildHeight - groundHeight) > unitDef.maxHeightDif then
				return STATUS_BLOCKED, STATUS_OPEN
			end
		else
			local moveDef = unitDef.moveDef
			local maxSlope = moveDef and moveDef.maxSlope
			if maxSlope then
				local _, _, _, slope = spGetGroundNormal(worldX, worldZ, false)
				if slope > maxSlope then
					return STATUS_BLOCKED, STATUS_OPEN
				end
			end
		end
	end

	local objectType, objectID = spGetGroundBlocked(worldX, worldZ)
	if objectType == "feature" then
		local featureDefID = spGetFeatureDefID(objectID)
		local featureDef = featureDefID and FeatureDefs[featureDefID]
		if featureDef and featureDef.reclaimable then
			return STATUS_RECLAIMABLE, STATUS_RECLAIMABLE
		end
		return STATUS_BLOCKED, STATUS_BLOCKED
	elseif objectType == "unit" then
		local blockingUnitDefID = spGetUnitDefID(objectID)
		local blockingUnitDef = blockingUnitDefID and UnitDefs[blockingUnitDefID]
		if blockingUnitDef and not blockingUnitDef.isImmobile then
			return STATUS_OCCUPIED, STATUS_OCCUPIED
		end
		return STATUS_BLOCKED, STATUS_BLOCKED
	end

	return STATUS_OPEN, STATUS_OPEN
end

local function findPreviewRenderCache(unitDefID, x, z, facing)
	local unitCaches = previewRenderCacheLookup[unitDefID]
	local facingCaches = unitCaches and unitCaches[facing]
	local xCaches = facingCaches and facingCaches[x]
	return xCaches and xCaches[z]
end

local function removePreviewRenderCache(cache)
	local unitCaches = previewRenderCacheLookup[cache.unitDefID]
	local facingCaches = unitCaches and unitCaches[cache.facing]
	local xCaches = facingCaches and facingCaches[cache.x]
	if xCaches and xCaches[cache.z] == cache then
		xCaches[cache.z] = nil
		if not next(xCaches) then
			facingCaches[cache.x] = nil
			if not next(facingCaches) then
				unitCaches[cache.facing] = nil
				if not next(unitCaches) then
					previewRenderCacheLookup[cache.unitDefID] = nil
				end
			end
		end
	end
end

local function addPreviewRenderCache(cache)
	local unitCaches = previewRenderCacheLookup[cache.unitDefID]
	if not unitCaches then
		unitCaches = {}
		previewRenderCacheLookup[cache.unitDefID] = unitCaches
	end
	local facingCaches = unitCaches[cache.facing]
	if not facingCaches then
		facingCaches = {}
		unitCaches[cache.facing] = facingCaches
	end
	local xCaches = facingCaches[cache.x]
	if not xCaches then
		xCaches = {}
		facingCaches[cache.x] = xCaches
	end
	xCaches[cache.z] = cache
end

local function getPreviewRenderCache(unitDefID, x, z, facing, sequenceIndex)
	local cache = orderedPreviewCaches[sequenceIndex]
	if cache and cache.unitDefID == unitDefID and cache.x == x and cache.z == z and cache.facing == facing then
		return cache
	end

	cache = findPreviewRenderCache(unitDefID, x, z, facing)
	if cache then
		orderedPreviewCaches[sequenceIndex] = cache
		return cache
	end

	if previewRenderCacheCount < MAX_PREVIEW_RENDER_CACHES then
		previewRenderCacheCount = previewRenderCacheCount + 1
		cache = {
			footprintStatuses = {},
			extendedStatuses = {},
			colorData = {},
		}
		previewRenderCaches[previewRenderCacheCount] = cache
	else
		local checkedCacheCount = 0
		while checkedCacheCount < previewRenderCacheCount do
			local candidate = previewRenderCaches[nextPreviewRenderCache]
			nextPreviewRenderCache = nextPreviewRenderCache % previewRenderCacheCount + 1
			checkedCacheCount = checkedCacheCount + 1
			if candidate.lastDrawFrame ~= extendedCellsDrawFrame then
				cache = candidate
				removePreviewRenderCache(cache)
				break
			end
		end
		if not cache then
			previewRenderCacheCount = previewRenderCacheCount + 1
			cache = {
				footprintStatuses = {},
				extendedStatuses = {},
				colorData = {},
			}
			previewRenderCaches[previewRenderCacheCount] = cache
		end
	end

	cache.unitDefID = unitDefID
	cache.floatOnWater = UnitDefs[unitDefID].floatOnWater and 1 or 0
	cache.x = x
	cache.z = z
	cache.facing = facing
	cache.inputX = nil
	cache.inputZ = nil
	cache.resolvedExtendedStatusCount = 0
	cache.extendedLastUpdate = nil
	cache.extendedCandidateRevision = nil
	cache.statusCheckGameFrame = nil
	cache.statusCheckPhase = math.abs(math.floor(x / SQUARE_SIZE) + math.floor(z / SQUARE_SIZE) * 31 + unitDefID)
	cache.colorValid = false
	cache.extendedStatusCount = 0
	cache.colorRevision = (cache.colorRevision or 0) + 1
	cache.batchNumCells = nil
	cache.mergedRectCount = nil
	addPreviewRenderCache(cache)
	orderedPreviewCaches[sequenceIndex] = cache
	return cache
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Shader sources

local vsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

layout (location = 0) in vec2 a_cornerPos;
layout (location = 1) in vec4 a_cellData; // x, z, quad width, quad height (world units)
layout (location = 2) in vec4 a_color;
layout (location = 3) in vec4 a_outlineColor;
layout (location = 4) in vec4 a_cellExtra; // floatOnWater, mode (0 cell, 1 simplified, 2 merged block), external edge mask, packed footprint data
layout (location = 5) in vec2 a_footprintSize; // footprint size in cells; merged blocks measure corner radius and outline relative to it

//__ENGINEUNIFORMBUFFERDEFS__

out vec4 v_color;
out vec4 v_outlineColor;
flat out float v_footprintEdges;
flat out float v_footprintValid;
flat out float v_mode;
flat out float v_externalEdges;
flat out vec2 v_quadUnits;
flat out vec2 v_cellToUnit;
flat out float v_simplifiedSizeScale;
out vec2 v_cellUV;

uniform sampler2D heightmapTex;
uniform float heightOffset;
uniform float waterLevel;
uniform float cellInset;
uniform float cellSize;
uniform float simplifiedReferenceCells;
uniform float simplifiedSizeFalloff;
uniform float minimumScreenDiameter;
uniform int isMiniMap;
uniform int rotationMiniMap;

vec2 heightmapUVatWorldPos(vec2 worldpos) {
	vec2 inverseMapSize = vec2(1.0) / mapSize.xy;
	vec2 heightmaptexel = vec2(8.0, 8.0);
	worldpos += vec2(-8.0, -8.0) * (worldpos * inverseMapSize) + vec2(4.0, 4.0);
	vec2 uvhm = clamp(worldpos, heightmaptexel, mapSize.xy - heightmaptexel);
	return uvhm * inverseMapSize;
}

void main() {
	float mode = a_cellExtra.y;
	bool simplified = mode > 0.5 && mode < 1.5;
	bool merged = mode > 1.5;
	vec2 quadSize = a_cellData.zw;
	vec2 cellUV = a_cornerPos / cellSize;
	// Merged blocks are only inset on edges that are not shared with a same-styled neighbour block.
	vec2 insetMin = vec2(cellInset);
	vec2 insetMax = vec2(cellInset);
	if (merged) {
		float externalEdges = a_cellExtra.z;
		insetMin.x *= mod(floor(externalEdges), 2.0);
		insetMax.x *= mod(floor(externalEdges / 2.0), 2.0);
		insetMin.y *= mod(floor(externalEdges / 4.0), 2.0);
		insetMax.y *= mod(floor(externalEdges / 8.0), 2.0);
	}
	vec2 insetQuadSize = quadSize - insetMin - insetMax;
	vec2 insetCorner = insetMin + cellUV * insetQuadSize;
	float wx = a_cellData.x + insetCorner.x;
	float wz = a_cellData.y + insetCorner.y;

	v_color = a_color;
	v_outlineColor = a_outlineColor;
	float packedFootprintData = a_cellExtra.w;
	v_footprintEdges = mod(packedFootprintData, 16.0);
	v_footprintValid = step(15.5, mod(packedFootprintData, 32.0));
	v_mode = mode;
	v_externalEdges = a_cellExtra.z;
	// Merged blocks measure distances relative to the inset footprint, exactly like the simplified quad of the
	// whole footprint would, so a fully placeable footprint looks identical to the simplified rendering.
	vec2 quadUnits = vec2(1.0);
	vec2 cellToUnit = vec2(1.0);
	float simplifiedSizeScale = 1.0;
	if (simplified || merged) {
		vec2 footprintInsetSize = max(a_footprintSize * cellSize - 2.0 * cellInset, vec2(0.001));
		// Corner radius and outline width grow with the footprint but with diminishing returns: unchanged at the
		// reference size, scaled by (reference / footprint) ^ falloff elsewhere (falloff 0 = proportional, 1 = constant).
		float referenceInsetSize = max(simplifiedReferenceCells * cellSize - 2.0 * cellInset, 0.001);
		simplifiedSizeScale = pow(referenceInsetSize / min(footprintInsetSize.x, footprintInsetSize.y), simplifiedSizeFalloff);
		if (merged) {
			quadUnits = insetQuadSize / footprintInsetSize;
			cellToUnit = (cellSize - 2.0 * cellInset) / footprintInsetSize;
		}
	}
	v_quadUnits = quadUnits;
	v_cellToUnit = cellToUnit;
	v_simplifiedSizeScale = simplifiedSizeScale;
	v_cellUV = cellUV;
	if (isMiniMap == 0) {
		vec2 uvhm = heightmapUVatWorldPos(vec2(wx, wz));
		float wy = textureLod(heightmapTex, uvhm, 0.0).x;
		wy = mix(wy, max(wy, waterLevel), a_cellExtra.x) + heightOffset;
		vec4 clipPosition = cameraViewProj * vec4(wx, wy, wz, 1.0);
		if (simplified) {
			vec2 centerWorldPos = a_cellData.xy + quadSize * 0.5;
			vec4 centerClipPosition = cameraViewProj * vec4(centerWorldPos.x, wy, centerWorldPos.y, 1.0);
			vec2 centerNdcPosition = centerClipPosition.xy / centerClipPosition.w;
			vec2 cornerNdcOffset = clipPosition.xy / clipPosition.w - centerNdcPosition;
			float halfDiagonalPixels = length(cornerNdcOffset * viewGeometry.xy * 0.5);
			float minimumHalfDiagonal = minimumScreenDiameter * 0.5;
			float expansion = max(1.0, minimumHalfDiagonal / max(halfDiagonalPixels, 0.001));
			clipPosition.xy = (centerNdcPosition + cornerNdcOffset * expansion) * clipPosition.w;
		}
		gl_Position = clipPosition;
	} else {
		vec2 ndcxy = vec2(wx, wz) / mapSize.xy * 2.0 - 1.0;
		if (rotationMiniMap == 0) {
			ndcxy.y *= -1.0;
		} else if (rotationMiniMap == 1) {
			ndcxy.xy = ndcxy.yx;
		} else if (rotationMiniMap == 2) {
			ndcxy.x *= -1.0;
		} else {
			ndcxy.xy = -ndcxy.yx;
		}
		gl_Position = vec4(ndcxy, 0.0, 1.0);
	}
}
]]

local fsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

//__ENGINEUNIFORMBUFFERDEFS__

in vec4 v_color;
in vec4 v_outlineColor;
flat in float v_footprintEdges;
flat in float v_footprintValid;
flat in float v_mode;
flat in float v_externalEdges;
flat in vec2 v_quadUnits;
flat in vec2 v_cellToUnit;
flat in float v_simplifiedSizeScale;
in vec2 v_cellUV;
out vec4 fragColor;

uniform float simplifiedOutlineScale;
uniform float simplifiedCornerRadiusScale;
uniform float cornerRadius;
uniform float cellInset;
uniform float cellSize;
uniform float footprintBoundaryWidth;
uniform float showInvalidFootprintBoundary;
uniform vec4 invalidFootprintBoundaryColor;
uniform float alphaMultiplier;

void main() {
	bool merged = v_mode > 1.5;
	// Simplified quads and merged blocks share the same corner radius and outline width (relative to the footprint).
	float simplifiedMix = (v_mode > 0.5) ? 1.0 : 0.0;
	float scaledCornerRadius = min(
		cornerRadius * mix(1.0, simplifiedCornerRadiusScale * v_simplifiedSizeScale, simplifiedMix),
		0.5
	);
	float outlineWidth = 0.045 * mix(1.0, simplifiedOutlineScale * v_simplifiedSizeScale, simplifiedMix);
	// Distances are measured in inset-quad units for cells and simplified quads (the quad is one unit) and in
	// inset-footprint units for merged blocks (v_quadUnits = block size relative to the footprint), whose edges
	// shared with a same-styled neighbour are ignored so adjacent blocks join seamlessly.
	vec2 quadUnits = merged ? v_quadUnits : vec2(1.0);
	vec2 quadPos = v_cellUV * quadUnits;
	float distanceToEdge;
	if (merged) {
		// Shared edges are pushed far away. Use exact selects, never mix() with the large constant: in float
		// precision that quantises the distances and turns the corners into staircases.
		float farAway = 1.0e5;
		bool leftExternal = mod(floor(v_externalEdges), 2.0) > 0.5;
		bool rightExternal = mod(floor(v_externalEdges / 2.0), 2.0) > 0.5;
		bool topExternal = mod(floor(v_externalEdges / 4.0), 2.0) > 0.5;
		bool bottomExternal = mod(floor(v_externalEdges / 8.0), 2.0) > 0.5;
		// The rounding has to fit inside the block: half its extent on an axis with both edges exposed, the full
		// extent with one exposed edge, unlimited when neither edge is exposed.
		float radiusLimitX = (leftExternal && rightExternal) ? quadUnits.x * 0.5
			: ((leftExternal || rightExternal) ? quadUnits.x : farAway);
		float radiusLimitY = (topExternal && bottomExternal) ? quadUnits.y * 0.5
			: ((topExternal || bottomExternal) ? quadUnits.y : farAway);
		float blockCornerRadius = min(scaledCornerRadius, min(radiusLimitX, radiusLimitY));
		float distanceX = min(leftExternal ? quadPos.x : farAway, rightExternal ? quadUnits.x - quadPos.x : farAway);
		float distanceY = min(topExternal ? quadPos.y : farAway, bottomExternal ? quadUnits.y - quadPos.y : farAway);
		vec2 cornerDistance = vec2(blockCornerRadius) - vec2(distanceX, distanceY);
		distanceToEdge = length(max(cornerDistance, 0.0)) + min(max(cornerDistance.x, cornerDistance.y), 0.0) - blockCornerRadius;
		// Concave corners (two shared edges meeting a diagonal block of another style): carve the cell inset around
		// the corner point so that block's margin and outline continue around the corner.
		float reflexCorners = floor(v_externalEdges / 16.0);
		if (reflexCorners > 0.5) {
			vec2 cellPos = quadPos / v_cellToUnit;
			vec2 blockCells = quadUnits / v_cellToUnit;
			float insetCells = cellInset / max(cellSize - 2.0 * cellInset, 0.001);
			float reflexDistance = -farAway;
			if (mod(reflexCorners, 2.0) > 0.5) {
				reflexDistance = max(reflexDistance, insetCells - length(cellPos));
			}
			if (mod(floor(reflexCorners / 2.0), 2.0) > 0.5) {
				reflexDistance = max(reflexDistance, insetCells - length(cellPos - vec2(blockCells.x, 0.0)));
			}
			if (mod(floor(reflexCorners / 4.0), 2.0) > 0.5) {
				reflexDistance = max(reflexDistance, insetCells - length(cellPos - vec2(0.0, blockCells.y)));
			}
			if (mod(floor(reflexCorners / 8.0), 2.0) > 0.5) {
				reflexDistance = max(reflexDistance, insetCells - length(cellPos - blockCells));
			}
			distanceToEdge = max(distanceToEdge, reflexDistance * v_cellToUnit.x);
		}
	} else {
		vec2 cornerDistance = abs(v_cellUV - vec2(0.5)) - vec2(0.5 - scaledCornerRadius);
		distanceToEdge = length(max(cornerDistance, 0.0)) - scaledCornerRadius;
	}
	float antialiasWidth = fwidth(distanceToEdge);
	float coverage = 1.0 - smoothstep(0.0, antialiasWidth, distanceToEdge);
	float outline = smoothstep(-outlineWidth - antialiasWidth, -outlineWidth + antialiasWidth, distanceToEdge);
	vec4 cellColor = mix(v_color, v_outlineColor, outline);
	vec3 color = cellColor.rgb;
	float alpha = cellColor.a;
	bool showInvalidPlacementBoundary = showInvalidFootprintBoundary > 0.5 && v_footprintValid < 0.5;
	if (showInvalidPlacementBoundary) {
		float leftEdge = mod(floor(v_footprintEdges), 2.0);
		float rightEdge = mod(floor(v_footprintEdges / 2.0), 2.0);
		float topEdge = mod(floor(v_footprintEdges / 4.0), 2.0);
		float bottomEdge = mod(floor(v_footprintEdges / 8.0), 2.0);
		// The boundary band keeps its per-cell width on merged blocks.
		vec2 boundaryWidth = footprintBoundaryWidth * v_cellToUnit;
		float leftOutline = leftEdge * (1.0 - smoothstep(0.0, boundaryWidth.x, quadPos.x));
		float rightOutline = rightEdge * smoothstep(quadUnits.x - boundaryWidth.x, quadUnits.x, quadPos.x);
		float topOutline = topEdge * (1.0 - smoothstep(0.0, boundaryWidth.y, quadPos.y));
		float bottomOutline = bottomEdge * smoothstep(quadUnits.y - boundaryWidth.y, quadUnits.y, quadPos.y);
		float footprintOutline = max(max(leftOutline, rightOutline), max(topOutline, bottomOutline));
		color = mix(color, invalidFootprintBoundaryColor.rgb, footprintOutline);
		alpha = mix(alpha, invalidFootprintBoundaryColor.a, footprintOutline);
	}

	fragColor = vec4(color, alpha * coverage * alphaMultiplier);
}
]]

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Initialization / cleanup

local function goodbye(reason)
	Spring.Echo("BuildSquare GL4 Example widget exiting: " .. reason)
	widgetHandler:RemoveWidget()
end

local function getCurrentHeightOffset()
	if spGetGameFrame() <= 0 and WG.map_startbox ~= nil then
		return PREGAME_STARTBOX_HEIGHT_OFFSET
	end
	return HEIGHT_OFFSET
end

local function initGL4Resources()
	local uboMatDefs = glGetEngineUniformBufferDef(0)
	local uboParamDefs = glGetEngineUniformBufferDef(1)
	local uboDefs = uboMatDefs .. "\n" .. uboParamDefs

	local vsProcessed = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", uboDefs)
	local fsProcessed = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", uboDefs)

	local shaderID = glCreateShader({
		vertex = vsProcessed,
		fragment = fsProcessed,
		uniformInt = {
			heightmapTex = 0,
			isMiniMap = 0,
			rotationMiniMap = 0,
		},
		uniformFloat = {
			heightOffset = HEIGHT_OFFSET,
			waterLevel = 0,
			cellInset = CELL_DISTANCE * 0.5,
			cellSize = SQUARE_SIZE,
			minimumScreenDiameter = MINIMUM_SCREEN_DIAMETER,
			cornerRadius = CORNER_RADIUS,
			simplifiedOutlineScale = SIMPLIFIED_OUTLINE_SCALE,
			simplifiedCornerRadiusScale = SIMPLIFIED_CORNER_RADIUS_SCALE,
			simplifiedReferenceCells = SIMPLIFIED_SIZE_REFERENCE_CELLS,
			simplifiedSizeFalloff = SIMPLIFIED_SIZE_FALLOFF,
			footprintBoundaryWidth = FOOTPRINT_BOUNDARY_WIDTH,
			showInvalidFootprintBoundary = SHOW_INVALID_FOOTPRINT_BOUNDARY and 1.0 or 0.0,
			invalidFootprintBoundaryColor = INVALID_FOOTPRINT_BOUNDARY_COLOR,
			alphaMultiplier = 1.0,
		},
	})

	if not shaderID then
		goodbye("Failed to compile shader: " .. (glGetShaderLog() or "unknown error"))
		return false
	end

	shaderProgram = shaderID
	isMiniMapLoc = glGetUniformLocation(shaderID, "isMiniMap")
	rotationMiniMapLoc = glGetUniformLocation(shaderID, "rotationMiniMap")
	heightOffsetLoc = glGetUniformLocation(shaderID, "heightOffset")
	waterLevelLoc = glGetUniformLocation(shaderID, "waterLevel")
	alphaMultiplierLoc = glGetUniformLocation(shaderID, "alphaMultiplier")

	local quadVerts = {
		0.0,
		0.0,
		SQUARE_SIZE,
		0.0,
		0.0,
		SQUARE_SIZE,
		SQUARE_SIZE,
		SQUARE_SIZE,
	}

	quadVBO = glGetVBO(GL_ARRAY_BUFFER, false)
	quadVBO:Define(4, {
		{ id = 0, name = "a_cornerPos", size = 2 },
	})
	quadVBO:Upload(quadVerts)

	batchInstanceVBO = glGetVBO(GL_ARRAY_BUFFER, true)
	batchInstanceVBO:Define(MAX_BATCH_CELLS, {
		{ id = 1, name = "a_cellData", size = 4 },
		{ id = 2, name = "a_color", size = 4 },
		{ id = 3, name = "a_outlineColor", size = 4 },
		{ id = 4, name = "a_cellExtra", size = 4 },
		{ id = 5, name = "a_footprintSize", size = 2 },
	})

	batchVAO = glGetVAO()
	batchVAO:AttachVertexBuffer(quadVBO)
	batchVAO:AttachInstanceBuffer(batchInstanceVBO)

	minimapInstanceVBO = glGetVBO(GL_ARRAY_BUFFER, true)
	minimapInstanceVBO:Define(MAX_MINIMAP_BUILDINGS, {
		{ id = 1, name = "a_cellData", size = 4 },
		{ id = 2, name = "a_color", size = 4 },
		{ id = 3, name = "a_outlineColor", size = 4 },
		{ id = 4, name = "a_cellExtra", size = 4 },
		{ id = 5, name = "a_footprintSize", size = 2 },
	})

	minimapVAO = glGetVAO()
	minimapVAO:AttachVertexBuffer(quadVBO)
	minimapVAO:AttachInstanceBuffer(minimapInstanceVBO)

	return true
end

local function freeGL4Resources()
	if minimapVAO then
		minimapVAO:Delete()
		minimapVAO = nil
	end
	if minimapInstanceVBO then
		minimapInstanceVBO:Delete()
		minimapInstanceVBO = nil
	end
	if batchVAO then
		batchVAO:Delete()
		batchVAO = nil
	end
	if batchInstanceVBO then
		batchInstanceVBO:Delete()
		batchInstanceVBO = nil
	end
	for index = 1, previewRenderCacheCount do
		previewRenderCaches[index] = nil
	end
	previewRenderCacheCount = 0
	nextPreviewRenderCache = 1
	previewRenderCacheLookup = {}
	if quadVBO then
		quadVBO:Delete()
		quadVBO = nil
	end
	if shaderProgram then
		glDeleteShader(shaderProgram)
		shaderProgram = nil
	end
end

local function resetPreviewState()
	for index = 1, previewRenderCacheCount do
		previewRenderCaches[index] = nil
	end
	previewRenderCaches = {}
	previewRenderCacheCount = 0
	nextPreviewRenderCache = 1
	previewRenderCacheLookup = {}
	orderedPreviewCaches = {}
	collectedPreviews = {}
	collectedPreviewCount = 0
	collectedDrawFrame = -1
	collectedBatchChanged = true
	residentBatchPreviewCount = 0
	batchInstanceCount = 0
	minimapInstanceCount = 0
	extendedCellsDrawFrame = -1
	overlayBatchDrawFrame = -1
	drawSquareCount = 0
	drawSquareCellCount = 0
	buildSquareGameFrame = -1
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Widget callbacks

function widget:Initialize()
	if not glCreateShader then
		goodbye("Shaders not supported")
		return
	end

	if not initGL4Resources() then
		return
	end

	WG["buildsquare-gl4"] = true
	spSetEngineBuildSquareRendering(false)
end

function widget:PlayerChanged(playerID)
	if playerID == spGetMyPlayerID() then
		resetPreviewState()
		spSetEngineBuildSquareRendering(false)
	end
end

function widget:Shutdown()
	WG["buildsquare-gl4"] = nil
	spSetEngineBuildSquareRendering(true)
	freeGL4Resources()
end

local function updateExtendedStatuses(
	renderCache,
	unitDefID,
	unitDef,
	x,
	z,
	facing,
	xsize,
	zsize,
	extendedCells,
	openYardmapCells
)
	tracy.ZoneBeginN("W:BuildSquare:ExtendedStatuses")
	local now = spGetTimer()
	local expectedStatusCount = (xsize + extendedCells * 2) * (zsize + extendedCells * 2) - xsize * zsize
	if
		renderCache.resolvedExtendedStatusCount == expectedStatusCount
		and renderCache.extendedLastUpdate
		and spDiffTimers(now, renderCache.extendedLastUpdate) < EXTENDED_STATUS_UPDATE_INTERVAL
	then
		tracy.ZoneEnd()
		return renderCache.extendedStatuses, renderCache.openYardmapStatuses, false
	end
	candidateBuildHeightGeneration = candidateBuildHeightGeneration + 1
	local buildHeightGeneration = candidateBuildHeightGeneration
	local candidateRadius = mathCeil(extendedCells / 2)
	local candidateStride = candidateRadius * 2 + 1
	local statusIndex = 0
	local halfXsize = math.floor(xsize / 2)
	local halfZsize = math.floor(zsize / 2)
	local openYardmapStatuses = renderCache.openYardmapStatuses
	if not openYardmapStatuses then
		openYardmapStatuses = {}
		renderCache.openYardmapStatuses = openYardmapStatuses
	end
	local openYardmapStatusesChanged = false
	for zi = -extendedCells, zsize + extendedCells - 1 do
		for xi = -extendedCells, xsize + extendedCells - 1 do
			local isFootprintCell = xi >= 0 and xi < xsize and zi >= 0 and zi < zsize
			local footprintCellIndex = isFootprintCell and (zi * xsize + xi + 1)
			local isOpenYardmapCell = footprintCellIndex and openYardmapCells and openYardmapCells[footprintCellIndex]
			if not isFootprintCell or isOpenYardmapCell then
				local worldX = x + (xi - halfXsize) * SQUARE_SIZE
				local worldZ = z + (zi - halfZsize) * SQUARE_SIZE
				local shiftX = xi < 0 and xi or (xi >= xsize and xi - xsize + 1 or 0)
				local shiftZ = zi < 0 and zi or (zi >= zsize and zi - zsize + 1 or 0)
				local candidateStepX = shiftX < 0 and -mathCeil(-shiftX / 2) or mathCeil(shiftX / 2)
				local candidateStepZ = shiftZ < 0 and -mathCeil(-shiftZ / 2) or mathCeil(shiftZ / 2)
				local candidateKey = (candidateStepZ + candidateRadius) * candidateStride
					+ candidateStepX
					+ candidateRadius
					+ 1
				if candidateBuildHeightGenerations[candidateKey] ~= buildHeightGeneration then
					local candidateX = x + candidateStepX * BUILD_GRID_SIZE
					local candidateZ = z + candidateStepZ * BUILD_GRID_SIZE
					local _, buildHeight = spPos2BuildPos(
						unitDefID,
						candidateX,
						spGetGroundHeight(candidateX, candidateZ),
						candidateZ,
						facing
					)
					candidateBuildHeights[candidateKey] = buildHeight
					candidateBuildHeightGenerations[candidateKey] = buildHeightGeneration
				end
				local status, objectStatus =
					getPredictedCellStatus(unitDef, worldX, worldZ, candidateBuildHeights[candidateKey])
				if isFootprintCell then
					if openYardmapStatuses[footprintCellIndex] ~= objectStatus then
						openYardmapStatuses[footprintCellIndex] = objectStatus
						openYardmapStatusesChanged = true
					end
				else
					statusIndex = statusIndex + 1
					extendedStatuses[statusIndex] = status
				end
			end
		end
	end

	for index = statusIndex + 1, #extendedStatuses do
		extendedStatuses[index] = nil
	end
	renderCache.resolvedExtendedStatusCount = statusIndex
	renderCache.extendedLastUpdate = now

	tracy.ZoneEnd()
	return extendedStatuses, openYardmapStatuses, openYardmapStatusesChanged
end

-- Style of a cell inside the footprint (extended cells outside the footprint use a distance based alpha instead).
local function getFootprintCellStyle(status, isOpenYardmapCell, isOpenYardmapTerrainBlocked, footprintIsValid)
	local color = STATUS_COLORS[status] or STATUS_COLORS[STATUS_BLOCKED]
	local outlineColor = STATUS_OUTLINE_COLORS[status] or STATUS_OUTLINE_COLORS[STATUS_BLOCKED]
	local isPlaceableOverObject = footprintIsValid and (status == STATUS_OCCUPIED or status == STATUS_RECLAIMABLE)
	if isOpenYardmapCell and status ~= STATUS_BLOCKED then
		color = VALID_FOOTPRINT_COLOR
		outlineColor = VALID_FOOTPRINT_OUTLINE_COLOR
	elseif footprintIsValid and status == STATUS_OPEN then
		color = VALID_FOOTPRINT_COLOR
		outlineColor = VALID_FOOTPRINT_OUTLINE_COLOR
	elseif isPlaceableOverObject then
		outlineColor = VALID_FOOTPRINT_OUTLINE_COLOR
	end
	local alpha = isPlaceableOverObject and VALID_FOOTPRINT_COLOR[4] or color[4]
	local outlineAlpha = outlineColor[4]
	if OPEN_YARDMAP_ONLY_WHEN_BLOCKED and footprintIsValid and isOpenYardmapCell then
		alpha = 0
		outlineAlpha = 0
	elseif isOpenYardmapCell and not isOpenYardmapTerrainBlocked then
		alpha = EXTENDED_ALPHA_NEAR
		outlineAlpha = outlineAlpha * alpha
	end
	return color, outlineColor, alpha, outlineAlpha
end

local function getStyleColorId(color)
	local id = styleColorIds[color]
	if not id then
		styleColorIdCount = styleColorIdCount + 1
		id = styleColorIdCount
		styleColorIds[color] = id
	end
	return id
end

-- Merges same-styled cells of a placeable footprint into rectangles. Every rectangle edge is either fully shared
-- with a same-styled neighbour rectangle (drawn without inset or outline so the blocks join into one shape) or
-- fully exposed.
-- Writes 14 numbers per rectangle into rectData: cell x, cell z, width, height (cells), external edge mask plus
-- 16 * concave corner mask, packed footprint data, fill rgba, outline rgba. Returns the rectangle count.
local function buildMergedFootprintRects(rectData, statuses, footprint)
	local xsize = footprint.xsize
	local zsize = footprint.zsize
	-- Hidden open yardmap cells get no rectangle, which keeps them as holes in the merged shape.
	local openYardmapCells = footprint.openYardmapCells
	local cellKeys = mergeCellKeys
	for cellIndex = 1, xsize * zsize do
		local status = statuses[cellIndex] or STATUS_BLOCKED
		local isOpenYardmapCell = (openYardmapCells and openYardmapCells[cellIndex]) or false
		local color, outlineColor, alpha, outlineAlpha = getFootprintCellStyle(status, isOpenYardmapCell, false, true)
		if alpha <= 0 and outlineAlpha <= 0 then
			cellKeys[cellIndex] = false
		else
			local key = getStyleColorId(color)
				+ getStyleColorId(outlineColor) * 64
				+ math.floor(alpha * 1000 + 0.5) * 4096
				+ math.floor(outlineAlpha * 1000 + 0.5) * 4194304
			cellKeys[cellIndex] = key
			mergeStyleColors[key] = color
			mergeStyleOutlineColors[key] = outlineColor
			mergeStyleAlphas[key] = alpha
			mergeStyleOutlineAlphas[key] = outlineAlpha
		end
	end

	local function hasSameKey(xi, zi, key)
		if xi < 0 or zi < 0 or xi >= xsize or zi >= zsize then
			return false
		end
		return cellKeys[zi * xsize + xi + 1] == key
	end

	-- Pass 1: horizontal runs whose cells agree on whether the cell above / below is same-styled, so the top and
	-- bottom edges of a run are uniform. Pass 2 (interleaved): extend the run from the previous row when x, width,
	-- key and the left / right neighbour status match, keeping every edge of the rectangle uniform.
	-- Scratch layout per rectangle (10 numbers): x, z, width, height, key, leftShared, rightShared, topShared,
	-- bottomShared, last row.
	local scratch = mergeRectData
	local openRects = mergeOpenRects
	for openX in pairs(openRects) do
		openRects[openX] = nil
	end
	local rectCount = 0
	for zi = 0, zsize - 1 do
		local xi = 0
		while xi < xsize do
			local key = cellKeys[zi * xsize + xi + 1]
			if not key then
				xi = xi + 1
			else
				local topShared = hasSameKey(xi, zi - 1, key)
				local bottomShared = hasSameKey(xi, zi + 1, key)
				local width = 1
				while
					xi + width < xsize
					and cellKeys[zi * xsize + xi + width + 1] == key
					and hasSameKey(xi + width, zi - 1, key) == topShared
					and hasSameKey(xi + width, zi + 1, key) == bottomShared
				do
					width = width + 1
				end
				local leftShared = hasSameKey(xi - 1, zi, key)
				local rightShared = hasSameKey(xi + width, zi, key)
				local rectIndex = openRects[xi]
				local rectBase = rectIndex and (rectIndex - 1) * 10
				if
					rectBase
					and scratch[rectBase + 10] == zi - 1
					and scratch[rectBase + 3] == width
					and scratch[rectBase + 5] == key
					and scratch[rectBase + 6] == leftShared
					and scratch[rectBase + 7] == rightShared
				then
					scratch[rectBase + 4] = scratch[rectBase + 4] + 1
					scratch[rectBase + 9] = bottomShared
					scratch[rectBase + 10] = zi
				else
					rectCount = rectCount + 1
					rectBase = (rectCount - 1) * 10
					scratch[rectBase + 1] = xi
					scratch[rectBase + 2] = zi
					scratch[rectBase + 3] = width
					scratch[rectBase + 4] = 1
					scratch[rectBase + 5] = key
					scratch[rectBase + 6] = leftShared
					scratch[rectBase + 7] = rightShared
					scratch[rectBase + 8] = topShared
					scratch[rectBase + 9] = bottomShared
					scratch[rectBase + 10] = zi
					openRects[xi] = rectCount
				end
				xi = xi + width
			end
		end
	end

	local packedFlags = 16
	local dataIndex = 0
	for rectIndex = 0, rectCount - 1 do
		local rectBase = rectIndex * 10
		local rectX = scratch[rectBase + 1]
		local rectZ = scratch[rectBase + 2]
		local rectWidth = scratch[rectBase + 3]
		local rectHeight = scratch[rectBase + 4]
		local key = scratch[rectBase + 5]
		local leftShared = scratch[rectBase + 6]
		local rightShared = scratch[rectBase + 7]
		local topShared = scratch[rectBase + 8]
		local bottomShared = scratch[rectBase + 9]
		local externalEdges = (leftShared and 0 or 1)
			+ (rightShared and 0 or 2)
			+ (topShared and 0 or 4)
			+ (bottomShared and 0 or 8)
		-- Concave corners: two shared edges meeting a diagonal cell of another style. The shader wraps the margin
		-- and outline of the neighbouring block around such a corner point so hole outlines stay continuous.
		local reflexCorners = (topShared and leftShared and not hasSameKey(rectX - 1, rectZ - 1, key) and 1 or 0)
			+ (topShared and rightShared and not hasSameKey(rectX + rectWidth, rectZ - 1, key) and 2 or 0)
			+ (bottomShared and leftShared and not hasSameKey(rectX - 1, rectZ + rectHeight, key) and 4 or 0)
			+ (bottomShared and rightShared and not hasSameKey(rectX + rectWidth, rectZ + rectHeight, key) and 8 or 0)
		local footprintEdges = (rectX == 0 and 1 or 0)
			+ (rectX + rectWidth == xsize and 2 or 0)
			+ (rectZ == 0 and 4 or 0)
			+ (rectZ + rectHeight == zsize and 8 or 0)
		local color = mergeStyleColors[key]
		local outlineColor = mergeStyleOutlineColors[key]
		rectData[dataIndex + 1] = rectX
		rectData[dataIndex + 2] = rectZ
		rectData[dataIndex + 3] = rectWidth
		rectData[dataIndex + 4] = rectHeight
		rectData[dataIndex + 5] = externalEdges + reflexCorners * 16
		rectData[dataIndex + 6] = footprintEdges + packedFlags
		rectData[dataIndex + 7] = color[1]
		rectData[dataIndex + 8] = color[2]
		rectData[dataIndex + 9] = color[3]
		rectData[dataIndex + 10] = mergeStyleAlphas[key]
		rectData[dataIndex + 11] = outlineColor[1]
		rectData[dataIndex + 12] = outlineColor[2]
		rectData[dataIndex + 13] = outlineColor[3]
		rectData[dataIndex + 14] = mergeStyleOutlineAlphas[key]
		dataIndex = dataIndex + 14
	end
	return rectCount
end

-- Per-cell statuses for a placement the engine did not evaluate for us (pregame, extractor snap target).
local function fillPredictedStatuses(statusList, unitDef, x, buildHeight, z, footprint, placementValid)
	local statusIndex = 0
	for zi = 0, footprint.zsize - 1 do
		for xi = 0, footprint.xsize - 1 do
			statusIndex = statusIndex + 1
			local status = STATUS_BLOCKED
			if placementValid then
				local objectStatus
				status, objectStatus = getPredictedCellStatus(
					unitDef,
					x + (xi - footprint.halfXsize) * SQUARE_SIZE,
					z + (zi - footprint.halfZsize) * SQUARE_SIZE,
					buildHeight
				)
				-- Match the in-game preview: terrain does not block open yardmap cells.
				if footprint.openYardmapCells and footprint.openYardmapCells[statusIndex] then
					status = objectStatus
				end
				-- The engine accepted the order, so a cell the prediction calls blocked is really placeable
				-- (e.g. an extractor upgrade over stackable / build-only yardmap squares).
				if status == STATUS_BLOCKED then
					status = STATUS_OPEN
				end
			end
			statusList[statusIndex] = status
		end
	end
	for index = statusIndex + 1, #statusList do
		statusList[index] = nil
	end
end

-- When the extractor snap widget targets a resource spot for the active build command, the preview belongs at
-- that spot rather than at the cursor. Returns the snapped x, z and predicted statuses, or nil.
local function getExtractorSnapPlacement(unitDefID, facing, footprint)
	if not FOLLOW_EXTRACTOR_SNAP then
		return nil
	end
	local extractorSnap = WG.ExtractorSnap
	local snapPosition = extractorSnap and extractorSnap.position
	if not snapPosition then
		return nil
	end
	if spGetGameFrame() > 0 then
		local _, activeCmdID = spGetActiveCommand()
		if not activeCmdID or -activeCmdID ~= unitDefID then
			return nil
		end
	end
	local x, buildHeight, z = spPos2BuildPos(unitDefID, snapPosition.x, snapPosition.y, snapPosition.z, facing)
	if not x or not buildHeight or not z then
		return nil
	end
	local unitDef = UnitDefs[unitDefID]
	if not unitDef then
		return nil
	end
	local placementValid = spTestBuildOrder(unitDefID, x, buildHeight, z, facing) ~= 0
	fillPredictedStatuses(snapStatuses, unitDef, x, buildHeight, z, footprint, placementValid)
	return x, z, snapStatuses
end

function widget:DrawBuildSquare(unitDefID, x, z, facing, statuses)
	--Spring.Echo("DrawBuildSquare called with unitDefID:", unitDefID, "x:", x, "z:", z, "facing:", facing, "statuses length:", #statuses)
	local extendedCells, gameFrame, footprintStatusCheckPeriod, sequenceIndex, simplified = getEffectiveExtendedCells()
	local footprint = getFootprintData(unitDefID, facing)
	if not footprint then
		return
	end
	local snapX, snapZ, snapCellStatuses = getExtractorSnapPlacement(unitDefID, facing, footprint)
	if snapX then
		x, z, statuses = snapX, snapZ, snapCellStatuses
	end
	local footprintCellCount = footprint.cellCount
	local footprintIsValid = true
	for cellIdx = 1, footprintCellCount do
		if (statuses[cellIdx] or STATUS_BLOCKED) == STATUS_BLOCKED then
			footprintIsValid = false
			break
		end
	end
	local centerGridX = math.floor(x / SQUARE_SIZE)
	local centerGridZ = math.floor(z / SQUARE_SIZE)
	local placementX = centerGridX * SQUARE_SIZE
	local placementZ = centerGridZ * SQUARE_SIZE
	if ONLY_WHEN_BLOCKED and footprintIsValid then
		extendedCells = 0
	end
	local xsize = footprint.xsize
	local zsize = footprint.zsize
	local totalXSize = xsize + extendedCells * 2
	local totalZSize = zsize + extendedCells * 2
	local sourceCellCount = totalXSize * totalZSize
	if sourceCellCount <= 0 or sourceCellCount > MAX_CELLS then
		return
	end
	-- Avoid a one-frame VBO overflow before the next frame enables global simplification.
	simplified = simplified or drawSquareCellCount + sourceCellCount > SIMPLIFIED_CELL_THRESHOLD
	local merged = COMBINE_VALID_FOOTPRINT_CELLS and not simplified and footprintIsValid and extendedCells == 0
	local renderCache = orderedPreviewCaches[sequenceIndex]
	if
		extendedCells == 0
		and renderCache
		and renderCache.unitDefID == unitDefID
		and renderCache.facing == facing
		and renderCache.inputX == x
		and renderCache.inputZ == z
		and renderCache.colorValid
		and renderCache.extendedStatusCount == 0
		and renderCache.simplifiedMode == simplified
		and renderCache.mergedMode == merged
	then
		local previewWasDrawnLastFrame = renderCache.lastDrawFrame == extendedCellsDrawFrame - 1
		local statusCheckDue = not previewWasDrawnLastFrame
			or renderCache.statusCheckGameFrame == nil
			or (
				statusChecksEnabled
				and renderCache.statusCheckGameFrame ~= gameFrame
				and statusCheckTargetPhase == renderCache.statusCheckPhase % footprintStatusCheckPeriod
			)
		if not statusCheckDue then
			renderCache.lastDrawFrame = extendedCellsDrawFrame
			drawSquareCellCount = drawSquareCellCount + renderCache.sourceCellCount
			appendCollectedPreview(renderCache)
			return
		end
	end

	local cellScale = not merged
			and COMBINE_FOUR_CELLS
			and xsize % 2 == 0
			and zsize % 2 == 0
			and extendedCells % 2 == 0
			and 2
		or 1
	local renderXSize = totalXSize / cellScale
	local renderZSize = totalZSize / cellScale
	local renderCellCount = renderXSize * renderZSize
	drawSquareCellCount = drawSquareCellCount + sourceCellCount
	local sx = centerGridX - footprint.halfXsize
	local sz = centerGridZ - footprint.halfZsize
	renderCache = getPreviewRenderCache(unitDefID, placementX, placementZ, facing, sequenceIndex)
	renderCache.inputX = x
	renderCache.inputZ = z
	local previewWasDrawnLastFrame = renderCache.lastDrawFrame == extendedCellsDrawFrame - 1
	renderCache.lastDrawFrame = extendedCellsDrawFrame
	local statusCheckDue = not previewWasDrawnLastFrame
		or renderCache.statusCheckGameFrame == nil
		or (
			statusChecksEnabled
			and renderCache.statusCheckGameFrame ~= gameFrame
			and statusCheckTargetPhase == renderCache.statusCheckPhase % footprintStatusCheckPeriod
		)
	if
		extendedCells == 0
		and renderCache.colorValid
		and renderCache.extendedStatusCount == 0
		and renderCache.simplifiedMode == simplified
		and renderCache.mergedMode == merged
		and not statusCheckDue
	then
		collectPreview(
			renderCache,
			sx * SQUARE_SIZE,
			sz * SQUARE_SIZE,
			simplified and 1 or (merged and renderCache.mergedRectCount) or renderCellCount,
			xsize,
			zsize,
			extendedCells,
			cellScale,
			simplified,
			merged
		)
		return
	end
	local extendedCellStatuses
	local openYardmapStatuses
	local openYardmapStatusesChanged = false
	if extendedCells > 0 then
		local unitDef = UnitDefs[unitDefID]
		extendedCellStatuses, openYardmapStatuses, openYardmapStatusesChanged = updateExtendedStatuses(
			renderCache,
			unitDefID,
			unitDef,
			placementX,
			placementZ,
			facing,
			xsize,
			zsize,
			extendedCells,
			footprint.openYardmapCells
		)
	end
	local extendedStatusCount = sourceCellCount - footprintCellCount
	local needsColorUpload = not renderCache.colorValid
		or renderCache.simplifiedMode ~= simplified
		or renderCache.mergedMode ~= merged
		or openYardmapStatusesChanged

	if not needsColorUpload and statusCheckDue then
		for cellIdx = 1, footprintCellCount do
			if renderCache.footprintStatuses[cellIdx] ~= (statuses[cellIdx] or STATUS_BLOCKED) then
				needsColorUpload = true
				break
			end
		end
		if not needsColorUpload then
			renderCache.statusCheckGameFrame = gameFrame
		end
	end
	if not needsColorUpload and renderCache.extendedStatusCount == extendedStatusCount then
		for statusIdx = 1, extendedStatusCount do
			if renderCache.extendedStatuses[statusIdx] ~= extendedCellStatuses[statusIdx] then
				needsColorUpload = true
				break
			end
		end
	elseif not needsColorUpload then
		needsColorUpload = true
	end

	if needsColorUpload then
		tracy.ZoneBeginN("W:BuildSquare:BuildColorData")
		local colorData = renderCache.colorData
		renderCache.colorValid = true
		renderCache.simplifiedMode = simplified
		renderCache.mergedMode = merged
		renderCache.sourceCellCount = sourceCellCount
		renderCache.statusCheckGameFrame = gameFrame
		renderCache.extendedStatusCount = extendedStatusCount
		for cellIdx = 1, footprintCellCount do
			local status = statuses[cellIdx] or STATUS_BLOCKED
			renderCache.footprintStatuses[cellIdx] = status
		end
		renderCache.footprintIsValid = footprintIsValid
		if simplified then
			local color = footprintIsValid and VALID_FOOTPRINT_COLOR or STATUS_COLORS[STATUS_BLOCKED]
			local outlineColor = footprintIsValid and VALID_FOOTPRINT_OUTLINE_COLOR
				or STATUS_OUTLINE_COLORS[STATUS_BLOCKED]
			colorData[1] = color[1]
			colorData[2] = color[2]
			colorData[3] = color[3]
			colorData[4] = color[4]
			colorData[5] = outlineColor[1]
			colorData[6] = outlineColor[2]
			colorData[7] = outlineColor[3]
			colorData[8] = outlineColor[4]
			for index = 9, renderCache.colorDataLength or 0 do
				colorData[index] = nil
			end
			renderCache.colorDataLength = 8
			renderCache.colorRevision = (renderCache.colorRevision or 0) + 1
			tracy.ZoneEnd()
			collectPreview(
				renderCache,
				sx * SQUARE_SIZE,
				sz * SQUARE_SIZE,
				1,
				xsize,
				zsize,
				extendedCells,
				cellScale,
				true,
				false
			)
			return
		end
		if merged then
			local rectCount = buildMergedFootprintRects(colorData, statuses, footprint)
			for index = rectCount * 14 + 1, renderCache.colorDataLength or 0 do
				colorData[index] = nil
			end
			renderCache.colorDataLength = rectCount * 14
			renderCache.mergedRectCount = rectCount
			renderCache.colorRevision = (renderCache.colorRevision or 0) + 1
			tracy.ZoneEnd()
			collectPreview(
				renderCache,
				sx * SQUARE_SIZE,
				sz * SQUARE_SIZE,
				rectCount,
				xsize,
				zsize,
				extendedCells,
				cellScale,
				false,
				true
			)
			return
		end
		for statusIdx = 1, extendedStatusCount do
			renderCache.extendedStatuses[statusIdx] = extendedCellStatuses[statusIdx]
		end

		local sourceCellIndex = 0
		local extendedStatusIndex = 0
		local openYardmapCells = footprint.openYardmapCells
		for zi = -extendedCells, zsize + extendedCells - 1 do
			for xi = -extendedCells, xsize + extendedCells - 1 do
				sourceCellIndex = sourceCellIndex + 1
				local isFootprintCell = xi >= 0 and xi < xsize and zi >= 0 and zi < zsize
				local footprintCellIndex = isFootprintCell and (zi * xsize + xi + 1)
				local isOpenYardmapCell = footprintCellIndex
					and openYardmapCells
					and openYardmapCells[footprintCellIndex]
				local status
				local isOpenYardmapTerrainBlocked = false
				if isFootprintCell then
					if isOpenYardmapCell and openYardmapStatuses then
						local footprintStatus = statuses[footprintCellIndex] or STATUS_BLOCKED
						local objectStatus = openYardmapStatuses[footprintCellIndex] or STATUS_OPEN
						isOpenYardmapTerrainBlocked = footprintStatus == STATUS_BLOCKED
							and objectStatus ~= STATUS_BLOCKED
						status = isOpenYardmapTerrainBlocked and footprintStatus or objectStatus
					else
						status = statuses[footprintCellIndex] or STATUS_BLOCKED
					end
				else
					extendedStatusIndex = extendedStatusIndex + 1
					status = extendedCellStatuses[extendedStatusIndex] or STATUS_BLOCKED
				end
				sourceCellStatuses[sourceCellIndex] = status
				sourceOpenYardmapFlags[sourceCellIndex] = isOpenYardmapCell or false
				sourceTerrainBlockedFlags[sourceCellIndex] = isOpenYardmapTerrainBlocked
			end
		end

		local colorDataIndex = 0
		local renderExtendedCells = extendedCells / cellScale
		local renderFootprintXSize = xsize / cellScale
		local renderFootprintZSize = zsize / cellScale
		for renderZi = 0, renderZSize - 1 do
			for renderXi = 0, renderXSize - 1 do
				local sourceX = renderXi * cellScale
				local sourceZ = renderZi * cellScale
				local firstSourceIndex = sourceZ * totalXSize + sourceX + 1
				local status = sourceCellStatuses[firstSourceIndex]
				local isOpenYardmapCell = sourceOpenYardmapFlags[firstSourceIndex]
				local isOpenYardmapTerrainBlocked = sourceTerrainBlockedFlags[firstSourceIndex]
				if cellScale == 2 then
					local secondSourceIndex = firstSourceIndex + 1
					local thirdSourceIndex = firstSourceIndex + totalXSize
					local fourthSourceIndex = thirdSourceIndex + 1
					status = math.min(
						status,
						sourceCellStatuses[secondSourceIndex],
						sourceCellStatuses[thirdSourceIndex],
						sourceCellStatuses[fourthSourceIndex]
					)
					isOpenYardmapCell = isOpenYardmapCell
						and sourceOpenYardmapFlags[secondSourceIndex]
						and sourceOpenYardmapFlags[thirdSourceIndex]
						and sourceOpenYardmapFlags[fourthSourceIndex]
					isOpenYardmapTerrainBlocked = isOpenYardmapTerrainBlocked
						or sourceTerrainBlockedFlags[secondSourceIndex]
						or sourceTerrainBlockedFlags[thirdSourceIndex]
						or sourceTerrainBlockedFlags[fourthSourceIndex]
				end

				local xi = renderXi - renderExtendedCells
				local zi = renderZi - renderExtendedCells
				local isFootprintCell = xi >= 0 and xi < renderFootprintXSize and zi >= 0 and zi < renderFootprintZSize
				local color, outlineColor, alpha, outlineAlpha
				if isFootprintCell then
					color, outlineColor, alpha, outlineAlpha =
						getFootprintCellStyle(status, isOpenYardmapCell, isOpenYardmapTerrainBlocked, footprintIsValid)
				else
					color = STATUS_COLORS[status] or STATUS_COLORS[STATUS_BLOCKED]
					outlineColor = STATUS_OUTLINE_COLORS[status] or STATUS_OUTLINE_COLORS[STATUS_BLOCKED]
					if status ~= STATUS_BLOCKED then
						color = VALID_FOOTPRINT_COLOR
						outlineColor = VALID_FOOTPRINT_OUTLINE_COLOR
					end
					local dx = xi < 0 and -xi or (xi - renderFootprintXSize + 1)
					local dz = zi < 0 and -zi or (zi - renderFootprintZSize + 1)
					local distance = math.max(dx, dz)
					local alphaMidpoint = (EXTENDED_ALPHA_NEAR + EXTENDED_ALPHA_FAR) * 0.5
					local alphaRangeScale = extendedCells / EXTENDED_CELLS
					local alphaNear = alphaMidpoint + (EXTENDED_ALPHA_NEAR - alphaMidpoint) * alphaRangeScale
					local alphaFar = alphaMidpoint + (EXTENDED_ALPHA_FAR - alphaMidpoint) * alphaRangeScale
					local t = (distance - 1) / math.max(1, renderExtendedCells - 1)
					alpha = alphaNear + (alphaFar - alphaNear) * t
					outlineAlpha = outlineColor[4] * alpha
				end

				colorDataIndex = colorDataIndex + 1
				colorData[colorDataIndex] = color[1]
				colorDataIndex = colorDataIndex + 1
				colorData[colorDataIndex] = color[2]
				colorDataIndex = colorDataIndex + 1
				colorData[colorDataIndex] = color[3]
				colorDataIndex = colorDataIndex + 1
				colorData[colorDataIndex] = alpha
				colorDataIndex = colorDataIndex + 1
				colorData[colorDataIndex] = outlineColor[1]
				colorDataIndex = colorDataIndex + 1
				colorData[colorDataIndex] = outlineColor[2]
				colorDataIndex = colorDataIndex + 1
				colorData[colorDataIndex] = outlineColor[3]
				colorDataIndex = colorDataIndex + 1
				colorData[colorDataIndex] = outlineAlpha
			end
		end

		for index = colorDataIndex + 1, renderCache.colorDataLength or 0 do
			colorData[index] = nil
		end
		renderCache.colorDataLength = colorDataIndex
		renderCache.colorRevision = (renderCache.colorRevision or 0) + 1
		tracy.ZoneEnd()
	end

	collectPreview(
		renderCache,
		sx * SQUARE_SIZE,
		sz * SQUARE_SIZE,
		simplified and 1 or (merged and renderCache.mergedRectCount) or renderCellCount,
		xsize,
		zsize,
		extendedCells,
		cellScale,
		simplified,
		merged
	)
end

local function collectPregameBuildSquare()
	if spGetGameFrame() > 0 then
		return
	end

	local pregameBuild = WG["pregame-build"]
	local getPreGameDefID = pregameBuild and pregameBuild.getPreGameDefID
	local unitDefID = getPreGameDefID and getPreGameDefID()
	if not unitDefID then
		return
	end
	local unitDef = UnitDefs[unitDefID]
	if not unitDef then
		return
	end

	local mouseX, mouseY = spGetMouseState()
	local _, position = spTraceScreenRay(mouseX, mouseY, true, false, false, unitDef.modCategories.underwater)
	if not position then
		return
	end
	local positionX = position[1]
	local positionY = position[2]
	local positionZ = position[3]
	if not positionX or not positionY or not positionZ then
		return
	end

	local facing = spGetBuildFacing()
	local x, buildHeight, z = spPos2BuildPos(unitDefID, positionX, positionY, positionZ, facing)
	if not x or not buildHeight or not z then
		return
	end

	local footprint = getFootprintData(unitDefID, facing)
	if not footprint then
		return
	end

	local placementValid = spTestBuildOrder(unitDefID, x, buildHeight, z, facing) ~= 0
	local doesBuildClashWithCommander = pregameBuild.doesBuildClashWithCommander
	if doesBuildClashWithCommander then
		placementValid = placementValid and not doesBuildClashWithCommander(unitDefID, x, buildHeight, z, facing)
	end
	local getCancelledQueuedBuilds = pregameBuild.getCancelledQueuedBuilds
	if getCancelledQueuedBuilds then
		local overlapsQueuedBuild, cancelsQueuedBuild =
			getCancelledQueuedBuilds(unitDefID, x, buildHeight, z, facing, pregameCancelledBuilds)
		placementValid = placementValid and (not overlapsQueuedBuild or cancelsQueuedBuild)
	else
		for i = #pregameCancelledBuilds, 1, -1 do
			pregameCancelledBuilds[i] = nil
		end
	end
	fillPredictedStatuses(pregameStatuses, unitDef, x, buildHeight, z, footprint, placementValid)
	-- Blank cells the engine would otherwise clear a queued build for: the cell prediction above only knows
	-- about terrain/yardmap conflicts, not which earlier queued command this placement would cancel.
	if #pregameCancelledBuilds > 0 then
		local statusIndex = 0
		for zi = 0, footprint.zsize - 1 do
			for xi = 0, footprint.xsize - 1 do
				statusIndex = statusIndex + 1
				local worldX = x + (xi - footprint.halfXsize) * SQUARE_SIZE
				local worldZ = z + (zi - footprint.halfZsize) * SQUARE_SIZE
				for i = 1, #pregameCancelledBuilds do
					local cancelledBuild = pregameCancelledBuilds[i]
					local cancelledFootprint = getFootprintData(cancelledBuild[1], cancelledBuild[5] or 0)
					local minX = cancelledBuild[2] - cancelledFootprint.halfXsize * SQUARE_SIZE
					local minZ = cancelledBuild[4] - cancelledFootprint.halfZsize * SQUARE_SIZE
					if
						worldX >= minX
						and worldX < minX + cancelledFootprint.xsize * SQUARE_SIZE
						and worldZ >= minZ
						and worldZ < minZ + cancelledFootprint.zsize * SQUARE_SIZE
					then
						pregameStatuses[statusIndex] = STATUS_BLOCKED
						break
					end
				end
			end
		end
	end

	widget:DrawBuildSquare(unitDefID, x, z, facing, pregameStatuses)
end

local function rebuildBatchBuffer()
	tracy.ZoneBeginN("W:BuildSquare:BuildBatch")
	local dataIndex = 0
	local instanceCount = 0
	local minimapDataIndex = 0
	local minimapCount = 0
	local capacityReached = false

	for previewIndex = 1, collectedPreviewCount do
		local renderCache = collectedPreviews[previewIndex]
		if SIMPLIFIED_MINIMAP_ENABLED and minimapCount < MAX_MINIMAP_BUILDINGS then
			local minimapColor = renderCache.footprintIsValid and VALID_FOOTPRINT_COLOR or STATUS_COLORS[STATUS_BLOCKED]
			local minimapOutlineColor = renderCache.footprintIsValid and VALID_FOOTPRINT_OUTLINE_COLOR
				or STATUS_OUTLINE_COLORS[STATUS_BLOCKED]
			minimapDataIndex = minimapDataIndex + 1
			minimapInstanceData[minimapDataIndex] = renderCache.batchOriginX
			minimapDataIndex = minimapDataIndex + 1
			minimapInstanceData[minimapDataIndex] = renderCache.batchOriginZ
			minimapDataIndex = minimapDataIndex + 1
			minimapInstanceData[minimapDataIndex] = renderCache.batchXsize * SQUARE_SIZE
			minimapDataIndex = minimapDataIndex + 1
			minimapInstanceData[minimapDataIndex] = renderCache.batchZsize * SQUARE_SIZE
			minimapDataIndex = minimapDataIndex + 1
			minimapInstanceData[minimapDataIndex] = minimapColor[1]
			minimapDataIndex = minimapDataIndex + 1
			minimapInstanceData[minimapDataIndex] = minimapColor[2]
			minimapDataIndex = minimapDataIndex + 1
			minimapInstanceData[minimapDataIndex] = minimapColor[3]
			minimapDataIndex = minimapDataIndex + 1
			minimapInstanceData[minimapDataIndex] = minimapColor[4]
			minimapDataIndex = minimapDataIndex + 1
			minimapInstanceData[minimapDataIndex] = minimapOutlineColor[1]
			minimapDataIndex = minimapDataIndex + 1
			minimapInstanceData[minimapDataIndex] = minimapOutlineColor[2]
			minimapDataIndex = minimapDataIndex + 1
			minimapInstanceData[minimapDataIndex] = minimapOutlineColor[3]
			minimapDataIndex = minimapDataIndex + 1
			minimapInstanceData[minimapDataIndex] = minimapOutlineColor[4]
			minimapDataIndex = minimapDataIndex + 1
			minimapInstanceData[minimapDataIndex] = renderCache.floatOnWater
			minimapDataIndex = minimapDataIndex + 1
			minimapInstanceData[minimapDataIndex] = 1 -- simplified quad
			minimapDataIndex = minimapDataIndex + 1
			minimapInstanceData[minimapDataIndex] = 0
			minimapDataIndex = minimapDataIndex + 1
			minimapInstanceData[minimapDataIndex] = 0
			minimapDataIndex = minimapDataIndex + 1
			minimapInstanceData[minimapDataIndex] = renderCache.batchXsize
			minimapDataIndex = minimapDataIndex + 1
			minimapInstanceData[minimapDataIndex] = renderCache.batchZsize
			minimapCount = minimapCount + 1
		end

		if not capacityReached and instanceCount + renderCache.batchNumCells <= MAX_BATCH_CELLS then
			local colorData = renderCache.colorData
			local originX = renderCache.batchOriginX
			local originZ = renderCache.batchOriginZ
			local floatOnWater = renderCache.floatOnWater
			local footprintXsize = renderCache.batchXsize
			local footprintZsize = renderCache.batchZsize
			if renderCache.batchSimplified then
				dataIndex = dataIndex + 1
				batchInstanceData[dataIndex] = renderCache.batchOriginX
				dataIndex = dataIndex + 1
				batchInstanceData[dataIndex] = renderCache.batchOriginZ
				dataIndex = dataIndex + 1
				batchInstanceData[dataIndex] = renderCache.batchXsize * SQUARE_SIZE
				dataIndex = dataIndex + 1
				batchInstanceData[dataIndex] = renderCache.batchZsize * SQUARE_SIZE
				dataIndex = dataIndex + 1
				batchInstanceData[dataIndex] = colorData[1]
				dataIndex = dataIndex + 1
				batchInstanceData[dataIndex] = colorData[2]
				dataIndex = dataIndex + 1
				batchInstanceData[dataIndex] = colorData[3]
				dataIndex = dataIndex + 1
				batchInstanceData[dataIndex] = colorData[4]
				dataIndex = dataIndex + 1
				batchInstanceData[dataIndex] = colorData[5]
				dataIndex = dataIndex + 1
				batchInstanceData[dataIndex] = colorData[6]
				dataIndex = dataIndex + 1
				batchInstanceData[dataIndex] = colorData[7]
				dataIndex = dataIndex + 1
				batchInstanceData[dataIndex] = colorData[8]
				dataIndex = dataIndex + 1
				batchInstanceData[dataIndex] = floatOnWater
				dataIndex = dataIndex + 1
				batchInstanceData[dataIndex] = 1 -- simplified quad
				dataIndex = dataIndex + 1
				batchInstanceData[dataIndex] = 0
				dataIndex = dataIndex + 1
				batchInstanceData[dataIndex] = 0
				dataIndex = dataIndex + 1
				batchInstanceData[dataIndex] = footprintXsize
				dataIndex = dataIndex + 1
				batchInstanceData[dataIndex] = footprintZsize
			elseif renderCache.batchMerged then
				for rectIndex = 0, renderCache.batchNumCells - 1 do
					local rectDataIndex = rectIndex * 14
					dataIndex = dataIndex + 1
					batchInstanceData[dataIndex] = originX + colorData[rectDataIndex + 1] * SQUARE_SIZE
					dataIndex = dataIndex + 1
					batchInstanceData[dataIndex] = originZ + colorData[rectDataIndex + 2] * SQUARE_SIZE
					dataIndex = dataIndex + 1
					batchInstanceData[dataIndex] = colorData[rectDataIndex + 3] * SQUARE_SIZE
					dataIndex = dataIndex + 1
					batchInstanceData[dataIndex] = colorData[rectDataIndex + 4] * SQUARE_SIZE
					for colorIndex = 7, 14 do
						dataIndex = dataIndex + 1
						batchInstanceData[dataIndex] = colorData[rectDataIndex + colorIndex]
					end
					dataIndex = dataIndex + 1
					batchInstanceData[dataIndex] = floatOnWater
					dataIndex = dataIndex + 1
					batchInstanceData[dataIndex] = 2 -- merged block
					dataIndex = dataIndex + 1
					batchInstanceData[dataIndex] = colorData[rectDataIndex + 5]
					dataIndex = dataIndex + 1
					batchInstanceData[dataIndex] = colorData[rectDataIndex + 6]
					dataIndex = dataIndex + 1
					batchInstanceData[dataIndex] = footprintXsize
					dataIndex = dataIndex + 1
					batchInstanceData[dataIndex] = footprintZsize
				end
			else
				local cellScale = renderCache.batchCellScale or 1
				local quadSize = SQUARE_SIZE * cellScale
				local geometryData = getCellGeometry(
					renderCache.batchXsize / cellScale,
					renderCache.batchZsize / cellScale,
					renderCache.batchExtendedCells / cellScale,
					cellScale
				)
				local packedFlags = renderCache.footprintIsValid and 16 or 0
				for cellIndex = 0, renderCache.batchNumCells - 1 do
					local geometryIndex = cellIndex * 3
					local colorIndex = cellIndex * 8
					dataIndex = dataIndex + 1
					batchInstanceData[dataIndex] = geometryData[geometryIndex + 1] + originX
					dataIndex = dataIndex + 1
					batchInstanceData[dataIndex] = geometryData[geometryIndex + 2] + originZ
					dataIndex = dataIndex + 1
					batchInstanceData[dataIndex] = quadSize
					dataIndex = dataIndex + 1
					batchInstanceData[dataIndex] = quadSize
					dataIndex = dataIndex + 1
					batchInstanceData[dataIndex] = colorData[colorIndex + 1]
					dataIndex = dataIndex + 1
					batchInstanceData[dataIndex] = colorData[colorIndex + 2]
					dataIndex = dataIndex + 1
					batchInstanceData[dataIndex] = colorData[colorIndex + 3]
					dataIndex = dataIndex + 1
					batchInstanceData[dataIndex] = colorData[colorIndex + 4]
					dataIndex = dataIndex + 1
					batchInstanceData[dataIndex] = colorData[colorIndex + 5]
					dataIndex = dataIndex + 1
					batchInstanceData[dataIndex] = colorData[colorIndex + 6]
					dataIndex = dataIndex + 1
					batchInstanceData[dataIndex] = colorData[colorIndex + 7]
					dataIndex = dataIndex + 1
					batchInstanceData[dataIndex] = colorData[colorIndex + 8]
					dataIndex = dataIndex + 1
					batchInstanceData[dataIndex] = floatOnWater
					dataIndex = dataIndex + 1
					batchInstanceData[dataIndex] = 0 -- regular cell
					dataIndex = dataIndex + 1
					batchInstanceData[dataIndex] = 0
					dataIndex = dataIndex + 1
					batchInstanceData[dataIndex] = geometryData[geometryIndex + 3] + packedFlags
					dataIndex = dataIndex + 1
					batchInstanceData[dataIndex] = footprintXsize
					dataIndex = dataIndex + 1
					batchInstanceData[dataIndex] = footprintZsize
				end
			end
			instanceCount = instanceCount + renderCache.batchNumCells
		else
			capacityReached = true
		end
	end

	for index = dataIndex + 1, batchInstanceDataLength do
		batchInstanceData[index] = nil
	end
	for index = minimapDataIndex + 1, minimapInstanceDataLength do
		minimapInstanceData[index] = nil
	end

	residentBatchPreviewCount = collectedPreviewCount
	batchInstanceDataLength = dataIndex
	batchInstanceCount = instanceCount
	minimapInstanceDataLength = minimapDataIndex
	minimapInstanceCount = minimapCount
	tracy.ZoneEnd()

	if batchInstanceCount > 0 then
		tracy.ZoneBeginN("W:BuildSquare:UploadBatch")
		batchInstanceVBO:Upload(batchInstanceData)
		tracy.ZoneEnd()
	end
	if SIMPLIFIED_MINIMAP_ENABLED and minimapInstanceCount > 0 then
		tracy.ZoneBeginN("W:BuildSquare:UploadMiniMapBatch")
		minimapInstanceVBO:Upload(minimapInstanceData)
		tracy.ZoneEnd()
	end
end

function widget:DrawWorldPreUnit()
	local drawFrame = beginBuildSquareDrawFrame(spGetDrawFrame())
	collectPregameBuildSquare()
	if collectedPreviewCount == 0 or collectedDrawFrame < drawFrame - 1 or collectedDrawFrame > drawFrame then
		batchInstanceCount = 0
		minimapInstanceCount = 0
		residentBatchPreviewCount = 0
		return
	end

	if collectedBatchChanged or residentBatchPreviewCount ~= collectedPreviewCount then
		rebuildBatchBuffer()
	end
	if batchInstanceCount == 0 then
		return
	end

	tracy.ZoneBeginN("W:BuildSquare:DrawBatch")
	glTexture(0, "$heightmap")
	glDepthTest(false)
	-- Set blend func and culling explicitly: widgets drawn earlier in the same callin can leave
	-- another blend func or face culling enabled (e.g. map edge extension), which would make
	-- these quads invisible.
	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	glCulling(false)
	glUseShader(shaderProgram)
	glUniform(heightOffsetLoc, getCurrentHeightOffset())
	glUniform(waterLevelLoc, spGetWaterPlaneLevel and spGetWaterPlaneLevel() or 0)
	glUniform(alphaMultiplierLoc, PREUNIT_PASS_ALPHA)
	glUniformInt(isMiniMapLoc, 0)
	if PREUNIT_PASS_ALPHA > 0 then
		batchVAO:DrawArrays(GL_TRIANGLE_STRIP, 4, 0, batchInstanceCount)
	end
	glUseShader(0)
	glTexture(0, false)
	glDepthTest(GL_LESS)
	overlayBatchDrawFrame = drawFrame
	tracy.ZoneEnd()
end

-- Overlay pass: redraws the batch that DrawWorldPreUnit just drew, on top of units, at reduced opacity so covered
-- squares stay visible. Reuses the uploaded instance buffer and the uniforms set by the pre-unit pass this frame;
-- only the alpha multiplier differs, so the extra cost is a single draw call.
function widget:DrawWorld()
	if
		not OVERLAY_PASS_ENABLED
		or OVERLAY_PASS_ALPHA <= 0
		or batchInstanceCount == 0
		or overlayBatchDrawFrame ~= spGetDrawFrame()
	then
		return
	end

	tracy.ZoneBeginN("W:BuildSquare:DrawOverlayBatch")
	glTexture(0, "$heightmap")
	glDepthTest(false)
	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	glCulling(false)
	glUseShader(shaderProgram)
	glUniform(alphaMultiplierLoc, OVERLAY_PASS_ALPHA)
	batchVAO:DrawArrays(GL_TRIANGLE_STRIP, 4, 0, batchInstanceCount)
	glUseShader(0)
	glTexture(0, false)
	glDepthTest(GL_LESS)
	tracy.ZoneEnd()
end

function widget:DrawInMiniMap()
	local drawFrame = spGetDrawFrame()
	if
		not SIMPLIFIED_MINIMAP_ENABLED
		or minimapInstanceCount == 0
		or collectedDrawFrame < drawFrame - 1
		or collectedDrawFrame > drawFrame
	then
		minimapInstanceCount = 0
		return
	end

	tracy.ZoneBeginN("W:BuildSquare:DrawMiniMapBatch")
	glDepthTest(false)
	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	glCulling(false)
	glUseShader(shaderProgram)
	local rotation = spGetMiniMapRotation and spGetMiniMapRotation() or 0
	local rotationQuarterTurns = math.floor((rotation / math.pi * 2 + 0.5) % 4)
	glUniform(alphaMultiplierLoc, 1.0)
	glUniformInt(isMiniMapLoc, 1)
	glUniformInt(rotationMiniMapLoc, rotationQuarterTurns)
	minimapVAO:DrawArrays(GL_TRIANGLE_STRIP, 4, 0, minimapInstanceCount)
	glUseShader(0)
	glDepthTest(false)
	tracy.ZoneEnd()
end
