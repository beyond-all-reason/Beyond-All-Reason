local isPotatoGpu = false
local gpuMem = (Platform.gpuMemorySize and Platform.gpuMemorySize or 1000) / 1000
if Platform ~= nil and Platform.gpuVendor == "Intel" then
	isPotatoGpu = true
end
if gpuMem and gpuMem > 0 and gpuMem < 1800 then
	isPotatoGpu = true
end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Map Grass GL4",
		version = "1.0",
		desc = "Instanced rendering of custom grass",
		author = "Beherith (mysterme@gmail.com)",
		date = "2021.04.12",
		license = "GNU GPL, v2",
		layer = -999999,
		enabled = not isPotatoGpu,
	}
end

-- Localized functions for performance
local mathAbs = math.abs
local mathFloor = math.floor
local mathMax = math.max
local mathMin = math.min
local mathRandom = math.random

-- Localized Spring API for performance
local spGetUnitPosition = Spring.GetUnitPosition
local spGetMouseState = Spring.GetMouseState
local spTraceScreenRay = Spring.TraceScreenRay
local spGetCameraPosition = Spring.GetCameraPosition
local spEcho = Spring.Echo
local spGetAllUnits = Spring.GetAllUnits
local spGetVisibleUnits = Spring.GetVisibleUnits

----------IMPORTANT USAGE INSTRUCTIONS/ README----------

-- The grass configuration is set in the following order:
-- Defaults are in grassConfig
-- Any values in mapinfo.lua s  mapinfo.custom.grassConfig table is merged into the default
-- Any further params in mapOverrides table is merged into grassConfig table
-- The distribution of grass by default is taken (smartly) from the maps original grass map, or the grassDistTGA param of the config
-- grassDistTGA _must_ be 8 bit greyscale tga, mapSize[X|Z] / patchResolution sized
-- Commands to load/save grass:
-- /loadgrass [filename] : loads a grass distribution from filename path, defaults to VFS_root [mapName]_grassDist.tga
-- /savegrass [filename] : saves the grass distribution to filename path, defaults to VFS_root [mapName]_grassDist.tga
-- /cleargrass : Sets the entire map to have 0 sized grass
-- /editgrass : allows you to edit the already defined grass (either from mapSMFgrass, or grassDistTGA, if specified)
-- /dumpgrassshaders : dumps shaders
-- UI to paint grass:
-- Once placement mode has been toggled with /loadgrass or /cleargrass or /editgrass
-- use the '[' and ']' keys to change brush size
-- use the left mouse button to make the grass grow, right mouse button to make it small/disappear
-- hold shift to paint max height grass/ fully remove grass
-- I also recommend binding toggle grass widget to alt+f for fast colorization reloading in uikeys.txt
-- If you want to change colorization, and want to save your 'painting progress', do /savegrass, reload the widget, then /loadgrass
-- NOTE: Shader load is MUCH higher in editing mode, and especially on large maps (pushing 10's of millions of vertices)

-- Load Order
-- 1. Parse Mapinfo
--     -- if grass params exist, use them
-- 2. Parse Overrides-------------------
--     -- if overrides exist, use them
-- 3. cleargrass or loadgrass overrides, and enables placement mode
-- 4. enable placementMode -- this should reload the instance VBO, but keep any parsed params
-- 5. Separate autograss function
-- 6. GrassDistTexture overrides builtin grass

--------- TODO/ DEVNOTES: -------------------------------------------
-- Todo:
-- do all of this in geom shader to do early LOD culling
-- customizable shadowmap sample size
-- grass UV offsets multiplier

-- issues:
--	Pretty high vertex shader load :/
-- 	anisotropic transparency - where quads viewed from their edge should be transparent :)
-- 	fix darkening on distort to be better?

--------- HOW TO CONFIGURE GRASS (also important!) -------------------------
local grassConfig = {
	patchResolution = 32, -- distance between patches, default is 32, which matches the SpringRTS grass map resolution. If using external .tga, you can use any resolution you wish
	patchPlacementJitter = 0.66, -- how much each patch should be randomized in XZ position, in fraction of patchResolution
	patchSize = 4, -- 1 or 4 clusters of blades, 4 recommended
	grassBladeScale = 0.55, -- scales the baked patch mesh itself; lower this to make blades physically smaller regardless of patchSize
	grassMinSize = 0.55, --Size for grassmap value of 1 , min and max should be equal for old style binary grassmap (because its only 0,1)
	grassMaxSize = 1.5, -- Size for grassmap value of 254
	grassShaderParams = { -- allcaps because thats how i know
		MAPCOLORFACTOR = 0.6, -- how much effect the minimapcolor has
		MAPCOLORBASE = 1.0, --how much more to blend the bottom of the grass patches into map color
		ALPHATHRESHOLD = 0.01, --alpha limit under which to discard a fragment
		WINDSTRENGTH = 0.1, -- how much the wind will blow the grass
		WINDSCALE = 0.33, -- how fast the wind texture moves
		WINDSAMPLESCALE = 0.001, -- tiling resolution of the noise texture
		FADESTART = 5000, -- distance at which grass starts to fade
		FADEEND = 8000, --distance at which grass completely fades out
		SHADOWFACTOR = 0.25, -- how much shadowed grass gets darkened, lower values mean more shadows
		HASSHADOWS = 1, -- 0 for disable, no real difference in this (does not work yet)
		GRASSBRIGHTNESS = 1.0, -- this is for future dark mode
		COMPACTVBO = 1, -- if set to 1, then the grass patch vbo will be compacted to 8 vertices per patch, otherwise it will be 17 vertices per patch
		UNITBENDENABLED = 1, -- 1 to enable grass bending away from units, 0 to disable
		UNITBENDSTRENGTH = 5.5, -- how strongly grass bends away from nearby units
		UNITBENDFALLOFF = 0.8, -- falloff exponent for bending effect (higher = sharper falloff)
		UNITBENDSHRINK = 0.55, -- how much grass shrinks near unit center (0 = no shrink, 1 = fully gone)
	},
	grassBladeColorTex = "LuaUI/Images/luagrass/grass_field_medit_flowering.dds.cached.dds", -- rgb + alpha transp
	mapGrassColorModTex = "$grass", -- by default this means that grass will be colorized with the minimap
	grassWindPerturbTex = "bitmaps/GPL/perlin_noise.jpg", -- rgba of various frequencies of perlin noise?
	grassWindMult = 4.5, -- how 'strong' the perturbation effect is
	maxWindSpeed = 20, -- the fastest the wind noise texture will ever move,
	-- The grassdisttex overrides the default map grass, if specified!
	grassDistTGA = "", -- MUST BE 8 bit uncompressed TGA, sized Game.mapSize* / patchResolution, where 0 is no grass, and 1<= controls grass size.
}

local nightFactor = { 1, 1, 1, 1 }

local distanceMult = 0.45

local MAX_BEND_UNITS = 128

--------------------------------------------------------------------------------
-- map custom config
-- if map has a custom mapinfo.lua configuration, then merge the keys of it with our config table

local success, mapcfg = pcall(VFS.Include, "mapinfo.lua") -- load mapinfo.lua confs
if not success then
	spEcho("Map Grass GL4 failed to find a mapinfo.lua, using default configs")
else
	if mapcfg and mapcfg.custom and mapcfg.custom.grassconfig then
		spEcho("Loading LuaGrass custom parameters from mapinfo.lua")
		for k, v in pairs(mapcfg.custom.grassconfig) do
			for kUp, _ in pairs(grassConfig) do
				if k == string.lower(kUp) then
					k = kUp
				end
			end
			--spEcho("Found grass params",k,v)

			if string.lower(k) == "grassshaderparams" then
				for k2, v2 in pairs(v) do
					for k2Up, _ in pairs(grassConfig.grassShaderParams) do
						--spEcho("Found grass params",k2,k2Up,v2)
						if k2 == string.lower(k2Up) then
							k2 = k2Up
						end
					end
					grassConfig[k][k2] = v2
				end
			else
				grassConfig[k] = v
			end
		end
	end
end
spEcho("Map is", Game.mapName)

-----------------------Old Map Overrides-------------------
local mapoverrides = {
	["DSDR 4.0"] = {
		--grassDistTGA = "DSDR 4.0_grassDist.tga",
		grassMaxSize = 2.0, -- Size for grassmap value of 254
		grassShaderParams = {
			MAPCOLORFACTOR = 0.6,
		},
	},
	DeltaSiegeDry = {
		patchResolution = 32,
		grassShaderParams = {
			MAPCOLORFACTOR = 0.6,
			SHADOWFACTOR = 0.001,
		},
	},
	Pentos_V1 = {
		patchResolution = 32,
		grassShaderParams = {
			MAPCOLORFACTOR = 0.6,
		},
	},
	Taldarim_V3 = {
		patchResolution = 32,
		grassShaderParams = {
			MAPCOLORFACTOR = 0.5,
		},
		grassDistTGA = "LuaUI/Images/luagrass/Taldarim_V3_grassDist.tga",
	},
	Altair_Crossing_V4 = {
		patchResolution = 32,
		grassMinSize = 0.5, --Size for grassmap value of 1 , min and max should be equal for old style binary grassmap (because its only 0,1)
		grassMaxSize = 2.0, -- Size for grassmap value of 254
		grassShaderParams = {
			MAPCOLORFACTOR = -1.2,
		},
	},
}

if mapoverrides[Game.mapName] then
	spEcho("Overriding map grass")
	for k, v in pairs(mapoverrides[Game.mapName]) do
		if k == "grassShaderParams" then
			for k2, v2 in pairs(v) do
				grassConfig[k][k2] = v2
			end
		else
			grassConfig[k] = v
		end
	end
end

--------------------------------------------------------------------------------
local patchResolution = grassConfig.patchResolution
local spGetGroundHeight = Spring.GetGroundHeight
local spGetGrass = Spring.GetGrass
local spGetUnitDefID = Spring.GetUnitDefID
local mapSizeX, mapSizeZ = Game.mapSizeX, Game.mapSizeZ
local vsx, vsy = gl.GetViewSizes()
local minHeight, maxHeight = Spring.GetGroundExtremes()
local removedBelowHeight
local lastLavaLevel
local lavaCheckInterval = 30 -- check every N game frames

local processChanges = false -- auto enabled when map has grass or editmode toggles

local mousepos = { 0, 0, 0 }
local cursorradius = 50
local removeUnitGrassFrames = 25
local placementMode = false -- this controls wether we are in 'game mode' or placement map dev mode
local externalBrushActive = false -- when true, suppress built-in painting UI (mouse, keys, circle)

-- Spawn animation: grass grows from ground with elastic wobble when placed
local SPAWN_ANIM_DURATION = 0.45 -- seconds for grow animation
local SPAWN_ANIM_MAX = 800 -- max concurrent animations (ring buffer)
local spawnAnims = {} -- keyed by vboElementIndex: {target=size, start=clock, prev=oldSize}
local spawnAnimCount = 0
local spawnAnimClock = os.clock()

-- Elastic-out easing: overshoots then settles (simulates sprouting wobble)
local function elasticOut(t)
	if t <= 0 then
		return 0
	end
	if t >= 1 then
		return 1
	end
	local p = 0.35
	return math.pow(2, -10 * t) * math.sin((t - p / 4) * (2 * math.pi) / p) + 1
end

include("keysym.h.lua") -- so we can do hacky keypress
local grassInstanceData = {}
---------------------------VAO VBO stuff:---------------------------------------

local grassPatchVBO = nil
local grassPatchVBOsize = 0
local grassPatchIndexVBO = nil
local grassInstanceVBO = nil
local grassInstanceVBOSize = nil
local grassInstanceVBOStep = 4 -- 4 values per patch
-- World-space tile grid: the instance buffer is grouped into GRID_SIZE tiles so we can
-- frustum-cull and draw only the contiguous instance ranges of the tiles that are visible.
local GRID_SIZE = 512
local gridPatchCols, gridPatchRows = 0, 0 -- whole-map patch grid dimensions
local gridCols, gridRows = 0, 0 -- tile grid dimensions
local patchesPerTileX, patchesPerTileZ = 1, 1 -- patches per tile edge
local tileOffset = {} -- [tileIdx] = first patch element index in buffer
local tileCount = {} -- [tileIdx] = patch count in tile
local tileWidth = {} -- [tileIdx] = patch columns in tile (edge tiles differ)
local tileMidHeight = (minHeight + maxHeight) * 0.5 -- sphere-cull center height
local tileHeightSlack = (maxHeight - minHeight) * 0.5 + 200 -- vertical slack for sphere cull
local grassVAO = nil
local grassShader = nil
local grassVertexShaderDebug = ""
local grassFragmentShaderDebug = ""
local grassPatchCount = 0

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable

local windDirX = 0
local windDirZ = 0
local offsetX = 0
local offsetZ = 0
local oldGameSeconds = os.clock()

local unitGrassRemovedHistory = {}
local removeUnitGrassQueue = {}

local buildingRadius = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if (unitDef.isBuilding or string.find(unitDef.name, "nanotc")) and unitDef.radius > 18 then
		buildingRadius[unitDefID] = unitDef.radius
	end
end

-- Unit bending: pre-compute collision radii for non-building, non-flying units
local unitBendSSBO = nil
local unitBendData = {}
local unitBendCount = 0
for i = 1, MAX_BEND_UNITS * 4 do
	unitBendData[i] = 0
end

local unitBendRadius = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	local isShip = unitDef.modCategories and unitDef.modCategories.ship
	if not buildingRadius[unitDefID] and not unitDef.canFly and not isShip then
		local radius = unitDef.radius or 20
		if radius > 10 then
			unitBendRadius[unitDefID] = radius
		end
	end
end

local cachedUnitList = {} -- array of {x, z, radius} for indexed iteration
local cachedUnitCount = 0
local lastUploadedCount = -1 -- track to skip redundant uploads
local unitScanDirty = true
local skipBendUntilGF = 0 -- when conditions fail, skip scanning for 30 frames to avoid table allocs
local unitScanIntervalGF = 4 -- base scan rate; adaptive logic lowers this when camera is close
local nextUnitScanGF = 0

local function scanUnitPositions(gf)
	-- When previously skipped, avoid all API calls until recheck time
	if gf < skipBendUntilGF then
		return
	end

	local cx, cy, cz = spGetCameraPosition()
	local gh = Spring.GetGroundHeight(cx, cz) or 0
	local camHeight = cy - gh
	local fadeEndDist = grassConfig.grassShaderParams.FADEEND * distanceMult
	-- Skip bending when camera is too high to see grass detail
	if camHeight > fadeEndDist then
		skipBendUntilGF = gf + 30
		if cachedUnitCount > 0 then
			cachedUnitCount = 0
			unitScanDirty = true
		end
		return
	end

	local visibleUnits = spGetVisibleUnits(-1, nil, false)
	-- Skip when too many units visible (zoomed out, expensive, not noticeable)
	local visibleCount = visibleUnits and #visibleUnits or 0
	if visibleCount > 250 then
		skipBendUntilGF = gf + 30
		if cachedUnitCount > 0 then
			cachedUnitCount = 0
			unitScanDirty = true
		end
		return
	end

	local count = 0
	if visibleCount > 0 then
		for i = 1, visibleCount do
			local unitID = visibleUnits[i]
			local unitDefID = spGetUnitDefID(unitID)
			if unitDefID then
				local radius = unitBendRadius[unitDefID]
				if radius then
					local ux, _, uz = spGetUnitPosition(unitID)
					if ux then
						local bendRadius = radius + 15
						-- Grass beyond the distance fade is discarded, so a unit only affects visible
						-- grass when it can reach the fade circle. No cull in placement mode, which
						-- draws every tile regardless of distance.
						local maxBendDist = bendRadius + fadeEndDist
						local ddX = ux - cx
						local ddZ = uz - cz
						if ddX * ddX + ddZ * ddZ <= maxBendDist * maxBendDist or placementMode then
							count = count + 1
							local entry = cachedUnitList[count]
							if entry then
								entry[1], entry[2], entry[3] = ux, uz, bendRadius
							else
								cachedUnitList[count] = { ux, uz, bendRadius }
							end
						end
					end
				end
			end
		end
	end
	cachedUnitCount = count
	unitScanDirty = true
end

local function updateUnitBendSSBO()
	if not unitBendSSBO then
		return
	end

	-- Skip upload if nothing changed
	if not unitScanDirty and lastUploadedCount == cachedUnitCount then
		return
	end
	unitScanDirty = false

	-- Pack SSBO from cached unit list (indexed array, no pairs())
	local count = mathMin(cachedUnitCount, MAX_BEND_UNITS)
	unitBendCount = count
	for i = 1, count do
		local pos = cachedUnitList[i]
		local offset = (i - 1) * 4
		unitBendData[offset + 1] = pos[1]
		unitBendData[offset + 2] = pos[2]
		unitBendData[offset + 3] = pos[3]
		unitBendData[offset + 4] = 1.0
	end

	-- Zero out remaining only if count decreased
	if count < lastUploadedCount then
		for i = count * 4 + 1, lastUploadedCount * 4 do
			unitBendData[i] = 0
		end
	end
	lastUploadedCount = count

	unitBendSSBO:Upload(unitBendData)
end

local function goodbye(reason)
	spEcho("Map Grass GL4 widget exiting with reason: " .. reason)
	if grassPatchVBO then
		grassPatchVBO = nil
	end
	if grassInstanceVBO then
		grassInstanceVBO = nil
	end
	if unitBendSSBO then
		unitBendSSBO = nil
	end
	if grassVAO then
		grassVAO = nil
	end
	--if grassShader then grassShader:Finalize() end
	widgetHandler:RemoveWidget()
end
--------------------------------------------------------------------------------
-- using: http://ogldev.atspace.co.uk/www/tutorial33/tutorial33.html
local function makeGrassPatchVBO(grassPatchSize) -- grassPatchSize = 1|4, see the commented out python section at the bottom to make a custom vbo
	grassPatchVBO = gl.GetVBO(GL.ARRAY_BUFFER, false)
	if grassPatchVBO == nil then
		goodbye("No LuaVAO support")
	end

	local VBOLayout = {
		{ id = 0, name = "position", size = 3 },
		{ id = 1, name = "normal", size = 3 },
		{ id = 2, name = "stangent", size = 3 },
		{ id = 3, name = "ttangent", size = 3 },
		{ id = 4, name = "texcoords0", size = 2 },
		{ id = 5, name = "texcoords1", size = 2 },
		{ id = 6, name = "pieceindex", size = 1 },
	} --khm, this should be unsigned int

	local VBOData = VFS.Include("LuaUI/Include/grassPatches.lua")

	if grassPatchSize == 1 then
		grassPatchVBOsize = 36
		VBOData = VBOData[1]
	elseif grassPatchSize == 4 then
		grassPatchVBOsize = 144
		VBOData = VBOData[4]
	end
	-- What if we went down to 8 vertices?
	if grassConfig.grassShaderParams.COMPACTVBO == 1 then
		VBOLayout = { { id = 0, name = "pos_u" }, { id = 1, name = "norm_v" } }
		local compactVBO = {}
		for v = 1, grassPatchVBOsize do
			compactVBO[8 * (v - 1) + 1] = VBOData[17 * (v - 1) + 1] -- px
			compactVBO[8 * (v - 1) + 2] = VBOData[17 * (v - 1) + 2] -- py
			compactVBO[8 * (v - 1) + 3] = VBOData[17 * (v - 1) + 3] -- pz
			compactVBO[8 * (v - 1) + 4] = VBOData[17 * (v - 1) + 13] -- u
			compactVBO[8 * (v - 1) + 5] = VBOData[17 * (v - 1) + 4] -- nx
			compactVBO[8 * (v - 1) + 6] = VBOData[17 * (v - 1) + 5] -- ny
			compactVBO[8 * (v - 1) + 7] = VBOData[17 * (v - 1) + 6] -- nz
			compactVBO[8 * (v - 1) + 8] = VBOData[17 * (v - 1) + 14] -- v
		end
		VBOData = compactVBO
	end

	-- The source mesh is a triangle soup (each of grassPatchVBOsize verts belongs to one
	-- triangle, so shared quad corners are duplicated). Merge bit-identical vertices into a
	-- unique set + index list so indexed drawing can reuse them via the post-transform cache,
	-- cutting VS invocations per patch. UV/normal seams stay split because only fully identical
	-- vertices merge. grassPatchVBOsize keeps meaning the index count (one index per soup vert).
	local stride = #VBOData / grassPatchVBOsize
	local uniqueVBOData = {}
	local uniqueCount = 0
	local indexList = {}
	local vertKeyToIndex = {}
	local keyParts = {}
	for v = 0, grassPatchVBOsize - 1 do
		local base = v * stride
		for f = 1, stride do
			keyParts[f] = VBOData[base + f]
		end
		local key = table.concat(keyParts, "_", 1, stride)
		local idx = vertKeyToIndex[key]
		if not idx then
			idx = uniqueCount
			vertKeyToIndex[key] = idx
			local ubase = uniqueCount * stride
			for f = 1, stride do
				uniqueVBOData[ubase + f] = VBOData[base + f]
			end
			uniqueCount = uniqueCount + 1
		end
		indexList[v + 1] = idx
	end

	grassPatchVBO:Define(uniqueCount, VBOLayout)

	grassPatchIndexVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false)
	grassPatchIndexVBO:Define(grassPatchVBOsize) -- one index per triangle-soup vertex
	grassPatchIndexVBO:Upload(indexList)

	grassPatchVBO:Upload(uniqueVBOData)
end

local function fsrand(a, b) -- fast, repeatable random vec2
	local s = math.sin((a * 12.9898 + b * 78.233))
	return math.fract(s * 43758.5453), math.fract(s * 41758.5453)
end

local function testForGrass(mx, mz)
	if grassConfig.obeyGrassMap then
		if spGetGrass(mx, mz) == 1 then
			return spGetGroundHeight(mx, mz)
		else
			return nil
		end
	else
		local gx, gy, gz, gs = Spring.GetGroundNormal(mx, mz)
		local gh = spGetGroundHeight(mx, mz)
		if
			(gh > grassConfig.grassMinHeight)
			and (gh < grassConfig.grassMaxHeight)
			and (gy > grassConfig.grassMaxSlope)
		then
			return gh
		else
			return nil
		end
	end
end

local function mapHasSMFGrass() -- returns 255 is SMF has no grass, 0 if map has no grass, 1 if map has old style binary grass, 2<=  <=254 if map has new style uint grass
	local highestgrassmapvalue = 0
	local patchResolution = 32

	for x = patchResolution / 2, mapSizeX, patchResolution do
		for z = patchResolution / 2, mapSizeZ, patchResolution do
			local localgrass = spGetGrass(x, z)
			if localgrass == 255 then
				return 255
			else
				highestgrassmapvalue = mathMax(highestgrassmapvalue, localgrass)
			end
		end
	end
	return highestgrassmapvalue
end

local function grassByteToPatchMult(grassbyte) -- coverts grassmap byte to size multiplier for instancebuffer
	if grassbyte == 0 then
		return 0
	end
	return (grassConfig.grassMinSize + (grassConfig.grassMaxSize - grassConfig.grassMinSize) * (grassbyte / 254.0))
end

local function grassPatchMultToByte(grasspatchsize) -- converts instancebuffer size to grassmap byte
	if grasspatchsize < grassConfig.grassMinSize then
		return 0
	end
	local grassbyte = (grasspatchsize - grassConfig.grassMinSize)
	grassbyte = grassbyte / (grassConfig.grassMaxSize - grassConfig.grassMinSize) * 254.0
	return math.clamp(grassbyte, 1, 254)
end

local function world2grassmap(wx, wz) -- returns the patch element index for a world position, or -1 if out of range
	local gx = mathFloor(wx / grassConfig.patchResolution)
	local gz = mathFloor(wz / grassConfig.patchResolution)
	if gx < 0 or gx >= gridPatchCols or gz < 0 or gz >= gridPatchRows then
		return -1
	end
	local tx = mathFloor(gx / patchesPerTileX)
	local tz = mathFloor(gz / patchesPerTileZ)
	local tile = tz * gridCols + tx
	local localX = gx - tx * patchesPerTileX
	local localZ = gz - tz * patchesPerTileZ
	return tileOffset[tile] + localZ * tileWidth[tile] + localX
end

local gCT = {} -- Grass Cache Table
local function updateGrassInstanceVBO(wx, wz, size, sizemod, vboOffset)
	-- we are assuming that we can do this
	--spEcho(wx, wz, sizemod)
	if not grassInstanceVBO then
		return
	end
	local vboOffset = vboOffset or world2grassmap(wx, wz) * grassInstanceVBOStep
	if vboOffset < 0 or vboOffset >= #grassInstanceData then -- top left of map gets vboOffset: 0
		--spEcho(boOffset > #grassInstanceData",vboOffset,#grassInstanceData, " you probably need to /editgrass")
		return
	end

	local oldsize = grassInstanceData[vboOffset + 4]
	if (not oldsize or oldsize <= 0) and not placementMode then
		return
	end

	local oldpx = grassInstanceData[vboOffset + 1] -- We must read all instance params, because we need to write them all at once
	local oldry = grassInstanceData[vboOffset + 2]
	local oldpz = grassInstanceData[vboOffset + 3]

	if sizemod then
		size = mathMin(grassConfig.grassMaxSize, oldsize * sizemod)
	end

	local shift = false
	if placementMode then
		_, _, _, shift = Spring.GetModKeyState()
	end
	if sizemod < 1 then
		if size < grassConfig.grassMinSize or shift then
			size = 0
		end
	else
		if shift then
			size = grassConfig.grassMaxSize
		else
			size = mathMax(grassConfig.grassMinSize, size)
		end
	end
	grassInstanceData[vboOffset + 4] = size
	--spEcho("updateGrassInstanceVBO:",oldpx, "x", wx, oldpz ,"z", wz, oldsize, "s", size)
	--size_t LuaVBOImpl::Upload(const sol::stack_table& luaTblData, const sol::optional<int> attribIdxOpt, const sol::optional<int> elemOffsetOpt, const sol::optional<int> luastartInstanceIndexndexOpt, const sol::optional<int> luaFinishIndexOpt)
	gCT[1], gCT[2], gCT[3], gCT[4] = oldpx, oldry, oldpz, size
	grassInstanceVBO:Upload(gCT, 7, vboOffset / 4) -- We _must_ upload whole instance params at once
end

function widget:KeyPress(key, modifier, isRepeat)
	if not placementMode then
		return false
	end
	if externalBrushActive then
		return false
	end
	if key == KEYSYMS.LEFTBRACKET then
		cursorradius = mathMax(8, cursorradius * 0.8)
	end
	if key == KEYSYMS.RIGHTBRACKET then
		cursorradius = mathMin(512, cursorradius * 1.2)
	end
	return false
end

local function adjustGrass(px, pz, radius, multiplier)
	--local params = {mathFloor(px),mathFloor(pz)}
	px, pz = mathFloor(px), mathFloor(pz)
	for x = px - radius, px + radius, grassConfig.patchResolution do
		if x >= 0 and x <= mapSizeX then
			for z = pz - radius, pz + radius, grassConfig.patchResolution do
				if z >= 0 and z <= mapSizeZ then
					if (x - px) * (x - px) + (z - pz) * (z - pz) < radius * radius then
						local vboOffset = world2grassmap(x, z) * grassInstanceVBOStep
						if vboOffset then
							local sizeMod = 1 - (mathAbs(((x - px) / radius)) + mathAbs(((z - pz) / radius))) / 2 -- sizemode in range 0...1
							sizeMod = (sizeMod * 2 - mathMin(0.66, radius / 100)) -- adjust sizemod so inner grass is gone fully and not just the very center dot
							sizeMod = sizeMod * multiplier -- apply multiplier to animate it over time
							updateGrassInstanceVBO(x, z, 1, 1 - sizeMod, vboOffset)
						end
					end
				end
			end
		end
	end
end

local function adjustUnitGrass(unitID, multiplier)
	local radius
	if not unitGrassRemovedHistory[unitID] then
		local unitDefID = spGetUnitDefID(unitID)
		if not buildingRadius[unitDefID] then
			return
		end
		radius = buildingRadius[unitDefID] * 1.7 -- enlarge radius so it can gradually diminish in size more
		local px, _, pz = spGetUnitPosition(unitID)
		unitGrassRemovedHistory[unitID] = { px, pz, unitDefID, radius, multiplier or 1, 0 }
	end
	local params = unitGrassRemovedHistory[unitID]
	radius = params[4]
	unitGrassRemovedHistory[unitID][6] = params[6] + params[5]
	for x = params[1] - radius, params[1] + radius, grassConfig.patchResolution do
		if x >= 0 and x <= mapSizeX then
			for z = params[2] - radius, params[2] + radius, grassConfig.patchResolution do
				if z >= 0 and z <= mapSizeZ then
					if (x - params[1]) * (x - params[1]) + (z - params[2]) * (z - params[2]) < radius * radius then
						local vboOffset = world2grassmap(x, z) * grassInstanceVBOStep
						if vboOffset then
							local sizeMod = 1
								- (mathAbs(((x - params[1]) / radius)) + mathAbs(((z - params[2]) / radius))) / 2 -- sizemode in range 0...1
							sizeMod = (sizeMod * 2 - mathMin(0.25, radius / 120)) -- adjust sizemod so inner grass is gone fully and not just the very center dot
							sizeMod = (params[5] * sizeMod) -- apply multiplier to animate it over time
							updateGrassInstanceVBO(x, z, 1, 1 - sizeMod, vboOffset)
						end
					end
				end
			end
		end
	end
end

local function clearAllUnitGrass()
	local allUnits = spGetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		local unitDefID = spGetUnitDefID(unitID)
		if buildingRadius[unitDefID] then
			adjustUnitGrass(unitID)
		end
	end
end

local function clearGeothermalGrass()
	if WG.resource_spot_finder then
		local spots = WG.resource_spot_finder.geoSpotsList
		if spots then
			local maxValue = 15
			for i = 1, #spots do
				local spot = spots[i]
				adjustGrass(
					spot.x,
					spot.z,
					mathMax(96, mathMax((spot.maxZ - spot.minZ), (spot.maxX - spot.minX)) * 1.2),
					1
				)
			end
		end
	end
end

-- because not all maps have done this for us
local function clearMetalspotGrass()
	if WG.resource_spot_finder then
		local spots = WG.resource_spot_finder.metalSpotsList
		if spots then
			local maxValue = 15
			for i = 1, #spots do
				local spot = spots[i]
				local value = string.format("%0.1f", math.round(spot.worth / 1000, 1))
				if tonumber(value) > 0.001 and tonumber(value) < maxValue then
					adjustGrass(spot.x, spot.z, mathMax((spot.maxZ - spot.minZ), (spot.maxX - spot.minX)) * 1.2, 1)
				end
			end
		end
	end
end

function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam)
	if processChanges and not placementMode and buildingRadius[unitDefID] and not unitGrassRemovedHistory[unitID] then
		local isBuilding = Spring.GetUnitIsBeingBuilt(unitID)
		if isBuilding then
			removeUnitGrassQueue[unitID] = removeUnitGrassFrames
		else
			adjustUnitGrass(unitID)
		end
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	if processChanges and not placementMode and buildingRadius[unitDefID] and not unitGrassRemovedHistory[unitID] then
		removeUnitGrassQueue[unitID] = removeUnitGrassFrames
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	if processChanges and not placementMode and buildingRadius[unitDefID] then
		removeUnitGrassQueue[unitID] = nil
		unitGrassRemovedHistory[unitID] = nil
	end
end

function widget:GameFrame(gf)
	-- Scanning visible units allocates with unit count; adapt rate by camera height.
	if unitBendSSBO then
		local scanInterval = unitScanIntervalGF
		local cx, cy, cz = spGetCameraPosition()
		local gh = spGetGroundHeight(cx, cz) or 0
		local camHeight = cy - gh
		local fadeEnd = grassConfig.grassShaderParams.FADEEND * distanceMult
		if camHeight < fadeEnd * 0.33 then
			scanInterval = 1
		elseif camHeight < fadeEnd * 0.66 then
			scanInterval = 2
		end

		if gf >= nextUnitScanGF or scanInterval == 1 then
			nextUnitScanGF = gf + scanInterval
			scanUnitPositions(gf)
		end
	end

	if not processChanges then
		return
	end

	if not placementMode then
		for unitID, count in pairs(removeUnitGrassQueue) do
			if not unitGrassRemovedHistory[unitID] then
				adjustUnitGrass(unitID, 1 / count)
			else
				adjustUnitGrass(unitID)
			end
			count = count - 1
			removeUnitGrassQueue[unitID] = count
			if count <= 0 then
				removeUnitGrassQueue[unitID] = nil
			end
		end
	end

	-- check lava level and remove grass where lava is higher than ground
	if gf % lavaCheckInterval == 0 then
		local lavaLevel = Spring.GetGameRulesParam("lavaLevel")
		if lavaLevel and lavaLevel ~= -99999 and (not lastLavaLevel or lavaLevel > lastLavaLevel) then
			lastLavaLevel = lavaLevel
			if WG.grassgl4 and WG.grassgl4.removeGrassBelowHeight then
				WG.grassgl4.removeGrassBelowHeight(lavaLevel)
			end
		end
	end

	-- fake the commander spawn explosion
	if gf == 85 then
		local isCommander = {}
		for unitDefID, unitDef in pairs(UnitDefs) do
			if unitDef.customParams.iscommander then
				isCommander[unitDefID] = true
			end
		end
		local allUnits = spGetAllUnits()
		for _, unitID in pairs(allUnits) do
			if isCommander[Spring.GetUnitDefID(unitID)] then
				local x, _, z = spGetUnitPosition(unitID)
				adjustGrass(x, z, 90, 1)
			end
		end
	end
end

function widget:MousePress(x, y, button)
	if placementMode and not externalBrushActive then
		return true
	end
end

local firstUpdate = true
local shaderRebuildPending = false
local makeShaderVAO

local function clampNum(v, lo, hi)
	v = tonumber(v)
	if not v then
		return nil
	end
	if v < lo then
		return lo
	end
	if v > hi then
		return hi
	end
	return v
end

local function getGrassVisualConfig()
	local sp = grassConfig.grassShaderParams or {}
	return {
		mapColorFactor = tonumber(sp.MAPCOLORFACTOR) or 0.6,
		mapColorBase = tonumber(sp.MAPCOLORBASE) or 1.0,
		grassBrightness = tonumber(sp.GRASSBRIGHTNESS) or 1.0,
		grassBladeColorTex = grassConfig.grassBladeColorTex,
		mapGrassColorModTex = grassConfig.mapGrassColorModTex,
		grassWindPerturbTex = grassConfig.grassWindPerturbTex,
	}
end

local function setGrassVisualConfig(cfg)
	if type(cfg) ~= "table" then
		return false
	end
	local changed = false
	local sp = grassConfig.grassShaderParams or {}

	local mapColorFactor = clampNum(cfg.mapColorFactor, 0.0, 3.0)
	if mapColorFactor and sp.MAPCOLORFACTOR ~= mapColorFactor then
		sp.MAPCOLORFACTOR = mapColorFactor
		changed = true
	end

	local mapColorBase = clampNum(cfg.mapColorBase, 0.0, 3.0)
	if mapColorBase and sp.MAPCOLORBASE ~= mapColorBase then
		sp.MAPCOLORBASE = mapColorBase
		changed = true
	end

	local grassBrightness = clampNum(cfg.grassBrightness, 0.0, 4.0)
	if grassBrightness and sp.GRASSBRIGHTNESS ~= grassBrightness then
		sp.GRASSBRIGHTNESS = grassBrightness
		changed = true
	end

	if
		type(cfg.grassBladeColorTex) == "string"
		and cfg.grassBladeColorTex ~= ""
		and grassConfig.grassBladeColorTex ~= cfg.grassBladeColorTex
	then
		grassConfig.grassBladeColorTex = cfg.grassBladeColorTex
		changed = true
	end

	if
		type(cfg.mapGrassColorModTex) == "string"
		and cfg.mapGrassColorModTex ~= ""
		and grassConfig.mapGrassColorModTex ~= cfg.mapGrassColorModTex
	then
		grassConfig.mapGrassColorModTex = cfg.mapGrassColorModTex
		changed = true
	end

	if
		type(cfg.grassWindPerturbTex) == "string"
		and cfg.grassWindPerturbTex ~= ""
		and grassConfig.grassWindPerturbTex ~= cfg.grassWindPerturbTex
	then
		grassConfig.grassWindPerturbTex = cfg.grassWindPerturbTex
		changed = true
	end

	if changed then
		grassConfig.grassShaderParams = sp
		shaderRebuildPending = true
	end
	return changed
end

function widget:Update(dt)
	if shaderRebuildPending then
		makeShaderVAO()
		shaderRebuildPending = false
	end

	if not processChanges then
		return
	end

	if firstUpdate then
		firstUpdate = false
		clearGeothermalGrass() -- uses Spring.GetAllFeatures() which is empty at the time of widget:Initialize
	end

	if not placementMode then
		return
	end

	-- Process spawn grow animations (runs even when external brush is active)
	spawnAnimClock = os.clock()
	if spawnAnimCount > 0 then
		for elemIdx, anim in pairs(spawnAnims) do
			local elapsed = spawnAnimClock - anim.start
			local progress = elapsed / SPAWN_ANIM_DURATION
			local vboOffset = elemIdx * grassInstanceVBOStep
			if progress >= 1.0 then
				-- Animation complete: set final target size
				grassInstanceData[vboOffset + 4] = anim.target
				gCT[1] = grassInstanceData[vboOffset + 1]
				gCT[2] = grassInstanceData[vboOffset + 2]
				gCT[3] = grassInstanceData[vboOffset + 3]
				gCT[4] = anim.target
				grassInstanceVBO:Upload(gCT, 7, elemIdx)
				spawnAnims[elemIdx] = nil
				spawnAnimCount = spawnAnimCount - 1
			else
				-- Interpolate with elastic easing from previous size to target
				local factor = elasticOut(progress)
				local visualSize = anim.prev + (anim.target - anim.prev) * factor
				if visualSize < 0 then
					visualSize = 0
				end
				grassInstanceData[vboOffset + 4] = visualSize
				gCT[1] = grassInstanceData[vboOffset + 1]
				gCT[2] = grassInstanceData[vboOffset + 2]
				gCT[3] = grassInstanceData[vboOffset + 3]
				gCT[4] = visualSize
				grassInstanceVBO:Upload(gCT, 7, elemIdx)
			end
		end
	end

	if externalBrushActive then
		return
	end -- painting handled by external grass brush
	local mx, my, lp, mp, rp, offscreen = spGetMouseState()
	local _, coords = spTraceScreenRay(mx, my, true)
	if coords then
		mousepos = { coords[1], coords[2], coords[3] }
	else
		return
	end

	if not offscreen then
		if lp or rp then
			for x = coords[1] - cursorradius, coords[1] + cursorradius, grassConfig.patchResolution do
				for z = coords[3] - cursorradius, coords[3] + cursorradius, grassConfig.patchResolution do
					if
						(x - coords[1]) * (x - coords[1]) + (z - coords[3]) * (z - coords[3])
						< cursorradius * cursorradius
					then
						updateGrassInstanceVBO(x, z, 1, (lp and 1.025) or (rp and 0.975))
					end
				end
			end
		end
	end
end

local function MakeAndAttachToVAO()
	if grassVAO then
		grassVAO = nil
	end
	grassVAO = gl.GetVAO()

	if grassVAO == nil then
		goodbye("Failed to create grassVAO")
	end
	grassVAO:AttachVertexBuffer(grassPatchVBO)
	if grassPatchIndexVBO then
		grassVAO:AttachIndexBuffer(grassPatchIndexVBO)
	end
	grassVAO:AttachInstanceBuffer(grassInstanceVBO)
end

local function defineUploadGrassInstanceVBOData()
	grassInstanceVBO = nil
	grassInstanceVBO = gl.GetVBO(GL.ARRAY_BUFFER, true)
	if grassInstanceVBO == nil then
		goodbye("Failed to create grassInstanceVBO")
	end
	grassInstanceVBO:Define(
		mathMax(1, #grassInstanceData / grassInstanceVBOStep), --?we dont know how big yet!
		{
			{ id = 7, name = "instanceposrotscale", size = 4 }, -- a vec4 for pos + random rotation + scale
		}
	)
	grassInstanceVBOSize = #grassInstanceData
	if grassInstanceVBOSize > 0 then
		grassInstanceVBO:Upload(grassInstanceData)
	end
end

-- Builds grassInstanceData in tile-major order and fills the tileOffset/tileCount/tileWidth
-- metadata. sampleFn(gx, gz) returns the patch size for the patch at grid coords (gx, gz).
local function buildGrassTiles(cols, rows, sampleFn, jitter)
	grassInstanceData = {}
	tileOffset = {}
	tileCount = {}
	tileWidth = {}
	gridPatchCols = cols
	gridPatchRows = rows
	patchesPerTileX = mathMax(1, mathFloor(GRID_SIZE / patchResolution))
	patchesPerTileZ = patchesPerTileX
	gridCols = math.ceil(cols / patchesPerTileX)
	gridRows = math.ceil(rows / patchesPerTileZ)
	local offset = 0
	for tz = 0, gridRows - 1 do
		local gz0 = tz * patchesPerTileZ
		local tileH = mathMin(patchesPerTileZ, rows - gz0)
		for tx = 0, gridCols - 1 do
			local gx0 = tx * patchesPerTileX
			local tileW = mathMin(patchesPerTileX, cols - gx0)
			local tile = tz * gridCols + tx
			tileOffset[tile] = offset
			tileWidth[tile] = tileW
			for lz = 0, tileH - 1 do
				local gz = gz0 + lz
				local czw = (gz + 0.5) * patchResolution
				for lx = 0, tileW - 1 do
					local gx = gx0 + lx
					local cxw = (gx + 0.5) * patchResolution
					grassInstanceData[offset * 4 + 1] = cxw + (mathRandom() - 0.5) * patchResolution * jitter
					grassInstanceData[offset * 4 + 2] = mathRandom() * 6.28
					grassInstanceData[offset * 4 + 3] = czw + (mathRandom() - 0.5) * patchResolution * jitter
					grassInstanceData[offset * 4 + 4] = sampleFn(gx, gz)
					offset = offset + 1
				end
			end
			tileCount[tile] = offset - tileOffset[tile]
		end
	end
	grassPatchCount = offset
end

local function LoadGrassTGA(filename)
	local texture, loadfailed = BAR.Utilities.LoadTGA(filename)
	if loadfailed then
		spEcho("Grass: Failed to load image for grass:", filename, loadfailed)
		return nil
	end
	if texture.channels ~= 1 then
		spEcho("Loadgrass: only single channel .tga files are supported!")
		return nil
	end

	buildGrassTiles(texture.width, texture.height, function(gx, gz)
		return grassByteToPatchMult(texture[gz + 1][gx + 1])
	end, grassConfig.patchPlacementJitter)
	return true
end

local function makeGrassInstanceVBO()
	grassInstanceVBO = gl.GetVBO(GL.ARRAY_BUFFER, true)
	if grassInstanceVBO == nil then
		goodbye("No LuaVAO support")
	end

	grassInstanceData = {}
	-- upload image type if exists
	if grassConfig.grassDistTGA and grassConfig.grassDistTGA ~= "" then
		LoadGrassTGA(grassConfig.grassDistTGA)

		defineUploadGrassInstanceVBOData()
		MakeAndAttachToVAO()
	else -- try to load builtin grass type
		local mapprocessChanges = mapHasSMFGrass()
		--spEcho("mapHasSMFGrass",mapprocessChanges, placementMode)
		if (mapprocessChanges == 0 or mapprocessChanges == 255) and not placementMode then
			return nil
		end -- bail if none specified at all anywhere

		local cols = mathFloor(mapSizeX / patchResolution)
		local rows = mathFloor(mapSizeZ / patchResolution)
		local minSize = grassConfig.grassMinSize
		local sizeRange = grassConfig.grassMaxSize - grassConfig.grassMinSize
		buildGrassTiles(cols, rows, function(gx, gz)
			local localgrass = spGetGrass((gx + 0.5) * patchResolution, (gz + 0.5) * patchResolution)
			if localgrass <= 0 then
				return 0
			end
			if mapprocessChanges == 1 then
				return minSize + mathRandom() * sizeRange
			end
			return minSize + (localgrass / 254.0) * sizeRange
		end, 1 / 1.5)

		--spEcho("Grass: Drawing ",#grassInstanceData/grassInstanceVBOStep,"grass patches")
		grassInstanceVBOSize = #grassInstanceData
		defineUploadGrassInstanceVBOData()
		MakeAndAttachToVAO()
	end
end

local vsSrcPath = "LuaUI/Shaders/map_grass_gl4.vert.glsl"
local fsSrcPath = "LuaUI/Shaders/map_grass_gl4.frag.glsl"

makeShaderVAO = function()
	local shaderSourceCache = {
		vssrcpath = vsSrcPath,
		fssrcpath = fsSrcPath,
		shaderName = "GrassShaderGL4",
		uniformInt = {
			grassBladeColorTex = 0, -- rgb + alpha transp
			--grassBladeNormalTex = 1,-- xyz + specular factor
			mapGrassColorModTex = 1, -- minimap
			grassWindPerturbTex = 2, -- perlin
			shadowTex = 3, -- perlin
			losTex = 4, -- perlin
			heightmapTex = 5, -- perlin
		},
		uniformFloat = {
			grassuniforms = { 1, 1, 1, 1 },
			distanceMult = distanceMult,
			grassBladeScale = grassConfig.grassBladeScale,
			nightFactor = { 1, 1, 1, 1 },
		},
		shaderConfig = grassConfig.grassShaderParams,
		silent = true,
	}

	if grassConfig.grassShaderParams.UNITBENDENABLED == 1 then
		shaderSourceCache.uniformInt.unitBendCount = 0
	end

	grassShader = LuaShader.CheckShaderUpdates(shaderSourceCache)

	if not grassShader then
		goodbye("Failed to compile grassShader GL4 ")
	end
end

local weaponConf = {}
for i = 0, #WeaponDefs do
	local radius = WeaponDefs[i].damageAreaOfEffect * 1.2
	local edgeEffectiveness = WeaponDefs[i].edgeEffectiveness * 1.75
	if WeaponDefs[i].type == "DGun" then
		radius = radius * 2
		edgeEffectiveness = 4
	end
	if radius * edgeEffectiveness > 9 then
		weaponConf[i] = { radius, edgeEffectiveness }
	end
end

function widget:VisibleExplosion(px, py, pz, weaponID, ownerID)
	if not processChanges then
		return
	end
	if not placementMode and weaponConf[weaponID] ~= nil and py - 10 < spGetGroundHeight(px, pz) then
		adjustGrass(
			px,
			pz,
			weaponConf[weaponID][1],
			mathMin(1, (weaponConf[weaponID][1] * weaponConf[weaponID][2]) / 45)
		)
	end
end

local function placegrassCmd(_, _, params)
	placementMode = not placementMode
	processChanges = true
	spEcho("Grass placement mode toggle to:", placementMode)
end

local function savegrassCmd(_, _, params)
	if not params[1] then
		return
	end

	local filename = params[1]
	if string.len(filename) < 2 then
		filename = Game.mapName .. "_grassDist.tga"
	end
	spEcho("Savegrass: ", filename)

	texture = BAR.Utilities.NewTGA(
		mathFloor(mapSizeX / grassConfig.patchResolution),
		mathFloor(mapSizeZ / grassConfig.patchResolution),
		1
	)
	-- Instance buffer is tile-ordered; the on-disk TGA stays row-major for backward compatibility.
	for y = 1, texture.height do
		for x = 1, texture.width do
			local elem = world2grassmap((x - 0.5) * grassConfig.patchResolution, (y - 0.5) * grassConfig.patchResolution)
			texture[y][x] = grassPatchMultToByte((elem >= 0 and grassInstanceData[elem * 4 + 4]) or 0)
		end
	end
	-- Spring.Utilities.SaveTGA returns nil on success, error string on failure.
	local saveError = BAR.Utilities.SaveTGA(texture, filename)
	if saveError then
		spEcho("Saving grass map image failed", filename, saveError)
	end
end

local function exportGrassConfig(filename, opts)
	local function fmtVal(v)
		local t = type(v)
		if t == "number" then
			if v == mathFloor(v) then
				return tostring(v)
			end
			return string.format("%.4f", v)
		elseif t == "boolean" then
			return v and "true" or "false"
		end
		return string.format("%q", tostring(v))
	end

	local mapSafe = (Game.mapName or "unknown"):gsub("[^%w_%-]", "_")
	if not filename or #filename < 2 then
		local ts = os.date("%Y%m%d_%H%M%S")
		local dir = "Terraform Brush/GrassConfig/"
		Spring.CreateDir(dir)
		filename = dir .. mapSafe .. "_grassconfig_" .. ts .. ".lua"
	end

	local shader = grassConfig.grassShaderParams or {}
	local shaderKeys = {}
	for k, _ in pairs(shader) do
		shaderKeys[#shaderKeys + 1] = k
	end
	table.sort(shaderKeys)

	local out = {
		"-- Grass config export from Map Grass GL4",
		"-- Map: " .. (Game.mapName or "unknown"),
	}
	-- Project saves suppress the date comment: repeated saves of unchanged state
	-- must serialize identically (project files live in git).
	if not (opts and opts.nodate) then
		out[#out + 1] = "-- Date: " .. os.date("%Y-%m-%d %H:%M:%S")
	end
	local body = {
		"-- Paste mapinfo.custom = mapinfo.custom or {} and then mapinfo.custom.grassConfig = (this file table).custom.grassConfig",
		"return {",
		"\tcustom = {",
		"\t\tgrassConfig = {",
		"\t\t\t-- Density/placement",
		"\t\t\tpatchResolution = " .. fmtVal(grassConfig.patchResolution) .. ",",
		"\t\t\tpatchPlacementJitter = " .. fmtVal(grassConfig.patchPlacementJitter) .. ",",
		"\t\t\tpatchSize = " .. fmtVal(grassConfig.patchSize) .. ",",
		"\t\t\tgrassMinSize = " .. fmtVal(grassConfig.grassMinSize) .. ",",
		"\t\t\tgrassMaxSize = " .. fmtVal(grassConfig.grassMaxSize) .. ",",
		"",
		"\t\t\t-- Color/look",
		"\t\t\tgrassBladeColorTex = " .. fmtVal(grassConfig.grassBladeColorTex) .. ",",
		"\t\t\tmapGrassColorModTex = " .. fmtVal(grassConfig.mapGrassColorModTex) .. ",",
		"\t\t\tgrassWindPerturbTex = " .. fmtVal(grassConfig.grassWindPerturbTex) .. ",",
		"\t\t\tgrassWindMult = " .. fmtVal(grassConfig.grassWindMult) .. ",",
		"\t\t\tmaxWindSpeed = " .. fmtVal(grassConfig.maxWindSpeed) .. ",",
		"\t\t\tgrassDistTGA = " .. fmtVal(grassConfig.grassDistTGA) .. ",",
		"",
		"\t\t\tgrassShaderParams = {",
	}
	for i = 1, #body do
		out[#out + 1] = body[i]
	end

	for i = 1, #shaderKeys do
		local k = shaderKeys[i]
		out[#out + 1] = "\t\t\t\t" .. k .. " = " .. fmtVal(shader[k]) .. ","
	end

	out[#out + 1] = "\t\t\t},"
	out[#out + 1] = "\t\t},"
	out[#out + 1] = "\t},"
	out[#out + 1] = "}"
	out[#out + 1] = ""

	local f = io.open(filename, "w")
	if not f then
		spEcho("[Grass] ERROR: Could not write grass config to " .. tostring(filename))
		return false, filename
	end
	f:write(table.concat(out, "\n"))
	f:close()
	spEcho("[Grass] Saved grass config: " .. filename)
	return true, filename
end

local function savegrassconfigCmd(_, _, params)
	local filename = params and params[1]
	exportGrassConfig(filename)
end

local function loadgrassCmd(_, _, params)
	if not params[1] then
		return
	end

	placementMode = true
	local filename = params[1]
	if string.len(filename) < 2 then
		filename = Game.mapName .. "_grassDist.tga"
	end
	spEcho("Loadgrass: ", filename)

	LoadGrassTGA(filename)
	defineUploadGrassInstanceVBOData()
	MakeAndAttachToVAO()
	--grassVAO:AttachInstanceBuffer(grassInstanceVBO)
end

local function editgrassCmd(_, _, params)
	placementMode = true
	makeGrassInstanceVBO()
	defineUploadGrassInstanceVBOData()
	MakeAndAttachToVAO()
	--grassVAO:AttachInstanceBuffer(grassInstanceVBO)
end

local function cleargrassCmd(_, _, params)
	spEcho("Clearing grass")
	placementMode = true
	local cols = mathFloor(mapSizeX / patchResolution)
	local rows = mathFloor(mapSizeZ / patchResolution)
	buildGrassTiles(cols, rows, function()
		return 0
	end, 1 / 1.5)
	grassInstanceVBOSize = #grassInstanceData
	defineUploadGrassInstanceVBOData()
	MakeAndAttachToVAO()
	--grassVAO:AttachInstanceBuffer(grassInstanceVBO)
	spEcho("Cleared grass")
end

local function dumpgrassshadersCmd(_, _, params)
	spEcho(grassVertexShaderDebug)
	spEcho(grassFragmentShaderDebug)
	--grassVAO:AttachInstanceBuffer(grassInstanceVBO)
end

function widget:Initialize()
	if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end
	WG.grassgl4 = {}
	WG.grassgl4.getDistanceMult = function()
		return distanceMult
	end
	WG.grassgl4.setDistanceMult = function(value)
		distanceMult = value
	end
	WG.grassgl4.getUnitBendEnabled = function()
		return unitBendSSBO ~= nil
	end
	WG.grassgl4.removeGrass = function(wx, wz, radius)
		radius = radius or grassConfig.patchResolution
		for x = wx - radius, wx + radius, grassConfig.patchResolution do
			for z = wz - radius, wz + radius, grassConfig.patchResolution do
				if (x - wx) * (x - wx) + (z - wz) * (z - wz) < radius * radius then
					local sizeMod = 1 - (mathAbs(((x - wx) / radius)) + mathAbs(((z - wz) / radius))) / 2 -- sizemode in range 0...1
					sizeMod = (sizeMod * 2 - mathMin(0.66, radius / 100)) -- adjust sizemod so inner grass is gone fully and not just the very center dot
					updateGrassInstanceVBO(x, z, 1, 1 - sizeMod)
				end
			end
		end
	end
	WG.grassgl4.removeGrassBelowHeight = function(height)
		if #grassInstanceData == 0 then
			return nil
		end
		if not removedBelowHeight or height > removedBelowHeight then
			removedBelowHeight = height

			local patchResolution = grassConfig.patchResolution
			for gz = 0, gridPatchRows - 1 do
				for gx = 0, gridPatchCols - 1 do
					local wx = (gx + 0.5) * patchResolution
					local wz = (gz + 0.5) * patchResolution
					if spGetGroundHeight(wx, wz) <= height then
						local elem = world2grassmap(wx, wz)
						if elem >= 0 then
							grassInstanceData[elem * 4 + 4] = 0
						end
					end
				end
			end
			defineUploadGrassInstanceVBOData()
			MakeAndAttachToVAO()
		end
	end
	makeGrassPatchVBO(grassConfig.patchSize)
	makeGrassInstanceVBO()
	makeShaderVAO()

	-- Create unit bend SSBO after shader is ready
	if grassConfig.grassShaderParams.UNITBENDENABLED == 1 then
		unitBendSSBO = gl.GetVBO(GL.SHADER_STORAGE_BUFFER, false)
		if unitBendSSBO then
			unitBendSSBO:Define(MAX_BEND_UNITS, { { id = 0, name = "unitBendPositions", size = 4 } })
			unitBendSSBO:Upload(unitBendData)
		end
	end

	clearAllUnitGrass()
	clearMetalspotGrass()
	if Game.waterDamage > 0 then
		WG.grassgl4.removeGrassBelowHeight(20)
	end
	-- initial lava check
	local initLavaLevel = Spring.GetGameRulesParam("lavaLevel")
	if initLavaLevel and initLavaLevel ~= -99999 then
		lastLavaLevel = initLavaLevel
		WG.grassgl4.removeGrassBelowHeight(initLavaLevel)
	end
	-- Brush-aware grass painting for integration with Grass Brush tool
	WG.grassgl4.getConfig = function()
		return {
			patchResolution = grassConfig.patchResolution,
			grassMinSize = grassConfig.grassMinSize,
			grassMaxSize = grassConfig.grassMaxSize,
			mapSizeX = mapSizeX,
			mapSizeZ = mapSizeZ,
		}
	end
	WG.grassgl4.getDensityAt = function(wx, wz)
		local vboOffset = world2grassmap(wx, wz) * grassInstanceVBOStep
		if vboOffset < 0 or vboOffset >= #grassInstanceData then
			return 0
		end
		local size = grassInstanceData[vboOffset + 4]
		if not size or size <= 0 then
			return 0
		end
		return size / grassConfig.grassMaxSize
	end
	WG.grassgl4.setDensityAt = function(wx, wz, density, skipAnim)
		local vboOffset = world2grassmap(wx, wz) * grassInstanceVBOStep
		if vboOffset < 0 or vboOffset >= #grassInstanceData then
			return
		end
		local size = density * grassConfig.grassMaxSize
		if size < grassConfig.grassMinSize then
			size = 0
		end
		local oldSize = grassInstanceData[vboOffset + 4] or 0
		local oldpx = grassInstanceData[vboOffset + 1]
		local oldry = grassInstanceData[vboOffset + 2]
		local oldpz = grassInstanceData[vboOffset + 3]

		-- Register spawn grow animation when density increases
		local elemIdx = vboOffset / grassInstanceVBOStep
		if not skipAnim and externalBrushActive and size > oldSize and size > 0 then
			if spawnAnimCount < SPAWN_ANIM_MAX then
				if not spawnAnims[elemIdx] then
					spawnAnimCount = spawnAnimCount + 1
				end
				spawnAnims[elemIdx] = {
					target = size,
					start = spawnAnimClock,
					prev = oldSize,
				}
			end
			-- Set initial visual size (start small, animation will grow it)
			local initSize = oldSize
			grassInstanceData[vboOffset + 4] = initSize
			gCT[1], gCT[2], gCT[3], gCT[4] = oldpx, oldry, oldpz, initSize
			grassInstanceVBO:Upload(gCT, 7, elemIdx)
		else
			-- No animation: immediate set
			if spawnAnims[elemIdx] then
				spawnAnims[elemIdx] = nil
				spawnAnimCount = spawnAnimCount - 1
			end
			grassInstanceData[vboOffset + 4] = size
			gCT[1], gCT[2], gCT[3], gCT[4] = oldpx, oldry, oldpz, size
			grassInstanceVBO:Upload(gCT, 7, elemIdx)
		end
	end
	WG.grassgl4.enableEditMode = function()
		if not placementMode then
			placementMode = true
			processChanges = true
			if #grassInstanceData == 0 then
				makeGrassInstanceVBO()
			else
				defineUploadGrassInstanceVBOData()
				MakeAndAttachToVAO()
			end
		end
	end
	WG.grassgl4.disableEditMode = function()
		placementMode = false
		externalBrushActive = false
	end
	WG.grassgl4.isEditMode = function()
		return placementMode
	end
	WG.grassgl4.setExternalBrush = function(active)
		externalBrushActive = active and true or false
		if not active then
			-- Flush all pending spawn animations to final values
			for elemIdx, anim in pairs(spawnAnims) do
				local vboOffset = elemIdx * grassInstanceVBOStep
				grassInstanceData[vboOffset + 4] = anim.target
				gCT[1] = grassInstanceData[vboOffset + 1]
				gCT[2] = grassInstanceData[vboOffset + 2]
				gCT[3] = grassInstanceData[vboOffset + 3]
				gCT[4] = anim.target
				grassInstanceVBO:Upload(gCT, 7, elemIdx)
			end
			spawnAnims = {}
			spawnAnimCount = 0
		end
	end
	WG.grassgl4.hasGrass = function()
		return #grassInstanceData > 0
	end
	WG.grassgl4.saveGrassTGA = function(filename)
		if not filename or #filename < 2 then
			filename = Game.mapName .. "_grassDist.tga"
		end
		local texture = BAR.Utilities.NewTGA(
			mathFloor(mapSizeX / grassConfig.patchResolution),
			mathFloor(mapSizeZ / grassConfig.patchResolution),
			1
		)
		-- Instance buffer is tile-ordered; the on-disk TGA stays row-major for backward compatibility.
		for y = 1, texture.height do
			for x = 1, texture.width do
				local elem = world2grassmap((x - 0.5) * grassConfig.patchResolution, (y - 0.5) * grassConfig.patchResolution)
				texture[y][x] = grassPatchMultToByte((elem >= 0 and grassInstanceData[elem * 4 + 4]) or 0)
			end
		end
		-- Spring.Utilities.SaveTGA returns nil on success, error string on failure.
		local saveError = BAR.Utilities.SaveTGA(texture, filename)
		if saveError then
			spEcho("[Grass] Failed to save grass map: " .. filename .. " (" .. tostring(saveError) .. ")")
			return false
		end
		spEcho("[Grass] Saved grass map: " .. filename)
		return true
	end
	WG.grassgl4.saveGrassConfig = function(filename, opts)
		local ok = exportGrassConfig(filename, opts)
		return ok
	end
	WG.grassgl4.getVisualConfig = function()
		return getGrassVisualConfig()
	end
	WG.grassgl4.setVisualConfig = function(cfg)
		return setGrassVisualConfig(cfg)
	end
	WG.grassgl4.loadGrass = function(filename)
		if not filename or #filename < 2 then
			filename = Game.mapName .. "_grassDist.tga"
		end
		placementMode = true
		local ok = LoadGrassTGA(filename)
		if not ok then
			return
		end
		defineUploadGrassInstanceVBOData()
		MakeAndAttachToVAO()
	end
	WG.grassgl4.clearGrass = function()
		cleargrassCmd(nil, nil, {})
	end

	processChanges = next(grassInstanceData) ~= nil

	widgetHandler:AddAction("placegrass", placegrassCmd, nil, "t")
	widgetHandler:AddAction("savegrass", savegrassCmd, nil, "t")
	widgetHandler:AddAction("loadgrass", loadgrassCmd, nil, "t")
	widgetHandler:AddAction("editgrass", editgrassCmd, nil, "t")
	widgetHandler:AddAction("cleargrass", cleargrassCmd, nil, "t")
	widgetHandler:AddAction("savegrassconfig", savegrassconfigCmd, nil, "t")
	widgetHandler:AddAction("dumpgrassshaders", dumpgrassshadersCmd, nil, "t")
end

function widget:GadgetRemoveGrass(posx, posz, radius)
	if WG.grassgl4 then
		WG.grassgl4.removeGrass(posx, posz, radius)
	end
end

function widget:Shutdown()
	if unitBendSSBO then
		unitBendSSBO = nil
	end

	widgetHandler:RemoveAction("placegrass")
	widgetHandler:RemoveAction("savegrass")
	widgetHandler:RemoveAction("loadgrass")
	widgetHandler:RemoveAction("editgrass")
	widgetHandler:RemoveAction("cleargrass")
	widgetHandler:RemoveAction("savegrassconfig")
	widgetHandler:RemoveAction("dumpgrassshaders")
end

function widget:SetConfigData(data)
	if data.distanceMult ~= nil then
		distanceMult = data.distanceMult
	end
end

function widget:GetConfigData()
	return {
		distanceMult = distanceMult,
	}
end

local function getWindSpeed()
	windDirX, _, windDirZ, _ = Spring.GetWind()
	-- cap windspeed while preserving direction
	if windDirX > grassConfig.maxWindSpeed and windDirX > windDirZ then
		windDirZ = (windDirZ / windDirX) * grassConfig.maxWindSpeed
		windDirX = grassConfig.maxWindSpeed
	elseif windDirZ > grassConfig.maxWindSpeed and windDirZ > windDirX then
		windDirX = (windDirX / windDirZ) * grassConfig.maxWindSpeed
		windDirZ = grassConfig.maxWindSpeed
	end
end

local glTexture = gl.Texture

local smoothGrassFadeExp = 1

function widget:DrawWorldPreUnit()
	if not processChanges then
		return
	end
	if #grassInstanceData == 0 then
		return
	end
	local mapDrawMode = Spring.GetMapDrawMode()
	if mapDrawMode ~= "normal" and mapDrawMode ~= "los" then
		return
	end
	if placementMode and not externalBrushActive then
		--spEcho("circle",mousepos[1],mousepos[2]+10,mousepos[3])
		gl.LineWidth(2)
		gl.Color(0.3, 1.0, 0.2, 0.75)
		gl.DrawGroundCircle(mousepos[1], mousepos[2] + 10, mousepos[3], cursorradius, 16)
	end
	local newGameSeconds = os.clock()
	local timePassed = newGameSeconds - oldGameSeconds
	oldGameSeconds = newGameSeconds

	local cx, cy, cz = spGetCameraPosition()
	local gh = (Spring.GetGroundHeight(cx, cz) or 0)

	local fadeEnd = grassConfig.grassShaderParams.FADEEND * distanceMult
	local fadeStart = grassConfig.grassShaderParams.FADESTART * distanceMult
	local camHeight = cy - gh
	local globalgrassfade = math.clamp((fadeEnd - camHeight) / (fadeEnd - fadeStart), 0, 1)

	local expFactor = mathMin(1.0, 3 * timePassed) -- ADJUST THE TEMPORAL FACTOR OF 3
	smoothGrassFadeExp = smoothGrassFadeExp * (1.0 - expFactor) + globalgrassfade * expFactor

	local grassDataLen = #grassInstanceData
	if camHeight < fadeEnd and grassVAO ~= nil and grassDataLen > 0 then
		local _, _, isPaused = Spring.GetGameSpeed()
		if not isPaused then
			getWindSpeed()
			offsetX = offsetX - ((windDirX * grassConfig.grassWindMult) * timePassed)
			offsetZ = offsetZ - ((windDirZ * grassConfig.grassWindMult) * timePassed)
		end

		gl.DepthTest(GL.LEQUAL)
		gl.DepthMask(true)
		gl.Culling(GL.BACK) -- needs better front and back instead of using this

		glTexture(0, grassConfig.grassBladeColorTex)
		glTexture(1, grassConfig.mapGrassColorModTex)
		glTexture(2, grassConfig.grassWindPerturbTex)
		glTexture(3, "$shadow")
		glTexture(4, "$info")
		glTexture(5, "$heightmap")

		-- Bind unit bending SSBO
		if unitBendSSBO then
			updateUnitBendSSBO()
			unitBendSSBO:BindBufferRange(6)
		end

		grassShader:Activate()
		--spEcho("globalgrassfade",globalgrassfade)
		local windStrength = mathMin(grassConfig.maxWindSpeed, mathMax(4.0, mathAbs(windDirX) + mathAbs(windDirZ)))
		grassShader:SetUniform("grassuniforms", offsetX, offsetZ, windStrength, smoothGrassFadeExp)
		grassShader:SetUniform("distanceMult", distanceMult)
		grassShader:SetUniform("nightFactor", nightFactor[1], nightFactor[2], nightFactor[3], nightFactor[4])
		if unitBendSSBO then
			grassShader:SetUniformInt("unitBendCount", unitBendCount)
		end

		-- Draw only the contiguous instance ranges of tiles inside the view frustum.
		-- Consecutive visible tiles in a row share a contiguous buffer range, so merge them into one call.
		local tileWorldX = patchesPerTileX * patchResolution
		local tileWorldZ = patchesPerTileZ * patchResolution
		local halfX = tileWorldX * 0.5
		local halfZ = tileWorldZ * 0.5
		local tileRadius = math.sqrt(halfX * halfX + halfZ * halfZ) + tileHeightSlack
		local fadeBound = fadeEnd + tileRadius
		local fadeCullSq = fadeBound * fadeBound
		local spIsSphereInView = Spring.IsSphereInView
		local drawnInstances = 0
		local visibleCount = 0
		-- Only tile centers inside the fade circle can pass the distance test, so bound the
		-- sweep to the circle's bounding box instead of scanning the whole grid (full grid
		-- in placement mode; the loops simply don't run when the box misses the map).
		local tx0, tx1, tz0, tz1
		if placementMode then
			tx0, tx1, tz0, tz1 = 0, gridCols - 1, 0, gridRows - 1
		else
			local minTx = mathFloor((cx - fadeBound) / tileWorldX)
			local maxTx = mathFloor((cx + fadeBound) / tileWorldX)
			local minTz = mathFloor((cz - fadeBound) / tileWorldZ)
			local maxTz = mathFloor((cz + fadeBound) / tileWorldZ)
			tx0, tx1 = mathMax(0, minTx), mathMin(gridCols - 1, maxTx)
			tz0, tz1 = mathMax(0, minTz), mathMin(gridRows - 1, maxTz)
		end
		for tz = tz0, tz1 do
			local czw = tz * tileWorldZ + halfZ
			local ddz = czw - cz
			local runStart, runCount = -1, 0
			for tx = tx0, tx1 do
				local tile = tz * gridCols + tx
				local count = tileCount[tile]
				local visible = false
				if count and count > 0 then
					if placementMode then
						visible = true
					else
						local cxw = tx * tileWorldX + halfX
						local ddx = cxw - cx
						if ddx * ddx + ddz * ddz < fadeCullSq
							and spIsSphereInView(cxw, tileMidHeight, czw, tileRadius)
						then
							visible = true
						end
					end
				end
				if visible then
					visibleCount = visibleCount + 1
					if runStart < 0 then
						runStart = tileOffset[tile]
						runCount = count
					else
						runCount = runCount + count
					end
				elseif runStart >= 0 then
					grassVAO:DrawElements(GL.TRIANGLES, grassPatchVBOsize, 0, runCount, 0, runStart)
					drawnInstances = drawnInstances + runCount
					runStart, runCount = -1, 0
				end
			end
			if runStart >= 0 then
				grassVAO:DrawElements(GL.TRIANGLES, grassPatchVBOsize, 0, runCount, 0, runStart)
				drawnInstances = drawnInstances + runCount
			end
		end

		if placementMode and Spring.GetGameFrame() % 30 == 0 then
			spEcho("Drawing", drawnInstances, "grass patches")
		end
		grassShader:Deactivate()

		if unitBendSSBO then
			unitBendSSBO:UnbindBufferRange(6)
		end
		tracy.LuaTracyPlot("GrassDrawnInstances", drawnInstances)
		tracy.LuaTracyPlot("GrassVisibleTiles", visibleCount)

		glTexture(0, false)
		glTexture(1, false)
		glTexture(2, false)
		glTexture(3, false)
		glTexture(4, false)
		glTexture(5, false)

		gl.DepthTest(GL.ALWAYS)
		gl.DepthMask(false)
		gl.Culling(GL.BACK)
	end
end

local function NightFactorChanged(red, green, blue, shadow, altitude)
	local altitudefactor = 1.0 --+ (1.0 - altitude) * 0.5
	nightFactor[1] = red * altitudefactor
	nightFactor[2] = green * altitudefactor
	nightFactor[3] = blue * altitudefactor
	nightFactor[4] = shadow
end

function widget:NightFactorChanged(red, green, blue, shadow, altitude)
	NightFactorChanged(red, green, blue, shadow, altitude)
end

-- ahahahah you cant stop me:
--[[

import sys

normals_up = True
if len(sys.argv) <2:
	sys.argv.append("tovbo.obj")

objdata = {'vn' : [], 'vt' : [], 'v' : []}
numverts = 0

outfile = open(sys.argv[1]+'.lua','w')
outfile.write("""local VBOLayout= {  {id = 0, name = "position", size = 3},
      {id = 1, name = "normal", size = 3},
      {id = 2, name = "stangent", size = 3},
      {id = 3, name = "ttangent", size = 3},
      {id = 4, name = "texcoords0", size = 2},
      {id = 5, name = "texcoords1", size = 2},
      {id = 6, name = "pieceindex", size = 1},} --khm, this should be unsigned int
local VBOData = { """)

def listoffloats_to_line(lof):
	return '\t' + ','.join("0" if f == 0 else '%.4f'%f for f in lof) + ',\n'

for objline in open(sys.argv[1]).readlines():
	objitems = objline.strip().split()
	if objitems[0] in objdata:
		objdata[objitems[0] ].append(list(map(float,objitems[1:])))
	if objitems[0] == 'f':
		for objitem in objitems[1:4]:
			vi, vti, vni = tuple(map(int,objitem.split('/')))
			if normals_up:
				vn = [0,1,0]
			else:
				vn = objdata['vn'][vni-1]
			outfile.write(listoffloats_to_line(objdata['v'][vi-1] + vn + [0,0,0] + [0,0,0] + objdata['vt'][vti-1][0:2] + [0,0] + [0]))
			numverts += 1

outfile.write('\n}\nlocal numVerts = %d\n'%numverts)
outfile.close()

]]
--
