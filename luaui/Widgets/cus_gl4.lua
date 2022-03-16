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
	-- Shaders / shaderconfig:
		-- Features
		-- Trees
		-- Regular Units
		-- Tanks
		-- Chickens
		-- Scavengers
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

local objectDefToBitShaderOptions = {} -- This is a table containing positive UnitIDs, negative featureDefIDs to bitShaderOptions mapping
local defaultBitShaderOptions = OPTION_SHADOWMAPPING + OPTION_NORMALMAPPING + OPTION_MODELSFOG

local function GetBitShaderOptions(unitDefID, featureDefID)
	if unitDefID and objectDefToBitShaderOptions[unitDefID] then 
		return objectDefToBitShaderOptions[unitDefID]
	elseif featureDefID and objectDefToBitShaderOptions[-1 * featureDefID] then 
		return objectDefToBitShaderOptions[-1 * featureDefID] 
	end
	return defaultBitShaderOptions
end

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

local overriddenUnits = {}
local processedUnits = {}

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


local idToDefId = {}

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

local function GetShader(drawPass, unitDef)
	return shaders[drawPass]['unit']
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
local function SetShaderUniforms(drawPass, shaderID)
	if true then return end
	if drawPass <= 2 then
		gl.UniformInt(gl.GetUniformLocation(shaderID, "drawMode"), 0)
		gl.Uniform(gl.GetUniformLocation(shaderID, "clipPlane2"), 0.0, 0.0, 0.0, 1.0)
	elseif drawPass == 16 then
		--gl.Uniform(gl.GetUniformLocation(shaderID, "alphaCtrl"), alphaThresholdOpaque, 1.0, 0.0, 0.0)
		-- set properly by default
	end

	if HasBit(drawPass, 1) then
		gl.Uniform(gl.GetUniformLocation(shaderID, "alphaCtrl"), alphaThresholdOpaque, 1.0, 0.0, 0.0)
		gl.Uniform(gl.GetUniformLocation(shaderID, "colorMult"), 1.0, 1.0, 1.0, 1.0)
	elseif HasBit(drawPass, 2) then
		gl.Uniform(gl.GetUniformLocation(shaderID, "alphaCtrl"), alphaThresholdAlpha , 1.0, 0.0, 0.0)
		gl.Uniform(gl.GetUniformLocation(shaderID, "colorMult"), 1.0, 1.0, 1.0, alphaMult)
	elseif HasBit(drawPass, 4) then
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
	texUnits  = {
		[0] = "%%UNITDEFID:0",
		[1] = "%%UNITDEFID:1",
		[2] = "%NORMALTEX",
	},
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

local shaderOptions = {
	forward = {
		unit = {},
		scavenger = {},
		chicken = {},
		otherunit = {},
		wreck = {},
		tree = {},
		feature = {},
	},
	deferred = {
		unit = {},
		scavenger = {},
		chicken = {},
		otherunit = {},
		wreck = {},
		tree = {},
		feature = {},
	},
	shadow = {
		unit = {},
		scavenger = {},
		chicken = {},
		otherunit = {},
		wreck = {},
		tree = {},
		feature = {},
	},
}


local DEFAULT_VERSION = [[#version 430 core
	#extension GL_ARB_uniform_buffer_object : require
	#extension GL_ARB_shader_storage_buffer_object : require
	#extension GL_ARB_shading_language_420pack: require
	]]

local function _CompileShader(shader, definitions, plugIns, addName)
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

	local luaShader = LuaShader(shader, "Custom Unit Shaders. " .. addName)
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
	local forwardShader = _CompileShader(template.shader, template.shaderDefinitions, template.shaderPlugins, name .."_forward" )
	local shadowShader = _CompileShader(template.shadow, template.shadowDefinitions, template.shaderPlugins, name .."_shadow" )
	local deferredShader = _CompileShader(template.deferred, template.deferredDefinitions, template.shaderPlugins, name .."_deferred" )
	
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


local unitDefIDtoTextureKeys = {}    -- table of  {unitDefID : TextureKey}
local featureDefIDtoTextureKeys = {} -- table of {featureDefID : TextureKey}

local textureKeytoSet = {} -- table of {TextureKey : {textureTable}}

local unitDefShaderBin = {} -- A table of {"armpw".id:"unit", "armpw_scav".id:"scavenger", "chickenx1".id:"chicken", "randomjunk":"vanilla"}

local featureDefShaderBin = {} --  A table of {"armpw_dead".id: "wrecks", "tree01".id:"featuretree", "rock1".id:"feature",}

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


local brdfLUT = false
local envLUT = false

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

local function initTextures()
	--if true then return end
	for unitDefID, unitDef in pairs(UnitDefs) do
		if unitDef.model then 
			local bitShaderOptions = defaultBitShaderOptions
			if unitDef.name:sub(1,3) == 'arm' or  unitDef.name:sub(1,3) == 'cor' then 
				bitShaderOptions = bitShaderOptions + OPTION_VERTEX_AO + OPTION_FLASHLIGHTS + OPTION_HEALTH_TEXTURING + OPTION_HEALTH_DISPLACE
			end 
			if unitDef.modCategories["tank"] then 
				if unitDef.name:sub(1,3) == 'arm' then 
					bitShaderOptions = bitShaderOptions + OPTION_THREADS_ARM
				elseif unitDef.name:sub(1,3) == 'cor' then 
					bitShaderOptions = bitShaderOptions + OPTION_THREADS_CORE
				end
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
				[9] = "modelmaterials_gl4/brdf_0.png",
				[10] = "modelmaterials_gl4/envlut_0.png",
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
				unitDefShaderBin[unitDefID] = 'scavenger'
				textureTable[3] = wreckTex1
				textureTable[4] = wreckTex2
				textureTable[5] = wreckNormalTex
				bitShaderOptions = bitShaderOptions + OPTION_SCAVENGER
			elseif unitDef.name:find("chicken", nil, true) then 
				unitDefShaderBin[unitDefID] = 'chicken'
				bitShaderOptions = bitShaderOptions + OPTION_HEALTH_TEXCHICKS + OPTION_HEALTH_DISPLACE
			elseif wreckTex1 and wreckTex2 then -- just a true unit:
				unitDefShaderBin[unitDefID] = 'unit'
				textureTable[3] = wreckTex1
				textureTable[4] = wreckTex2
				textureTable[5] = wreckNormalTex
			else
				unitDefShaderBin[unitDefID] = 'otherunit'
			end
			
			local texKey = GetTexturesKey(textureTable)
			if textureKeytoSet[texKey] == nil then 
				textureKeytoSet[texKey] = textureTable
			end 
			unitDefIDtoTextureKeys[unitDefID] = texKey
			if unitDef.name == 'corcom' or unitDef.name == 'armcom' then 
				--Spring.Echo(unitDef.name, texKey,unitDefShaderBin[unitDefID] , lowercasetex1,lowercasetex2 , normalTex, wreckTex1, wreckTex2)
				--Spring.Debug.TableEcho(textureTable)
			end
			objectDefToBitShaderOptions[unitDefID] = bitShaderOptions
		end
	end
	
	for featureDefID, featureDef in pairs(FeatureDefs) do 
		if featureDef.model then -- this is kind of a hack to work around specific modelless features metalspots found on Otago 1.4
			local bitShaderOptions = defaultBitShaderOptions
			
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
			}
			local texKey = GetTexturesKey(textureTable)
			if textureKeytoSet[texKey] == nil then 
				textureKeytoSet[texKey] = textureTable
			end 
			featureDefIDtoTextureKeys[featureDefID] = texKey
			
			if featureDef.name:find("_dead", nil, true) or featureDef.name:find("_heap", nil, true) then 
				featureDefShaderBin[featureDefID] = 'wreck'
			elseif featureDef.customParams and featureDef.customParams.treeshader == 'yes' then 
				featureDefShaderBin[featureDefID] = 'tree'
				bitShaderOptions = bitShaderOptions + OPTION_TREEWIND
			else
				featureDefShaderBin[featureDefID] = 'feature'
			end
			
			objectDefToBitShaderOptions[featureDefID] = bitShaderOptions
		end
	end
end

local function GetTextures(drawPass, unitDef)


	gettexturescalls = (gettexturescalls + 1 ) % (2^20)
	if drawPass == 16 then
		return {
			[0] = string.format("%%%s:%i", unitDef, 1), --tex2 only
		}
	else
		--Spring.Echo("GetTextures",drawPass, unitDef,unitDefIDtoTextureKeys[unitDef], textureKeytoSet[unitDefIDtoTextureKeys[unitDef]])
		if unitDefIDtoTextureKeys[unitDef] then 
			if textureKeytoSet[unitDefIDtoTextureKeys[unitDef]] then 
				return textureKeytoSet[unitDefIDtoTextureKeys[unitDef]]
			end
		end
		return {
			[0] = string.format("%%%s:%i", unitDef, 0),
			[1] = string.format("%%%s:%i", unitDef, 1),
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
-- @param unitID The unitID of the unit
-- @param unitDefID Which unitdef it belongs to 
-- @param flag which drawflags it has
-- @param shader which shader should be assigned to it
-- @param textures A table of {bindPosition:texturename} for this unit
-- @param texKey A unique key hashed from the textures names, bindpositions
local function AsssignUnitToBin(unitID, unitDefID, flag, shader, textures, texKey)
	asssigncalls = (asssigncalls + 1 ) % (2^20)
	shader = shader or GetShader(flag, unitDefID)
	textures = textures or GetTextures(flag, unitDefID)
	texKey = texKey or GetTexturesKey(textures)
	--	Spring.Debug.TraceFullEcho()	
	local unitDrawBinsFlag = unitDrawBins[flag]
	if unitDrawBinsFlag[shader] == nil then
		unitDrawBinsFlag[shader] = {}
	end
	local unitDrawBinsFlagShader = unitDrawBinsFlag[shader]
	uniformCache[1] = GetBitShaderOptions(unitDefID)
	gl.SetUnitBufferUniforms(unitID, uniformCache, 6)
	Spring.Echo("Setting UnitBufferUniforms", unitID, uniformCache[1])
	if unitDrawBinsFlagShader[texKey] == nil then
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
	
		unitDrawBinsFlagShader[texKey] = {
			textures = textures, -- hashmap of textures for this unit
			IBO = mybinIBO, -- my own IBO, for incrementing
			VAO = mybinVAO, -- my own VBO, for incremental updating
			objectsArray = {}, -- {index: objectID} 
			objectsIndex = {}, -- {objectID : index} (this is needed for efficient removal of items, as RemoveFromSubmission takes an index as arg)
			numobjects = 0,  -- a 'pointer to the end' 
		}
	end
	
	local unitDrawBinsFlagShaderTexKey = unitDrawBinsFlagShader[texKey]
	
	if unitDrawBinsFlagShaderTexKey.objectsIndex[unitID] then 
		Spring.Echo("Trying to add a unit to a bin that is already in it!")
	end
	
	
	local numobjects = unitDrawBinsFlagShaderTexKey.numobjects
	unitDrawBinsFlagShaderTexKey.IBO:InstanceDataFromUnitIDs(unitID, objectTypeAttribID, numobjects)
	unitDrawBinsFlagShaderTexKey.VAO:AddUnitsToSubmission   (unitID)
	
	numobjects = numobjects + 1 
	unitDrawBinsFlagShaderTexKey.numobjects = numobjects
	unitDrawBinsFlagShaderTexKey.objectsArray[numobjects] = unitID
	unitDrawBinsFlagShaderTexKey.objectsIndex[unitID    ] = numobjects
	
	if debugmode and flag == 0 then 
		Spring.Echo("AsssignUnitToBin", unitID, unitDefID, texKey,shader,flag, numobjects)
		local objids = "objectsArray "
		for k,v in pairs(unitDrawBinsFlagShaderTexKey.objectsArray) do 
			objids = objids .. tostring(k) .. ":" ..tostring(v) .. " " 
		end
		Spring.Echo(objids) 
	end
end


local function AddUnit(unitID, drawFlag)
	if (drawFlag >= 128) then --icon
		return
	end
	if (drawFlag >=  32) then --far tex
		return
	end

	local unitDefID = Spring.GetUnitDefID(unitID)
	idToDefId[unitID] = unitDefID

	--Spring.Echo(unitID, UnitDefs[unitDefID].name)

	for k = 1, #drawBinKeys do
		local flag = drawBinKeys[k]

		if HasAllBits(drawFlag, flag) then
			if overrideDrawFlagsCombined[flag] then
				AsssignUnitToBin(unitID, unitDefID, flag)
				if flag == 1 then
					AsssignUnitToBin(unitID, unitDefID, 0) --deferred hack
				end
			end
		end
	end

	Spring.SetUnitEngineDrawMask(unitID, 255 - overrideDrawFlag) -- ~overrideDrawFlag & 255
	overriddenUnits[unitID] = drawFlag
	--overriddenUnits[unitID] = overrideDrawFlag
end

local function RemoveUnitFromBin(unitID, unitDefID, texKey, shader, flag)
	shader = shader or GetShader(flag, unitDefID)
	textures = textures or GetTextures(flag, unitDefID)
	texKey = texKey or GetTexturesKey(textures)
	if unitDrawBins[flag][shader] then
		if unitDrawBins[flag][shader][texKey] then
			
			-- do the pop magic
			local unitDrawBinsFlagShaderTexKey = unitDrawBins[flag][shader][texKey]
			local objectIndex = unitDrawBinsFlagShaderTexKey.objectsIndex[unitID]
			
			--if flag == 0 then Spring.Echo("RemoveUnitFromBin", unitID, unitDefID, texKey,shader,flag,objectIndex) end
			if objectIndex == nil then 
				--Spring.Echo("Remove failed")
				return 
				end
			local numobjects = unitDrawBinsFlagShaderTexKey.numobjects
			
			unitDrawBinsFlagShaderTexKey.VAO:RemoveFromSubmission(objectIndex - 1) -- do we become out of order?
			if objectIndex == numobjects then -- last element
				unitDrawBinsFlagShaderTexKey.objectsIndex[unitID    ] = nil
				unitDrawBinsFlagShaderTexKey.objectsArray[numobjects] = nil
				unitDrawBinsFlagShaderTexKey.numobjects = numobjects -1 
			else
				local unitIDatEnd = unitDrawBinsFlagShaderTexKey.objectsArray[numobjects]
				if debugmode and flag == 0 then Spring.Echo("Moving", unitIDatEnd, "from", numobjects, " to", objectIndex, "while removing", unitID) end
				unitDrawBinsFlagShaderTexKey.objectsIndex[unitID     ] = nil -- pop back
				unitDrawBinsFlagShaderTexKey.objectsIndex[unitIDatEnd] = objectIndex -- bring the last unitID to to this one
				if Spring.ValidUnitID(unitIDatEnd) == true and Spring.GetUnitIsDead(unitIDatEnd) ~= true then
					unitDrawBinsFlagShaderTexKey.IBO:InstanceDataFromUnitIDs(unitIDatEnd, objectTypeAttribID, objectIndex - 1)
				else
					Spring.Echo("Tried to remove invalid unitID", unitID)
				end
				unitDrawBinsFlagShaderTexKey.objectsArray[numobjects ] = nil -- pop back
				unitDrawBinsFlagShaderTexKey.objectsArray[objectIndex] = unitIDatEnd -- Bring the last unitID here 
				unitDrawBinsFlagShaderTexKey.numobjects = numobjects -1 
			end
		end
	end
end

local function UpdateUnit(unitID, drawFlag)
	if (drawFlag >= 128) then --icon
		return
	end
	if (drawFlag >=  32) then --far tex
		return
	end

	local unitDefID = idToDefId[unitID]

	for k = 1, #drawBinKeys do
		local flag = drawBinKeys[k]

		local hasFlagOld = HasAllBits(overriddenUnits[unitID], flag)
		local hasFlagNew = HasAllBits(               drawFlag, flag)

		if hasFlagOld ~= hasFlagNew and overrideDrawFlagsCombined[flag] then
			local shader = GetShader(flag, unitDefID)
			local textures = GetTextures(flag, unitDefID)
			local texKey  = GetTexturesKey(textures)

			if hasFlagOld then --had this flag, but no longer have
				RemoveUnitFromBin(unitID, unitDefID, texKey, shader, flag)
				if flag == 1 then
					RemoveUnitFromBin(unitID, unitDefID, texKey, nil, 0)
				end
			end
			if hasFlagNew then -- didn't have this flag, but now has
				AsssignUnitToBin(unitID, unitDefID, flag, shader, textures, texKey)
				if flag == 1 then
					AsssignUnitToBin(unitID, unitDefID, 0, nil, textures, texKey) --deferred
				end
			end
		end
	end

	overriddenUnits[unitID] = drawFlag
end

local function RemoveUnit(unitID)
	--remove the object from every bin and table

	local unitDefID = idToDefId[unitID]

	for k = 1, #drawBinKeys do
		local flag = drawBinKeys[k]

		if overrideDrawFlagsCombined[flag] then
			local shader = GetShader(flag, unitDefID)
			local textures = GetTextures(flag, unitDefID)
			local texKey  = GetTexturesKey(textures)
			RemoveUnitFromBin(unitID, unitDefID, texKey, shader, flag)
			if flag == 1 then
				RemoveUnitFromBin(unitID, unitDefID, texKey, nil, 0)
			end
		end
	end

	idToDefId[unitID] = nil
	overriddenUnits[unitID] = nil
	processedUnits[unitID] = nil

	Spring.SetUnitEngineDrawMask(unitID, 255)
	--Spring.Debug.TableEcho(unitDrawBins)
end

local function ProcessUnits(units, drawFlags)
	processedCounter = (processedCounter + 1) % (2 ^ 16)

	for i = 1, #units do
		local unitID = units[i]
		local drawFlag = drawFlags[i]

		if overriddenUnits[unitID] == nil then --object was not seen
			AddUnit(unitID, drawFlag)
		elseif overriddenUnits[unitID] ~= drawFlag then --flags have changed
			UpdateUnit(unitID, drawFlag)
		end
		processedUnits[unitID] = processedCounter
	end

	for unitID, _ in pairs(overriddenUnits) do
		if processedUnits[unitID] ~= processedCounter then --object was not updated thus was removed
			RemoveUnit(unitID)
		end
	end
end

local unitIDscache = {}


local function ExecuteDrawPass(drawPass)
	--defersubmissionupdate = (defersubmissionupdate + 1) % 10;
	local batches = 0
	local units = 0
	for shaderId, data in pairs(unitDrawBins[drawPass]) do
		for _, texAndObj in pairs(data) do
		
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
					
					gl.UseShader(shaderId.shaderObj)
					SetShaderUniforms(drawPass, shaderId)
					
					mybinVAO:Submit()
					gl.UseShader(0)

					SetFixedStatePost(drawPass, shaderId)

					for bindPosition, tex in pairs(texAndObj.textures) do
						gl.Texture(bindPosition, false)
					end
				end
					
			elseif drawIncrementalMode == 0 then 
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
	return batches, units
end

function widget:Initialize()
	

	shaders[0 ] = {}
	for k = 1, #drawBinKeys do
		local flag = drawBinKeys[k]
		shaders[flag] = {}
	end

	compileMaterialShader(unitsNormalMapTemplate, "unit")
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
	
	initTextures()

	widget:Update()
end

function widget:Shutdown()
	--Spring.Debug.TableEcho(unitDrawBins)
	

	for unitID, _ in pairs(overriddenUnits) do
		RemoveUnit(unitID)
	end


	vbo = nil
	ebo = nil
	ibo = nil

	vao = nil
	unitDrawBins = nil
	
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
		local units, drawFlags = Spring.GetRenderUnits(overrideDrawFlag, true) 
		--units, drawFlags = Spring.GetRenderUnits(overrideDrawFlag, true)
		--Spring.Echo("#units", #units, overrideDrawFlag)
		ProcessUnits(units, drawFlags)
		--Spring.Debug.TableEcho(unitDrawBins)
	end
	
end

function widget:GameFrame(n)
	
	if (n%60) == 0 then 
		--Spring.Echo(Spring.GetGameFrame(), "processedCounter", processedCounter, asssigncalls,gettexturescalls)
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

	local batches, units = ExecuteDrawPass(drawPass)
	--Spring.Echo("drawPass", drawPass, "batches", batches, "units", units)
end

function widget:DrawAlphaUnitsLua(drawReflection, drawRefraction)
	local drawPass = 2 --alpha

	if drawReflection then
		drawPass = 2 + 4
	end

	if drawRefraction then
		drawPass = 2 + 8
	end

	local batches, units = ExecuteDrawPass(drawPass)
	--Spring.Echo("drawPass", drawPass, "batches", batches, "units", units)
	
end

function widget:DrawShadowUnitsLua()
	ExecuteDrawPass(16)
end