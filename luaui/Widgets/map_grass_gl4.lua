local isPotatoGpu = false
local gpuMem = (Platform.gpuMemorySize and Platform.gpuMemorySize or 1000) / 1000
if Platform ~= nil and Platform.gpuVendor == 'Intel' then
	isPotatoGpu = true
end
if gpuMem and gpuMem > 0 and gpuMem < 1800 then
	isPotatoGpu = true
end

local widget = widget ---@type Widget

function widget:GetInfo()
  return {
    name      = "Map Grass GL4",
    version   = "1.0",
    desc      = "Instanced rendering of custom grass",
    author    = "Beherith (mysterme@gmail.com)",
    date      = "2021.04.12",
    license   = "GNU GPL, v2",
    layer     = -999999,
    enabled   = not isPotatoGpu,
  }
end

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
  grassMinSize = 0.3; --Size for grassmap value of 1 , min and max should be equal for old style binary grassmap (because its only 0,1)
  grassMaxSize = 1.7; -- Size for grassmap value of 254
  grassShaderParams = { -- allcaps because thats how i know
    MAPCOLORFACTOR = 0.6, -- how much effect the minimapcolor has
    MAPCOLORBASE = 1.0,     --how much more to blend the bottom of the grass patches into map color
    ALPHATHRESHOLD = 0.01,--alpha limit under which to discard a fragment
    WINDSTRENGTH = 0.1,	  -- how much the wind will blow the grass
    WINDSCALE = 0.33, -- how fast the wind texture moves
    WINDSAMPLESCALE = 0.001, -- tiling resolution of the noise texture
    FADESTART = 5000,-- distance at which grass starts to fade
    FADEEND = 8000,--distance at which grass completely fades out
    SHADOWFACTOR = 0.25, -- how much shadowed grass gets darkened, lower values mean more shadows
    HASSHADOWS = 1, -- 0 for disable, no real difference in this (does not work yet)
	GRASSBRIGHTNESS = 1.0; -- this is for future dark mode
  },
  grassBladeColorTex = "LuaUI/Images/luagrass/grass_field_medit_flowering.dds.cached.dds", -- rgb + alpha transp
  mapGrassColorModTex = "$grass", -- by default this means that grass will be colorized with the minimap
  grassWindPerturbTex = "bitmaps/Lups/perlin_noise.jpg", -- rgba of various frequencies of perlin noise?
  grassWindMult = 4.5, -- how 'strong' the perturbation effect is
  maxWindSpeed = 20, -- the fastest the wind noise texture will ever move,
  -- The grassdisttex overrides the default map grass, if specified!
  grassDistTGA = "", -- MUST BE 8 bit uncompressed TGA, sized Game.mapSize* / patchResolution, where 0 is no grass, and 1<= controls grass size.
}

local nightFactor = {1,1,1,1}

local distanceMult = 0.4 

--------------------------------------------------------------------------------
-- map custom config
-- if map has a custom mapinfo.lua configuration, then merge the keys of it with our config table

local success, mapcfg = pcall(VFS.Include,"mapinfo.lua") -- load mapinfo.lua confs
if not success then
  Spring.Echo("Map Grass GL4 failed to find a mapinfo.lua, using default configs")
else
  if mapcfg and mapcfg.custom and mapcfg.custom.grassconfig then
	Spring.Echo("Loading LuaGrass custom parameters from mapinfo.lua")
    for k,v in pairs(mapcfg.custom.grassconfig) do

      for kUp, _ in pairs(grassConfig) do
		if k == string.lower(kUp) then k = kUp end
	  end
	--Spring.Echo("Found grass params",k,v)

      if string.lower(k) == "grassshaderparams" then
        for k2,v2 in pairs(v) do
			for k2Up, _ in pairs(grassConfig.grassShaderParams) do
				--Spring.Echo("Found grass params",k2,k2Up,v2)
				if k2 == string.lower(k2Up) then k2 = k2Up end
			end
          grassConfig[k][k2]=v2
        end
      else
        grassConfig[k] = v
      end
    end
  end
end
Spring.Echo("Map is",Game.mapName)

-----------------------Old Map Overrides-------------------
local mapoverrides  = {
  ["DSDR 4.0"] = {
    --grassDistTGA = "DSDR 4.0_grassDist.tga",
    grassMaxSize = 2.0	; -- Size for grassmap value of 254
    grassShaderParams = {
        MAPCOLORFACTOR = 0.6,
     },
  },
  ["DeltaSiegeDry"] = {
    patchResolution = 32,
    grassShaderParams = {
        MAPCOLORFACTOR = 0.6,
		SHADOWFACTOR = 0.001,
     },
  },
  ["Pentos_V1"] = {
    patchResolution = 32,
    grassShaderParams = {
        MAPCOLORFACTOR = 0.6,
     },

  },
  ["Taldarim_V3"] = {
    patchResolution = 32,
    grassShaderParams = {
        MAPCOLORFACTOR = 0.5,
     },
     grassDistTGA = "LuaUI/Images/luagrass/Taldarim_V3_grassDist.tga",
  },
  ["Altair_Crossing_V4"] = {
    patchResolution = 32,
	grassMinSize = 0.5; --Size for grassmap value of 1 , min and max should be equal for old style binary grassmap (because its only 0,1)
    grassMaxSize = 2.0; -- Size for grassmap value of 254
    grassShaderParams = {
        MAPCOLORFACTOR = -1.2,
     },

  },
}

if mapoverrides[Game.mapName] then
  Spring.Echo("Overriding map grass")
  for k,v in pairs(mapoverrides[Game.mapName]) do
    if k == "grassShaderParams" then
      for k2,v2 in pairs(v) do
        grassConfig[k][k2]=v2
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

local processChanges = false	-- auto enabled when map has grass or editmode toggles

local mousepos = {0,0,0}
local cursorradius = 50
local removeUnitGrassFrames = 25
local placementMode = false -- this controls wether we are in 'game mode' or placement map dev mode
include("keysym.h.lua") -- so we can do hacky keypress
local grassInstanceData = {}
---------------------------VAO VBO stuff:---------------------------------------

local grassPatchVBO = nil
local grassPatchVBOsize = 0
local grassInstanceVBO = nil
local grassInstanceVBOSize = nil
local grassInstanceVBOStep = 4 -- 4 values per patch
local grassVAO = nil
local grassShader = nil
local grassVertexShaderDebug = ""
local grassFragmentShaderDebug = ""
local grassPatchCount = 0

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable

local grassRowInstance = {0} -- a table of row, instanceidx from top side of the view

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

local function goodbye(reason)
  Spring.Echo("Map Grass GL4 widget exiting with reason: "..reason)
  if grassPatchVBO then grassPatchVBO = nil end
  if grassInstanceVBO then grassInstanceVBO = nil end
  if grassVAO then grassVAO = nil end
  --if grassShader then grassShader:Finalize() end
  widgetHandler:RemoveWidget()
end
--------------------------------------------------------------------------------
-- using: http://ogldev.atspace.co.uk/www/tutorial33/tutorial33.html
local function makeGrassPatchVBO(grassPatchSize) -- grassPatchSize = 1|4, see the commented out python section at the bottom to make a custom vbo
	grassPatchVBO = gl.GetVBO(GL.ARRAY_BUFFER,true)
	if grassPatchVBO == nil then goodbye("No LuaVAO support") end

	local VBOLayout= {  {id = 0, name = "position", size = 3},
	  {id = 1, name = "normal", size = 3},
	  {id = 2, name = "stangent", size = 3},
	  {id = 3, name = "ttangent", size = 3},
	  {id = 4, name = "texcoords0", size = 2},
	  {id = 5, name = "texcoords1", size = 2},
	  {id = 6, name = "pieceindex", size = 1},} --khm, this should be unsigned int

	local VBOData = VFS.Include("LuaUI/Include/grassPatches.lua")

	if grassPatchSize == 1 then
		grassPatchVBOsize = 36
		VBOData = VBOData[1]

	elseif grassPatchSize == 4 then
		grassPatchVBOsize = 144
		VBOData = VBOData[4]
	end

	grassPatchVBO:Define(
		grassPatchVBOsize, -- 3 verts, just a triangle for now
		VBOLayout -- 17 floats per vertex
	)
	--Spring.Echo("VBODATA #", grassPatchSize, #VBOData)

	grassPatchVBO:Upload(VBOData)
end

local function fsrand(a,b) -- fast, repeatable random vec2
  local s = math.sin((a*12.9898 + b*78.233))
  return math.fract(s* 43758.5453),  math.fract(s* 41758.5453)
end

local function testForGrass(mx, mz)
  if grassConfig.obeyGrassMap then
    if (spGetGrass(mx,mz) == 1) then
      return spGetGroundHeight(mx,mz)
    else
      return nil
    end
  else
    local gx, gy, gz, gs = Spring.GetGroundNormal (mx,mz )
    local gh = spGetGroundHeight(mx,mz)
    if (gh > grassConfig.grassMinHeight) and
      (gh < grassConfig.grassMaxHeight) and
      (gy >  grassConfig.grassMaxSlope) then
       return gh
    else
      return nil
    end
  end
end


local function mapHasSMFGrass() -- returns 255 is SMF has no grass, 0 if map has no grass, 1 if map has old style binary grass, 2<=  <=254 if map has new style uint grass
  local highestgrassmapvalue = 0
  local patchResolution = 32

  for x = patchResolution  / 2, mapSizeX, patchResolution do
    for z = patchResolution / 2, mapSizeZ, patchResolution do
	local localgrass = spGetGrass(x,z)
      if (localgrass == 255)  then
		return 255
		else
		highestgrassmapvalue = math.max(highestgrassmapvalue, localgrass)
		end
    end
  end
  return highestgrassmapvalue
end

local function grassByteToPatchMult(grassbyte) -- coverts grassmap byte to size multiplier for instancebuffer
	if grassbyte == 0 then return 0 end
	return (grassConfig.grassMinSize + (grassConfig.grassMaxSize - grassConfig.grassMinSize) * (grassbyte/254.0) )
end

local function grassPatchMultToByte(grasspatchsize) -- converts instancebuffer size to grassmap byte
	if grasspatchsize < grassConfig.grassMinSize then return 0 end
	local grassbyte = (grasspatchsize - grassConfig.grassMinSize)
	grassbyte = grassbyte / (grassConfig.grassMaxSize - grassConfig.grassMinSize) *254.0
	return math.clamp(grassbyte, 1, 254)
end

local function world2grassmap(wx, wz) -- returns an index into the elements of a vbo
	local gx = math.floor(wx / grassConfig.patchResolution)
	local gz = math.floor(wz / grassConfig.patchResolution)
	local cols = math.floor(mapSizeX / grassConfig.patchResolution)
	--Spring.Echo(gx, gz, cols)
	local index =  (gz*cols + gx)
	if index <= 1 then return 0 end
	return index
end

local gCT = {} -- Grass Cache Table
local function updateGrassInstanceVBO(wx, wz, size, sizemod, vboOffset)
	-- we are assuming that we can do this
	--Spring.Echo(wx, wz, sizemod)
	local vboOffset = vboOffset or world2grassmap(wx,wz) * grassInstanceVBOStep
	if vboOffset<0 or vboOffset >= #grassInstanceData then	-- top left of map gets vboOffset: 0
		--Spring.Echo(boOffset > #grassInstanceData",vboOffset,#grassInstanceData, " you probably need to /editgrass")
		return
	end

	local oldsize = grassInstanceData[vboOffset + 4]
	if (not oldsize or oldsize <= 0) and not placementMode then return end

	local oldpx = grassInstanceData[vboOffset + 1] -- We must read all instance params, because we need to write them all at once
	local oldry = grassInstanceData[vboOffset + 2]
	local oldpz = grassInstanceData[vboOffset + 3]

	if sizemod then size = math.min(grassConfig.grassMaxSize, oldsize * sizemod) end

	local shift = false
	if placementMode then
		_, _, _, shift = Spring.GetModKeyState()
	end
	if sizemod < 1 then
		if size < grassConfig.grassMinSize or shift then size = 0 end
	else
		if shift then
			size = grassConfig.grassMaxSize
		else
			size = math.max(grassConfig.grassMinSize,size)
		end
	end
	grassInstanceData[vboOffset + 4] = size
	--Spring.Echo("updateGrassInstanceVBO:",oldpx, "x", wx, oldpz ,"z", wz, oldsize, "s", size)
	--size_t LuaVBOImpl::Upload(const sol::stack_table& luaTblData, const sol::optional<int> attribIdxOpt, const sol::optional<int> elemOffsetOpt, const sol::optional<int> luastartInstanceIndexndexOpt, const sol::optional<int> luaFinishIndexOpt)
	gCT[1], gCT[2], gCT[3], gCT[4] = oldpx, oldry, oldpz, size
	grassInstanceVBO:Upload(gCT, 7, vboOffset/4) -- We _must_ upload whole instance params at once
end

function widget:KeyPress(key, modifier, isRepeat)
	if not placementMode then return false end
	if key == KEYSYMS.LEFTBRACKET then cursorradius = math.max(8, cursorradius *0.8) end
	if key == KEYSYMS.RIGHTBRACKET then cursorradius = math.min(512, cursorradius *1.2) end
	return false
end

local function adjustGrass(px, pz, radius, multiplier)
	--local params = {math.floor(px),math.floor(pz)}
	px, pz = math.floor(px), math.floor(pz)
	for x = px - radius, px + radius, grassConfig.patchResolution do
		if x >= 0 and x <= mapSizeX then
			for z = pz - radius, pz + radius, grassConfig.patchResolution do
				if z >= 0 and z <= mapSizeZ then
					if (x-px)*(x-px) + (z-pz)*(z-pz) < radius*radius then
						local vboOffset = world2grassmap(x,z) * grassInstanceVBOStep
						if vboOffset then
							local sizeMod = 1-(math.abs(((x-px)/radius)) + math.abs(((z-pz)/radius))) / 2	-- sizemode in range 0...1
							sizeMod = (sizeMod*2-math.min(0.66, radius/100))	-- adjust sizemod so inner grass is gone fully and not just the very center dot
							sizeMod = sizeMod*multiplier	-- apply multiplier to animate it over time
							updateGrassInstanceVBO(x,z, 1, 1-sizeMod, vboOffset)
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
		radius = buildingRadius[unitDefID]*1.7	-- enlarge radius so it can gradually diminish in size more
		local px,_,pz = Spring.GetUnitPosition(unitID)
		unitGrassRemovedHistory[unitID] = {px, pz, unitDefID, radius, multiplier or 1, 0}
	end
	local params = unitGrassRemovedHistory[unitID]
	radius = params[4]
	unitGrassRemovedHistory[unitID][6] = params[6] + params[5]
	for x = params[1] - radius, params[1] + radius, grassConfig.patchResolution do
		if x >= 0 and x <= mapSizeX then
			for z = params[2] - radius, params[2] + radius, grassConfig.patchResolution do
				if z >= 0 and z <= mapSizeZ then
					if (x-params[1])*(x-params[1]) + (z-params[2])*(z-params[2]) < radius*radius then
						local vboOffset = world2grassmap(x,z) * grassInstanceVBOStep
						if vboOffset then
							local sizeMod = 1-(math.abs(((x-params[1])/radius)) + math.abs(((z-params[2])/radius))) / 2	-- sizemode in range 0...1
							sizeMod = (sizeMod*2-math.min(0.25, radius/120))	-- adjust sizemod so inner grass is gone fully and not just the very center dot
							sizeMod = (params[5]*sizeMod)	-- apply multiplier to animate it over time
							updateGrassInstanceVBO(x,z, 1, 1-sizeMod, vboOffset)
						end
					end
				end
			end
		end
	end
end

local function clearAllUnitGrass()
	local allUnits = Spring.GetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		local unitDefID = spGetUnitDefID(unitID)
		if buildingRadius[unitDefID] then
			adjustUnitGrass(unitID)
		end
	end
end

local function clearGeothermalGrass()
	if WG['resource_spot_finder'] then
		local spots = WG['resource_spot_finder'].geoSpotsList
		if spots then
			local maxValue = 15
			for i = 1, #spots do
				local spot = spots[i]
				adjustGrass(spot.x, spot.z, math.max(96, math.max((spot.maxZ-spot.minZ), (spot.maxX-spot.minX))*1.2), 1)
			end
		end
	end
end

-- because not all maps have done this for us
local function clearMetalspotGrass()
	if WG['resource_spot_finder'] then
		local spots = WG['resource_spot_finder'].metalSpotsList
		if spots then
			local maxValue = 15
			for i = 1, #spots do
				local spot = spots[i]
				local value = string.format("%0.1f",math.round(spot.worth/1000,1))
				if tonumber(value) > 0.001 and tonumber(value) < maxValue then
					adjustGrass(spot.x, spot.z, math.max((spot.maxZ-spot.minZ), (spot.maxX-spot.minX))*1.2, 1)
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
	if not processChanges then
		return
	end

	if not placementMode then
		for unitID, count in pairs(removeUnitGrassQueue) do
			adjustUnitGrass(unitID, (not unitGrassRemovedHistory[unitID] and 1/removeUnitGrassQueue[unitID]) )
			removeUnitGrassQueue[unitID] = removeUnitGrassQueue[unitID] - 1
			if count <= 1 then
				removeUnitGrassQueue[unitID] = nil
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
		local allUnits = Spring.GetAllUnits()
		for _, unitID in pairs(allUnits) do
			if isCommander[Spring.GetUnitDefID(unitID)] then
				local x,_,z = Spring.GetUnitPosition(unitID)
				adjustGrass(x, z, 90, 1)
			end
		end
	end
end

function widget:MousePress(x,y,button)
	if placementMode then
		return true
	end
end

local firstUpdate = true
function widget:Update(dt)
	if not processChanges then
		return
	end

	if firstUpdate then
		firstUpdate = false
		clearGeothermalGrass()	-- uses Spring.GetAllFeatures() which is empty at the time of widget:Initialize
	end

	if not placementMode then return end
	local mx, my, lp, mp, rp, offscreen = Spring.GetMouseState ( )
	local mx, my, lp, mp, rp, offscreen = Spring.GetMouseState ( )
	local _ , coords = Spring.TraceScreenRay(mx,my,true)
	if coords then
		mousepos = {coords[1],coords[2],coords[3]}
	else
		return
	end

	if not offscreen then
		if lp or rp then
			for x = coords[1] - cursorradius, coords[1] + cursorradius, grassConfig.patchResolution do
				for z = coords[3] - cursorradius, coords[3] + cursorradius, grassConfig.patchResolution do
					if (x-coords[1])*(x-coords[1]) + (z-coords[3])*(z-coords[3]) < cursorradius*cursorradius then
						updateGrassInstanceVBO(x,z, 1, (lp and 1.025) or (rp and 0.975))
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

  if grassVAO == nil then goodbye("Failed to create grassVAO") end
  grassVAO:AttachVertexBuffer(grassPatchVBO)
  grassVAO:AttachInstanceBuffer(grassInstanceVBO)
end

local function defineUploadGrassInstanceVBOData()
	grassInstanceVBO = nil
	grassInstanceVBO = gl.GetVBO(GL.ARRAY_BUFFER,true)
	if grassInstanceVBO == nil then goodbye("Failed to create grassInstanceVBO") end
	grassInstanceVBO:Define(
		math.max(1,#grassInstanceData/grassInstanceVBOStep),--?we dont know how big yet!
		{
		  {id = 7, name = 'instanceposrotscale', size = 4}, -- a vec4 for pos + random rotation + scale
		  }
		)
	grassInstanceVBOSize = #grassInstanceData
	if grassInstanceVBOSize > 0 then
		grassInstanceVBO:Upload(grassInstanceData)
	end
end

local function LoadGrassTGA(filename)
	local texture, loadfailed = Spring.Utilities.LoadTGA(filename)
	if loadfailed then
		Spring.Echo("Grass: Failed to load image for grass:",filename, loadfailed)
		return nil
	end
	if texture.channels ~= 1 then
		Spring.Echo("Loadgrass: only single channel .tga files are supported!")
		return nil
	end

	local patchResolution = grassConfig.patchResolution
	local patchPlacementJitter = grassConfig.patchPlacementJitter
	local offset = 0


	grassRowInstance = {0}
	local rowIndex = 1
	grassPatchCount = 0

	for z = 1, texture.height do
		grassRowInstance[rowIndex] = grassPatchCount
		rowIndex = rowIndex + 1
		for x = 1, texture.width do
			--if placementMode or texture[z][x] > 0 then
				local lx = (x - 0.5) * patchResolution + (math.random() - 0.5) * patchResolution*patchPlacementJitter
				local lz = (z - 0.5) * patchResolution + (math.random() - 0.5) * patchResolution*patchPlacementJitter
				grassPatchCount = grassPatchCount + 1
				grassInstanceData[offset*4 + 1] = lx
				grassInstanceData[offset*4 + 2] = math.random()*6.28
				grassInstanceData[offset*4 + 3] = lz
				grassInstanceData[offset*4 + 4] = grassByteToPatchMult(texture[z][x])
				offset = offset + 1
			--end
		end
	end
	return true
end


local function makeGrassInstanceVBO()
	grassInstanceVBO = gl.GetVBO(GL.ARRAY_BUFFER,true)
	if grassInstanceVBO == nil then  goodbye("No LuaVAO support") end

	grassInstanceData= {}
	grassRowInstance = {0}
	-- upload image type if exists
	if grassConfig.grassDistTGA and grassConfig.grassDistTGA ~= "" then
		LoadGrassTGA(grassConfig.grassDistTGA)

		defineUploadGrassInstanceVBOData()
		MakeAndAttachToVAO()
	else -- try to load builtin grass type

		local mapprocessChanges = mapHasSMFGrass()
		--Spring.Echo("mapHasSMFGrass",mapprocessChanges, placementMode)
		if (mapprocessChanges == 0 or mapprocessChanges == 255) and (not placementMode) then return nil end -- bail if none specified at all anywhere

		local rowIndex = 1
		for z = patchResolution / 2, mapSizeZ, patchResolution do
			grassRowInstance[rowIndex] = grassPatchCount
			rowIndex = rowIndex + 1
			for x = patchResolution / 2, mapSizeX, patchResolution do
				local localgrass =  spGetGrass(x,z)
				--if localgrass > 0 or placementMode then
					local lx = x + (math.random() -0.5) * patchResolution/1.5
					local lz = z + (math.random() -0.5) * patchResolution/1.5
					local grasssize = localgrass
					if grasssize > 0 then
						if mapprocessChanges == 1 then
							grasssize = grassConfig.grassMinSize + math.random() * (grassConfig.grassMaxSize - grassConfig.grassMinSize )
						else
							grasssize = grassConfig.grassMinSize + (localgrass/254.0) * (grassConfig.grassMaxSize - grassConfig.grassMinSize )
						end
					end
					grassPatchCount = grassPatchCount + 1
					grassInstanceData[#grassInstanceData+1] = lx
					grassInstanceData[#grassInstanceData+1] = math.random()*6.28 -- rotation 2 pi
					grassInstanceData[#grassInstanceData+1] = lz
					grassInstanceData[#grassInstanceData+1] = grasssize -- size
				--end
			end
		end
		--Spring.Echo("Grass: Drawing ",#grassInstanceData/grassInstanceVBOStep,"grass patches")
		grassInstanceVBOSize = #grassInstanceData
		defineUploadGrassInstanceVBOData()
		MakeAndAttachToVAO()
	end
end

local vsSrcPath = "LuaUI/Shaders/map_grass_gl4.vert.glsl"
local fsSrcPath = "LuaUI/Shaders/map_grass_gl4.frag.glsl"



local function makeShaderVAO()
	local shaderSourceCache = {
		vssrcpath = vsSrcPath,
		fssrcpath = fsSrcPath,
		shaderName = "GrassShaderGL4",
		uniformInt = {
			grassBladeColorTex = 0,-- rgb + alpha transp
			--grassBladeNormalTex = 1,-- xyz + specular factor
			mapGrassColorModTex = 1, -- minimap
			grassWindPerturbTex = 2, -- perlin
			shadowTex = 3, -- perlin
			losTex = 4, -- perlin
			heightmapTex = 5, -- perlin
			},
		uniformFloat = {
			grassuniforms = {1,1,1,1},
			distanceMult = distanceMult,
			nightFactor = {1,1,1,1},
		  },
		shaderConfig = grassConfig.grassShaderParams,
		silent = true,
	}

  grassShader = LuaShader.CheckShaderUpdates(shaderSourceCache)

  if not grassShader then goodbye("Failed to compile grassShader GL4 ") end
end

local weaponConf = {}
for i=1, #WeaponDefs do
	local radius = WeaponDefs[i].damageAreaOfEffect * 1.2
	local edgeEffectiveness = WeaponDefs[i].edgeEffectiveness * 1.75
	if WeaponDefs[i].type == 'DGun' then
		radius = radius * 2
		edgeEffectiveness = 4
	end
	if radius*edgeEffectiveness > 9 then
		weaponConf[i] = {radius, edgeEffectiveness}
	end
end

function widget:VisibleExplosion(px, py, pz, weaponID, ownerID)
	if not processChanges then
		return
	end
	if not placementMode and weaponConf[weaponID] ~= nil and py - 10 < spGetGroundHeight(px, pz) then
		adjustGrass(px, pz, weaponConf[weaponID][1], math.min(1, (weaponConf[weaponID][1]*weaponConf[weaponID][2])/45))
	end
end

local function placegrassCmd(_, _, params)
	placementMode = not placementMode
	processChanges = true
	Spring.Echo("Grass placement mode toggle to:", placementMode)
end

local function savegrassCmd(_, _, params)
	if not params[1] then return end

	local filename = params[1]
	if string.len(filename) < 2 then
		filename = Game.mapName .. "_grassDist.tga"
	end
	Spring.Echo("Savegrass: ", filename)

	texture = Spring.Utilities.NewTGA(
		math.floor(mapSizeX / grassConfig.patchResolution),
		math.floor(mapSizeZ / grassConfig.patchResolution),
		1)
	local offset = 0
	for y = 1, texture.height do
		for x = 1, texture.width do
			texture[y][x] = grassPatchMultToByte(grassInstanceData[offset*4 + 4])
			offset = offset + 1
		end
	end
	local success = Spring.Utilities.SaveTGA(texture, filename)
	if success then Spring.Echo("Saving grass map image failed",filename,success) end
end

local function loadgrassCmd(_, _, params)
	if not params[1] then return end

	placementMode = true
	local filename = params[1]
	if string.len(filename) < 2 then
		filename = Game.mapName .. "_grassDist.tga"
	end
	Spring.Echo("Loadgrass: ", filename)

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
	Spring.Echo("Clearing grass")
	placementMode = true
	local patchResolution = grassConfig.patchResolution
	local offset = 0
	for z = 1, math.floor(mapSizeZ/patchResolution )do
		for x = 1, math.floor(mapSizeX/patchResolution)do

			local lx = (x - 0.5) * patchResolution + (math.random() - 0.5) * patchResolution/1.5
			local lz = (z - 0.5) * patchResolution + (math.random() - 0.5) * patchResolution/1.5
			grassInstanceData[offset*4 + 1] = lx
			grassInstanceData[offset*4 + 2] = math.random()*6.28
			grassInstanceData[offset*4 + 3] = lz
			grassInstanceData[offset*4 + 4] = 0
			offset = offset + 1
		end
	end
	defineUploadGrassInstanceVBOData()
	MakeAndAttachToVAO()
	--grassVAO:AttachInstanceBuffer(grassInstanceVBO)
	Spring.Echo("Cleared grass")
end

local function dumpgrassshadersCmd(_, _, params)
	Spring.Echo(grassVertexShaderDebug)
	Spring.Echo(grassFragmentShaderDebug)
	--grassVAO:AttachInstanceBuffer(grassInstanceVBO)
end

function widget:Initialize()
	if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end
	WG['grassgl4'] = {}
	WG['grassgl4'].getDistanceMult = function()
		return distanceMult
	end
	WG['grassgl4'].setDistanceMult = function(value)
		distanceMult = value
	end
	WG['grassgl4'].removeGrass = function(wx,wz,radius)
		radius = radius or grassConfig.patchResolution
		for x = wx - radius, wx + radius, grassConfig.patchResolution do
			for z = wz - radius, wz + radius, grassConfig.patchResolution do
				if (x-wx)*(x-wx) + (z-wz)*(z-wz) < radius*radius then
					local sizeMod = 1-(math.abs(((x-wx)/radius)) + math.abs(((z-wz)/radius))) / 2	-- sizemode in range 0...1
					sizeMod = (sizeMod*2-math.min(0.66, radius/100))	-- adjust sizemod so inner grass is gone fully and not just the very center dot
					updateGrassInstanceVBO(x,z, 1, 1-sizeMod)
				end
			end
		end
	end
	WG['grassgl4'].removeGrassBelowHeight = function(height)
		if #grassInstanceData == 0 then return nil end
		if not removedBelowHeight or height > removedBelowHeight then
			removedBelowHeight = height

			local patchResolution = grassConfig.patchResolution
			local offset = 0
			for z = 1, math.floor(mapSizeZ/patchResolution )do
				for x = 1, math.floor(mapSizeX/patchResolution)do
					if spGetGroundHeight(x*patchResolution,z*patchResolution) <= height then
						local lx = (x - 0.5) * patchResolution + (math.random() - 0.5) * patchResolution/1.5
						local lz = (z - 0.5) * patchResolution + (math.random() - 0.5) * patchResolution/1.5
						grassInstanceData[offset*4 + 1] = lx
						grassInstanceData[offset*4 + 2] = math.random()*6.28
						grassInstanceData[offset*4 + 3] = lz
						grassInstanceData[offset*4 + 4] = 0
					end
					offset = offset + 1
				end
			end
			defineUploadGrassInstanceVBOData()
			MakeAndAttachToVAO()
		end
	end
	makeGrassPatchVBO(grassConfig.patchSize)
	makeGrassInstanceVBO()
	makeShaderVAO()
	clearAllUnitGrass()
	clearMetalspotGrass()
	if Game.waterDamage > 0 then
		WG['grassgl4'].removeGrassBelowHeight(20)
	end
	widgetHandler:RegisterGlobal('GadgetRemoveGrass', WG['grassgl4'].removeGrass)

	processChanges = false
	for k, v in pairs(grassInstanceData) do
		processChanges = true
		break
	end

	widgetHandler:AddAction("placegrass", placegrassCmd, nil, 't')
	widgetHandler:AddAction("savegrass", savegrassCmd, nil, 't')
	widgetHandler:AddAction("loadgrass", loadgrassCmd, nil, 't')
	widgetHandler:AddAction("editgrass", editgrassCmd, nil, 't')
	widgetHandler:AddAction("cleargrass", cleargrassCmd, nil, 't')
	widgetHandler:AddAction("dumpgrassshaders", dumpgrassshadersCmd, nil, 't')
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal('GadgetRemoveGrass')

	widgetHandler:RemoveAction("placegrass")
	widgetHandler:RemoveAction("savegrass")
	widgetHandler:RemoveAction("loadgrass")
	widgetHandler:RemoveAction("editgrass")
	widgetHandler:RemoveAction("cleargrass")
	widgetHandler:RemoveAction("dumpgrassshaders")
end

function widget:SetConfigData(data)
	if data.distanceMult ~= nil then
		distanceMult = data.distanceMult
	end
end

function widget:GetConfigData(data)
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

local function mapcoordtorow(mapz, offset) -- is this even worth it?
  local rownum = math.ceil((mapz - patchResolution/2) /patchResolution)
	rownum = math.max(1, math.min(#grassRowInstance, rownum + offset))
  return grassRowInstance[rownum]
end

local spIsAABBInView = Spring.IsAABBInView

local viewtables = {{0,0},{vsx-1,0},{0,vsy-1},{vsx-1,vsy-1}}

local function distto2dsqr(camy, camz, mapy, mapz)
  return math.sqrt((camy-mapy)*(camy-mapy) + (camz-mapz) * (camz-mapz))
end

local function GetStartEndRows() -- returns start and end indices of the instance buffer for more conservative drawing of grass
  --check if the top or bottom of map is in view
  -- this function is an abomination
	local topseen = spIsAABBInView(-9999,0,-9999, mapSizeX+9999,300,22)
	local botseen = spIsAABBInView(-9999,0,mapSizeZ, mapSizeX+9999,300,mapSizeZ+9999)

	local vsx, vsy = gl.GetViewSizes()
	local minZ = mapSizeZ
	local maxZ = 0

	local _, coordsBottomLeft = Spring.TraceScreenRay(viewtables[1][1], viewtables[1][2], true)
	if coordsBottomLeft then
	  minZ = math.min(minZ,coordsBottomLeft[3])
	  maxZ = math.max(maxZ,coordsBottomLeft[3])
	end
	dontcare, coordsBottomRight = Spring.TraceScreenRay(viewtables[2][1], viewtables[2][2], true)
	if coordsBottomRight then
	  minZ = math.min(minZ,coordsBottomRight[3])
	  maxZ = math.max(maxZ,coordsBottomRight[3])
	end
	dontcare, coordsTopLeft = Spring.TraceScreenRay(viewtables[3][1], viewtables[3][2], true)
	if coordsTopLeft then
	  minZ = math.min(minZ,coordsTopLeft[3])
	  maxZ = math.max(maxZ,coordsTopLeft[3])
	end
	dontcare, coordsTopRight = Spring.TraceScreenRay(viewtables[4][1], viewtables[4][2], true)
	if coordsTopRight then
	  minZ = math.min(minZ,coordsTopRight[3])
	  maxZ = math.max(maxZ,coordsTopRight[3])
	end

	if topseen or minZ == mapSizeX  or (coordsTopLeft == nil and coordTopRight == nil) then minZ = 0 end
	if botseen or maxZ == 0         then maxZ = mapSizeZ end

	local cx, cy, cz = Spring.GetCameraPosition()

	minZ = math.max(minZ, (distto2dsqr(cy,cz,maxHeight,0) - (grassConfig.grassShaderParams.FADEEND*distanceMult))) -- additional stupidity
	maxZ = math.min(maxZ, mapSizeZ - (distto2dsqr(cy,cz,maxHeight,mapSizeZ) - (grassConfig.grassShaderParams.FADEEND*distanceMult)))

	local startInstanceIndex = mapcoordtorow(minZ,-4)
	local endInstanceIndex =  mapcoordtorow(maxZ, 4)

	local numInstanceElements = endInstanceIndex - startInstanceIndex
	--Spring.Echo("GetStartEndRows", topseen, botseen,minZ,maxZ, startInstanceIndex,endInstanceIndex, numInstanceElements)
	return startInstanceIndex, numInstanceElements
	end

local glTexture = gl.Texture

local smoothGrassFadeExp = 1


function widget:DrawWorldPreUnit()
	if not processChanges then
		return
	end
  if #grassInstanceData == 0 then return end
  local mapDrawMode = Spring.GetMapDrawMode()
  if mapDrawMode ~= 'normal' and mapDrawMode ~= 'los' then return end
	if placementMode then
		--Spring.Echo("circle",mousepos[1],mousepos[2]+10,mousepos[3])
		gl.LineWidth(2)
		gl.Color(0.3, 1.0, 0.2, 0.75)
		gl.DrawGroundCircle(mousepos[1],mousepos[2]+10,mousepos[3],cursorradius,16)
	end
  local newGameSeconds = os.clock()
  local timePassed = newGameSeconds - oldGameSeconds
  oldGameSeconds = newGameSeconds

  local cx, cy, cz = Spring.GetCameraPosition()
  local gh = (Spring.GetGroundHeight(cx,cz) or 0)

  local globalgrassfade = math.clamp(((grassConfig.grassShaderParams.FADEEND*distanceMult) - (cy-gh))/((grassConfig.grassShaderParams.FADEEND*distanceMult)-(grassConfig.grassShaderParams.FADESTART*distanceMult)), 0, 1)

  local expFactor = math.min(1.0, 3 * timePassed) -- ADJUST THE TEMPORAL FACTOR OF 3
  smoothGrassFadeExp = smoothGrassFadeExp * (1.0 - expFactor) + globalgrassfade * expFactor
  --Spring.Echo(smoothGrassFadeExp, globalgrassfade)


  if cy  < ((grassConfig.grassShaderParams.FADEEND*distanceMult) + gh) and grassVAO ~= nil and #grassInstanceData > 0 then
	local startInstanceIndex = 0
	local instanceCount =  #grassInstanceData/4
    if not placementMode then
		startInstanceIndex, instanceCount = GetStartEndRows()
	end
	if instanceCount <= 0 or startInstanceIndex == #grassInstanceData/4 then return end
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

    grassShader:Activate()
    --Spring.Echo("globalgrassfade",globalgrassfade)
    local windStrength = math.min(grassConfig.maxWindSpeed, math.max(4.0, math.abs(windDirX) + math.abs(windDirZ)))
    grassShader:SetUniform("grassuniforms", offsetX, offsetZ, windStrength, smoothGrassFadeExp)
    grassShader:SetUniform("distanceMult", distanceMult)
	grassShader:SetUniform("nightFactor", nightFactor[1], nightFactor[2], nightFactor[3], nightFactor[4])



    grassVAO:DrawArrays(GL.TRIANGLES, grassPatchVBOsize, 0, instanceCount, startInstanceIndex)
    if placementMode and Spring.GetGameFrame()%30 == 0 then Spring.Echo("Drawing",instanceCount,"grass patches") end
    grassShader:Deactivate()
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

local lastSunChanged = -1
function widget:SunChanged() -- Note that map_nightmode.lua gadget has to change sun twice in a single draw frame to update all
	local df = Spring.GetDrawFrame()
	--Spring.Echo("widget:SunChanged", df)
	if df == lastSunChanged then return end
	lastSunChanged = df

	-- Do the math:
	if WG['NightFactor'] then
		local altitudefactor = 1.0 --+ (1.0 - WG['NightFactor'].altitude) * 0.5
		nightFactor[1] = WG['NightFactor'].red * altitudefactor
		nightFactor[2] = WG['NightFactor'].green * altitudefactor
		nightFactor[3] = WG['NightFactor'].blue * altitudefactor
		nightFactor[4] = WG['NightFactor'].shadow
	end
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

]]--
