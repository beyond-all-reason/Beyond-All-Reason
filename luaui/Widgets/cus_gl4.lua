function widget:GetInfo()
	return {
		name	= "CUS GL4",
		author	= "ivand",
		layer	= 0,
		enabled	= true,
	}
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
			-- chickens
			-- scavengers
			-- 
			
		-- Cloakedunits for alpha
		-- Underconstructionunits


	-- Textures:
		-- arm/cor 
		-- 10x chickensets
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
	-- TODO treadoffset unitUniform
	-- TODO BITOPTIONS UNIFOOOOORM!
	-- normalmapping
	-- chickens
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
	-- todo: dynamically size IBOS instead of using the max of 8192!
	-- TODO: new engine callins needed:
		-- get the number of drawflaggable units (this is kind of gettable already from the API anyway) 
		-- get the number of changed drawFlags
		-- if the number of changed drawflags > log(numdrawflags) then do a full rebuild instead of push-popping
		-- e.g if there are 100 units of a bin in view, then a change of ~ 8 units will trigger a full rebuild?
			-- cant know ahead of time how many per-bin changes this will trigger though
			
	-- TODO: write an engine callin that, instead of the full list of unitdrawflags, only returns the list of units whos drawflags have changed!
		-- reset this 'hashmap' when reading it
		-- also a problem is handling units that died, what 'drawflag' should they get? 
			-- probably 0 
	-- TODO: handle fast rebuilds of the IBO's when large-magnitude changes happen
	-- TODO: faster bitops maybe?
	-- TODO: we dont handle shaderOptions yet for batches, where we are to keep the same shader, but only change its relevant options uniform
	
	-- TODO: Too many varyings are passed from VS to FS. 
		-- Specify some as flat, to avoid interpolation (e.g. teamcolor and selfillummod and maybe even fogfactor
		-- reduce total number of these varyings 
	
	-- TODO: GetTextures() is not the best implementation at the moment
	
	-- NOTE: in general, a function call is about 10x faster than a table lookup.... 
	
	-- TODO: how to handle units under construction? They cant be their own completely separate shit, cause of textures...
		-- might still make sense to do so
	-- TODO: fully blank normal map for non-normal mapped units (or else risk having to write a shader for that bin, which wont even get used
	
	-- TODO: alpha cloaked unitses :/ 
	
	-- TODO: feature drawing bits too
	
	-- TODO: rewrite treewave
	
	-- TODO: fix flashlights to be piece-unique
	
	-- TODO: investigate why/how refraction pass doesnt ever seem to get called
	
	-- TODO: reduce the amount of deferred buffers being used from 6 to 4
	
	-- TODO: check if LuaShader UniformLocations are cached
	
	-- TODO: Also add alpha units to deferred pass somehow?
	
	-- TODO: engine side: optimize shadow camera as it stupidly overdraws
	
	-- GetTextures :
		-- should return array table instead of hash table
			-- fill in unused stuff with 'false' for contiguous array table
			-- index -1 
			-- oddly enough, accessing array tables instead of hash tables is only 25% faster, so the overhead of -1 might not even result in any perf gains
			
		-- Should also get the normalmaps for each unit!
		-- PBR textures:
			-- uniform sampler2D brdfLUT;			//9
			-- uniform sampler2D envLUT;			//10
			-- uniform sampler2D rgbNoise;			//11
			-- uniform samplerCube reflectTex; 		// 7
			
			-- uniform sampler2D losMapTex;	//8 for features out of los maybe?
			
		-- We also need the skybox cubemap for PBR (samplerCube reflectTex)
		-- We also need wrecktex for damaged units!
	-- Create a default 'wrecktex' for features too? 
	
	

-- DONE:
	-- unit uniforms
-- KNOWN BUGS:
	-- Unitdestroyed doesnt trigger removal?
	-- CorCS doesnt always show up for reflection pass?
	-- Hovers dont show up for reflection pass
	-- Check the triangle tesselation artifacts on dbg_sphere!

--inputs

---- SHADERUNITUNIFORMS / BITSHADEROPTIONS ----
-- We are using the SUniformsBuffer vec4 uni[instData.y].userDefined[5] to pass data persistent unit-info
-- floats 0-5 are already in use by HealthBars
-- Buildprogress is in: UNITUNIFORMS.userDefined[0].x
-- bitShaderOptions are in 6: UNITUNIFORMS.userDefined[1].z
-- treadOffset goes into   7: UNITUNIFORMS.userDefined[1].w

local OPTION_SHADOWMAPPING    = 1
local OPTION_NORMALMAPPING    = 2
local OPTION_NORMALMAP_FLIP   = 4
local OPTION_VERTEX_AO        = 8
local OPTION_FLASHLIGHTS      = 16
local OPTION_THREADS_ARM      = 32
local OPTION_THREADS_CORE     = 64
local OPTION_HEALTH_TEXTURING = 128
local OPTION_HEALTH_DISPLACE  = 256
local OPTION_HEALTH_TEXCHICKS = 512
local OPTION_MODELSFOG        = 1024
local OPTION_TREEWIND         = 2048
local OPTION_SCAVENGER        = 4096

local defaultBitShaderOptions = OPTION_SHADOWMAPPING + OPTION_NORMALMAPPING  + OPTION_MODELSFOG

local objectDefToBitShaderOptions = {} -- This is a table containing positive UnitIDs, negative featureDefIDs to bitShaderOptions mapping

--[[ -- this is now unused
local function GetBitShaderOptions(unitDefID, featureDefID)
	if unitDefID and objectDefToBitShaderOptions[unitDefID] then 
		return objectDefToBitShaderOptions[unitDefID]
	elseif featureDefID and objectDefToBitShaderOptions[-1 * featureDefID] then 
		return objectDefToBitShaderOptions[-1 * featureDefID] 
	end
	return defaultBitShaderOptions
end
]]-- 

local objectDefToUniformBin = {} -- maps unitDefID/featuredefID to a uniform bin
-- IMPORTANT: OBJECTID AND OBJECTDEFID ARE ALWAYS POS FOR UNITS, NEG FOR FEATURES!
-- this will still use the same shader, but we gotta switch uniforms in between for efficiency
-- a uniform bin contains 
-- objectDefs are negative for features
-- objectIDs are negative for features too 

local function GetUniformBinID(objectDefID)
	if objectDefID >= 0 and objectDefToUniformBin[objectDefID] then
		return objectDefToUniformBin[objectDefID] 
	elseif objectDefToUniformBin[objectDefID] then 
		return objectDefToUniformBin[objectDefID] 
	else
		Spring.Echo("Failed to find a uniform bin id for objectDefID", objectDefID)
		Spring.Debug.TraceFullEcho()
		return 'otherunit'
	end
end

local uniformBins = {
	armunit = {
		bitOptions = defaultBitShaderOptions + OPTION_VERTEX_AO + OPTION_FLASHLIGHTS + OPTION_THREADS_ARM + OPTION_HEALTH_TEXTURING + OPTION_HEALTH_DISPLACE,
		baseVertexDisplacement = 0.0,
	},
	corunit = {
		bitOptions = defaultBitShaderOptions + OPTION_VERTEX_AO + OPTION_FLASHLIGHTS + OPTION_THREADS_CORE + OPTION_HEALTH_TEXTURING + OPTION_HEALTH_DISPLACE,
		baseVertexDisplacement = 0.0,
	},
	armscavenger = {
		bitOptions = defaultBitShaderOptions + OPTION_VERTEX_AO + OPTION_FLASHLIGHTS + OPTION_THREADS_ARM + OPTION_HEALTH_TEXTURING + OPTION_HEALTH_DISPLACE,
		baseVertexDisplacement = 0.4,
	},
	corscavenger = {
		bitOptions = defaultBitShaderOptions + OPTION_VERTEX_AO + OPTION_FLASHLIGHTS + OPTION_THREADS_CORE + OPTION_HEALTH_TEXTURING + OPTION_HEALTH_DISPLACE,
		baseVertexDisplacement = 0.4,
	},
	chicken = {
		bitOptions = defaultBitShaderOptions + OPTION_VERTEX_AO + OPTION_FLASHLIGHTS + OPTION_HEALTH_TEXTURING + OPTION_HEALTH_DISPLACE + OPTION_HEALTH_TEXCHICKS + OPTION_TREEWIND,
		baseVertexDisplacement = 0.0,
	},
	otherunit = {
		bitOptions = defaultBitShaderOptions,
		baseVertexDisplacement = 0.0,
	},
	feature = {
		bitOptions = defaultBitShaderOptions,
		baseVertexDisplacement = 0.0,
	},
	treepbr = {
		bitOptions = defaultBitShaderOptions,
		baseVertexDisplacement = 0.0,
	},
	tree = {
		bitOptions = defaultBitShaderOptions + OPTION_TREEWIND,
		baseVertexDisplacement = 0.0,
	},
	wreck = {
		bitOptions = defaultBitShaderOptions,
		baseVertexDisplacement = 0.0,
	},
} -- maps uniformbins to a table of uniform names/values

local shaderIDtoLuaShader = {}

local debugmode = false

local alphaMult = 0.35
local alphaThresholdOpaque = 0.5
local alphaThresholdAlpha  = 0.1
local overrideDrawFlags = {
	[0]  = true , --SO_OPAQUE_FLAG = 1, deferred hack
	[1]  = true , --SO_OPAQUE_FLAG = 1,
	[2]  = true , --SO_ALPHAF_FLAG = 2,
	[4]  = true , --SO_REFLEC_FLAG = 4,
	[8]  = true , --SO_REFRAC_FLAG = 8,
	[16] = true , --SO_SHADOW_FLAG = 16,
}


--implementation
local overrideDrawFlag = 0
for f, e in pairs(overrideDrawFlags) do
	overrideDrawFlag = overrideDrawFlag + f * (e and 1 or 0)
end
--      deferred    fw  fwrfl  fwrfr  op oprfl  oprfr  shadow
--         0         1    5     9     2    6     10     16
local drawBinKeys = {1, 1 + 4, 1 + 8, 2, 2 + 4, 2 + 8, 16} --deferred is handled ad-hoc
local overrideDrawFlagsCombined = {
	[0    ] = overrideDrawFlags[0],
	[1    ] = overrideDrawFlags[1],
	[1 + 4] = overrideDrawFlags[1] and overrideDrawFlags[4],
	[1 + 8] = overrideDrawFlags[1] and overrideDrawFlags[8],
	[2    ] = overrideDrawFlags[2],
	[2 + 4] = overrideDrawFlags[2] and overrideDrawFlags[4],
	[2 + 8] = overrideDrawFlags[2] and overrideDrawFlags[8],
	[16   ] = overrideDrawFlags[16],
}

local overriddenUnits = {} -- these remain positive, as they are traversed separately
local processedUnits = {}

local overriddenFeatures = {} -- this remains positive
local processedFeatures = {}

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
local unitDrawBins = {
	[0    ] = {},	-- deferred opaque
	[1    ] = {},	-- forward  opaque
	[1 + 4] = {},	-- forward  opaque + reflection
	[1 + 8] = {},	-- forward  opaque + refraction
	[2    ] = {},	-- alpha
	[2 + 4] = {},	-- alpha + reflection
	[2 + 8] = {},	-- alpha + refraction
	[16   ] = {},	-- shadow
}


local objectIDtoDefID = {}

local processedCounter = 0

local shaders = {} -- double nested table of {drawflag : {"units":shaderID}}

local vao = nil

local vbo = nil
local ebo = nil
local ibo = nil


local MAX_DRAWN_UNITS = 8192
local objectTypeAttribID = 6

-- setting this to 1 enables the incrementally updated VBOs
-- 0 updates it every frame
-- 2 completely disables draw, so one can measure overhead sans draw
local drawIncrementalMode = 1 -- 
-----------------

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

-----------------

local function GetShader(drawPass, objectDefID)
	if objectDefID == nil then 
		Spring.Debug.TraceFullEcho(nil,nil,nil, "No shader found for", objectDefID)
		return false
	end 
	if objectDefID >= 0 then 
		return shaders[drawPass]['unit']
	else
		return shaders[drawPass]['feature']
	end
	
end


local function SetFixedStatePre(drawPass, shaderID)
	if HasBit(drawPass, 4) then
		gl.ClipDistance(2, true)
	elseif HasBit(drawPass, 8) then
		gl.ClipDistance(2, true)
	end
end

local function SetFixedStatePost(drawPass, shaderID)
	if HasBit(drawPass, 4) then
		gl.ClipDistance(2, false)
	elseif HasBit(drawPass, 8) then
		gl.ClipDistance(2, false)
	end
end

--[[
drawMode:
		case  1: // water reflection
		case  2: // water refraction
		default: // player, (-1) static model, (0) normal rendering
]]--
local function SetShaderUniforms(drawPass, shaderID, uniformBinID)
	--if true then return end
	gl.UniformInt(gl.GetUniformLocation(shaderID, "drawPass"), drawPass)
	if drawPass <= 2 then
		gl.UniformInt(gl.GetUniformLocation(shaderID, "drawMode"), 0)
		gl.Uniform(gl.GetUniformLocation(shaderID, "clipPlane2"), 0.0, 0.0, 0.0, 1.0)
	elseif drawPass == 16 then
		--gl.Uniform(gl.GetUniformLocation(shaderID, "alphaCtrl"), alphaThresholdOpaque, 1.0, 0.0, 0.0)
		-- set properly by default
	end
	
	for uniformLocationName, uniformValue in pairs(uniformBins[uniformBinID]) do 
		--Spring.Echo("Setting uniform",uniformLocationName, uniformValue)
		if uniformLocationName == 'bitOptions' then 
			gl.UniformInt(gl.GetUniformLocation(shaderID, uniformLocationName), uniformValue)
		else
			gl.Uniform(gl.GetUniformLocation(shaderID, uniformLocationName), uniformValue)
		end
	end
	
	if HasBit(drawPass, 4) then
		gl.UniformInt(gl.GetUniformLocation(shaderID, "drawMode"), 1)
		gl.Uniform(gl.GetUniformLocation(shaderID, "clipPlane2"), 0.0, 1.0, 0.0, 0.0)
	elseif HasBit(drawPass, 8) then
		gl.UniformInt(gl.GetUniformLocation(shaderID, "drawMode"), 2)
		gl.Uniform(gl.GetUniformLocation(shaderID, "clipPlane2"), 0.0, -1.0, 0.0, 0.0)
	end
	
end

local MAX_TEX_ID = 131072 --should be enough
--- Hashes a table of textures to a unique integer
-- @param textures a table of {bindposition:texture}
-- @return a unique hash for binning
local function GetTexturesKey(textures)
	local cs = 0
	--Spring.Debug.TraceFullEcho(nil,nil,15)	
	for bindPosition, tex in pairs(textures) do
		local texInfo = nil
		if tex ~= false then 
			texInfo = gl.TextureInfo(tex)
		end
			
		
		local texInfoid = 0
		if texInfo and texInfo.id then texInfoid = texInfo.id end 
		cs = cs + (texInfoid or 0) + bindPosition * MAX_TEX_ID
	end

	return cs
end

------------------------- SHADERS                   ----------------------
------------------------- LOADING OLD CUS MATERIALS ----------------------
local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()

local MATERIALS_DIR = "modelmaterials_gl4/"

local defaultMaterialTemplate = VFS.Include("modelmaterials_gl4/templates/defaultMaterialTemplate.lua")

local unitsNormalMapTemplate = table.merge(defaultMaterialTemplate, {
	shaderDefinitions = {
		"#define RENDERING_MODE 0",
		"#define SUNMULT pbrParams[6]",
		"#define EXPOSURE pbrParams[7]",

		"#define SPECULAR_AO",

		"#define ROUGHNESS_AA 1.0",

		"#define ENV_SMPL_NUM " .. tostring(Spring.GetConfigInt("ENV_SMPL_NUM", 64)),
		"#define USE_ENVIRONMENT_DIFFUSE 1",
		"#define USE_ENVIRONMENT_SPECULAR 1",

		"#define TONEMAP(c) CustomTM(c)",
		"#define ENABLE_OPTION_HEALTH_TEXTURING 1",
		"#define ENABLE_OPTION_THREADS 1",
		"#define ENABLE_OPTION_HEALTH_DISPLACE 1",
	},
	deferredDefinitions = {
		"#define RENDERING_MODE 1",
		"#define SUNMULT pbrParams[6]",
		"#define EXPOSURE pbrParams[7]",

		"#define SPECULAR_AO",

		"#define ROUGHNESS_AA 1.0",

		"#define ENV_SMPL_NUM " .. tostring(Spring.GetConfigInt("ENV_SMPL_NUM", 64)),
		"#define USE_ENVIRONMENT_DIFFUSE 1",
		"#define USE_ENVIRONMENT_SPECULAR 1",

		"#define TONEMAP(c) CustomTM(c)",
		"#define ENABLE_OPTION_HEALTH_TEXTURING 1",
		"#define ENABLE_OPTION_THREADS 1",
		"#define ENABLE_OPTION_HEALTH_DISPLACE 1",
	},
	shadowOptions = {
		health_displace = true,
	},
	shaderOptions = {
		normalmapping = true,
		flashlights = true,
		vertex_ao = true,
		health_displace = true,
		health_texturing = true,
	},
	deferredOptions = {
		normalmapping = true,
		flashlights = true,
		vertex_ao = true,
		health_displace = true,
		health_texturing = true,
	},
})



local featuresNormalMapTemplate = table.merge(defaultMaterialTemplate, {

	shaderDefinitions = {
		"#define RENDERING_MODE 0",
		"#define SUNMULT pbrParams[6]",
		"#define EXPOSURE pbrParams[7]",

		"#define SPECULAR_AO",

		"#define ROUGHNESS_AA 1.0",

		"#define ENV_SMPL_NUM " .. tostring(Spring.GetConfigInt("ENV_SMPL_NUM", 64)),
		"#define USE_ENVIRONMENT_DIFFUSE 1",
		"#define USE_ENVIRONMENT_SPECULAR 1",

		"#define TONEMAP(c) CustomTM(c)",
		"#define USE_LOSMAP",
		
	},
	deferredDefinitions = {
		"#define RENDERING_MODE 1",
		"#define SUNMULT pbrParams[6]",
		"#define EXPOSURE pbrParams[7]",

		"#define SPECULAR_AO",

		"#define ROUGHNESS_AA 1.0",

		"#define ENV_SMPL_NUM " .. tostring(Spring.GetConfigInt("ENV_SMPL_NUM", 64)),
		"#define USE_ENVIRONMENT_DIFFUSE 1",
		"#define USE_ENVIRONMENT_SPECULAR 1",

		"#define TONEMAP(c) CustomTM(c)",
		"#define USE_LOSMAP",
	},
	shadowOptions = {
		health_displace = true,
	},
	shaderOptions = {
		normalmapping = true,
		flashlights = true,
		vertex_ao = true,
		health_displace = true,
		health_texturing = true,
	},
	deferredOptions = {
		normalmapping = true,
		flashlights = true,
		vertex_ao = true,
		health_displace = true,
		health_texturing = true,
	},
})




local DEFAULT_VERSION = [[#version 430 core
	#extension GL_ARB_uniform_buffer_object : require
	#extension GL_ARB_shader_storage_buffer_object : require
	#extension GL_ARB_shading_language_420pack: require
	]]

local function CompileLuaShader(shader, definitions, plugIns, addName)
	if definitions == nil or definitions == {} then 
		Spring.Echo(addName, "nul definitions", definitions)
	end
	definitions = definitions or {}

	local hasVersion = false
	if definitions[1] then -- #version must be 1st statement
		hasVersion = string.find(definitions[1], "#version") == 1
	end

	if not hasVersion then
		table.insert(definitions, 1, DEFAULT_VERSION)
	end

	shader.definitions = table.concat(definitions, "\n") .. "\n"
	
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
		local vsfile = io.open("cus_vs.glsl","w+")
		vsfile:write(shader.definitions .. shader.vertex)
		vsfile:close()

		local fsfile = io.open("cus_fs.glsl","w+")
		fsfile:write(shader.definitions .. shader.fragment)
		fsfile:close()

		
		
		widgetHandler:RemoveWidget()
		
		return nil
	else
		--Spring.Echo(addName, "Compiled successfully")
	end
	
	-- luaShader:SetUniformFloatAlways("gamma", Spring.GetConfigFloat("modelGamma", 1.0)) -- only possible with active shaders wtf

	return (compilationResult and luaShader) or nil
end




local function compileMaterialShader(template, name)
	local forwardShader = CompileLuaShader(template.shader, template.shaderDefinitions, template.shaderPlugins, name .."_forward" )
	local shadowShader = CompileLuaShader(template.shadow, template.shadowDefinitions, template.shaderPlugins, name .."_shadow" )
	local deferredShader = CompileLuaShader(template.deferred, template.deferredDefinitions, template.shaderPlugins, name .."_deferred" )
	
	for k = 1, #drawBinKeys do
		local flag = drawBinKeys[k]
		shaders[flag][name] = forwardShader
	end
	shaders[0 ][name] = deferredShader
	shaders[16][name] = shadowShader
end


local gettexturescalls = 0

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
	-- uniform sampler2D envLUT;			//10
	-- uniform sampler2D rgbNoise;			//11


local objectDefIDtoTextureKeys = {}    -- table of  {unitDefID : TextureKey, -featureDefID : TextureKey }
--local featureDefIDtoTextureKeys = {} -- table of {featureDefID : TextureKey}

local textureKeytoSet = {} -- table of {TextureKey : {textureTable}}

local unitDefShaderBin = {} -- A table of {"armpw".id:"unit", "armpw_scav".id:"scavenger", "chickenx1".id:"chicken", "randomjunk":"vanilla"}

local wreckTextureNames = {} -- A table of regular texture names to wreck texture names {"Arm_color.dds": "Arm_color_wreck.dds"}
local blankNormalMap = "unittextures/blank_normal.dds"

local wreckAtlases = {
	["arm"] = {
		"unittextures/Arm_wreck_color.dds",
		"unittextures/Arm_wreck_other.dds",
		"unittextures/Arm_wreck_color_normal.dds",
	},
	["cor"] = {
		"unittextures/cor_color_wreck.dds",
		"unittextures/cor_other_wreck.dds",
		"unittextures/cor_color_wreck_normal.dds",
	},
}


local brdfLUT = "modelmaterials_gl4/brdf_0.png"
local envLUT = "modelmaterials_gl4/envlut_0.png"

local function GetNormal(unitDef, featureDef)
	local normalMap = blankNormalMap

	if unitDef and unitDef.customParams and unitDef.customParams.normaltex and VFS.FileExists(unitDef.customParams.normaltex) then
		return unitDef.customParams.normaltex
	end

	if featureDef then
		if featureDef.customParams and featureDef.customParams.normaltex and VFS.FileExists(featureDef.customParams.normaltex) then
			return featureDef.customParams.normaltex
		end
		
		local tex1 = featureDef.model.textures.tex1 or "DOESNTEXIST.PNG"
		local tex2 = featureDef.model.textures.tex2 or "DOESNTEXIST.PNG"

		local unittexttures = "unittextures/"
		if (VFS.FileExists(unittexttures .. tex1)) and (VFS.FileExists(unittexttures .. tex2)) then
			normalMap = unittexttures .. tex1:gsub("%.","_normals.")
			-- Spring.Echo(normalMap)
			if (VFS.FileExists(normalMap)) then
				return normalMap
			end
			normalMap = unittexttures .. tex1:gsub("%.","_normal.")
			-- Spring.Echo(normalMap)
			if (VFS.FileExists(normalMap)) then
				return normalMap
			end
		end
	end

	return normalMap
end

local function initBinsAndTextures()
	--if true then return end
	for unitDefID, unitDef in pairs(UnitDefs) do
		if unitDef.model then 
			unitDefShaderBin[unitDefID] = 'unit'
			objectDefToUniformBin[unitDefID] = "otherunit"
			if unitDef.name:sub(1,3) == 'arm' then
				objectDefToUniformBin[unitDefID] = 'armunit'
			elseif 	unitDef.name:sub(1,3) == 'cor' then 
				objectDefToUniformBin[unitDefID] = 'corunit'
			end
			local normalTex = GetNormal(unitDef, nil)
			local textureTable = {
				--%-102:0 = featureDef 102 s3o tex1 
				[0] = string.format("%%%s:%i", unitDefID, 0),
				[1] = string.format("%%%s:%i", unitDefID, 1),
				[2] = normalTex,
				[3] = false,
				[4] = false,
				[5] = false,
				[6] = "$shadow",
				[7] = "$reflection",
				[8] = "$info:los", 
				[9] = brdfLUT,
				[10] = envLUT,
				[11] = "LuaUI/Images/rgbnoise.png",
			}
			-- is this a proper unitdef with a real 
			
			local lowercasetex1 = string.lower(unitDef.model.textures.tex1 or "")
			local lowercasetex2 = string.lower(unitDef.model.textures.tex2 or "")
			local lowercasenormaltex = string.lower(normalTex or "")
			
			local wreckTex1 = (lowercasetex1:find("arm_color", nil, true) and "unittextures/Arm_wreck_color.dds") or 
								(lowercasetex1:find("cor_color", nil, true) and "unittextures/Cor_color_wreck.dds")  or false
			local wreckTex2 = (lowercasetex2:find("arm_other", nil, true) and "unittextures/Arm_wreck_other.dds") or 
								(lowercasetex2:find("cor_other", nil, true) and "unittextures/Cor_other_wreck.dds")  or false
			local wreckNormalTex = (lowercasenormaltex:find("arm_normal") and "unittextures/Arm_wreck_color_normal.dds") or
					(lowercasenormaltex:find("cor_normal") and "unittextures/Cor_color_wreck_normal.dds") or false
			
			if unitDef.name:find("_scav", nil, true) then -- it better be a scavenger unit, or ill kill you
				textureTable[3] = wreckTex1
				textureTable[4] = wreckTex2
				textureTable[5] = wreckNormalTex
				if unitDef.name:sub(1,3) == 'arm' then
					objectDefToUniformBin[unitDefID] = 'armscavenger'
				elseif 	unitDef.name:sub(1,3) == 'cor' then 
					objectDefToUniformBin[unitDefID] = 'corscavenger'
				end
			elseif unitDef.name:find("chicken", nil, true) then 	
				objectDefToUniformBin[unitDefID] = 'chicken'
			elseif wreckTex1 and wreckTex2 then -- just a true unit:
				textureTable[3] = wreckTex1
				textureTable[4] = wreckTex2
				textureTable[5] = wreckNormalTex
			end
			
			local texKey = GetTexturesKey(textureTable)
			if textureKeytoSet[texKey] == nil then 
				textureKeytoSet[texKey] = textureTable
			end 
			objectDefIDtoTextureKeys[unitDefID] = texKey
			if unitDef.name == 'corcom' or unitDef.name == 'armcom' then 
				--Spring.Echo(unitDef.name, texKey,unitDefShaderBin[unitDefID] , lowercasetex1,lowercasetex2 , normalTex, wreckTex1, wreckTex2)
				--Spring.Debug.TableEcho(textureTable)
			end
		end
	end
	
	for featureDefID, featureDef in pairs(FeatureDefs) do 
		if featureDef.model then -- this is kind of a hack to work around specific modelless features metalspots found on Otago 1.4
			
			local textureTable = {
				[0] = string.format("%%-%s:%i", featureDefID, 0),
				[1] = string.format("%%-%s:%i", featureDefID, 1),
				[2] = GetNormal(nil, featureDef),
				[3] = false,
				[4] = false,
				[5] = false,
				[6] = "$shadow",
				[7] = "$reflection",
				[8] = "$info:los", 
				[9] = brdfLUT,
				[10] = envLUT,
				[11] = "LuaUI/Images/rgbnoise.png",
			}
			local texKey = GetTexturesKey(textureTable)
			if textureKeytoSet[texKey] == nil then 
				textureKeytoSet[texKey] = textureTable
			end 
			
			objectDefIDtoTextureKeys[-1 * featureDefID] = texKey
			objectDefToUniformBin[-1 * featureDefID] = 'feature'
			
			if featureDef.name:find("_dead", nil, true) or featureDef.name:find("_heap", nil, true) then 
				objectDefToUniformBin[-1 * featureDefID] = 'wreck'
			elseif featureDef.customParams and featureDef.customParams.treeshader == 'yes' then 
				objectDefToUniformBin[-1 * featureDefID] = 'tree'
			else
				
			end
		end
	end
end

local function GetTextures(drawPass, objectDefID)
	gettexturescalls = (gettexturescalls + 1 ) % (2^20)
	if objectDefID == nil then Spring.Debug.TraceFullEcho() end 
	if drawPass == 16 then
		return {
			[0] = string.format("%%%s:%i", objectDefID, 1), --tex2 only
		}
	else
		--Spring.Echo("GetTextures",drawPass, objectDef,objectDefIDtoTextureKeys[objectDef], textureKeytoSet[objectDefIDtoTextureKeys[objectDef]])
		if objectDefIDtoTextureKeys[objectDefID] then 
			if textureKeytoSet[objectDefIDtoTextureKeys[objectDefID]] then 
				return textureKeytoSet[objectDefIDtoTextureKeys[objectDefID]]
			end
		end
		return {
			[0] = string.format("%%%s:%i", objectDefID, 0),
			[1] = string.format("%%%s:%i", objectDefID, 1),
			[2] = "$shadow",
			[3] = "$reflection",
		}
	end
end




-----------------

local asssigncalls = 0
local uniformCache = {defaultBitShaderOptions}
--- Assigns a unit to a material bin
-- This function gets called from AddUnit every time a unit enters drawrange (or gets its flags changed)
-- @param objectID The unitID of the unit, or negative for featureID's
-- @param objectDefID Which unitdef it belongs to, negative for featureDefIDs
-- @param flag which drawflags it has
-- @param shader which shader should be assigned to it
-- @param textures A table of {bindPosition:texturename} for this unit
-- @param texKey A unique key hashed from the textures names, bindpositions
local function AsssignObjectToBin(objectID, objectDefID, flag, shader, textures, texKey, uniformBinID)
	asssigncalls = (asssigncalls + 1 ) % (2^20)
	shader = shader or GetShader(flag, objectDefID)
	textures = textures or GetTextures(flag, objectDefID)
	texKey = texKey or GetTexturesKey(textures)
	uniformBinID = uniformBinID or GetUniformBinID(objectDefID)
	--	Spring.Debug.TraceFullEcho()	
	local unitDrawBinsFlag = unitDrawBins[flag]
	if unitDrawBinsFlag[shader] == nil then
		unitDrawBinsFlag[shader] = {}
	end
	local unitDrawBinsFlagShader = unitDrawBinsFlag[shader]
	
	if unitDrawBinsFlagShader[uniformBinID] == nil then 
		unitDrawBinsFlagShader[uniformBinID] = {}
	end
	
	local unitDrawBinsFlagShaderUniforms = unitDrawBinsFlagShader[uniformBinID]
	--uniformCache[1] = GetBitShaderOptions(objectDefID)
	--gl.SetUnitBufferUniforms(objectID, uniformCache, 6)
	--Spring.Echo("Setting UnitBufferUniforms", objectID, uniformCache[1])
	if unitDrawBinsFlagShaderUniforms[texKey] == nil then
		local mybinVAO = gl.GetVAO()
		local mybinIBO = gl.GetVBO(GL.ARRAY_BUFFER, true)
		
		if (mybinIBO == nil) or (mybinVAO == nil) then 
			Spring.Echo("Failed to allocate IBO or VAO for CUS GL4", mybinIBO, mybinVAO)
			Spring.Debug.TraceFullEcho()
			widgetHandler:RemoveWidget()
		end
		
		mybinIBO:Define(MAX_DRAWN_UNITS, {
			{id = 6, name = "instData", type = GL.UNSIGNED_INT, size = 4},
		})
		
		mybinVAO:AttachVertexBuffer(vbo)
		mybinVAO:AttachIndexBuffer(ebo)
		mybinVAO:AttachInstanceBuffer(mybinIBO)
	
		unitDrawBinsFlagShaderUniforms[texKey] = {
			textures = textures, -- hashmap of textures for this unit
			IBO = mybinIBO, -- my own IBO, for incrementing
			VAO = mybinVAO, -- my own VBO, for incremental updating
			objectsArray = {}, -- {index: objectID} 
			objectsIndex = {}, -- {objectID : index} (this is needed for efficient removal of items, as RemoveFromSubmission takes an index as arg)
			numobjects = 0,  -- a 'pointer to the end' 
		}
	end
	
	local unitDrawBinsFlagShaderUniformsTexKey = unitDrawBinsFlagShaderUniforms[texKey]
	
	if unitDrawBinsFlagShaderUniformsTexKey.objectsIndex[objectID] then 
		Spring.Echo("Trying to add a unit to a bin that is already in it!")
	else
		Spring.Echo("AsssignObjectToBin success:",objectID, objectDefID, flag, shader, textures, texKey, uniformBinID	)
	end
	
	local numobjects = unitDrawBinsFlagShaderUniformsTexKey.numobjects
	
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
	unitDrawBinsFlagShaderUniformsTexKey.objectsIndex[objectID    ] = numobjects
	
	if debugmode and flag == 0 then 
		Spring.Echo("AsssignObjectToBin", objectID, objectDefID, texKey,uniformBinID, shader,flag, numobjects)
		local objids = "objectsArray "
		for k,v in pairs(unitDrawBinsFlagShaderUniformsTexKey.objectsArray) do 
			objids = objids .. tostring(k) .. ":" ..tostring(v) .. " " 
		end
		Spring.Echo(objids) 
	end
end


local function AddObject(objectID, drawFlag)
	if (drawFlag >= 128) then --icon
		return
	end
	if (drawFlag >=  32) then --far tex
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

	--Spring.Echo(unitID, UnitDefs[unitDefID].name)

	for k = 1, #drawBinKeys do
		local flag = drawBinKeys[k]

		if HasAllBits(drawFlag, flag) then
			if overrideDrawFlagsCombined[flag] then
				AsssignObjectToBin(objectID, objectDefID, flag)
				if flag == 1 then
					AsssignObjectToBin(objectID, objectDefID, 0) --deferred hack - what the fuck is this, it probably runs every time the 'forward opaque' pass is added
					
				end
			end
		end
	end
	if objectID >= 0 then 
		Spring.SetUnitEngineDrawMask(objectID, 255 - overrideDrawFlag) -- ~overrideDrawFlag & 255
		overriddenUnits[objectID] = drawFlag
	else
		Spring.SetFeatureEngineDrawMask(-objectID, 255 - overrideDrawFlag) -- ~overrideDrawFlag & 255
		overriddenFeatures[-1 *objectID] = drawFlag
	end
	--overriddenUnits[unitID] = overrideDrawFlag
end

local function RemoveObjectFromBin(objectID, objectDefID, texKey, shader, flag, uniformBinID)
	shader = shader or GetShader(flag, objectDefID)
	textures = textures or GetTextures(flag, objectDefID)
	texKey = texKey or GetTexturesKey(textures)
	Spring.Echo("RemoveObjectFromBin", objectID, objectDefID, texKey,shader,flag,objectIndex) 
	if unitDrawBins[flag][shader] then
		if unitDrawBins[flag][shader][uniformBinID] then 
			if unitDrawBins[flag][shader][uniformBinID][texKey] then
				
				-- do the pop magic
				local unitDrawBinsFlagShaderTexKey = unitDrawBins[flag][shader][uniformBinID][texKey]
				local objectIndex = unitDrawBinsFlagShaderTexKey.objectsIndex[objectID]
				
				--if flag == 0 then Spring.Echo("RemoveObjectFromBin", objectID, objectDefID, texKey,shader,flag,objectIndex) end
				Spring.Echo("RemoveObjectFromBin really", objectID, objectDefID, texKey,shader,flag,objectIndex) 
				if objectIndex == nil then 
					Spring.Echo("Remove failed")
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
							Spring.Echo("Tried to remove invalid unitID", objectID)
						end
					else -- feauture
						if Spring.ValidFeatureID(-objectIDatEnd) == true then
							unitDrawBinsFlagShaderTexKey.IBO:InstanceDataFromFeatureIDs(-1 * objectIDatEnd, objectTypeAttribID, objectIndex - 1)
						else
							Spring.Echo("Tried to remove invalid featureID", objectID)
						end
					end
					unitDrawBinsFlagShaderTexKey.objectsArray[numobjects ] = nil -- pop back
					unitDrawBinsFlagShaderTexKey.objectsArray[objectIndex] = objectIDatEnd -- Bring the last objectID here 
					unitDrawBinsFlagShaderTexKey.numobjects = numobjects -1 
				end
			else
				Spring.Echo("Failed to find texKey for", objectID, objectDefID, texKey, shader, flag, uniformBinID)
			end
		else
			Spring.Echo("Failed to find uniformBinID for", objectID, objectDefID, texKey, shader, flag, uniformBinID)
		end
	else
		local defName ='niiiil'
		if objectDefID then
			if objectDefID >= 0 then 
				defName =  UnitDefs[objectDefID].name
			else
				defName =  FeatureDefs[-1 * objectDefID].name
			end
		end
			
		
		Spring.Echo("Failed to find shader for", objectID, objectDefID, texKey, shader, flag, uniformBinID, defName) 
		Spring.Debug.TraceFullEcho(30,30,30)
	end
end

local function UpdateObject(objectID, drawFlag)
	if (drawFlag >= 128) then --icon
		return
	end
	if (drawFlag >=  32) then --far tex
		return
	end

	local objectDefID = objectIDtoDefID[objectID]

	for k = 1, #drawBinKeys do
		local flag = drawBinKeys[k]
		local hasFlagOld
		if objectID >= 0 then 
			hasFlagOld = HasAllBits(overriddenUnits[objectID], flag)
		else
			hasFlagOld = HasAllBits(overriddenFeatures[-1 * objectID], flag)
		end
		local hasFlagNew = HasAllBits(               drawFlag, flag)

		if hasFlagOld ~= hasFlagNew and overrideDrawFlagsCombined[flag] then
			local shader = GetShader(flag, objectDefID)
			local textures = GetTextures(flag, objectDefID)
			local texKey  = GetTexturesKey(textures)
			local uniformBinID = GetUniformBinID(objectDefID)

			if hasFlagOld then --had this flag, but no longer have
				RemoveObjectFromBin(objectID, objectDefID, texKey, shader, flag, uniformBinID)
				if flag == 1 then
					RemoveObjectFromBin(objectID, objectDefID, texKey, nil, 0, uniformBinID)
				end
			end
			if hasFlagNew then -- didn't have this flag, but now has
				AsssignObjectToBin(objectID, objectDefID, flag, shader, textures, texKey, uniformBinID)
				if flag == 1 then
					AsssignObjectToBin(objectID, objectDefID, 0, nil, textures, texKey, uniformBinID) --deferred
				end
			end
		end
	end
	if objectID >= 0 then 
		overriddenUnits[objectID] = drawFlag
	else	
		overriddenFeatures[-1 * objectID] = drawFlag
	end
end

local function RemoveObject(objectID) -- we get pos/neg objectID here 
	--remove the object from every bin and table
	local objectDefID 
	if objectID == nil then Spring.Debug.TraceFullEcho() end 
	if objectID >= 0 then 
		objectDefID = Spring.GetUnitDefID(objectID)
	else 
		objectDefID = -1 * Spring.GetFeatureDefID(-1 * objectID)
	end
		
	objectIDtoDefID[objectID] = objectDefID -- TODO this looks redundant

	for k = 1, #drawBinKeys do
		local flag = drawBinKeys[k]
		Spring.Echo("RemoveObject Flags", objectID, flag, overrideDrawFlagsCombined[flag] )
		if overrideDrawFlagsCombined[flag] then
			local shader = GetShader(flag, objectDefID)
			local textures = GetTextures(flag, objectDefID)
			local texKey  = GetTexturesKey(textures)
			local uniformBinID = GetUniformBinID(objectDefID)
			RemoveObjectFromBin(objectID, objectDefID, texKey, shader, flag, uniformBinID)
			if flag == 1 then
				RemoveObjectFromBin(objectID, objectDefID, texKey, nil, 0, uniformBinID)
			end
		end
	end
	objectIDtoDefID[objectID] = nil
	if unitID then 
		overriddenUnits[objectID] = nil
		processedUnits[objectID] = nil
		Spring.SetUnitEngineDrawMask(objectID, 255)
	else
		overriddenFeatures[-1 * objectID] = nil
		processedFeatures[-1 * objectID] = nil
		Spring.SetFeatureEngineDrawMask(-1 * objectID, 255)
	end

	--Spring.Debug.TableEcho(unitDrawBins)
end

local function ProcessUnits(units, drawFlags)
	processedCounter = (processedCounter + 1) % (2 ^ 16)

	for i = 1, #units do
		local unitID = units[i]
		local drawFlag = drawFlags[i]
		--Spring.Echo("ProcessUnit", unitID, drawFlag)
		if overriddenUnits[unitID] == nil then --object was not seen
			AddObject(unitID, drawFlag)
		elseif overriddenUnits[unitID] ~= drawFlag then --flags have changed
			UpdateObject(unitID, drawFlag)
		end
		processedUnits[unitID] = processedCounter
	end

	for unitID, _ in pairs(overriddenUnits) do
		if processedUnits[unitID] ~= processedCounter then --object was not updated thus was removed
			RemoveObject(unitID)
		end
	end
end

local function ProcessFeatures(features, drawFlags)
	processedCounter = (processedCounter + 1) % (2 ^ 16)

	for i = 1, #features do
		local featureID = features[i]
		local drawFlag = drawFlags[i]

		--Spring.Echo("ProcessFeature", featureID	, drawFlag)
		if overriddenFeatures[featureID] == nil then --object was not seen
			AddObject(-1 * featureID, drawFlag)
		elseif overriddenFeatures[featureID] ~= drawFlag then --flags have changed
			UpdateObject(-1 * featureID, drawFlag)
		end
		processedFeatures[featureID] = processedCounter
	end

	for featureID, _ in pairs(overriddenFeatures) do
		if processedFeatures[featureID] ~= processedCounter then --object was not updated thus was removed
			RemoveObject(-1 * featureID)
		end
	end
end

local unitIDscache = {}

local shaderactivations = 0

local function ExecuteDrawPass(drawPass)
	--defersubmissionupdate = (defersubmissionupdate + 1) % 10;
	local batches = 0
	local units = 0
	for shaderId, data in pairs(unitDrawBins[drawPass]) do
		local unitscountforthisshader = 0 
		--Spring.Echo("uniformBinID", uniformBinID)
		
		for _, uniformBin in pairs(data) do
			for _, texAndObj in pairs(uniformBin) do
				unitscountforthisshader = unitscountforthisshader + texAndObj.numobjects
			end
		end
		
		if unitscountforthisshader > 0 then 
			gl.UseShader(shaderId.shaderObj)
			
			for uniformBinID, uniformBin in pairs(data) do

				--Spring.Echo("Shadername", shaderId.shaderName,"uniformBinID", uniformBinID)
				--local uniforms = uniformBins[uniformBinID] 
				
				-- TODO: only activate shader if we actually have units in its bins?
				SetShaderUniforms(drawPass, shaderId.shaderObj, uniformBinID)
				
				for _, texAndObj in pairs(uniformBin) do
					if drawIncrementalMode == 1 then 
						if texAndObj.numobjects > 0  then 
							batches = batches + 1
							units = units + texAndObj.numobjects
							local mybinVAO = texAndObj.VAO
							for bindPosition, tex in pairs(texAndObj.textures) do
								if Spring.GetGameFrame() % 60 == 0 then 
									--Spring.Echo(bindPosition, tex)	
								end
								gl.Texture(bindPosition, tex)
							end
							
							SetFixedStatePre(drawPass, shaderId)
							shaderactivations = shaderactivations + 1 
							--SetShaderUniforms(drawPass, shaderId.shaderObj)
							
							mybinVAO:Submit()

							SetFixedStatePost(drawPass, shaderId)

							for bindPosition, tex in pairs(texAndObj.textures) do
								gl.Texture(bindPosition, false)
							end
						end
					elseif drawIncrementalMode == 0 then -- will no longer work when features are present!
						batches = batches + 1
						
						for bindPosition, tex in pairs(texAndObj.textures) do
							gl.Texture(bindPosition, tex)
						end
						
						SetFixedStatePre(drawPass, shaderId)
						
						for unitID, _ in pairs(texAndObj.objectsIndex) do
							unitIDscache[#unitIDscache + 1] = unitID
							units = units + 1 
						end
						
						ibo:InstanceDataFromUnitIDs(unitIDscache, 6) --id = 6, name = "instData"
						vao:ClearSubmission()
						vao:AddUnitsToSubmission(unitIDscache)
						
						for i=1, #unitIDscache do
							unitIDscache[i] = nil
						end
						
						gl.UseShader(shaderId)
						SetShaderUniforms(drawPass, shaderId)
						
						vao:Submit()
						gl.UseShader(0)

						SetFixedStatePost(drawPass, shaderId)
						

						for bindPosition, tex in pairs(texAndObj.textures) do
							gl.Texture(bindPosition, false)
						end
					end
				end
			end
			
			gl.UseShader(0)
		end
	end
	return batches, units
end

function widget:Initialize()
	

	shaders[0 ] = {}
	for k = 1, #drawBinKeys do
		local flag = drawBinKeys[k]
		shaders[flag] = {}
	end

	compileMaterialShader(unitsNormalMapTemplate, "unit")
	compileMaterialShader(featuresNormalMapTemplate, "feature")
	-- Initialize shaders types like so:
	--shaders[0 ]['units] ...

	vao = gl.GetVAO()
	if vao == nil then
		widgetHandler:RemoveWidget()
	end

	vbo = gl.GetVBO(GL.ARRAY_BUFFER, false)
	ebo = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false)
	ibo = gl.GetVBO(GL.ARRAY_BUFFER, true)

	if ((vbo == nil) or (ebo == nil) or (ibo == nil)) then
		widgetHandler:RemoveWidget()
	end

	ibo:Define(MAX_DRAWN_UNITS, {
		{id = 6, name = "instData", type = GL.UNSIGNED_INT, size = 4},
	})

	vbo:ModelsVBO()
	ebo:ModelsVBO()

	vao:AttachVertexBuffer(vbo)
	vao:AttachIndexBuffer(ebo)
	vao:AttachInstanceBuffer(ibo)
	
	initBinsAndTextures()

	widget:Update()
end


local function tableEcho(data, name, indent, tableChecked)
	name = name or "TableEcho"
	indent = indent or ""
	if (not tableChecked) and type(data) ~= "table" then
		Spring.Echo(indent .. name, data)
		return
	end
	if type (name) == "table" then 
		name = '<table>'
	end
	Spring.Echo(indent .. name .. " = {")
	local newIndent = indent .. "    "
	for name, v in pairs(data) do
		local ty = type(v)
		if ty == "table" then
			tableEcho(v, name, newIndent, true)
		elseif ty == "boolean" then
			Spring.Echo(newIndent .. name .. " = " .. (v and "true" or "false"))
		elseif ty == "string" or ty == "number" then
			Spring.Echo(newIndent .. name .. " = " .. v)
		else
			Spring.Echo(newIndent .. name .. " = ", v)
		end
	end
	Spring.Echo(indent .. "},")
end

function widget:Shutdown()
	tableEcho(unitDrawBins, 'unitDrawBins')
	

	for unitID, _ in pairs(overriddenUnits) do
		RemoveObject(unitID)
	end
	
	for featureID, _ in pairs(overriddenFeatures) do
		RemoveObject(-1 * featureID)
	end



	vbo = nil
	ebo = nil
	ibo = nil

	vao = nil
	unitDrawBins = nil
	Spring.Debug.TraceFullEcho()
	if true then return end
	gl.DeleteShader(shaders[0]) -- deferred
	gl.DeleteShader(shaders[1]) -- forward
	gl.DeleteShader(shaders[16]) -- shadow
end

local updateframe = 0
function widget:Update()
	
	updateframe = (updateframe + 1) % 1
	
	if updateframe == 0 then 
		-- this call has a massive mem load, at 1k units at 225 fps, its 7mb/sec, e.g. for each unit each frame, its 32 bytes alloc/dealloc
		-- which isnt all that bad, but still far from optimal
		-- it is, however, not that bad CPU wise, and it doesnt force GC load either
		local units, drawFlagsUnits = Spring.GetRenderUnits(overrideDrawFlag, true) 
		--units, drawFlags = Spring.GetRenderUnits(overrideDrawFlag, true)
		--Spring.Echo("#units", #units, overrideDrawFlag)
		ProcessUnits(units, drawFlagsUnits)
		
		local features, drawFlagsFeatures = Spring.GetRenderFeatures(overrideDrawFlag, true)
		ProcessFeatures(features, drawFlagsFeatures)
		--Spring.Debug.TableEcho(unitDrawBins)
	end
	
end

local seenbitsopaque = 0
local seenbitsalpha = 0
local gf = 0
function widget:GameFrame(n)
	gf = n
	if (n%300) == 0 then 
		Spring.Echo(Spring.GetGameFrame(), "processedCounter", processedCounter, asssigncalls,gettexturescalls, 'seenopaque', seenbitsopaque, 'seenalpha', seenbitsalpha)
	end
end

local function markBin(drawPass)
	local count = 0
	for shaderId, data in pairs(unitDrawBins[drawPass]) do
		for _, uniformBin in pairs(data) do
			for uniformBinID, uniformBin in pairs(data) do
				for _, texAndObj in pairs(uniformBin) do
					for unitID, _ in pairs(texAndObj.objectsIndex) do
						local px, py, pz = Spring.GetUnitPosition(unitID)
						if px then 
							Spring.MarkerAddPoint(px,py,pz, tostring(drawPass) .. "/" .. tostring(unitID))
							count = count + 1
						end
					end
				end
			end
		end
	end
	Spring.Echo("Added markers for", count, "units in drawPass", drawPass)
end
	

function widget:TextCommand(command)
	if string.find(command, "cusgl4markbin", nil, true) == 1 then
		local startmatch, endmatch = string.find(command, "cusgl4markbin", nil, true)
		local param = string.sub(command, endmatch + 2,nil)
		if param and tonumber(param) then 
			markBin(tonumber(param))
		end
	end
end


function widget:DrawOpaqueUnitsLua(deferredPass, drawReflection, drawRefraction)
	local drawPass = 1 --opaque

	if deferredPass then
		drawPass = 0
	end

	if drawReflection then
		drawPass = 1 + 4
	end

	if drawRefraction then
		drawPass = 1 + 8
	end

	seenbitsopaque = math.bit_or(seenbitsopaque, drawPass)
	local batches, units = ExecuteDrawPass(drawPass)
	--if gf % 61 == 0 then Spring.Echo("drawPass", drawPass, "batches", batches, "units", units) end 	
end

function widget:DrawAlphaUnitsLua(drawReflection, drawRefraction)
	local drawPass = 2 --alpha

	if drawReflection then
		drawPass = 2 + 4
	end

	if drawRefraction then
		drawPass = 2 + 8
	end
	
	seenbitsalpha = math.bit_or(seenbitsalpha, drawPass)
	local batches, units = ExecuteDrawPass(drawPass)
	--if gf % 61 == 0 then Spring.Echo("drawPass", drawPass, "batches", batches, "units", units) end
	
end

function widget:DrawOpaqueFeaturesLua(deferredPass, drawReflection, drawRefraction)

	--Spring.Echo("widget:DrawOpaqueFeaturesLua",deferredPass, drawReflection, drawRefraction)
	local drawPass = 1 --opaque

	if deferredPass then
		drawPass = 0
	end

	if drawReflection then
		drawPass = 1 + 4
	end

	if drawRefraction then
		drawPass = 1 + 8
	end

	seenbitsopaque = math.bit_or(seenbitsopaque, drawPass)
	--local batches, units = ExecuteDrawPass(drawPass)
	--if gf % 61 == 0 then Spring.Echo("drawPass", drawPass, "batches", batches, "units", units) end 	
end

function widget:DrawAlphaFeaturesLua(drawReflection, drawRefraction)
	--Spring.Echo("widget:DrawAlphaFeaturesLua",drawReflection, drawRefraction)
	local drawPass = 2 --alpha

	if drawReflection then
		drawPass = 2 + 4
	end

	if drawRefraction then
		drawPass = 2 + 8
	end
	
	seenbitsalpha = math.bit_or(seenbitsalpha, drawPass)
	--local batches, units = ExecuteDrawPass(drawPass)
	--if gf % 61 == 0 then Spring.Echo("drawPass", drawPass, "batches", batches, "units", units) end
	
end

function widget:DrawShadowUnitsLua()
	ExecuteDrawPass(16)
end