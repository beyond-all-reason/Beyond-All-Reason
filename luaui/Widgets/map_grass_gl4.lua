local isPotatoGpu = false
local gpuMem = (Platform.gpuMemorySize and Platform.gpuMemorySize or 1000) / 1000
if Platform ~= nil and Platform.gpuVendor == 'Intel' then
	isPotatoGpu = true
end
if gpuMem and gpuMem > 0 and gpuMem < 1800 then
	isPotatoGpu = true
end

function widget:GetInfo()
  return {
    name      = "Map Grass GL4",
    version   = "v0.001",
    desc      = "Instanced rendering of garbagegrass",
    author    = "Beherith (mysterme@gmail.com)",
    date      = "2021.04.12",
    license   = "Lua code: GPL V2, Shader Code: CC-BY-NC-ND 4.0",
    layer     = -9999999,
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
    ALPHATHRESHOLD = 0.15,--alpha limit under which to discard a fragment
    WINDSTRENGTH = 0.1,	  -- how much the wind will blow the grass
    WINDSCALE = 0.33, -- how fast the wind texture moves
    WINDSAMPLESCALE = 0.001, -- tiling resolution of the noise texture
    FADESTART = 5800,-- distance at which grass starts to fade
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
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitDefID = Spring.GetUnitDefID
local mapSizeX, mapSizeZ = Game.mapSizeX, Game.mapSizeZ
local vsx, vsy = gl.GetViewSizes()
local minHeight, maxHeight = Spring.GetGroundExtremes()
local removedBelowHeight

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
local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
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
	local VBOData
	if grassPatchSize == 1 then
		grassPatchVBOsize = 36
		VBOData = { 	19.9253,-0.3833,-5.5756,0,1.0000,0,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			-15.0340,-0.3833,14.6081,0,1.0000,0,0,0,0,0,0,0,0.0019,0.0028,0,0,0,
			-11.7273,16.8366,20.3354,0,1.0000,0,0,0,0,0,0,0,0.0019,0.9876,0,0,0,
			-11.7273,16.8366,20.3354,0,1.0000,0,0,0,0,0,0,0,0.0019,0.9876,0,0,0,
			23.2319,16.8365,0.1517,0,1.0000,0,0,0,0,0,0,0,0.9984,0.9876,0,0,0,
			19.9253,-0.3833,-5.5756,0,1.0000,0,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			-14.8705,-0.3833,14.8913,0,1.0000,0,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			20.0888,-0.3833,-5.2924,0,1.0000,0,0,0,0,0,0,0,0.0019,0.0028,0,0,0,
			16.7821,16.8365,-11.0198,0,1.0000,0,0,0,0,0,0,0,0.0019,0.9876,0,0,0,
			16.7821,16.8365,-11.0198,0,1.0000,0,0,0,0,0,0,0,0.0019,0.9876,0,0,0,
			-18.1772,16.8365,9.1640,0,1.0000,0,0,0,0,0,0,0,0.9984,0.9876,0,0,0,
			-14.8705,-0.3833,14.8913,0,1.0000,0,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			19.8347,-0.3833,4.6970,0,1.0000,0,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			-15.1245,-0.3833,-15.4867,0,1.0000,0,0,0,0,0,0,0,0.0019,0.0028,0,0,0,
			-18.4312,16.8366,-9.7594,0,1.0000,0,0,0,0,0,0,0,0.0019,0.9876,0,0,0,
			-18.4312,16.8366,-9.7594,0,1.0000,0,0,0,0,0,0,0,0.0019,0.9876,0,0,0,
			16.5280,16.8365,10.4243,0,1.0000,0,0,0,0,0,0,0,0.9984,0.9876,0,0,0,
			19.8347,-0.3833,4.6970,0,1.0000,0,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			-15.2880,-0.3833,-15.2036,0,1.0000,0,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			19.6712,-0.3833,4.9802,0,1.0000,0,0,0,0,0,0,0,0.0019,0.0028,0,0,0,
			22.9779,16.8365,-0.7471,0,1.0000,0,0,0,0,0,0,0,0.0019,0.9876,0,0,0,
			22.9779,16.8365,-0.7471,0,1.0000,0,0,0,0,0,0,0,0.0019,0.9876,0,0,0,
			-11.9814,16.8365,-20.9309,0,1.0000,0,0,0,0,0,0,0,0.9984,0.9876,0,0,0,
			-15.2880,-0.3833,-15.2036,0,1.0000,0,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			-6.1704,-0.3833,20.5802,0,1.0000,0,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			-6.1704,-0.3833,-19.7872,0,1.0000,0,0,0,0,0,0,0,0.0019,0.0028,0,0,0,
			-12.7837,16.8366,-19.7872,0,1.0000,0,0,0,0,0,0,0,0.0019,0.9876,0,0,0,
			-12.7837,16.8366,-19.7872,0,1.0000,0,0,0,0,0,0,0,0.0019,0.9876,0,0,0,
			-12.7837,16.8365,20.5802,0,1.0000,0,0,0,0,0,0,0,0.9984,0.9876,0,0,0,
			-6.1704,-0.3833,20.5802,0,1.0000,0,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			-6.4974,-0.3833,-19.7872,0,1.0000,0,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			-6.4974,-0.3833,20.5802,0,1.0000,0,0,0,0,0,0,0,0.0019,0.0028,0,0,0,
			0.1159,16.8365,20.5802,0,1.0000,0,0,0,0,0,0,0,0.0019,0.9876,0,0,0,
			0.1159,16.8365,20.5802,0,1.0000,0,0,0,0,0,0,0,0.0019,0.9876,0,0,0,
			0.1159,16.8365,-19.7872,0,1.0000,0,0,0,0,0,0,0,0.9984,0.9876,0,0,0,
			-6.4974,-0.3833,-19.7872,0,1.0000,0,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
		}

	elseif grassPatchSize == 4 then
		grassPatchVBOsize = 144
		VBOData = { 	-14.8090,-0.0012,1.0914,0.8390,0.3585,0.4092,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			-5.5186,-0.0012,-17.9567,0.8390,0.3585,0.4092,0,0,0,0,0,0,0.0019,0.0028,0,0,0,
			-8.6393,9.0392,-19.4787,0.8390,0.3585,0.4092,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			-8.6393,9.0392,-19.4787,0.8390,0.3585,0.4092,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			-17.9296,9.0392,-0.4307,0.8390,0.3585,0.4092,0,0,0,0,0,0,0.9984,0.9976,0,0,0,
			-14.8090,-0.0012,1.0914,0.8390,0.3585,0.4092,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			-5.6729,-0.0012,-18.0320,-0.8390,0.3585,-0.4092,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			-14.9633,-0.0012,1.0161,-0.8390,0.3585,-0.4092,0,0,0,0,0,0,0.0019,0.0028,0,0,0,
			-11.8427,9.0392,2.5381,-0.8390,0.3585,-0.4092,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			-11.8427,9.0392,2.5381,-0.8390,0.3585,-0.4092,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			-2.5523,9.0392,-16.5100,-0.8390,0.3585,-0.4092,0,0,0,0,0,0,0.9984,0.9976,0,0,0,
			-5.6729,-0.0012,-18.0320,-0.8390,0.3585,-0.4092,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			-17.7854,-0.0012,-3.4063,0.0651,0.3585,0.9312,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			3.3559,-0.0012,-4.8847,0.0651,0.3585,0.9312,0,0,0,0,0,0,0.0019,0.0028,0,0,0,
			3.1137,9.0392,-8.3482,0.0651,0.3585,0.9312,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			3.1137,9.0392,-8.3482,0.0651,0.3585,0.9312,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			-18.0276,9.0392,-6.8699,0.0651,0.3585,0.9312,0,0,0,0,0,0,0.9984,0.9976,0,0,0,
			-17.7854,-0.0012,-3.4063,0.0651,0.3585,0.9312,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			3.3439,-0.0012,-5.0559,-0.0651,0.3585,-0.9312,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			-17.7974,-0.0012,-3.5776,-0.0651,0.3585,-0.9312,0,0,0,0,0,0,0.0019,0.0028,0,0,0,
			-17.5552,9.0392,-0.1140,-0.0651,0.3585,-0.9312,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			-17.5552,9.0392,-0.1140,-0.0651,0.3585,-0.9312,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			3.5861,9.0392,-1.5924,-0.0651,0.3585,-0.9312,0,0,0,0,0,0,0.9984,0.9976,0,0,0,
			3.3439,-0.0012,-5.0559,-0.0651,0.3585,-0.9312,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			-11.1297,-0.0012,-17.9539,-0.7739,0.3585,0.5220,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			0.7212,-0.0012,-0.3842,-0.7739,0.3585,0.5220,0,0,0,0,0,0,0.0019,0.0028,0,0,0,
			3.5996,9.0392,-2.3257,-0.7739,0.3585,0.5220,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			3.5996,9.0392,-2.3257,-0.7739,0.3585,0.5220,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			-8.2513,9.0392,-19.8954,-0.7739,0.3585,0.5220,0,0,0,0,0,0,0.9984,0.9976,0,0,0,
			-11.1297,-0.0012,-17.9539,-0.7739,0.3585,0.5220,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			0.8635,-0.0012,-0.4802,0.7739,0.3585,-0.5220,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			-10.9874,-0.0012,-18.0499,0.7739,0.3585,-0.5220,0,0,0,0,0,0,0.0019,0.0028,0,0,0,
			-13.8658,9.0392,-16.1084,0.7739,0.3585,-0.5220,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			-13.8658,9.0392,-16.1084,0.7739,0.3585,-0.5220,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			-2.0149,9.0392,1.4613,0.7739,0.3585,-0.5220,0,0,0,0,0,0,0.9984,0.9976,0,0,0,
			0.8635,-0.0012,-0.4802,0.7739,0.3585,-0.5220,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			3.6502,-0.0012,12.7368,0.1621,0.3585,-0.9193,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			-17.2208,-0.0012,9.0567,0.1621,0.3585,-0.9193,0,0,0,0,0,0,0.0019,0.0028,0,0,0,
			-17.8237,9.0392,12.4759,0.1621,0.3585,-0.9193,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			-17.8237,9.0392,12.4759,0.1621,0.3585,-0.9193,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			3.0473,9.0392,16.1560,0.1621,0.3585,-0.9193,0,0,0,0,0,0,0.9984,0.9976,0,0,0,
			3.6502,-0.0012,12.7368,0.1621,0.3585,-0.9193,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			-17.2506,-0.0012,9.2257,-0.1621,0.3585,0.9193,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			3.6204,-0.0012,12.9058,-0.1621,0.3585,0.9193,0,0,0,0,0,0,0.0019,0.0028,0,0,0,
			4.2233,9.0392,9.4866,-0.1621,0.3585,0.9193,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			4.2233,9.0392,9.4866,-0.1621,0.3585,0.9193,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			-16.6477,9.0392,5.8065,-0.1621,0.3585,0.9193,0,0,0,0,0,0,0.9984,0.9976,0,0,0,
			-17.2506,-0.0012,9.2257,-0.1621,0.3585,0.9193,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			0.1471,-0.0012,16.8376,0.8772,0.3585,-0.3193,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			-7.1013,-0.0012,-3.0772,0.8772,0.3585,-0.3193,0,0,0,0,0,0,0.0019,0.0028,0,0,0,
			-10.3639,9.0392,-1.8897,0.8772,0.3585,-0.3193,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			-10.3639,9.0392,-1.8897,0.8772,0.3585,-0.3193,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			-3.1155,9.0392,18.0251,0.8772,0.3585,-0.3193,0,0,0,0,0,0,0.9984,0.9976,0,0,0,
			0.1471,-0.0012,16.8376,0.8772,0.3585,-0.3193,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			-7.2626,-0.0012,-3.0185,-0.8772,0.3585,0.3193,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			-0.0142,-0.0012,16.8963,-0.8772,0.3585,0.3193,0,0,0,0,0,0,0.0019,0.0028,0,0,0,
			3.2484,9.0392,15.7088,-0.8772,0.3585,0.3193,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			3.2484,9.0392,15.7088,-0.8772,0.3585,0.3193,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			-4.0000,9.0392,-4.2060,-0.8772,0.3585,0.3193,0,0,0,0,0,0,0.9984,0.9976,0,0,0,
			-7.2626,-0.0012,-3.0185,-0.8772,0.3585,0.3193,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			-15.6714,-0.0012,14.4496,0.7151,0.3585,0.6001,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			-2.0489,-0.0012,-1.7851,0.7151,0.3585,0.6001,0,0,0,0,0,0,0.0019,0.0028,0,0,0,
			-4.7086,9.0392,-4.0168,0.7151,0.3585,0.6001,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			-4.7086,9.0392,-4.0168,0.7151,0.3585,0.6001,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			-18.3311,9.0392,12.2179,0.7151,0.3585,0.6001,0,0,0,0,0,0,0.9984,0.9976,0,0,0,
			-15.6714,-0.0012,14.4496,0.7151,0.3585,0.6001,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			-2.1804,-0.0012,-1.8954,-0.7151,0.3585,-0.6001,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			-15.8029,-0.0012,14.3393,-0.7151,0.3585,-0.6001,0,0,0,0,0,0,0.0019,0.0028,0,0,0,
			-13.1432,9.0392,16.5711,-0.7151,0.3585,-0.6001,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			-13.1432,9.0392,16.5711,-0.7151,0.3585,-0.6001,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			0.4793,9.0392,0.3363,-0.7151,0.3585,-0.6001,0,0,0,0,0,0,0.9984,0.9976,0,0,0,
			-2.1804,-0.0012,-1.8954,-0.7151,0.3585,-0.6001,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			14.9866,-0.0012,-17.5038,-0.8243,0.3585,-0.4383,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			5.0372,-0.0012,1.2084,-0.8243,0.3585,-0.4383,0,0,0,0,0,0,0.0019,0.0028,0,0,0,
			8.1028,9.0392,2.8384,-0.8243,0.3585,-0.4383,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			8.1028,9.0392,2.8384,-0.8243,0.3585,-0.4383,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			18.0522,9.0392,-15.8738,-0.8243,0.3585,-0.4383,0,0,0,0,0,0,0.9984,0.9976,0,0,0,
			14.9866,-0.0012,-17.5038,-0.8243,0.3585,-0.4383,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			5.1887,-0.0012,1.2890,0.8243,0.3585,0.4383,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			15.1382,-0.0012,-17.4233,0.8243,0.3585,0.4383,0,0,0,0,0,0,0.0019,0.0028,0,0,0,
			12.0726,9.0392,-19.0533,0.8243,0.3585,0.4383,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			12.0726,9.0392,-19.0533,0.8243,0.3585,0.4383,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			2.1231,9.0392,-0.3410,0.8243,0.3585,0.4383,0,0,0,0,0,0,0.9984,0.9976,0,0,0,
			5.1887,-0.0012,1.2890,0.8243,0.3585,0.4383,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			17.8042,-0.0012,-12.9050,-0.0326,0.3585,-0.9330,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			-3.3758,-0.0012,-12.1654,-0.0326,0.3585,-0.9330,0,0,0,0,0,0,0.0019,0.0028,0,0,0,
			-3.2546,9.0392,-8.6955,-0.0326,0.3585,-0.9330,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			-3.2546,9.0392,-8.6955,-0.0326,0.3585,-0.9330,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			17.9254,9.0392,-9.4351,-0.0326,0.3585,-0.9330,0,0,0,0,0,0,0.9984,0.9976,0,0,0,
			17.8042,-0.0012,-12.9050,-0.0326,0.3585,-0.9330,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			-3.3698,-0.0012,-11.9938,0.0326,0.3585,0.9330,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			17.8102,-0.0012,-12.7335,0.0326,0.3585,0.9330,0,0,0,0,0,0,0.0019,0.0028,0,0,0,
			17.6891,9.0392,-16.2033,0.0326,0.3585,0.9330,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			17.6891,9.0392,-16.2033,0.0326,0.3585,0.9330,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			-3.4909,9.0392,-15.4637,0.0326,0.3585,0.9330,0,0,0,0,0,0,0.9984,0.9976,0,0,0,
			-3.3698,-0.0012,-11.9938,0.0326,0.3585,0.9330,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			10.6450,-0.0012,1.4014,0.7917,0.3585,-0.4947,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			-0.5856,-0.0012,-16.5712,0.7917,0.3585,-0.4947,0,0,0,0,0,0,0.0019,0.0028,0,0,0,
			-3.5300,9.0392,-14.7313,0.7917,0.3585,-0.4947,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			-3.5300,9.0392,-14.7313,0.7917,0.3585,-0.4947,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			7.7005,9.0392,3.2413,0.7917,0.3585,-0.4947,0,0,0,0,0,0,0.9984,0.9976,0,0,0,
			10.6450,-0.0012,1.4014,0.7917,0.3585,-0.4947,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			-0.7312,-0.0012,-16.4802,-0.7917,0.3585,0.4947,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			10.4994,-0.0012,1.4924,-0.7917,0.3585,0.4947,0,0,0,0,0,0,0.0019,0.0028,0,0,0,
			13.4438,9.0392,-0.3475,-0.7917,0.3585,0.4947,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			13.4438,9.0392,-0.3475,-0.7917,0.3585,0.4947,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			2.2133,9.0392,-18.3201,-0.7917,0.3585,0.4947,0,0,0,0,0,0,0.9984,0.9976,0,0,0,
			-0.7312,-0.0012,-16.4802,-0.7917,0.3585,0.4947,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			14.4134,-0.0012,16.0154,0.6715,0.3585,-0.6485,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			-0.3084,-0.0012,0.7705,0.6715,0.3585,-0.6485,0,0,0,0,0,0,0.0019,0.0028,0,0,0,
			-2.8060,9.0392,3.1823,0.6715,0.3585,-0.6485,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			-2.8060,9.0392,3.1823,0.6715,0.3585,-0.6485,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			11.9158,9.0392,18.4272,0.6715,0.3585,-0.6485,0,0,0,0,0,0,0.9984,0.9976,0,0,0,
			14.4134,-0.0012,16.0154,0.6715,0.3585,-0.6485,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			-0.4319,-0.0012,0.8897,-0.6715,0.3585,0.6485,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			14.2899,-0.0012,16.1346,-0.6715,0.3585,0.6485,0,0,0,0,0,0,0.0019,0.0028,0,0,0,
			16.7875,9.0392,13.7228,-0.6715,0.3585,0.6485,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			16.7875,9.0392,13.7228,-0.6715,0.3585,0.6485,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			2.0656,9.0392,-1.5221,-0.6715,0.3585,0.6485,0,0,0,0,0,0,0.9984,0.9976,0,0,0,
			-0.4319,-0.0012,0.8897,-0.6715,0.3585,0.6485,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			9.1690,-0.0012,17.2740,0.8974,0.3585,0.2573,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			15.0105,-0.0012,-3.0980,0.8974,0.3585,0.2573,0,0,0,0,0,0,0.0019,0.0028,0,0,0,
			11.6730,9.0392,-4.0550,0.8974,0.3585,0.2573,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			11.6730,9.0392,-4.0550,0.8974,0.3585,0.2573,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			5.8315,9.0392,16.3170,0.8974,0.3585,0.2573,0,0,0,0,0,0,0.9984,0.9976,0,0,0,
			9.1690,-0.0012,17.2740,0.8974,0.3585,0.2573,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			14.8455,-0.0012,-3.1453,-0.8974,0.3585,-0.2573,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			9.0039,-0.0012,17.2267,-0.8974,0.3585,-0.2573,0,0,0,0,0,0,0.0019,0.0028,0,0,0,
			12.3414,9.0392,18.1837,-0.8974,0.3585,-0.2573,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			12.3414,9.0392,18.1837,-0.8974,0.3585,-0.2573,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			18.1830,9.0392,-2.1883,-0.8974,0.3585,-0.2573,0,0,0,0,0,0,0.9984,0.9976,0,0,0,
			14.8455,-0.0012,-3.1453,-0.8974,0.3585,-0.2573,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			-2.2249,-0.0012,6.0441,0.2258,0.3585,0.9058,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			18.3385,-0.0012,0.9171,0.2258,0.3585,0.9058,0,0,0,0,0,0,0.0019,0.0028,0,0,0,
			17.4985,9.0392,-2.4517,0.2258,0.3585,0.9058,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			17.4985,9.0392,-2.4517,0.2258,0.3585,0.9058,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			-3.0649,9.0392,2.6753,0.2258,0.3585,0.9058,0,0,0,0,0,0,0.9984,0.9976,0,0,0,
			-2.2249,-0.0012,6.0441,0.2258,0.3585,0.9058,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			18.2970,-0.0012,0.7505,-0.2258,0.3585,-0.9058,0,0,0,0,0,0,0.9984,0.0028,0,0,0,
			-2.2665,-0.0012,5.8776,-0.2258,0.3585,-0.9058,0,0,0,0,0,0,0.0019,0.0028,0,0,0,
			-1.4265,9.0392,9.2464,-0.2258,0.3585,-0.9058,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			-1.4265,9.0392,9.2464,-0.2258,0.3585,-0.9058,0,0,0,0,0,0,0.0019,0.9976,0,0,0,
			19.1369,9.0392,4.1194,-0.2258,0.3585,-0.9058,0,0,0,0,0,0,0.9984,0.9976,0,0,0,
			18.2970,-0.0012,0.7505,-0.2258,0.3585,-0.9058,0,0,0,0,0,0,0.9984,0.0028,0,0,0,

		}
	end

	grassPatchVBO:Define(
		grassPatchVBOsize, -- 3 verts, just a triangle for now
		VBOLayout -- 17 floats per vertex
	)

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
	return math.floor(math.max(1, math.min(254,grassbyte)))
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

local function updateGrassInstanceVBO(wx, wz, size, sizemod, vboOffset)
	-- we are assuming that we can do this
	--Spring.Echo(wx, wz, sizemod)
	local vboOffset = vboOffset or world2grassmap(wx,wz) * grassInstanceVBOStep
	if vboOffset<0 or vboOffset >= #grassInstanceData then	-- top left of map gets vboOffset: 0
		--Spring.Echo("vboOffset > #grassInstanceData",vboOffset,#grassInstanceData, " you probably need to /editgrass")
		return
	end

	local oldsize = grassInstanceData[vboOffset + 4]
	if oldsize <= 0 and not placementMode then return end

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
	grassInstanceVBO:Upload({oldpx, oldry, oldpz, size}, 7, vboOffset/4) -- We _must_ upload whole instance params at once
end

function widget:KeyPress(key, modifier, isRepeat)
	if not placementMode then return false end
	if key == KEYSYMS.LEFTBRACKET then cursorradius = math.max(8, cursorradius *0.8) end
	if key == KEYSYMS.RIGHTBRACKET then cursorradius = math.min(512, cursorradius *1.2) end
	return false
end

local function adjustGrass(px, pz, radius, multiplier)
	local params = {math.floor(px),math.floor(pz)}
	for x = params[1] - radius, params[1] + radius, grassConfig.patchResolution do
		if x >= 0 and x <= mapSizeX then
			for z = params[2] - radius, params[2] + radius, grassConfig.patchResolution do
				if z >= 0 and z <= mapSizeZ then
					if (x-params[1])*(x-params[1]) + (z-params[2])*(z-params[2]) < radius*radius then
						local vboOffset = world2grassmap(x,z) * grassInstanceVBOStep
						if vboOffset then
							local sizeMod = 1-(math.abs(((x-params[1])/radius)) + math.abs(((z-params[2])/radius))) / 2	-- sizemode in range 0...1
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
	if not placementMode and buildingRadius[unitDefID] and not unitGrassRemovedHistory[unitID] then
		local _, _, _, _, buildProgress = spGetUnitHealth(unitID)
		if buildProgress and buildProgress >= 1 then
			adjustUnitGrass(unitID)
		else
			removeUnitGrassQueue[unitID] = removeUnitGrassFrames
		end
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	if not placementMode and buildingRadius[unitDefID] and not unitGrassRemovedHistory[unitID] then
		removeUnitGrassQueue[unitID] = removeUnitGrassFrames
	end
end


function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if not placementMode and buildingRadius[unitDefID] then
		removeUnitGrassQueue[unitID] = nil
		unitGrassRemovedHistory[unitID] = nil
	end
end

function widget:GameFrame(gf)
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

		local maphasgrass = mapHasSMFGrass()
		--Spring.Echo("mapHasSMFGrass",maphasgrass)
		if (maphasgrass == 0 or maphasgrass == 255) and (not placementMode) then return nil end -- bail if none specified at all anywhere

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
						if maphasgrass == 1 then
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

local vsSrc = [[
#version 420
#line 10000

//__DEFINES__
/*
#define MAPCOLORFACTOR 0.4
#define    DARKENBASE 0.5
#define    ALPHATHRESHOLD 0.02
#define    WINDSTRENGTH 1.0
#define    WINDSCALE 0.33
#define    FADESTART 2000
#define    FADEEND 3000
*/
layout (location = 0) in vec3 vertexPos;
layout (location = 1) in vec3 vertexNormal;
layout (location = 2) in vec3 stangent;
layout (location = 3) in vec3 ttangent;
layout (location = 4) in vec2 texcoords0;
layout (location = 5) in vec2 texcoords1;
layout (location = 6) in float pieceindex;
layout (location = 7) in vec4 instancePosRotSize; //x, rot, z, size

uniform vec4 grassuniforms; //windx, windz, 0, globalalpha

uniform sampler2D grassBladeColorTex;

uniform sampler2D mapGrassColorModTex;
uniform sampler2D grassWindPerturbTex;
uniform sampler2DShadow shadowTex;
uniform sampler2D losTex;
uniform sampler2D heightmapTex;

out DataVS {
	vec3 worldPos;
  //vec3 Normal;
  vec2 texCoord0;
  //vec3 Tangent;
  //vec3 Bitangent;
  vec4 mapColor; //alpha contains fog factor
  //vec4 grassNoise;
  vec4 instanceParamsVS; // x is distance from camera
  vec4 debuginfo;
};

//__ENGINEUNIFORMBUFFERDEFS__

#line 10770

// pre vs opt pure vs load is 182 -> 155 fps
void main() {


  vec3 grassVertWorldPos = vertexPos * instancePosRotSize.w; // scale it
  mat3 rotY = rotation3dY(instancePosRotSize.y); // poor mans random rotate

  grassVertWorldPos.xz = (rotY * grassVertWorldPos).xz + instancePosRotSize.xz; // rotate Y and move to world pos

  debuginfo.xyz = rotY*vertexNormal;
  //--- Heightmap sampling
  vec2 ts = vec2(textureSize(heightmapTex, 0));
  vec2 uvHM =   vec2(clamp(grassVertWorldPos.x,8.0,mapSize.x-8.0),clamp(grassVertWorldPos.z,8.0, mapSize.y-8.0))/ mapSize.xy; // this proves to be an actually useable heightmap i think.
  grassVertWorldPos.y = (vertexPos.y +0.5) *instancePosRotSize.w + textureLod(heightmapTex, uvHM, 0.0).x;

  //--- LOS tex
  vec4 losTexSample = texture(losTex, vec2(grassVertWorldPos.x / mapSize.z, grassVertWorldPos.z / mapSize.w)); // lostex is PO2
  instanceParamsVS.z = dot(losTexSample.rgb,vec3(0.33));
  instanceParamsVS.z = clamp(instanceParamsVS.z*1.5 , 0.0,1.0);
  //debuginfo = losTexSample;

  //--- SHADOWS ---
  float shadow = 1.0;

  #ifdef HASSHADOWS
    #define SHADOWOFFSET 4.0
    vec4 shadowVertexPos;
    shadowVertexPos = shadowView * vec4(grassVertWorldPos+ vec3(SHADOWOFFSET, 0.0, SHADOWOFFSET),1.0);
    shadowVertexPos.xy += vec2(0.5);
    shadow += clamp(textureProj(shadowTex, shadowVertexPos), SHADOWFACTOR, 1.0);
    shadowVertexPos = shadowView * vec4(grassVertWorldPos+ vec3(-SHADOWOFFSET, 0.0, -SHADOWOFFSET),1.0);
    shadowVertexPos.xy += vec2(0.5);
    shadow += clamp(textureProj(shadowTex, shadowVertexPos), SHADOWFACTOR, 1.0);
    shadowVertexPos = shadowView * vec4(grassVertWorldPos+ vec3(-SHADOWOFFSET, 0.0, SHADOWOFFSET),1.0);
    shadowVertexPos.xy += vec2(0.5);
    shadow += clamp(textureProj(shadowTex, shadowVertexPos), SHADOWFACTOR, 1.0);
    shadowVertexPos = shadowView * vec4(grassVertWorldPos+ vec3(SHADOWOFFSET, 0.0, -SHADOWOFFSET),1.0);
    shadowVertexPos.xy += vec2(0.5);
    shadow += clamp(textureProj(shadowTex, shadowVertexPos), SHADOWFACTOR, 1.0);
    shadow = shadow*0.2;
  #endif

  instanceParamsVS.y = clamp(shadow,SHADOWFACTOR,1.0);

  //--- MAP COLOR BLENDING
  mapColor = texture(mapGrassColorModTex, vec2(grassVertWorldPos.x / mapSize.x, grassVertWorldPos.z / mapSize.y)); // sample minimap

  //--- WIND NOISE
  //Sample wind noise texture depending on wind speed and scale:
  vec4 grassNoise = texture(grassWindPerturbTex, vec2(grassVertWorldPos.xz + grassuniforms.xy*WINDSCALE) * WINDSAMPLESCALE);

  //Adjust the sampled grass noise:
  grassNoise = (grassNoise - 0.5 ).xzyw; //scale and swizzle normals

  //Shade the patches to be darker when 'flattened' by noise
  float shadeamount = grassNoise.y *2.0; //0-1
  shadeamount = (shadeamount -0.66) *3.0;
  grassNoise.y *2.0;


  grassNoise.y = grassNoise.y -0.4;

  instanceParamsVS.w = mix(vec3(0.0,1.0,0.0),vec3(0.0,shadeamount,0.0), texcoords0.y).y;

  grassVertWorldPos = grassVertWorldPos.xyz +  grassNoise.rgb * vertexPos.y * instancePosRotSize.w * WINDSTRENGTH * grassuniforms.z; // wind is a factor of


  //--- FOG ----

  float fogDist = length((cameraView * vec4(grassVertWorldPos,1.0)).xyz);
  float fogFactor = (fogParams.y - fogDist) * fogParams.w;
  mapColor.a = smoothstep(0.0,1.0,fogFactor);
  mapColor.a = 1.0; // DEBUG FOR NOW AS FOG IS BORKED

  //--- DISTANCE FADE ---
  vec4 camPos = cameraViewInv[3];
  float distToCam = length(grassVertWorldPos.xyz - camPos.xyz); //dist from cam
  instanceParamsVS.x = clamp((FADEEND - distToCam)/(FADEEND- FADESTART),0.0,1.0);


  //--- ALPHA CULLING BASED ON QUAD NORMAL
  // float cosnormal = dot(normalize(grassVertWorldPos.xyz - camPos.xyz), rotY * vertexNormal);
  //instanceParamsVS.x *= clamp(cosnormal,0.0,1.0);
  debuginfo.w = dot(rotY*vertexNormal, normalize(camPos.xyz - grassVertWorldPos.xyz));

  // ------------ dump the stuff for FS --------------------
  texCoord0 = texcoords0;
  //Normal = rotY * vertexNormal;
  //Tangent = rotY * ttangent;
  gl_Position = cameraViewProj * vec4(grassVertWorldPos.xyz, 1.0);

}
]]

-- Geometry Shader is unused at the moment!
local gsSrc = [[
#version 420 core

layout (points) in;
layout (triangle_strip, max_vertices = 36) out;

//__ENGINEUNIFORMBUFFERDEFS__

in DataVS {
	vec4 cameraPos;
  vec4 patchPos;
  vec4 PatchColor;
} dataIn[];

out DataGS {
	vec2 texCoord;
};
/*
GS Process:
Draw a good 6  quads

A. Early Bailout:
- if patch vertex X

A. for each patch:
  -Grab grass shading tex
  -sample

*/
void main(){
  vec4 grassCenterPos = gl_in[0].gl_Position
  vec4 viewPos = cameraViewProj * grassCenterPos;

  if (any(lessThan(viewPos.xyz, vec3(-viewPos.w))) ||
    any(greaterThan(viewPos.xyz, vec3(viewPos.w))))
  { // (we could do this in whole thing in VS?)
    // WE BAIL HERE LIKE SCUM
  }else{
    // Sample the heightmap at this position
    float unsyncedheight = texture(unsyncedHeightMap, vec2(grassCenterPos.x / mapSize.x, grassCenterPos.z/ mapSize.y));

    // Sample the map Color:
    vec4 mapColor = texture(mapGrassColorModTex, vec2(grassCenterPos.x / mapSize.x, grassCenterPos.z/ mapSize.y));

    // Generate a random rotation matrix for this whole thing

    for (int q = 0; q<12; q++ ){

      // per quad data:
      // the two verts that actually need info are the sides of the quad.


    }
  }

	vec3 snowPos = gl_in[0].gl_Position.xyz;

	vec3 toCamera = normalize(dataIn[0].cameraPos.xyz - snowPos);
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 right = cross(toCamera,up);
	// TODO: randomly rotate them snowflakes :D
	// TODO: make them sized nicely random too
	// TODO: kill jester
	const float flakesize = 50.0;

	snowPos -= (right * 0.5) * flakesize;
	gl_Position = cameraViewProj * vec4(snowPos, 1.0);
	texCoord = vec2(0.0,0.0);
	EmitVertex();

	snowPos.y += 1.0 * flakesize;
	gl_Position = cameraViewProj * vec4(snowPos, 1.0);
	texCoord = vec2(0.0,1.0);
	EmitVertex();

	snowPos.y -= 1.0 * flakesize;
	snowPos += right * flakesize;
	gl_Position = cameraViewProj * vec4(snowPos, 1.0);
	texCoord = vec2(1.0,0.0);
	EmitVertex();

	snowPos.y += 1.0 * flakesize;
	gl_Position = cameraViewProj * vec4(snowPos, 1.0);
	texCoord = vec2(1.0,1.0);
	EmitVertex();

	EndPrimitive();
}
]]

local fsSrc = [[
#version 330

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

#line 20000
//__DEFINES__
/*
#define    MAPCOLORFACTOR 0.4
#define    DARKENBASE 0.5
#define    ALPHATHRESHOLD 0.02
#define    WINDSTRENGTH 1.0
#define    WINDSCALE 0.33
#define    FADESTART 2000
#define    FADEEND 3000
*/

uniform vec4 grassuniforms; //windx, windz, windstrength, globalalpha

uniform sampler2D grassBladeColorTex;
uniform sampler2D mapGrassColorModTex;
uniform sampler2D grassWindPerturbTex;

in DataVS {
	vec3 worldPos;
	//vec3 Normal;
	vec2 texCoord0;
	//vec3 Tangent;
	//vec3 Bitangent;
	vec4 mapColor;
	//vec4 grassNoise;
	vec4 instanceParamsVS;
	vec4 debuginfo;
};

//__ENGINEUNIFORMBUFFERDEFS__

out vec4 fragColor;

void main() {
	fragColor = texture(grassBladeColorTex, texCoord0);
	fragColor.rgb = mix(fragColor.rgb,fragColor.rgb * (mapColor.rgb * 2.0), MAPCOLORFACTOR); //blend mapcolor multiplicative
	fragColor.rgb = mix(fragColor.rgb,mapColor.rgb, (1.0 - texCoord0.y)* MAPCOLORBASE); // blend more mapcolor mix at base
	//fragColor.rgb = fragColor.rgb * 0.8; // futher darken
	fragColor.rgb = mix(fogColor.rgb,fragColor.rgb, mapColor.a ); // blend fog
	fragColor.a = fragColor.a * grassuniforms.w * instanceParamsVS.x; // increase transparency with distance
	fragColor.rgb = fragColor.rgb * instanceParamsVS.y; // darken with shadows
	fragColor.rgb = fragColor.rgb * instanceParamsVS.z; // darken out of los
	fragColor.rgb = fragColor.rgb * instanceParamsVS.w; // darken with windnoise
	fragColor.rgb *= GRASSBRIGHTNESS;

	fragColor.a = clamp((fragColor.a-0.5) * 1.5 + 0.5, 0.0, 1.0);

	//fragColor.rgb = vec3(instanceParamsVS.y	);
	//fragColor.a = 1;
	//fragColor = vec4(debuginfo.r,debuginfo.g, 0, (debuginfo.g)*5	);
	//fragColor = vec4(1.0, 1.0, 1.0, 1.0);
	//fragColor = vec4(debuginfo.w*5, 1.0 - debuginfo.w*5.0, 0,1.0);
	fragColor.a *= clamp(debuginfo.w *3,0.0,1.0);
	if (fragColor.a < ALPHATHRESHOLD) // needed for depthmask
	discard;
}
]]

local function makeShaderVAO()

  local grassShaderParams = ""
  for k,v in pairs(grassConfig.grassShaderParams) do
      grassShaderParams = grassShaderParams .. "#define "..k.." "..tostring(v).."\n"
  end

  grassVertexShaderDebug = vsSrc:gsub("//__DEFINES__", grassShaderParams)
  grassFragmentShaderDebug = fsSrc:gsub("//__DEFINES__", grassShaderParams)

  local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
  grassVertexShaderDebug = grassVertexShaderDebug:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
  grassFragmentShaderDebug = grassFragmentShaderDebug:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)

  grassShader = LuaShader(
    {
      vertex = grassVertexShaderDebug,
      fragment = grassFragmentShaderDebug,
      --geometry = gsSrc, no geom shader for now
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
      },
    },
    "GrassShaderGL4"
  )
  shaderCompiled = grassShader:Initialize()

  if not shaderCompiled then goodbye("Failed to compile grassShader GL4 ") end

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

local function GadgetWeaponExplosionGrass(px, py, pz, weaponID, ownerID)
	if not placementMode and weaponConf[weaponID] ~= nil and py - 10 < spGetGroundHeight(px, pz) then
		--Spring.Echo(weaponConf[weaponID])
		adjustGrass(px, pz, weaponConf[weaponID][1], math.min(1, (weaponConf[weaponID][1]*weaponConf[weaponID][2])/45))
	end
end

function widget:Initialize()
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
	widgetHandler:RegisterGlobal('GadgetWeaponExplosionGrass', GadgetWeaponExplosionGrass)
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal('GadgetRemoveGrass')
	widgetHandler:DeregisterGlobal('GadgetWeaponExplosionGrass')
end

function widget:TextCommand(command)
	-- savegrass filename
	--Spring.Echo(command)
	if string.find(command,"placegrass", nil, true ) == 1 then
		placementMode = not placementMode
		Spring.Echo("Grass placement mode toggle to:",placementMode)
	end

	if string.find(command,"savegrass", nil, true ) == 1 then
		local filename = string.sub(command, 11)
		if string.len(filename) < 2 then
			filename = Game.mapName .. "_grassDist.tga"
		end
		Spring.Echo("Savegrass: ",filename)

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

	if string.find(command,"loadgrass", nil, true ) == 1 then
		placementMode = true
		local filename = string.sub(command,11)
		if string.len(filename) < 2 then
			filename = Game.mapName .. "_grassDist.tga"
		end
		Spring.Echo("Loadgrass: ",filename)

		LoadGrassTGA(filename)
		defineUploadGrassInstanceVBOData()
		MakeAndAttachToVAO()
		--grassVAO:AttachInstanceBuffer(grassInstanceVBO)
	end

	if string.find(command,"editgrass", nil, true ) == 1 then
		placementMode = true
		makeGrassInstanceVBO()
		defineUploadGrassInstanceVBOData()
		MakeAndAttachToVAO()
		--grassVAO:AttachInstanceBuffer(grassInstanceVBO)
	end

	if string.find(command,"cleargrass", nil, true ) == 1 then
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

	if string.find(command,"dumpgrassshaders", nil, true ) == 1 then
		Spring.Echo(grassVertexShaderDebug)
		Spring.Echo(grassFragmentShaderDebug)
		--grassVAO:AttachInstanceBuffer(grassInstanceVBO)
	end
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
local spTraceScreenRay = Spring.TraceScreenRay

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

function widget:DrawWorldPreUnit()
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
  if cy  < ((grassConfig.grassShaderParams.FADEEND*distanceMult) + gh) and grassVAO ~= nil and #grassInstanceData > 0 then
	local startInstanceIndex = 0
	local instanceCount =  #grassInstanceData/4
    if not placementMode then
		startInstanceIndex, instanceCount = GetStartEndRows()
	end
    local _, _, isPaused = Spring.GetGameSpeed()
    if not isPaused then
      getWindSpeed()
      offsetX = offsetX - ((windDirX * grassConfig.grassWindMult) * timePassed)
      offsetZ = offsetZ - ((windDirZ * grassConfig.grassWindMult) * timePassed)
    end

    local globalgrassfade = math.max(0.0,math.min(1.0,
		((grassConfig.grassShaderParams.FADEEND*distanceMult) - (cy-gh))/((grassConfig.grassShaderParams.FADEEND*distanceMult)-(grassConfig.grassShaderParams.FADESTART*distanceMult))))

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
    grassShader:SetUniform("grassuniforms", offsetX, offsetZ, windStrength, globalgrassfade)

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
