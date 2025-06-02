local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name	= "CUS GL4",
		desc	= "Implements CustomUnitShaders for GL4 rendering pipeline",
		version = "0.5",
		author	= "ivand, Beherith",
		date 	= "20220310",
		license = "GNU GPL, v2 or later",
		layer	= 0,
		enabled	= true,
		depends = {'gl4'},
	}
end

if gadgetHandler:IsSyncedCode() then
	return false
end

-- Beheriths notes

-- Bins / separate VAO and IBO :
	-- Flags (drawpass):
		-- forward opaque + reflections
		-- deferred opaque, all units
		-- shadows. Now all units need their vertex displacement for efficient shadows, so better to bind a separate shader for this
	-- Shaders / shaderconfig via bitoptions uniform:
		-- Features
			-- simplefeatures: metallic nonwrecks
			-- treepbr: Real Trees with proper tex2
			-- tree: Shitty Trees
			-- wrecks: BAR wrecks
		-- Units
			-- tanks : -- these are units actually
			-- barunits :
			-- raptors
			-- scavengers
			--

		-- Cloakedunits for alpha
		-- Underconstructionunits


	-- Textures:
		-- arm/cor
		-- 10x raptorsets
		-- 5x featuresets
		-- scavengers?
	-- Objects (the VAO)
		-- 8x 8x 16x -> 8192 different VAOs? damn thats horrible
	-- Note that Units and Features cant share a VAO!

	-- Can we assume that all BAR units wont have transparency?
		-- if yes then we can say that forward and deferred can share!
	-- https://stackoverflow.com/questions/8923174/opengl-vao-best-practices
	-- Some shader optimization info: https://community.khronos.org/t/profiling-optimizing-a-fragment-shader-in-linux/105144/3



-- TODO:
	-- Under construction shader via uniform
		-- (READ THE ONE FROM HEALTHBARS!)
	-- DONE treadoffset unitUniform
	-- DONE: BITOPTIONS UNIFOOOOORM!
	-- normalmapping
	-- raptors
	-- tanktracks
	-- Reflection camera
	-- refraction camera
	-- texture LOD bias of -0.5, maybe adaptive for others
	-- still extremely perf heavy
		-- 1440p, Red Comet, fullscreen zoomed onto a corvp, SSAO on, Bloom On
			-- 110 FPS on corvp with oldcus
			-- 180 FPS without disablecus
		-- 1440p, Red Comet, fullscreen zoomed onto a corvp, SSAO off, Bloom off
			-- 130 fps oldcus
			-- 256 fps disablecus

	-- separate VAO and IBO for each 'bin' for less heavy updates
	-- Do alpha units also get drawn into deferred pass? Seems like no, because only flag == 1 is draw into that
	-- DONE: dynamically size IBOS instead of using the max of 8192!
		-- Starts from 32
	-- DONE  new engine callins needed:
		-- get the number of drawflaggable units (this is kind of gettable already from the API anyway)
		-- get the number of changed drawFlags
		-- if the number of changed drawflags > log(numdrawflags) then do a full rebuild instead of push-popping
		-- e.g if there are 100 units of a bin in view, then a change of ~ 8 units will trigger a full rebuild?
			-- cant know ahead of time how many per-bin changes this will trigger though

	-- DONE: write an engine callin that, instead of the full list of unitdrawflags, only returns the list of units whos drawflags have changed!
		-- reset this 'hashmap' when reading it
		-- also a problem is handling units that died, what 'drawflag' should they get?
			-- probably 0

	-- TODO: handle fast rebuilds of the IBO's when large-magnitude changes happen
		-- this is made difficult by the negative featureID crap


	-- TODO: faster bitops maybe?
	-- DONE: we dont handle shaderOptions yet for batches, where we are to keep the same shader, but only change its relevant options uniform

	-- NOTE: It seems that we are generally, and heavily fragment shader limited in most synthetic tests with large numbers of units spreading into full view
		-- in this case, the perf of oldcus and gl4cus is actually similar, (similar FS), but vanilla still outperforms

	-- DONE: Too many varyings are passed from VS to FS.
		-- Specify some as flat, to avoid interpolation (e.g. teamcolor and selfillummod and maybe even fogfactor
		-- reduce total number of these varyings
		-- we can save a varying here and there, but mostly done

	-- Done: GetTextures() is not the best implementation at the moment

	-- NOTE: in general, a function call is about 10x faster than a table lookup....

	-- DONE: how to handle units under construction? They cant be their own completely separate shit, cause of textures...
		-- might still make sense to do so
		-- they are handled by completely ignoring them

	-- DONE: fully blank normal map for non-normal mapped units (or else risk having to write a shader for that bin, which wont even get used

	-- DONE: alpha cloaked unitses :/
		-- also handled by completely leaving them out

	-- Done: feature drawing bits too

	-- TODO: rewrite treewave

	-- DONE: feature override metalness/roughness via uniforms

	-- TODO: fix flashlights to be piece-unique

	-- DONE: AVOID DISCARD in FS AT ALL COST!
		-- 500 armcom fullview is 82 vs 108 fps with nodiscard!
		-- Even if discard is in a never-called dynamically uniform!
		-- only transparent features need discard

	-- DONE:
		-- only ever use discard in deferred pass, dont use it in forward refl or shadow though
		-- DEFERRED FEATURE TREE DRAW IS WRONG

	-- TODO: investigate why/how refraction pass doesnt ever seem to get called
		-- kill the entire pass with fire (by ignoring its existence)

	-- TODO: reduce the amount of deferred buffers being used from 6 to 4

	-- TODO: check if LuaShader UniformLocations are cached

	-- DONE: add a wreck texture to raptors! It uses lavadistortion texture, its fine

	-- TODO: Use a 3d texture lookup instead of perlin implementation for damage shading

	-- TODO: separate out damaged units for better perf, damage shading is not free! (as damage is not dynamically uniform across all shader invocations)
		-- very difficult, unsure if worth anything in the long run

	-- TODO: Also add alpha units to deferred pass somehow?

	-- TODO: engine side: optimize shadow camera as it massively overdraws

	-- Done: reflection camera is also totally fucked up
		-- It seems that aircraft get removed from reflection pass if water depth is < -70
		-- hovers randomly do and dont get reflections based on water depth
		-- fixed in-engine, seems like a reasonably good fix too, though could be better
			-- is checking 5 groundheights within drawradius better than some minor overdraw cause of not-too-high above water ground shit?

	-- DONE: increase bumpwaterreflectcubetex size
	-- TODO: make lava disable drawing reflections!

	-- TODO: shared bins for deferred and forward and maybe even reflection?
		-- The sharing could be done on the uniformbin level, and this is quite elegant in general too, as tables are shared by reference....
		-- DONE: shared deferred and forward via ultimate cleverness!

	-- DONE: Specular highlights should also bloom, not just emissive!

	-- DONE: Cleaner Shutdown and reloadcusgl4 and disablecusgl4

	-- TODO: Get BRDFLUT from API_PBR_ENABLER (OR build your own float16 texture)

	-- TODO: WE ARE DRAWING ALL IN THE UNITS PASS INSTEAD OF BOTH FEATURE AND UNITS PASS! (can that bite us in the ass?)


	-- TODO: Reimplement featureFade, as it can kill perf on heavily forested maps and potatos

	-- DONE: GetTexturesKey is probably slow too!

	-- TODO: Shadows are 1 drawframe late, maybe update lists in DrawGenesis instead of DrawWorldPreUnit
	-- TODO: we need to update things earlier, to get the shadow stuff in on time

	-- Done: GetTextures :
		-- should return array table instead of hash table
			-- fill in unused stuff with 'false' for contiguous array table
			-- index -1
			-- oddly enough, accessing array tables instead of hash tables is only 25% faster, so the overhead of -1 might not even result in any perf gains

		-- Should also get the normalmaps for each unit!
		-- PBR textures:
			-- uniform sampler2D brdfLUT;			//9
			-- uniform sampler2D envLUT;			//10
			-- uniform samplerCube reflectTex; 		// 7

			-- uniform sampler2D losMapTex;	//8 for features out of los maybe?

		-- We also need the skybox cubemap for PBR (samplerCube reflectTex)
		-- We also need wrecktex for damaged units!

	-- Create a default 'wrecktex' for features too?

	-- TODO: Check the double-calls that happens when a unit is destroyed and fucks with out flags on update too

-- DONE:
	-- unit uniforms
-- KNOWN BUGS:
	-- Unitdestroyed doesnt trigger removal?

-- Export important things

---------------------------- SHADERUNITUNIFORMS / BITSHADEROPTIONS ---------------------------------------------

-- We can use the SUniformsBuffer vec4 uni[instData.y].userDefined[5] to pass data persistent unit-info
-- floats 0-5 are already in use by HealthBars



-- Set autoReload.enabled = true to enable on-the-fly editing of shaders.
local autoReload = {enabled = false, vssrc = "", fssrc = "", lastUpdate = Spring.GetTimer(), updateRate = 0.5}

-- Indicates wether the first round of getting units should grab all instead of delta
local manualReload = autoReload.enabled or false
local debugmode = false
local perfdebug = false

-- These 4 things are for the UnitViewportAPI
local unitsInViewport = {} -- unitID:drawFlag
local numUnitsInViewport = 0
local featuresInViewport = {} --featureID:featureDefID
local numFeaturesInViewport = 0

local objectDefToBitShaderOptions = {} -- This is a table containing positive UnitIDs, negative featureDefIDs to bitShaderOptions mapping

local objectDefToUniformBin = {} -- maps unitDefID/featuredefID to a uniform bin
-- IMPORTANT: OBJECTID AND OBJECTDEFID ARE ALWAYS POS FOR UNITS, NEG FOR FEATURES!
-- this will still use the same shader, but we gotta switch uniforms in between for efficiency
-- a uniform bin contains
-- objectDefs are negative for features
-- objectIDs are negative for features too

local function GetUniformBinID(objectDefID, reason)
	if objectDefID and objectDefToUniformBin[objectDefID] then
		return objectDefToUniformBin[objectDefID]
	else
		if debugmode then
			Spring.Echo("Failed to find a uniform bin id for objectDefID", objectDefID, reason)
		end
		return 'otherunit'
	end
end

local uniformBins = {}

do --save a ton of locals
	local OPTION_SHADOWMAPPING    = 1
	local OPTION_NORMALMAPPING    = 2
	local OPTION_SHIFT_RGBHSV     = 4 -- userDefined[2].rgb (gl.SetUnitBufferUniforms(unitID, {math.random(),math.random()-0.5,math.random()-0.5}, 8) -- shift Hue, saturation, valence )
	local OPTION_VERTEX_AO        = 8
	local OPTION_FLASHLIGHTS      = 16
	local OPTION_TREADS_ARM      = 32
	local OPTION_TREADS_CORE     = 64
	local OPTION_HEALTH_TEXTURING = 128
	local OPTION_HEALTH_DISPLACE  = 256
	local OPTION_HEALTH_TEXRAPTORS = 512
	local OPTION_MODELSFOG        = 1024
	local OPTION_TREEWIND         = 2048
	local OPTION_PBROVERRIDE      = 4096
	local OPTION_TREADS_LEG       = 8192

	local defaultBitShaderOptions = OPTION_SHADOWMAPPING + OPTION_NORMALMAPPING  + OPTION_MODELSFOG

	uniformBins = {
		armunit = {
			bitOptions = defaultBitShaderOptions + OPTION_VERTEX_AO + OPTION_FLASHLIGHTS + OPTION_TREADS_ARM + OPTION_HEALTH_TEXTURING + OPTION_HEALTH_DISPLACE,
			baseVertexDisplacement = 0.0,
			brightnessFactor = 1.5,
		},
		corunit = {
			bitOptions = defaultBitShaderOptions + OPTION_VERTEX_AO + OPTION_FLASHLIGHTS + OPTION_TREADS_CORE + OPTION_HEALTH_TEXTURING + OPTION_HEALTH_DISPLACE,
			baseVertexDisplacement = 0.0,
			brightnessFactor = 1.5,
		},
		legunit = {
			bitOptions = defaultBitShaderOptions + OPTION_VERTEX_AO + OPTION_FLASHLIGHTS + OPTION_TREADS_LEG + OPTION_HEALTH_TEXTURING + OPTION_HEALTH_DISPLACE,
			baseVertexDisplacement = 0.0,
			brightnessFactor = 1.5,
		},
		armscavenger = {
			bitOptions = defaultBitShaderOptions + OPTION_VERTEX_AO + OPTION_FLASHLIGHTS + OPTION_TREADS_ARM + OPTION_HEALTH_TEXTURING + OPTION_HEALTH_DISPLACE,
			baseVertexDisplacement = 0.4,
			brightnessFactor = 1.5,
		},
		corscavenger = {
			bitOptions = defaultBitShaderOptions + OPTION_VERTEX_AO + OPTION_FLASHLIGHTS + OPTION_TREADS_CORE + OPTION_HEALTH_TEXTURING + OPTION_HEALTH_DISPLACE,
			baseVertexDisplacement = 0.4,
			brightnessFactor = 1.5,
		},
		legscavenger = {
			bitOptions = defaultBitShaderOptions + OPTION_VERTEX_AO + OPTION_FLASHLIGHTS + OPTION_TREADS_LEG + OPTION_HEALTH_TEXTURING + OPTION_HEALTH_DISPLACE,
			baseVertexDisplacement = 0.4,
			brightnessFactor = 1.5,
		},
		raptor = {
			bitOptions = defaultBitShaderOptions + OPTION_VERTEX_AO + OPTION_FLASHLIGHTS  + OPTION_HEALTH_DISPLACE + OPTION_HEALTH_TEXRAPTORS + OPTION_TREEWIND + OPTION_SHIFT_RGBHSV,
			baseVertexDisplacement = 0.0,
			brightnessFactor = 1.5,
		},
		otherunit = {
			bitOptions = defaultBitShaderOptions,
			baseVertexDisplacement = 0.0,
			brightnessFactor = 1.5,
		},
		feature = {
			bitOptions = defaultBitShaderOptions + OPTION_PBROVERRIDE,
			baseVertexDisplacement = 0.0,
			brightnessFactor = 1.3,
		},
		featurepbr = {
			bitOptions = defaultBitShaderOptions,
			baseVertexDisplacement = 0.0,
			brightnessFactor = 1.3,
		},
		treepbr = {
			bitOptions = defaultBitShaderOptions + OPTION_TREEWIND + OPTION_PBROVERRIDE,
			baseVertexDisplacement = 0.0,
			brightnessFactor = 1.3,
		},
		tree = {
			bitOptions = defaultBitShaderOptions + OPTION_TREEWIND + OPTION_PBROVERRIDE,
			baseVertexDisplacement = 0.0,
			brightnessFactor = 1.3,
		},
		wreck = {
			bitOptions = defaultBitShaderOptions,
			baseVertexDisplacement = 0.0,
			brightnessFactor = 1.3,
		},
	} -- maps uniformbins to a table of uniform names/values
end

local overrideDrawFlags = {
	[0]  = true , --SO_OPAQUE_FLAG = 1, deferred hack
	[1]  = true , --SO_OPAQUE_FLAG = 1,
	[2]  = true , --SO_ALPHAF_FLAG = 2, -- THIS IS MIXED DOWN INTO SO_OPAQUE_FLAG
	[4]  = true , --SO_REFLEC_FLAG = 4,
	[8]  = true , --SO_REFRAC_FLAG = 8,
	[16] = true , --SO_SHADOW_FLAG = 16,
	[32] = true , --SO_SHTRAN_FLAG = 32, -- this is shadow transparency flag, to draw shadows into transparent pass 
				  --SO_DRICON_FLAG = 128, -- 
}

--implementation
local overrideDrawFlag = 0 -- should sum to 65
for flagbit, isset in pairs(overrideDrawFlags) do
	overrideDrawFlag = overrideDrawFlag + flagbit * (isset and 1 or 0)
end
--      deferred    fw  fwrfl  fwrfr  op oprfl  oprfr  shadow
--         0         1    5     9     2    6     10     16
-- deferred is handled by just copying fw
-- refraction and alpha are just dumped
-- local drawBinKeys = {1, 1 + 4, 1 + 8, 2, 2 + 4, 2 + 8, 16}
local drawBinKeys = {1, 1 + 4, 16}

local overrideDrawFlagsCombined = {
	[0    ] = overrideDrawFlags[0],
	[1    ] = overrideDrawFlags[1],
	[1 + 4] = overrideDrawFlags[1] and overrideDrawFlags[4],
	--[1 + 8] = overrideDrawFlags[1] and overrideDrawFlags[8],
	--[2    ] = overrideDrawFlags[2],
	--[2 + 4] = overrideDrawFlags[2] and overrideDrawFlags[4],
	--[2 + 8] = overrideDrawFlags[2] and overrideDrawFlags[8],
	[16   ] = overrideDrawFlags[16],
}

local cusUnitIDtoDrawFlag = {} -- {unitID = drawFlag,...}, these remain positive, as they are traversed separately

-- For managing under construction units:
local buildProgresses = {} -- keys unitID, value buildprogress, updated each frame for units being built
local uniformCache = {}
local spGetUnitHealth = Spring.GetUnitHealth
-- local processedUnits = {}

local cusFeatureIDtoDrawFlag = {} -- {featureID = drawFlag,...}, this remains positive
-- local processedFeatures = {}

-- This is the main table of all the unit drawbins:
-- It is organized like so:
-- unitDrawBins[drawFlag][shaderID][textureKey] = {
	-- textures = {
	   -- 0 = %586:1 -- in this example, its just texture 1
	-- },
	-- objects = {
	   -- 31357 = true
	   -- 20174 = true
	   -- 29714 = true
	   -- 3024 = true
	   -- 24268 = true
	   -- 5584 = true
	   -- 5374 = true
	   -- 26687 = true
	-- },
	-- VAO = vao,
	-- IBO = ibo,
	-- objectsArray = {}, -- {index: objectID}
	-- objectsIndex = {}, -- {objectID : index} (this is needed for efficient removal of items, as RemoveFromSubmission takes an index as arg)
	-- numobjects = 0,  -- a 'pointer to the end'
-- }

local unitDrawBins = nil -- this also controls wether cusgl4 is on at all!

local objectIDtoDefID = {}


local shaders = {} -- double nested table of {drawflag : {"units":shaderID}}

local modelsVertexVBO = nil
local modelsIndexVBO = nil

local INITIAL_VAO_SIZE = 32

local objectTypeAttribID = 6 -- this is the attribute index for instancedata in our VBO

local initiated = false

local function Bit(p)
	return 2 ^ (p - 1)  -- 1-based indexing
end

-- Typical call:  if hasbit(x, bit(3)) then ...
local function HasBit(x, p)
	return x % (p + p) >= p
end

local math_bit_and = math.bit_and
local function HasAllBits(x, p)
	return math_bit_and(x, p) == p
end

local function SetBit(x, p)
	return HasBit(x, p) and x or x + p
end

local function ClearBit(x, p)
	return HasBit(x, p) and x - p or x
end

local featuresDefsWithAlpha = {}
local unitDefsUseSkinning = {}

local function GetShader(drawPass, objectDefID)
	if objectDefID == nil then
		return false
	end
	if objectDefID >= 0 then
		if unitDefsUseSkinning[objectDefID] then 
			return shaders[drawPass]['unitskinning']
		else
			return shaders[drawPass]['unit']
		end
	else
		if featuresDefsWithAlpha[objectDefID] then
			return shaders[drawPass]['tree']
		else
			return shaders[drawPass]['feature']
		end
	end
end

local function GetShaderName(drawPass, objectDefID) 
	-- this function does 2 table lookups, could get away with just one. 
	if objectDefID == nil then
		return false
	end
	if objectDefID >= 0 then
		if unitDefsUseSkinning[objectDefID] then 
			return 'unitskinning'
		else
			return 'unit'
		end
	else
		if featuresDefsWithAlpha[objectDefID] then
			return 'tree'
		else
			return 'feature'
		end
	end
end

local function SetFixedStatePre(drawPass, shaderID)
	if HasBit(drawPass, 4) then
		gl.ClipDistance(0, true)
	elseif HasBit(drawPass, 8) then
		gl.ClipDistance(0, true)
	end
end

local function SetFixedStatePost(drawPass, shaderID)
	if HasBit(drawPass, 4) then
		gl.ClipDistance(0, false)
	elseif HasBit(drawPass, 8) then
		gl.ClipDistance(0, false)
	end
end

local function SetShaderUniforms(drawPass, shaderID, uniformBinID)
	gl.UniformInt(gl.GetUniformLocation(shaderID, "drawPass"), drawPass)

	-- The clip plane is used for above/below water, for the reflection and refraction cameras only
	if HasBit(drawPass, 4) then
		gl.Uniform(gl.GetUniformLocation(shaderID, "clipPlane0"), 0.0, 1.0, 0.0, 0.0)
	elseif HasBit(drawPass, 8) then
		gl.Uniform(gl.GetUniformLocation(shaderID, "clipPlane0"), 0.0, -1.0, 0.0, 0.0)
	else
		-- This will cull stuff that are not in view of the camera. Not too useful methinks
		gl.Uniform(gl.GetUniformLocation(shaderID, "clipPlane0"), 0.0, 0.0, 0.0, 1.0)
	end

	for uniformLocationName, uniformValue in pairs(uniformBins[uniformBinID]) do
		if uniformLocationName == 'bitOptions' then
			gl.UniformInt(gl.GetUniformLocation(shaderID, uniformLocationName), uniformValue)
		else
			gl.Uniform(gl.GetUniformLocation(shaderID, uniformLocationName), uniformValue)
		end
	end


end
------------------------- SHADERS                   ----------------------
------------------------- LOADING OLD CUS MATERIALS ----------------------

local LuaShader = gl.LuaShader

local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()


local defaultMaterialTemplate
local unitsNormalMapTemplate
local unitsSkinningTemplate -- This is reserved for units with skinning animations
local featuresNormalMapTemplate
local treesNormalMapTemplate

function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

local function appendShaderDefinitionsToTemplate(template, alldefinitions)
	local copytemplate = deepcopy(template)
	for i, singleShaderDefs in ipairs({"shaderDefinitions", "deferredDefinitions", "shadowDefinitions", "reflectionDefinitions"}) do
		if alldefinitions[singleShaderDefs] then
			if copytemplate[singleShaderDefs] == nil then
				copytemplate[singleShaderDefs] = {}
			end
			for j, defline in ipairs(alldefinitions[singleShaderDefs]) do
				copytemplate[singleShaderDefs][ #copytemplate[singleShaderDefs] + 1 ] = defline
			end
		end
	end
	return copytemplate
end

local itsXmas = false
local function initMaterials()
	defaultMaterialTemplate = VFS.Include("modelmaterials_gl4/templates/defaultMaterialTemplate.lua")
	if itsXmas then
		Spring.Echo("CUS GL4 enabled XMAS mode")
	end


	unitsNormalMapTemplate = appendShaderDefinitionsToTemplate(defaultMaterialTemplate, {
		shaderDefinitions = {
			"#define ENABLE_OPTION_HEALTH_TEXTURING 1",
			"#define ENABLE_OPTION_TREADS 1",
			"#define ENABLE_OPTION_HEALTH_DISPLACE 1",
			itsXmas and "#define XMAS 1" or "#define XMAS 0",
		},
		deferredDefinitions = {
			"#define ENABLE_OPTION_HEALTH_TEXTURING 1",
			"#define ENABLE_OPTION_TREADS 1",
			"#define ENABLE_OPTION_HEALTH_DISPLACE 1",
			itsXmas and "#define XMAS 1" or "#define XMAS 0",
		},
		shadowDefinitions = {
			itsXmas and "#define XMAS 1" or "",
		},
		reflectionDefinitions = {
			"#define ENABLE_OPTION_HEALTH_TEXTURING 1",
			"#define ENABLE_OPTION_TREADS 1",
			"#define ENABLE_OPTION_HEALTH_DISPLACE 1",
			itsXmas and "#define XMAS 1" or "#define XMAS 0",
		},
	})


	unitsSkinningTemplate = appendShaderDefinitionsToTemplate(defaultMaterialTemplate, {
		shaderDefinitions = {
			"#define ENABLE_OPTION_HEALTH_TEXTURING 1",
			"#define ENABLE_OPTION_TREADS 1",
			"#define ENABLE_OPTION_HEALTH_DISPLACE 1",
			"#define USESKINNING",
			itsXmas and "#define XMAS 1" or "#define XMAS 0",
		},
		deferredDefinitions = {
			"#define ENABLE_OPTION_HEALTH_TEXTURING 1",
			"#define ENABLE_OPTION_TREADS 1",
			"#define ENABLE_OPTION_HEALTH_DISPLACE 1",
			"#define USESKINNING",
			itsXmas and "#define XMAS 1" or "#define XMAS 0",
		},
		shadowDefinitions = {
			"#define USESKINNING",
			itsXmas and "#define XMAS 1" or "",
		},
		reflectionDefinitions = {
			"#define ENABLE_OPTION_HEALTH_TEXTURING 1",
			"#define ENABLE_OPTION_TREADS 1",
			"#define ENABLE_OPTION_HEALTH_DISPLACE 1",
			"#define USESKINNING",
			itsXmas and "#define XMAS 1" or "#define XMAS 0",
		},
	})

	featuresNormalMapTemplate = appendShaderDefinitionsToTemplate(defaultMaterialTemplate, {
		shaderDefinitions = {
			"#define USE_LOSMAP",
		},
		deferredDefinitions = {
			"#define USE_LOSMAP",
		},
		shadowDefinitions = {
			--"#define HASALPHASHADOWS",
		},
		reflectionDefinitions = {
			"#define USE_LOSMAP",
		},
	})

	treesNormalMapTemplate = appendShaderDefinitionsToTemplate(defaultMaterialTemplate, {
		shaderDefinitions = {
			"#define USE_LOSMAP",
			"#define HASALPHASHADOWS",
			"#define TREE_RANDOMIZATION",
		},
		deferredDefinitions = {
			"#define USE_LOSMAP",
			"#define HASALPHASHADOWS",
			"#define TREE_RANDOMIZATION",
		},
		shadowDefinitions = {
			"#define HASALPHASHADOWS",
			"#define TREE_RANDOMIZATION",
		},
		reflectionDefinitions = {
			"#define TREE_RANDOMIZATION",
			"#define USE_LOSMAP",
			"#define HASALPHASHADOWS",
		},
	})
end

local DEFAULT_VERSION = [[#version 430 core
	#extension GL_ARB_uniform_buffer_object : require
	#extension GL_ARB_shader_storage_buffer_object : require
	#extension GL_ARB_shading_language_420pack: require
	]]

local function dumpShaderCodeToFile(defs, src, filename) -- no IO in unsynced gadgets :/
	local vsfile = io.open('cus_' .. filename .. ".glsl","w+")
	vsfile:write(defs .. src)
	vsfile:close()
end

local function dumpShaderCodeToInfolog(defs, src, filename) -- no IO in unsynced gadgets :/
	Spring.Echo(filename)
	Spring.Echo(defs)
	Spring.Echo(src)
end

local function CompileLuaShader(shader, definitions, plugIns, addName, recompilation)
	--Spring.Echo(" CompileLuaShader",shader, definitions, plugIns, addName)
	if definitions == nil or definitions == {} then
		Spring.Echo(addName, "nul definitions", definitions)
	end
	definitions = definitions or {}

	local hasVersion = false
	if definitions[1] then -- #version must be 1st statement or else AMD throws a fit
		hasVersion = string.find(definitions[1], "#version") == 1
	end

	if not hasVersion then
		table.insert(definitions, 1, DEFAULT_VERSION)
	end

	-- First the default default defs
	shader.definitions = table.concat(definitions, "\n") .. "\n"

	-- Then the engineUniformBufferDefs (see LuaShader.lua)
	shader.definitions = shader.definitions .. engineUniformBufferDefs

	--// insert small pieces of code named `plugins`
	--// this way we can use a basic shader and add some simple vertex animations etc.
	do
		local function InsertPlugin(str)
			return (plugIns and plugIns[str]) or ""
		end

		if shader.vertex then
			shader.vertex   = shader.vertex:gsub("%%%%([%a_]+)%%%%", InsertPlugin)
		end
		if shader.fragment then
			shader.fragment = shader.fragment:gsub("%%%%([%a_]+)%%%%", InsertPlugin)
		end
		if shader.geometry then
			shader.geometry = shader.geometry:gsub("%%%%([%a_]+)%%%%", InsertPlugin)
		end
	end

	local luaShader = LuaShader(shader, "CUS_" .. addName)
	local compilationResult = luaShader:Initialize()
	if compilationResult ~= true then
		Spring.Echo("Custom Unit Shaders. " .. addName .. " shader compilation failed")
		--dumpShaderCodeToInfolog(shader.definitions, shader.vertex, "vs" .. addName)
		--dumpShaderCodeToInfolog(shader.definitions, shader.fragment, "fs" .. addName)
		if not recompilation then 
			gadgetHandler:RemoveGadget()
		end
		return nil
	end

	return (compilationResult and luaShader) or nil
end

local function compileMaterialShader(template, name, recompilation)
	--Spring.Echo("Compiling", template, name)
	local forwardShader = CompileLuaShader(template.shader, template.shaderDefinitions, template.shaderPlugins, name .."_forward" , recompilation)
	local shadowShader = CompileLuaShader(template.shadow, template.shadowDefinitions, template.shaderPlugins, name .."_shadow" , recompilation)
	local deferredShader = CompileLuaShader(template.deferred, template.deferredDefinitions, template.shaderPlugins, name .."_deferred" , recompilation)
	local reflectionShader = CompileLuaShader(template.reflection, template.reflectionDefinitions, template.shaderPlugins, name .."_reflection" , recompilation)
	if recompilation then
		if (not forwardShader) or (not shadowShader) or (not deferredShader) or (not reflectionShader) then 
			-- This is a recompilation attempt that failed, so we are not going to replace the shader objects themselves
			return nil
		end
	end
	
	for k = 1, #drawBinKeys do
		local flag = drawBinKeys[k]
		shaders[flag][name] = forwardShader
	end
	shaders[0 ][name] = deferredShader
	shaders[5 ][name] = reflectionShader
	shaders[16][name] = shadowShader
	return true
end

-- Order of textures in shader:
	-- uniform sampler2D texture1;			//0
	-- uniform sampler2D texture2;			//1
	-- uniform sampler2D normalTex;		//2

	-- uniform sampler2D texture1w;		//3
	-- uniform sampler2D texture2w;		//4
	-- uniform sampler2D normalTexw;		//5

	-- uniform sampler2DShadow shadowTex;	//6
	-- uniform samplerCube reflectTex;		//7

	-- uniform sampler2D losMapTex;	//8

	-- uniform sampler2D brdfLUT;			//9

local textureKeytoSet = {} -- table of {TextureKey : {textureTable}}

local blankNormalMap = "unittextures/blank_normal.dds"
local noisetex3dcube =  "LuaUI/images/noisetextures/noise64_cube_3.dds"

local fastObjectDefIDtoTextureKey = {} -- table of  {unitDefID : TextureKey, -featureDefID : TextureKey }
local fastTextureKeyCache = {} -- a table of concatenated texture names to increasing integers
local numfastTextureKeyCache = 0

--- Hashes a table of textures to a unique integer
-- @param textures a table of {bindposition:texture}
-- @return a unique hash for binning
local function GenFastTextureKey(objectDefID, objectDef, normaltexpath, texturetable) -- return integer
	if objectDef.model == nil or objectDef.model.textures == nil then
		return 0
	end

	local tex1 = string.lower(objectDef.model.textures.tex1 or "")
	local tex2 = string.lower(objectDef.model.textures.tex2 or "")
	normaltexpath = string.lower(normaltexpath or "")
	local strkey = tex1 .. tex2 .. normaltexpath
	for i=3, 20 do -- from 3 since 0-1-2 are tex12 and normals, and this guarantees order of the table
		if texturetable[i] then
			strkey = strkey .. texturetable[i]
		end
	end

	if fastTextureKeyCache[strkey] then  -- already exists
		fastObjectDefIDtoTextureKey[objectDefID] = fastTextureKeyCache[strkey]
	else
		numfastTextureKeyCache = numfastTextureKeyCache + 1
		fastTextureKeyCache[strkey] = numfastTextureKeyCache
		fastObjectDefIDtoTextureKey[objectDefID] = numfastTextureKeyCache
		--Spring.Echo("GenFastTextureKey", strkey, fastTextureKeyCache[strkey])
	end
	return fastTextureKeyCache[strkey]
end

local wreckAtlases = {
	["arm"] = { -- these are only here for posterity
		"unittextures/Arm_wreck_color.dds",
		"unittextures/Arm_wreck_other.dds",
		"unittextures/Arm_wreck_color_normal.dds",
	},
	["cor"] = { 
		"unittextures/cor_color_wreck.dds",
		"unittextures/cor_other_wreck.dds",
		"unittextures/cor_color_wreck_normal.dds",
	},
	["leg"] = {
		"unittextures/leg_wreck_color.dds",
		"unittextures/leg_wreck_shader.dds",
		"unittextures/leg_wreck_normal.dds",
	},
	["raptor"] = {
		"luaui/images/lavadistortion.png",
	}
}

local brdfLUT = "modelmaterials_gl4/brdf_0.png"

local existingfilecache = {} -- this speeds up the VFS calls

local function GetNormal(unitDef, featureDef)
	local FileExists =  VFS.FileExists

	local normalMap = blankNormalMap
	local unittextures = "unittextures/"
	if unitDef and unitDef.model then
		local tex1 = unittextures .. unitDef.model.textures.tex1
		local tex2 = unittextures .. unitDef.model.textures.tex2
		if existingfilecache[tex1] == nil and FileExists(tex1) then
			existingfilecache[tex1] = string.format("%%%i:0", unitDef.id)
		end
		if existingfilecache[tex2] == nil and FileExists(tex2) then
			existingfilecache[tex2] = string.format("%%%i:1", unitDef.id)
		end
		
		if unitDef.customParams and unitDef.customParams.normaltex then
			local normaltex = unitDef.customParams.normaltex
			if existingfilecache[normaltex] == nil and FileExists(normaltex) then 
				existingfilecache[normaltex] = normaltex
			end
			return normaltex
		end
	end

	if featureDef then
		local tex1 = unittextures .. (featureDef.model.textures.tex1 or "DOESNTEXIST.PNG")
		local tex2 = unittextures .. (featureDef.model.textures.tex2 or "DOESNTEXIST.PNG")
		
		-- cache them:
		if existingfilecache[tex1] == nil and FileExists(tex1) then 
			existingfilecache[tex1] = string.format("%%%i:0", -1*featureDef.id)
		end
		if existingfilecache[tex2] == nil and FileExists(tex2) then 
			existingfilecache[tex2] = string.format("%%%i:1", -1*featureDef.id)
		end

		if featureDef.customParams and featureDef.customParams.normaltex then
			local normaltex = featureDef.customParams.normaltex
			if existingfilecache[normaltex] == nil and FileExists(normaltex) then	
				existingfilecache[normaltex] = normaltex
			end
			return normaltex
		else
			if featureDef.model.textures.tex1 == "Arm_wreck_color.dds" then 
				return unittextures.."Arm_wreck_color_normal.dds"
			end
			
			if featureDef.model.textures.tex1 == "cor_color_wreck.dds" then 
				return unittextures.."cor_color_wreck_normal.dds"
			end

			if featureDef.model.textures.tex1 == "leg_wreck_color.dds" then
				return unittextures.."leg_wreck_normal.dds"
			end
			-- try to search for an appropriate normal
			normalMap = tex1:gsub("%.","_normals.")
			-- Spring.Echo(normalMap)
			if (existingfilecache[normalMap] or FileExists(normalMap)) then
				existingfilecache[normalMap] = true
				return normalMap
			end
			normalMap = tex1:gsub("%.","_normal.")
			-- Spring.Echo(normalMap)
			if (existingfilecache[normalMap] or FileExists(normalMap)) then
				existingfilecache[normalMap] = true
				return normalMap
			end
		end
	end
	return blankNormalMap
end
-- BIG TODO:
-- Replace lua texture names with overrides of WreckTex et al!
-- 
-- %34:1 = unitDef 34 s3o tex2 (:0->tex1,:1->tex2)
-- %-102:0 = featureDef 102 s3o tex1 
-- The problem here being hat tex1 and tex2 dont participate in texture key hashing.
-- so e.g. raptors may have been drawn with incorrect textures all along, due to them being keyed 



local knowntrees = VFS.Include("modelmaterials_gl4/known_feature_trees.lua")
local function initBinsAndTextures()
	
	-- init features first, to gain access to stored wreck textures!
	Spring.Echo("[CUS GL4] Init Feature bins")
	for featureDefID, featureDef in pairs(FeatureDefs) do
		if featureDef.model then -- this is kind of a hack to work around specific modelless features metalspots found on Otago 1.4
			local normalTex = GetNormal(nil, featureDef)
			local textureTable = {
				[0] = string.format("%%-%s:%i", featureDefID, 0),
				[1] = string.format("%%-%s:%i", featureDefID, 1),
				[2] = normalTex,
				[3] = false,
				[4] = false,
				[5] = false,
				[6] = "$shadow",
				[7] = "$reflection",
				[8] = "$info",
				[9] = brdfLUT,
				[10] = noisetex3dcube,
			}

			objectDefToUniformBin[-1 * featureDefID] = 'feature'

			if featureDef.name:find("raptor_egg", nil, true) then
				objectDefToUniformBin[-1 * featureDefID] = 'wreck'
				--featuresDefsWithAlpha[-1 * featureDefID] = "yes"
			elseif (featureDef.customParams and featureDef.customParams.treeshader == 'yes')
				or knowntrees[featureDef.name] then
				objectDefToUniformBin[-1 * featureDefID] = 'tree'
				featuresDefsWithAlpha[-1 * featureDefID] = "yes"
			elseif featureDef.name:find("_dead", nil, true) or featureDef.name:find("_heap", nil, true) then
				objectDefToUniformBin[-1 * featureDefID] = 'wreck'
			elseif featureDef.name:find("pilha_crystal", nil, true) or (featureDef.customParams and featureDef.customParams.cuspbr) then
				objectDefToUniformBin[-1 * featureDefID] = 'featurepbr'
			end
			--Spring.Echo("Assigned normal map to", featureDef.name, normalTex)

			local texKeyFast = GenFastTextureKey(-1 * featureDefID, featureDef, normalTex, textureTable)
			if textureKeytoSet[texKeyFast] == nil then
				textureKeytoSet[texKeyFast] = textureTable
			end
		end
	end
	--if true then return end
	Spring.Echo("[CUS GL4] Init Unit bins")
	for unitDefID, unitDef in pairs(UnitDefs) do
		if unitDef.model then
			local lowercasetex1 = string.lower(unitDef.model.textures.tex1 or "")
			local lowercasetex2 = string.lower(unitDef.model.textures.tex2 or "")
			local normalTex = GetNormal(unitDef, nil)
			local lowercasenormaltex = string.lower(normalTex or "")

			-- bin units according to what faction's texture they use
			local factionBinTag = lowercasetex1:sub(1,3)

			objectDefToUniformBin[unitDefID] = "otherunit"
			if factionBinTag == 'arm' then
				objectDefToUniformBin[unitDefID] = 'armunit'
			elseif factionBinTag == 'cor' then
				objectDefToUniformBin[unitDefID] = 'corunit'
			elseif factionBinTag == 'leg' then
				objectDefToUniformBin[unitDefID] = 'legunit'
			end

			local textureTable = {
				--%-102:0 = featureDef 102 s3o tex1
				[0] = string.format("%%%s:%i", unitDefID, 0),
				[1] = string.format("%%%s:%i", unitDefID, 1),
				[2] = normalTex,
				[3] = normalTex,
				[4] = normalTex,
				[5] = normalTex,
				[6] = "$shadow",
				[7] = "$reflection",
				[8] = "$info:los",
				[9] = GG.GetBrdfTexture(), --brdfLUT,
				[10] = noisetex3dcube,
			}

			local wreckTex1 =
					(lowercasetex1:find("arm_color", nil, true) and "unittextures/Arm_wreck_color.dds") or
					(lowercasetex1:find("cor_color", nil, true) and "unittextures/cor_color_wreck.dds") or
					(lowercasetex1:find("leg_color", nil, true) and "unittextures/leg_wreck_color.dds") or
					false
			if wreckTex1 and existingfilecache[wreckTex1] then -- this part is what ensures that these textures dont get loaded separately, but instead use ones provided by featuredefs
				wreckTex1 = existingfilecache[wreckTex1]
			end
			local wreckTex2 =
					(lowercasetex2:find("arm_other", nil, true) and "unittextures/Arm_wreck_other.dds") or
					(lowercasetex2:find("cor_other", nil, true) and "unittextures/cor_other_wreck.dds") or
					(lowercasetex2:find("leg_shader", nil, true) and "unittextures/leg_wreck_shader.dds") or
					false
			if wreckTex2 and existingfilecache[wreckTex2] then  -- this part is what ensures that these textures dont get loaded separately, but instead use ones provided by featuredefs
				wreckTex2 = existingfilecache[wreckTex2]
			end
			local wreckNormalTex =
					(lowercasenormaltex:find("arm_normal") and "unittextures/Arm_wreck_color_normal.dds") or
					(lowercasenormaltex:find("cor_normal") and "unittextures/cor_color_wreck_normal.dds") or
					(lowercasenormaltex:find("leg_normal") and "unittextures/leg_wreck_normal.dds") or
					false

			if unitDef.name:find("_scav", nil, true) then -- it better be a scavenger unit, or ill kill you
				textureTable[3] = wreckTex1
				textureTable[4] = wreckTex2
				textureTable[5] = wreckNormalTex
				if factionBinTag == 'arm' then
					objectDefToUniformBin[unitDefID] = 'armscavenger'
				elseif factionBinTag == 'cor' then
					objectDefToUniformBin[unitDefID] = 'corscavenger'
				elseif factionBinTag == 'leg' then
					objectDefToUniformBin[unitDefID] = 'legscavenger'
				end
			elseif unitDef.name:find("raptor", nil, true) or unitDef.name:find("raptor_hive", nil, true) then
				textureTable[5] = wreckAtlases['raptor'][1]
				objectDefToUniformBin[unitDefID] = 'raptor'
				--Spring.Echo("Raptorwreck", textureTable[5])
			elseif wreckTex1 and wreckTex2 then -- just a true unit:
				textureTable[3] = wreckTex1
				textureTable[4] = wreckTex2
				textureTable[5] = wreckNormalTex
			end
			
			if unitDef.customParams and unitDef.customParams.useskinning then 
				unitDefsUseSkinning[unitDefID] = true
				objectDefToUniformBin[unitDefID]  = 'otherunit' -- This will temporarily disable raptor shader
			end
			
			local texKeyFast = GenFastTextureKey(unitDefID, unitDef, normalTex, textureTable)
			if textureKeytoSet[texKeyFast] == nil then
				textureKeytoSet[texKeyFast] = textureTable
			end
		end
	end



end

local preloadedTextures = false
local function PreloadTextures()
	Spring.Echo("[CUS GL4] Cache Textures")
	-- init the arm and core wrecks, and wreck normals
	gl.Texture(0, "unittextures/Arm_wreck_color_normal.dds")
	--gl.Texture(0, "unittextures/Arm_wreck_color.dds")
	--gl.Texture(0, "unittextures/Arm_wreck_other.dds")
	gl.Texture(0, "unittextures/Arm_normal.dds")
	--gl.Texture(0, "unittextures/Arm_color.dds") -- these absolutely never need to be loaded like this
	--gl.Texture(0, "unittextures/Arm_other.dds")
	gl.Texture(0, "unittextures/cor_normal.dds")
	--gl.Texture(0, "unittextures/cor_other.dds")
	--gl.Texture(0, "unittextures/cor_color.dds")
	--gl.Texture(0, "unittextures/cor_other_wreck.dds")
	--gl.Texture(0, "unittextures/cor_color_wreck.dds")
	gl.Texture(0, "unittextures/cor_color_wreck_normal.dds")
	if Spring.GetModOptions().experimentallegionfaction then
		gl.Texture(0, "unittextures/leg_wreck_normal.dds")
	end
	gl.Texture(0, false)
	preloadedTextures = true
end

local function GetObjectDefName(objectID)
	if objectID == nil then
		return "Failed to GetObjectDefName(objectID): " .. tostring(objectID)
	elseif objectID >= 0 then
		if Spring.ValidUnitID(objectID) then
			local udid = Spring.GetUnitDefID(objectID)
			return UnitDefs[udid].name
		else
			return "Invalid UnitID:"..tostring(objectID)
		end
	else
		if Spring.ValidFeatureID(-1 * objectID) then
			local fdid = Spring.GetFeatureDefID(-1 * objectID)
			return FeatureDefs[fdid].name
		else
			return 'Invalid featuredefid:' .. tostring(objectID)
		end
	end
end

local badassigns = {} -- a table of unitDefs so that we only warn once

local assigncalls = 0
--- Assigns a unit to a material bin
-- This function gets called from AddUnit every time a unit enters drawrange (or gets its flags changed)
-- @param objectID The unitID of the unit, or negative for featureID's
-- @param objectDefID Which unitdef it belongs to, negative for featureDefIDs
-- @param flag which drawflags it has
-- @param shader which shader should be assigned to it
-- @param textures A table of {bindPosition:texturename} for this unit
-- @param texKey A unique key hashed from the textures names, bindpositions
local function AssignObjectToBin(objectID, objectDefID, flag, shader, textures, texKey, uniformBinID, calledfrom)
	assigncalls = (assigncalls + 1 ) % (2^20)
	shader = shader or GetShaderName(flag, objectDefID)
	texKey = texKey or fastObjectDefIDtoTextureKey[objectDefID]

	if objectDefID == nil then
		Spring.Echo("AssignObjectToBin",objectID, objectDefID, flag, shader, textures, texKey, uniformBinID, calledfrom)
	end
	uniformBinID = uniformBinID or GetUniformBinID(objectDefID, "AssignObjectToBin")
	--Spring.Echo("AssignObjectToBin", objectID, objectDefID, flag, shader, textures, texKey, uniformBinID)
	--	Spring.Debug.TraceFullEcho()
	if (texKey == nil or uniformBinID == nil) then
		if badassigns[objectID] == nil then
			Spring.Echo("[CUS GL4]Failure to assign to ", objectID, objectDefID, flag, shader, textures, texKey, uniformBinID, calledfrom)
			Spring.Echo("REPORT THIS TO BEHERITH: bad object:", GetObjectDefName(objectID))
			badassigns[objectID] = true
		end
		return
	end

	local unitDrawBinsFlag = unitDrawBins[flag]
	if unitDrawBinsFlag[shader] == nil then
		unitDrawBinsFlag[shader] = {}
	end
	local unitDrawBinsFlagShader = unitDrawBinsFlag[shader]

	if unitDrawBinsFlagShader[uniformBinID] == nil then
		unitDrawBinsFlagShader[uniformBinID] = {}
	end

	local unitDrawBinsFlagShaderUniforms = unitDrawBinsFlagShader[uniformBinID]

	if unitDrawBinsFlagShaderUniforms[texKey] == nil then
		local t0 = Spring.GetTimerMicros()
		local mybinVAO = gl.GetVAO()
		local mybinIBO = gl.GetVBO(GL.ARRAY_BUFFER, true)

		if (mybinIBO == nil) or (mybinVAO == nil) then
			Spring.Echo("Failed to allocate IBO or VAO for CUS GL4", mybinIBO, mybinVAO)
			--Spring.Debug.TraceFullEcho()
			gadgetHandler:RemoveGadget()
			return
		end

		mybinIBO:Define(INITIAL_VAO_SIZE, {
			{id = 6, name = "instData", type = GL.UNSIGNED_INT, size = 4},
		})

		mybinVAO:AttachVertexBuffer(modelsVertexVBO)
		mybinVAO:AttachIndexBuffer(modelsIndexVBO)
		mybinVAO:AttachInstanceBuffer(mybinIBO)

		unitDrawBinsFlagShaderUniforms[texKey] = { -- so texkey was somehow nil...
			textures = textureKeytoSet[texKey], -- hashmap of textures for this unit
			IBO = mybinIBO, -- my own IBO, for incrementing
			VAO = mybinVAO, -- my own VBO, for incremental updating
			objectsArray = {}, -- {index: objectID}
			objectsIndex = {}, -- {objectID : index} (this is needed for efficient removal of items, as RemoveFromSubmission takes an index as arg)
			numobjects = 0,  -- a 'pointer to the end'
			maxElements = INITIAL_VAO_SIZE,
		}

		-- this uniform bin is totally new, so we are going to make the deferred version have a shared copy of this!
		-- This means that deferred and forward will share their uniformbins
		-- they could share up to the shader level, but I dont know why im not using that
		if flag == 1 then
			deferredrawBin = unitDrawBins[0]
			if deferredrawBin[shader] == nil then  deferredrawBin[shader] = {} end
			if deferredrawBin[shader][uniformBinID] == nil then deferredrawBin[shader][uniformBinID] = unitDrawBinsFlagShader[uniformBinID] end
		end
		if debugmode then Spring.Echo("Init of bin",shader, flag, texKey, uniformBinID, "took", Spring.DiffTimers(Spring.GetTimerMicros(),t0,  nil), "ms" ) end
	end

	local unitDrawBinsFlagShaderUniformsTexKey = unitDrawBinsFlagShaderUniforms[texKey]

	if unitDrawBinsFlagShaderUniformsTexKey.objectsIndex[objectID] then
		Spring.Echo("Trying to add a unit to a bin that it is already in!")
	else
		if debugmode then Spring.Echo("AssignObjectToBin success:",objectID, objectDefID, flag, shader, texKey, uniformBinID	) end
	end

	local maxElements = unitDrawBinsFlagShaderUniformsTexKey.maxElements
	local numobjects = unitDrawBinsFlagShaderUniformsTexKey.numobjects

	-- of our VAO is too small, we need to increase it's size
	-- We do this by doubling size, and then recreating the IBO and VAO from scratch and checking validity as we go along
	if numobjects + 1 >= maxElements then
		-- we need to double our VAO size
		--Spring.Echo("Upsizing VAO for bin", flag, shader, texKey, uniformBinID, numobjects)
		maxElements = maxElements * 2
		unitDrawBinsFlagShaderUniformsTexKey.maxElements = maxElements
		local mybinVAO = gl.GetVAO()
		local mybinIBO = gl.GetVBO(GL.ARRAY_BUFFER, true)

		-- we have to rebuild the indices on a resize, because we are adding/removing objects in a random order
		-- per frame, and if we resize with objects that dont exist any more in the arrays, we will crash on AddUnitsToSubmission
		local newObjectsArray = {}
		local newObjectsIndex = {}

		if (mybinIBO == nil) or (mybinVAO == nil) then
			Spring.Echo("Failed to allocate IBO or VAO for CUS GL4", mybinIBO, mybinVAO)
			--Spring.Debug.TraceFullEcho()
			gadgetHandler:RemoveGadget()
			return
		end

		mybinIBO:Define(maxElements, {
			{id = 6, name = "instData", type = GL.UNSIGNED_INT, size = 4},
		})

		mybinVAO:AttachVertexBuffer(modelsVertexVBO)
		mybinVAO:AttachIndexBuffer(modelsIndexVBO)
		mybinVAO:AttachInstanceBuffer(mybinIBO)

		-- delete the old IBO and VAO
		unitDrawBinsFlagShaderUniformsTexKey.IBO = nil
		unitDrawBinsFlagShaderUniformsTexKey.IBO = mybinIBO
		unitDrawBinsFlagShaderUniformsTexKey.VAO:ClearSubmission()
		unitDrawBinsFlagShaderUniformsTexKey.VAO:Delete()
		unitDrawBinsFlagShaderUniformsTexKey.VAO = mybinVAO

		local newObjectsCount = 0
		local objectsArray = unitDrawBinsFlagShaderUniformsTexKey.objectsArray
		if objectID >= 0 then -- this tells us if we are gonna be using features or units
			for i, unitID in ipairs(objectsArray) do
				if Spring.ValidUnitID(unitID) == true and Spring.GetUnitIsDead(unitID) ~= true then
					newObjectsCount = newObjectsCount + 1
					newObjectsArray[newObjectsCount] = unitID
					newObjectsIndex[unitID] = newObjectsCount
				end
			end

			mybinIBO:InstanceDataFromUnitIDs(newObjectsArray, objectTypeAttribID)
			mybinVAO:AddUnitsToSubmission(newObjectsArray)

		else
			-- this additional table is needed to allow for one-time translation of negative objectID to featureID
			local newFeaturesArray = {}
			for i, featureID in ipairs(objectsArray) do
				if Spring.ValidFeatureID(-featureID) then
					newObjectsCount = newObjectsCount + 1
					newObjectsArray[newObjectsCount] = featureID
					newObjectsIndex[featureID      ] = newObjectsCount
					newFeaturesArray[newObjectsCount] = -1 * featureID
				end
			end

			mybinIBO:InstanceDataFromFeatureIDs(newFeaturesArray, objectTypeAttribID)
			mybinVAO:AddFeaturesToSubmission(newFeaturesArray)
		end

		numobjects = newObjectsCount
		unitDrawBinsFlagShaderUniformsTexKey.objectsArray = newObjectsArray
		unitDrawBinsFlagShaderUniformsTexKey.objectsIndex = newObjectsIndex
	end

	if objectID >= 0 then
		unitDrawBinsFlagShaderUniformsTexKey.IBO:InstanceDataFromUnitIDs(objectID, objectTypeAttribID, numobjects)
		unitDrawBinsFlagShaderUniformsTexKey.VAO:AddUnitsToSubmission   (objectID)
	else
		unitDrawBinsFlagShaderUniformsTexKey.IBO:InstanceDataFromFeatureIDs(-objectID, objectTypeAttribID, numobjects)
		unitDrawBinsFlagShaderUniformsTexKey.VAO:AddFeaturesToSubmission   (-objectID)
	end

	numobjects = numobjects + 1
	unitDrawBinsFlagShaderUniformsTexKey.numobjects = numobjects
	unitDrawBinsFlagShaderUniformsTexKey.objectsArray[numobjects] = objectID
	unitDrawBinsFlagShaderUniformsTexKey.objectsIndex[objectID  ] = numobjects

	if debugmode and flag == 0 then
		Spring.Echo("AssignObjectToBin", objectID, objectDefID, texKey,uniformBinID, shader,flag, numobjects)
		local objids = "objectsArray "
		for k,v in pairs(unitDrawBinsFlagShaderUniformsTexKey.objectsArray) do
			objids = objids .. tostring(k) .. ":" ..tostring(v) .. " "
		end
		Spring.Echo(objids)
	end
end

local function AddObject(objectID, drawFlag, reason)
	if debugmode then Spring.Echo("AddObject",objectID, objectDefID, drawFlag, reason) end
	if (drawFlag >= 128) then --icon
		return
	end

	local objectDefID
	if objectID >= 0 then
		objectDefID = Spring.GetUnitDefID(objectID)
		objectIDtoDefID[objectID] = objectDefID
	else
		objectDefID = -1 *  Spring.GetFeatureDefID(-1 * objectID)
		objectIDtoDefID[objectID] = objectDefID
	end
	if objectDefID == nil then return end -- This bail is needed so that we dont add/update units that dont actually exist any more, when cached from the catchup phase

	for k = 1, #drawBinKeys do
		local flag = drawBinKeys[k]
		if HasAllBits(drawFlag, flag) then
			if overrideDrawFlagsCombined[flag] then
								 --objectID, objectDefID, flag, shader, textures, texKey, uniformBinID, calledfrom
				AssignObjectToBin(objectID, objectDefID, flag, nil,	nil,	  nil,	  nil, 			"addobject")
			end
		end
	end
	if objectID >= 0 then
		Spring.SetUnitEngineDrawMask(objectID, 255 - overrideDrawFlag) -- ~overrideDrawFlag & 255
		cusUnitIDtoDrawFlag[objectID] = drawFlag
		local health, maxHealth, paralyzeDamage, capture, build = spGetUnitHealth(objectID)
		if health then 
			uniformCache[1] = ((build < 1) and build) or -1
			gl.SetUnitBufferUniforms(objectID, uniformCache, 0) -- buildprogress (0.x)
			if build < 1 then buildProgresses[objectID] = build end
			
			--uniformCache[1] = spGetUnitHeight(objectID)
			--gl.SetUnitBufferUniforms(objectID, uniformCache, 11) -- height is 11 (2.w)
		end
	else
		if Spring.ValidFeatureID(-1 * objectID) == false then Spring.Echo("Invalid feature for drawmask", objectID, objectDefID) end
		Spring.SetFeatureEngineDrawMask(-1 * objectID, 255 - overrideDrawFlag) -- ~overrideDrawFlag & 255
		Spring.SetFeatureNoDraw(-1 * objectID, false) -- ~overrideDrawFlag & 255
		Spring.SetFeatureFade(-1 * objectID, true) -- ~overrideDrawFlag & 255
		cusFeatureIDtoDrawFlag[-1 *objectID] = drawFlag
	end
	--cusUnitIDtoDrawFlag[unitID] = overrideDrawFlag
end

local function RemoveObjectFromBin(objectID, objectDefID, texKey, shader, flag, uniformBinID, reason)
	shader = shader or GetShaderName(flag, objectDefID)
	texKey = texKey or fastObjectDefIDtoTextureKey[objectDefID]
	if debugmode then Spring.Echo("RemoveObjectFromBin", objectID, objectDefID, texKey,shader,flag,uniformBinID, reason)  end

	if unitDrawBins[flag][shader] then
		if unitDrawBins[flag][shader][uniformBinID] then
			if unitDrawBins[flag][shader][uniformBinID][texKey] then

				-- do the pop magic
				local unitDrawBinsFlagShaderTexKey = unitDrawBins[flag][shader][uniformBinID][texKey]
				local objectIndex = unitDrawBinsFlagShaderTexKey.objectsIndex[objectID]

				--if flag == 0 then Spring.Echo("RemoveObjectFromBin", objectID, objectDefID, texKey,shader,flag,objectIndex) end
				--if debugmode then Spring.Echo("RemoveObjectFromBin really", objectID, objectDefID, texKey,shader,flag,objectIndex) end
				if objectIndex == nil then
					return
				end
				local numobjects = unitDrawBinsFlagShaderTexKey.numobjects

				unitDrawBinsFlagShaderTexKey.VAO:RemoveFromSubmission(objectIndex - 1) -- do we become out of order?
				if objectIndex == numobjects then -- last element
					unitDrawBinsFlagShaderTexKey.objectsIndex[objectID] = nil
					unitDrawBinsFlagShaderTexKey.objectsArray[numobjects] = nil
					unitDrawBinsFlagShaderTexKey.numobjects = numobjects -1
				else
					local objectIDatEnd = unitDrawBinsFlagShaderTexKey.objectsArray[numobjects]
					if debugmode and flag == 0 then Spring.Echo("Moving", objectIDatEnd, "from", numobjects, " to", objectIndex, "while removing", objectID) end
					unitDrawBinsFlagShaderTexKey.objectsIndex[objectID     ] = nil -- pop back
					unitDrawBinsFlagShaderTexKey.objectsIndex[objectIDatEnd] = objectIndex -- bring the last objectID to to this one
					if objectID >= 0 then -- unit
						if Spring.ValidUnitID(objectIDatEnd) == true and Spring.GetUnitIsDead(objectIDatEnd) ~= true then
							unitDrawBinsFlagShaderTexKey.IBO:InstanceDataFromUnitIDs(objectIDatEnd, objectTypeAttribID, objectIndex - 1)
						else
							if debugmode then Spring.Echo("Tried to remove invalid unitID", objectIDatEnd, "while removing", objectID) end
						end
					else -- feauture
						if Spring.ValidFeatureID(-objectIDatEnd) == true then
							unitDrawBinsFlagShaderTexKey.IBO:InstanceDataFromFeatureIDs(-1 * objectIDatEnd, objectTypeAttribID, objectIndex - 1)
						else
							if debugmode then Spring.Echo("Tried to remove invalid featureID", -objectIDatEnd, "while removing", -objectID) end
						end
					end
					unitDrawBinsFlagShaderTexKey.objectsArray[numobjects ] = nil -- pop back
					unitDrawBinsFlagShaderTexKey.objectsArray[objectIndex] = objectIDatEnd -- Bring the last objectID here
					unitDrawBinsFlagShaderTexKey.numobjects = numobjects -1
				end
			end
		else
			if debugmode then Spring.Echo("Failed to find uniformBinID for", objectID, objectDefID, texKey, shader, flag, uniformBinID) end
		end
	else
		if debugmode then
			local defName ='niiiil'
			if objectDefID then
				if objectDefID >= 0 then
					defName =  UnitDefs[objectDefID].name
				else
					defName =  FeatureDefs[-1 * objectDefID].name
				end
			end
			Spring.Echo("Failed to find shader for", objectID, objectDefID, texKey, shader, flag, uniformBinID, defName)
		end
		--Spring.Debug.TraceFullEcho(30,30,30)
	end
end

local function UpdateObject(objectID, drawFlag, reason)
	if debugmode then Spring.Echo("UpdateObject", objectID, drawFlag, reason) end
	if (drawFlag >= 128) then --icon
		return
	end

	local objectDefID = objectIDtoDefID[objectID]

	--if debugmode then Spring.Debug.TraceEcho("UpdateObject", objectID, drawFlag, objectDefID) end
	for k = 1, #drawBinKeys do
		local flag = drawBinKeys[k]
		local hasFlagOld
		if objectID >= 0 then
			hasFlagOld = HasAllBits(cusUnitIDtoDrawFlag[objectID], flag)
		else
			hasFlagOld = HasAllBits(cusFeatureIDtoDrawFlag[-1 * objectID], flag)
		end
		local hasFlagNew = HasAllBits(               drawFlag, flag)

		if hasFlagOld ~= hasFlagNew and overrideDrawFlagsCombined[flag] then
			local shader = GetShaderName(flag, objectDefID)
			local texKey  = fastObjectDefIDtoTextureKey[objectDefID]
			local uniformBinID = GetUniformBinID(objectDefID,'UpdateObject')

			if hasFlagOld then --had this flag, but no longer have
				RemoveObjectFromBin(objectID, objectDefID, texKey, shader, flag, uniformBinID, "nolongerhasflag")
				--if flag == 1 then
				--	RemoveObjectFromBin(objectID, objectDefID, texKey, nil, 0, uniformBinID)
				--end
			end
			if hasFlagNew then -- didn't have this flag, but now has
				AssignObjectToBin(objectID, objectDefID, flag, shader, nil, texKey, uniformBinID, "UpdateObject")
				--if flag == 1 then
				--	AssignObjectToBin(objectID, objectDefID, 0, nil, nil, texKey, uniformBinID) --deferred
				--end
			end
		end
	end
	if objectID >= 0 then
		cusUnitIDtoDrawFlag[objectID] = drawFlag
	else
		cusFeatureIDtoDrawFlag[-1 * objectID] = drawFlag
	end
end

local function RemoveObject(objectID, reason) -- we get pos/neg objectID here
	--remove the object from every bin and table
	if debugmode then Spring.Echo("RemoveObject", objectID, reason) end
	local objectDefID = objectIDtoDefID[objectID]
	if objectDefID == nil then return end
	--if objectID == nil then Spring.Debug.TraceFullEcho() end

	--if debugmode then Spring.Debug.TraceEcho("RemoveObject", objectID) end

	-- RemoveObject forces removal from ALL bins, even if it is not in the bin, or that bin straight up doesnt exist (like reflection and shadows)
	local oldFlag 
	if objectID >= 0 then 
		oldFlag = cusUnitIDtoDrawFlag[objectID]
	else 
		oldFlag = cusFeatureIDtoDrawFlag[-1 * objectID]
	end
	
	for k = 1, #drawBinKeys do --drawBinKeys = {1, 1 + 4, 16}
		local flag = drawBinKeys[k]
		if (oldFlag < flag) then break end -- if shadows are off, then dont even try to remove from them
		if debugmode then Spring.Echo("RemoveObject Flags", objectID, flag, overrideDrawFlagsCombined[flag] ) end
		if overrideDrawFlagsCombined[flag] then
			local shader = GetShaderName(flag, objectDefID)
			local texKey  = fastObjectDefIDtoTextureKey[objectDefID]
			local uniformBinID = GetUniformBinID(objectDefID,'RemoveObject')
			RemoveObjectFromBin(objectID, objectDefID, texKey, shader, flag, uniformBinID, "removeobject")
			--if flag == 1 then
			--	RemoveObjectFromBin(objectID, objectDefID, texKey, nil, 0, uniformBinID)
			--end
		end
	end
	objectIDtoDefID[objectID] = nil
	if objectID >= 0 then
		cusUnitIDtoDrawFlag[objectID] = nil
		buildProgresses[objectID] = nil
		Spring.SetUnitEngineDrawMask(objectID, 255)
	else
		cusFeatureIDtoDrawFlag[-1 * objectID] = nil
		Spring.SetFeatureEngineDrawMask(-1 * objectID, 255)
	end
end

local spGetUnitIsCloaked = Spring.GetUnitIsCloaked

local function ProcessUnits(units, drawFlags, reason)
	for i = 1, #units do
		local unitID = units[i]
		local drawFlag = drawFlags[i]
		if debugmode then Spring.Echo("ProcessUnits", unitID, drawFlag, reason) end


		if math_bit_and(drawFlag, 34) > 0 then -- has alpha (2) or alphashadow(32) flag 
			-- cloaked units get mapped to pure forward + deferred, no refl/refr either
			drawFlag = 1
		end
		
		if drawFlag % 4 > 1 then -- check if its at least in opaque or alpha pass
			if unitsInViewport[unitID] == nil then
				-- CALL the UnitViewportAPI
				numUnitsInViewport = numUnitsInViewport + 1
			end
			unitsInViewport[unitID] = drawFlag
		else
			if unitsInViewport[unitID] then
				-- CALL the UnitViewportAPI
				numUnitsInViewport = numUnitsInViewport - 1
			end
			unitsInViewport[unitID] = nil
		end
		
		if (drawFlag == 0) or (drawFlag >= 128) then
			RemoveObject(unitID, reason)
		else
			if cusUnitIDtoDrawFlag[unitID] == nil then --object was not seen
				if Spring.ValidUnitID(unitID) and (not spGetUnitIsCloaked(unitID)) then
					uniformCache[1] = 0
					gl.SetUnitBufferUniforms(unitID, uniformCache, 12) -- cloak
				end
				AddObject(unitID, drawFlag, reason)
			elseif cusUnitIDtoDrawFlag[unitID] ~= drawFlag then --flags have changed
				UpdateObject(unitID, drawFlag, reason)
			end
		end
	end

end


local function ProcessFeatures(features, drawFlags, reason)

	for i = 1, #features do
		local featureID = features[i]
		local drawFlag = drawFlags[i]

		if drawFlag % 4 > 1 then
			if featuresInViewport[featureID] == nil then
				-- CALL the UnitViewportAPI
				numFeaturesInViewport = numFeaturesInViewport + 1
			end
			featuresInViewport[featureID] = true
		else
			if featuresInViewport[featureID] then
				-- CALL the UnitViewportAPI
				numFeaturesInViewport = numFeaturesInViewport - 1
			end
			featuresInViewport[featureID] = nil
		end
		-- TODO: this is the nastiest hack in the world, because zero is positive, and we can get features that have a featureID of 0.
		-- we will solve this by simply not CUS-ing a feature that has an ID of 0
		-- I leave this wonderful bug to any future soul who has to maintain this
		if featureID > 0 then
			--Spring.Echo("ProcessFeature", featureID	, drawFlag)
			if math_bit_and(drawFlag, 34) > 0 then -- has alpha (2) or alphashadow(32) flag 
				-- cloaked units get mapped to pure forward + deferred, no refl/refr either
				drawFlag = 1
			end
			if (drawFlag == 0) or (drawFlag >= 128) then
				RemoveObject(-1 * featureID, reason)
			elseif cusFeatureIDtoDrawFlag[featureID] == nil then --object was not seen
				AddObject(-1 * featureID, drawFlag, reason)
			else --if cusFeatureIDtoDrawFlag[featureID] ~= drawFlag then --flags have changed
				UpdateObject(-1 * featureID, drawFlag, reason)
			end
		end
	end

end

local shaderactivations = 0

local shaderOrder = {'tree','feature','unit','unitskinning'} -- this forces ordering, no real reason to do so, just for testing

local drawpassstats = {} -- a table of drawpass number and the actual number of units and batches performed by that pass
for drawpass, _ in pairs(overrideDrawFlagsCombined) do drawpassstats[drawpass] = {shaders = 0, batches = 0, units = 0} end

local function printDrawPassStats()
	res = ""
	for drawpass, stats in pairs(drawpassstats) do
		res = res .. string.format("Pass_%d: %d/%d/%d  ", drawpass, stats.shaders, stats.batches, stats.units)
	end
	return res
end

local function ExecuteDrawPass(drawPass)
	--defersubmissionupdate = (defersubmissionupdate + 1) % 10;
	local batches = 0
	local units = 0
	local shaderswaps = 0
	local unbindtextures = false
	gl.Culling(GL.BACK)
	if (drawPass == 1) then --forward opaque pass
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA) -- 
	end
	
	--for shaderName, data in pairs(unitDrawBins[drawPass]) do
	for _, shaderName in ipairs(shaderOrder) do
		if unitDrawBins[drawPass][shaderName] then
			local data = unitDrawBins[drawPass][shaderName]
			local unitscountforthisshader = 0
			--Spring.Echo("uniformBinID", uniformBinID)

			for _, uniformBin in pairs(data) do
				for _, texAndObj in pairs(uniformBin) do
					unitscountforthisshader = unitscountforthisshader + texAndObj.numobjects
				end
			end

			local shaderTable = shaders[drawPass][shaderName]

			if unitscountforthisshader > 0 then
				shaderTable:Activate()
				shaderswaps = shaderswaps + 1
				for uniformBinID, uniformBin in pairs(data) do

					--Spring.Echo("Shadername", shaderId.shaderName,"uniformBinID", uniformBinID)
					--local uniforms = uniformBins[uniformBinID]

					-- TODO: only activate shader if we actually have units in its bins?
					SetShaderUniforms(drawPass, shaderTable.shaderObj, uniformBinID)

					for _, texAndObj in pairs(uniformBin) do
						if texAndObj.numobjects > 0  then
							batches = batches + 1
							units = units + texAndObj.numobjects
							local mybinVAO = texAndObj.VAO
							for bindPosition, tex in pairs(texAndObj.textures) do
								gl.Texture(bindPosition, tex)
							end

							SetFixedStatePre(drawPass, shaderTable)
							shaderactivations = shaderactivations + 1

							mybinVAO:Submit()

							SetFixedStatePost(drawPass, shaderTable)
							unbindtextures = true
				
						end
					end
				end

				shaderTable:Deactivate()
			end
		end
	end
	
	if unbindtextures then 
		for i=0,10 do
			gl.Texture(i, false)
		end
	end
	if drawPass == 1 then
		gl.Blending(GL.ONE, GL.ZERO) -- do full opaque
	end
	
	--drawpassstats[drawPass].batches = batches
	--drawpassstats[drawPass].units = units
	--drawpassstats[drawPass].shaders = shaderswaps
	return batches, units, shaderswaps
end

local function RecompileShaders(recompilation)
	initMaterials()

	Spring.Echo("[CUS GL4] Compiling Shaders")
	-- Initialize shaders types like so::
	-- shaders[0]['unit_deferred'] = LuaShaderObject
	compileMaterialShader(unitsNormalMapTemplate, "unit", recompilation)
	compileMaterialShader(unitsSkinningTemplate, "unitskinning", recompilation)
	compileMaterialShader(featuresNormalMapTemplate, "feature", recompilation)
	compileMaterialShader(treesNormalMapTemplate, "tree",recompilation)
end


local function initGL4()
	if initiated then return end

	if Platform.glHaveGL4 ~= true then
		Spring.Echo("[CUS GL4] No GL4 support for this gpu as indicated by Platform.glHaveGL4, disabling.")
		return
	end

	shaders[0 ] = {}
	for k = 1, #drawBinKeys do
		local flag = drawBinKeys[k]
		shaders[flag] = {}
	end

	unitDrawBins = {
		[0    ] = {},	-- deferred opaque
		[1    ] = {},	-- forward  opaque
		[1 + 4] = {},	-- forward  opaque + reflection
		[1 + 8] = {},	-- forward  opaque + refraction
		[2    ] = {},	-- alpha
		[2 + 4] = {},	-- alpha + reflection
		[2 + 8] = {},	-- alpha + refraction
		[16   ] = {},	-- shadow
	}
	Spring.Echo("[CUS GL4] Initializing materials")

	RecompileShaders()
	
	modelsVertexVBO = gl.GetVBO(GL.ARRAY_BUFFER, false)
	modelsIndexVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false)

	if modelsVertexVBO == nil or modelsIndexVBO == nil then
		Spring.Echo("CUS GL4 failed to initialize VBO, exiting")
		gadgetHandler:RemoveGadget()
		return
	end

	modelsVertexVBO:ModelsVBO()
	modelsIndexVBO:ModelsVBO()

	Spring.Echo("[CUS GL4] Initializing bins")

	initBinsAndTextures()

	Spring.Echo("[CUS GL4] Collecting units")
	Spring.ClearUnitsPreviousDrawFlag()
	Spring.ClearFeaturesPreviousDrawFlag()
	Spring.Echo("[CUS GL4] Ready")
	initiated = true
end


local function ReloadCUSGL4(optName, line, words, playerID)
	if initiated and (not words) then return end
	manualReload = true
	if playerID ~= Spring.GetMyPlayerID() then
		return
	end
	Spring.Echo("[CustomUnitShadersGL4] Reloading")
	gadget:Shutdown()
	gadget:Initialize()
	initGL4()
end

local function DisableCUSGL4(optName, _, _, playerID)
	if playerID ~= Spring.GetMyPlayerID() then
		return
	end
	Spring.Echo("[CustomUnitShadersGL4] Disabling")
	gadget:Shutdown()
end


function gadget:GameFrame(n)
	if not itsXmas and SYNCED.itsXmas then
		itsXmas = true
		initiated = false
		ReloadCUSGL4(nil,nil,nil, Spring.GetMyPlayerID())
	end
	for unitID, buildProgress in pairs(buildProgresses) do 
		local health, maxHealth, paralyzeDamage, capture, build = spGetUnitHealth(unitID)
		if health and build ~= buildProgress then  
			uniformCache[1] = ((build < 1) and build) or -1
			gl.SetUnitBufferUniforms(unitID, uniformCache, 0) -- buildprogress (0.x)
			if build < 1 then 
				buildProgresses[unitID] = build 
			else
				buildProgresses[unitID] = nil
			end
		end	
	end
end

local updaterate = 1
local function CUSGL4updaterate(optName, line, words, playerID)
	if playerID ~= Spring.GetMyPlayerID() then
		return
	end
	if updaterate == 1 then
		updaterate = 10
	else
		updaterate = 1
	end
	Spring.Echo("[CustomUnitShadersGL4] Updaterate set to", updaterate)
end

local function DebugCUSGL4(optName, line, words, playerID)
	if playerID ~= Spring.GetMyPlayerID() then
		return
	end
	debugmode = not debugmode
	Spring.Echo("[CustomUnitShadersGL4] Debugmode set to", debugmode)
end

local function DumpCUSGL4(optName, line, words, playerID)
	if playerID ~= Spring.GetMyPlayerID() then
		return
	end
	Spring.Echo("[CustomUnitShadersGL4] Dumping unit bins:", debugmode)

	if unitDrawBins == nil then return end
	for drawflag, bin in pairs(unitDrawBins) do
		Spring.Echo(string.format("%i = { -- drawFlag",drawflag))
		for shadername, uniformbin in pairs(bin) do
			Spring.Echo(string.format("  %s = { -- shadername",shadername))
			for uniformbinid, texandobjset in pairs(uniformbin) do
				Spring.Echo(string.format("    %s = { -- uniformbin",uniformbinid))
				for texturekey, minibin in pairs(texandobjset) do
				Spring.Echo(string.format("      %i = { -- textureset",texturekey))
					for minibinattr, minibinvalue in pairs(minibin) do
						if type( minibinvalue ) == "table" then
							Spring.Echo(string.format("        %s = {",minibinattr))
							if minibinattr == "objectsIndex" then
								for k,v in pairs(minibinvalue) do
									local objdefname = (k>=0 and Spring.GetUnitDefID(k) and UnitDefs[Spring.GetUnitDefID(k)].name) or (Spring.GetFeatureDefID(-1 * k)  and FeatureDefs[Spring.GetFeatureDefID(-1 * k) ].name) or "???"
									Spring.Echo(string.format("          %i = %i, --(%s)", k,v,objdefname))
								end
							elseif minibinattr == "objectsArray" then
								for k,v in pairs(minibinvalue) do
									local objdefname = (v>=0 and Spring.GetUnitDefID(v) and UnitDefs[Spring.GetUnitDefID(v)].name) or (Spring.GetFeatureDefID(-1 * v)  and FeatureDefs[Spring.GetFeatureDefID(-1 * v) ].name) or "???"
									Spring.Echo(string.format("          %i = %i, --(%s)", k,v,objdefname))
								end
							else
								for k,v in pairs(minibinvalue) do
									Spring.Echo(string.format("          %s = %s,", tostring(k),tostring(v)))
								end
							end
							Spring.Echo("        },")
						else
							Spring.Echo(string.format("        %s = %s,", tostring(minibinattr),tostring(minibinvalue)))
						end
					end
					Spring.Echo("      },")
				end
				Spring.Echo("    },")
			end
			Spring.Echo("  },")
		end
		Spring.Echo("},")
	end
end


local function MarkBinCUSGL4(optName, line, words, playerID)
	if (playerID ~= Spring.GetMyPlayerID()) then
		return
	end
	Spring.Echo("[CustomUnitShadersGL4] Marking Bins", optName, line, words, playerID)
	local passnum = tonumber(line)
	if passnum == nil then return end

	local function markBin(drawPass)
		local count = 0
		local bin = unitDrawBins[drawPass]
		for shadername, uniformbin in pairs(bin) do
			for uniformbinid, texandobjset in pairs(uniformbin) do
				for texturekey, minibin in pairs(texandobjset) do
					for objectID, _ in pairs(minibin.objectsIndex) do
						local px, py, pz
						if objectID > 0 then
							px, py, pz = Spring.GetUnitPosition(objectID)
						else
							px, py, pz = Spring.GetFeaturePosition(-1* objectID)
						end
						if px then
							Spring.MarkerAddPoint(px,py,pz,
								tostring(drawPass) .. "/" ..
								tostring(shadername) .. "/" ..
								tostring(uniformbinid) .. "/" ..
								tostring(texturekey) .. "/" ..
								tostring(objectID))
							count = count + 1
						end
					end
				end
			end
		end
		Spring.Echo("Added markers for", count, "units in drawPass", drawPass)
	end

	markBin(passnum)
end

local function FreeTextures() -- pre we are using 2200mb
	-- free all raptor texes
	-- free all pilha texes
	Spring.Echo("Freeing textures")
	--delete raptor texes if no raptors are present
	for unitDefID, uniformBin in pairs(objectDefToUniformBin) do 
		if uniformBin == 'raptor' then 
			local textureTable = textureKeytoSet[fastObjectDefIDtoTextureKey[unitDefID]]
			local s1 = gl.DeleteTexture(textureTable[0])
			local s2 = gl.DeleteTexture(textureTable[1])
			
			Spring.Echo("Freeing ",textureTable[0],textureTable[1], s1, s2)
		end
	end

	-- delete feature texes if not present, except wrecks of course
	local features = Spring.GetAllFeatures()

	local delFeatureDefs = {}
	for featureDefID, featureDef in pairs(FeatureDefs) do delFeatureDefs[featureDefID] = true end 

	for i, featureID in ipairs(features) do 
		local existingFeatureDefID = Spring.GetFeatureDefID(featureID)
		delFeatureDefs[existingFeatureDefID] = false
	end

	for featureDefID, deleteme in pairs(delFeatureDefs) do 
		local textureTable = textureKeytoSet[fastObjectDefIDtoTextureKey[-featureDefID]]
			local s1 = gl.DeleteTexture(textureTable[0])
			local s2 = gl.DeleteTexture(textureTable[1])
			
			Spring.Echo("Freeing ",textureTable[0],textureTable[1], s1, s2)
	end
	
	Spring.Echo("RawDelete")
	local unittexfiles = VFS.DirList("unittextures/")
	for i, fname in ipairs(unittexfiles) do 
		if string.find(fname,'chicken', nil, true) then 
			local s1 = gl.DeleteTexture(fname)
			Spring.Echo("Freeing ",fname, s1)

		end
		
	end
	
	
end


function gadget:Initialize()
	gadgetHandler:AddChatAction("reloadcusgl4", ReloadCUSGL4)
	gadgetHandler:AddChatAction("disablecusgl4", DisableCUSGL4)
	gadgetHandler:AddChatAction("cusgl4updaterate", CUSGL4updaterate)
	gadgetHandler:AddChatAction("debugcusgl4", DebugCUSGL4)
	gadgetHandler:AddChatAction("dumpcusgl4", DumpCUSGL4)
	gadgetHandler:AddChatAction("markbincusgl4", MarkBinCUSGL4)
	gadgetHandler:AddChatAction("freetextures", FreeTextures)
	if not initiated and tonumber(Spring.GetConfigInt("cus2", 1) or 1) == 1 then
		initGL4()
	end
	
	GG.CUSGL4 = {}
	GG.CUSGL4.unitsInViewport = unitsInViewport
	GG.CUSGL4.featuresInViewport = featuresInViewport
	GG.CUSGL4.objectDefToBitShaderOptions = objectDefToBitShaderOptions
	GG.CUSGL4.objectDefToUniformBin = objectDefToUniformBin
	GG.CUSGL4.GetUniformBinID = GetUniformBinID
	GG.CUSGL4.uniformBins = uniformBins
	GG.CUSGL4.uniformBins = uniformBins
	GG.CUSGL4.shaders = shaders
	GG.CUSGL4.GetShader = GetShader
	GG.CUSGL4.GetShaderName = GetShaderName
	GG.CUSGL4.SetShaderUniforms = SetShaderUniforms
	GG.CUSGL4.enabled = true
	
end

function gadget:Shutdown()
	if debugmode then Spring.Echo(unitDrawBins, 'unitDrawBins') end

	for unitID, _ in pairs(cusUnitIDtoDrawFlag) do
		RemoveObject(unitID, "shutdown")
	end

	for featureID, _ in pairs(cusFeatureIDtoDrawFlag) do
		RemoveObject(-1 * featureID, "shutdown")
	end
	if unitDrawBins then
		for drawFlag, bins in pairs(unitDrawBins) do
			for shaderName, _ in pairs(bins) do
				shaders[drawFlag][shaderName]:Finalize()
			end
		end
	end
	modelsVertexVBO = nil
	modelsIndexVBO = nil

	unitDrawBins = nil
	initiated = false
	--gadgetHandler:RemoveChatAction("disablecusgl4")
	--gadgetHandler:RemoveChatAction("reloadcusgl4")
	--gadgetHandler:RemoveChatAction("cusgl4updaterate")
	if GG.CUSGL4 then 
		for k,v in pairs(GG.CUSGL4) do
			GG.CUSGL4[k] = nil
		end
	end 
	
	GG.CUSGL4 = nil
end



local updateframe = 0




local function countbintypes(flagarray)
	local fwcnt = 0
	local defcnt = 0
	local reflcnt = 0
	local shadcnt = 0

	for i=1, #flagarray do
		local flag = flagarray[i]
		if HasBit(flag,1) then
			fwcnt = fwcnt + 1
			defcnt = defcnt + 1
		end
		if HasBit(flag, 4) then
			reflcnt = reflcnt + 1
		end
		if HasBit(flag, 16) then
			shadcnt = shadcnt + 1
		end
	end
	return fwcnt, defcnt, reflcnt, shadcnt
end

local destroyedUnitIDs = {} -- maps unitID to drawflag
local destroyedUnitDrawFlags = {}
local numdestroyedUnits = 0

local destroyedFeatureIDs = {}
local destroyedFeatureDrawFlags = {}
local numdestroyedFeatures = 0

-- The Call order for event triggered draw changes is the following:
--During Sim:
-- 1. gadget:Unit*
-- 2. UpdateUnit(unitID, flag), adds it to the destroyedUnitIDs queue
--On next Update:
-- 3. next gadget:DrawWorldPreUnit is called 
-- 4. ProcessUnits(destroyedUnitIDs)
	-- 4.1 can either AddUnit, UpdateUnit or RemoveUnit
-- 5. Regular draw flag changes are processed


local function UpdateUnit(unitID, flag)
	numdestroyedUnits = numdestroyedUnits + 1
	destroyedUnitIDs[numdestroyedUnits] = unitID
	destroyedUnitDrawFlags[numdestroyedUnits] = flag
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	--UpdateUnit(unitID, 0) -- having this here means that dying units lose CUS, RenderUnitDestroyed _should_ be fine
end

function gadget:RenderUnitDestroyed(unitID, unitDefID)
	UpdateUnit(unitID, 0)
end

function gadget:UnitFinished(unitID)
	gl.SetUnitBufferUniforms(unitID, {-1}, 0) -- set build progress to built
	buildProgresses[unitID] = nil
	UpdateUnit(unitID,Spring.GetUnitDrawFlag(unitID))
end

local unitDefModelMaxY = {}
function gadget:UnitCreated(unitID, unitDefID)
	if not unitDefModelMaxY[unitDefID] then 
		--local unitHeight = Spring.GetUnitHeight(unitID)
		--local maxY = UnitDefs[unitDefID].model.maxy
		--Spring.Echo(UnitDefs[unitDefID].name, unitHeight, maxY)
		unitDefModelMaxY[unitDefID] = UnitDefs[unitDefID].model.maxy or 10
	end
	uniformCache[1] = unitDefModelMaxY[unitDefID]
	gl.SetUnitBufferUniforms(unitID, uniformCache, 11) -- set unit height
	uniformCache[1] = 0 
	gl.SetUnitBufferUniforms(unitID, uniformCache, 12) -- clear cloak effect
	gl.SetUnitBufferUniforms(unitID, uniformCache, 6) -- clear selectedness effect
	
	UpdateUnit(unitID,Spring.GetUnitDrawFlag(unitID))
end

function gadget:UnitGiven(unitID)
	local flag = Spring.GetUnitDrawFlag(unitID)
	if flag > 0 and flag < 128 then
		UpdateUnit(unitID, 0)
		UpdateUnit(unitID, Spring.GetUnitDrawFlag(unitID))
	end
end

function gadget:UnitGiven(unitID)
	local flag = Spring.GetUnitDrawFlag(unitID)
	if flag > 0 and flag < 128 then
		UpdateUnit(unitID, 0)
		UpdateUnit(unitID, Spring.GetUnitDrawFlag(unitID))
	end
end

function gadget:UnitCloaked(unitID)
	uniformCache[1] = Spring.GetGameFrame()
	gl.SetUnitBufferUniforms(unitID, uniformCache, 12)
	UpdateUnit(unitID,Spring.GetUnitDrawFlag(unitID))
	if debugmode then 
		Spring.Echo("UnitCloaked", unitID, Spring.GetUnitDrawFlag(unitID))
	end
end

function gadget:UnitDecloaked(unitID)
	UpdateUnit(unitID,Spring.GetUnitDrawFlag(unitID))
	uniformCache[1] = -1 * Spring.GetGameFrame()
	gl.SetUnitBufferUniforms(unitID, uniformCache, 12)
	if debugmode then 
		Spring.Echo("UnitDecloaked", unitID, Spring.GetUnitDrawFlag(unitID))
	end
end

function gadget:FeatureDestroyed(featureID)
	numdestroyedFeatures = numdestroyedFeatures + 1
	destroyedFeatureIDs[numdestroyedFeatures] = featureID
	destroyedFeatureDrawFlags[numdestroyedFeatures] = 0
end

local firstDraw = false
function gadget:DrawWorldPreUnit()
--function gadget:DrawGenesis() -- nope, shadow flags still a frame late https://github.com/beyond-all-reason/spring/issues/264
	if unitDrawBins == nil then return end

	updateframe = (updateframe + 1) % updaterate

	if updateframe == 0 then
		local t0 = Spring.GetTimerMicros()
		
		local units, drawFlagsUnits, features, drawFlagsFeatures
		
		if autoReload.enabled then
			if Spring.DiffTimers(Spring.GetTimer(), autoReload.lastUpdate) > autoReload.updateRate then 
				-- Check for fs and vs src identity
				autoReload.lastUpdate = Spring.GetTimer()
				
				local defaulttemplate = VFS.Include("modelmaterials_gl4/templates/defaultMaterialTemplate.lua")
				if (defaulttemplate.shader.vertex ~= defaultMaterialTemplate.shader.vertex) or 
					(defaulttemplate.shader.fragment ~= defaultMaterialTemplate.shader.fragment) then
					-- recompile on change:
					Spring.Echo("Changes to CUS shaders detected, recompiling...")
					RecompileShaders(true)
				end
			end
		end
		
		
		if manualReload then 
			manualReload = false
			units, drawFlagsUnits = Spring.GetRenderUnits(overrideDrawFlag, true)
			features, drawFlagsFeatures = Spring.GetRenderFeatures(overrideDrawFlag, true)
		else
			units, drawFlagsUnits = Spring.GetRenderUnitsDrawFlagChanged(true)
			features, drawFlagsFeatures = Spring.GetRenderFeaturesDrawFlagChanged(true)
		end
		
		--if (Spring.GetGameFrame() % 31)  == 0 then
		--	Spring.Echo("Updatenums", #units, #features, # drawFlagsUnits, #drawFlagsFeatures, numdestroyedUnits, numdestroyedFeatures)
		--	Spring.Echo(printDrawPassStats())
		--end
		local totalobjects = #units + #features + numdestroyedUnits + numdestroyedFeatures
		
		-- Why do we also do this processing round if #units > 0?
		if debugmode and (#destroyedUnitIDs>0 or #units > 0) then Spring.Echo("Processing destroyedUnitIDs", #units, #destroyedUnitIDs) end
		if numdestroyedUnits > 0 then
			ProcessUnits(destroyedUnitIDs, destroyedUnitDrawFlags, "destroyed")
			for i=numdestroyedUnits,1,-1 do
				destroyedUnitIDs[i] = nil
				destroyedUnitDrawFlags[i] = nil
			end
			numdestroyedUnits = 0
		end

		if numdestroyedFeatures > 0 then

			ProcessFeatures(destroyedFeatureIDs, destroyedFeatureDrawFlags, "destroyed")
			for i=numdestroyedFeatures,1,-1 do
				destroyedFeatureIDs[i] = nil
				destroyedFeatureDrawFlags[i] = nil
			end
			numdestroyedFeatures = 0
		end
		if firstDraw then
			local firstfeatures = Spring.GetVisibleFeatures()
			local firstdrawFlagsFeatures = {}
			local validFirstFeatures = {}
			local numfirstfeatures = 0
			for i, featureID in ipairs(firstfeatures) do
				local flag = Spring.GetFeatureDrawFlag(featureID)
				if flag and flag > 0 then
					numfirstfeatures = numfirstfeatures + 1
					validFirstFeatures[numfirstfeatures] = featureID
					firstdrawFlagsFeatures[numfirstfeatures] = flag
				end

			end
			ProcessFeatures(validFirstFeatures, firstdrawFlagsFeatures, "firstDraw")

			local firstunits = Spring.GetVisibleUnits()
			local firstdrawFlagsUnits = {}
			for i, unitID in ipairs(firstunits) do firstdrawFlagsUnits[i] = 1 + 4 + 16 end
			ProcessUnits(firstunits, firstdrawFlagsUnits, "firstDraw")

			firstDraw = false
		end


		ProcessUnits(units, drawFlagsUnits, "changed")
		ProcessFeatures(features, drawFlagsFeatures, "changed")

		local deltat = Spring.DiffTimers(Spring.GetTimerMicros(),t0,  nil) -- in ms
		--Spring.Echo(deltat)
		if (deltat > 2) and perfdebug then
			local usecperobjectchange = (1000* deltat)  / (totalobjects)
			Spring.Echo("[CUS GL4] [",Spring.GetDrawFrame(),"]",totalobjects," Update time 2 < ", deltat, string.format("ms, per object change: %.2fus ", usecperobjectchange),  totalobjects , 'objs')
			-- PERF CONCULUSION:
				-- Additions of units are about 30 uS
				-- Removals of units is about 50 uS
			-- After faster texture key lookups, this has dropped significantly:
				-- Additions of units are about 7 uS
				-- Removals of units is about 10 uS
			-- Using shared deferred and forward bin perf is now even closer:
				-- Addition 6 us
				-- Removal 7 us
			-- Further optimizations:
				-- addition is 2.2us per unit
				-- removal is 3.2us per unit
			-- After only handling fw, refl and shadow:
				-- Addition is 1.98us per unit
				-- removal is 2.40 us per unit
		end
	end
end

local nightFactorBins = {tree = 1.3, feature = 1.3, featurepbr = 1.3, treepbr = 1.3}
local lastSunChanged = -1
function gadget:SunChanged() -- Note that map_nightmode.lua gadget has to change sun twice in a single draw frame to update all
	local df = Spring.GetDrawFrame()
	if df == lastSunChanged then return end
	lastSunChanged = df
	local nightFactor = 1.0
	if GG['NightFactor'] then
		nightFactor = (GG['NightFactor'].red + GG['NightFactor'].green + GG['NightFactor'].blue) * 0.33
	end
	for uniformBinName, defaultBrightnessFactor in pairs(nightFactorBins) do
		uniformBins[uniformBinName].brightnessFactor = defaultBrightnessFactor * nightFactor
	end
end

-- Returns 0 for deferred pass
-- bit 1 is the opaque forward pass
local function drawPassBitsToNumber(opaquePass, deferredPass, drawReflection, drawRefraction)
	local drawPass = 0
	if deferredPass then return drawPass end

	if opaquePass then
		drawPass = drawPass + 1
	else
		drawPass = drawPass + 2
	end

	if drawReflection then
		drawPass = drawPass + 4
	end

	if drawRefraction then
		drawPass = drawPass + 8
	end
	return drawPass
end

function gadget:DrawOpaqueUnitsLua(deferredPass, drawReflection, drawRefraction)
	
	if unitDrawBins == nil then return end
	if preloadedTextures == false then PreloadTextures() end
	local drawPass = drawPassBitsToNumber(true, deferredPass, drawReflection, drawRefraction)
	local batches, units = ExecuteDrawPass(drawPass)
end

function gadget:DrawShadowUnitsLua()
	if unitDrawBins == nil then return end
	local batches, units = ExecuteDrawPass(16)
end
