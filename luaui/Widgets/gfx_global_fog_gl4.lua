--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
function widget:GetInfo()
	return {
		name = "Global Fog GL4",
		version = 3,
		desc = "Draws new Global fog",
		author = "Beherith",
		date = "2022.07.14",
		license = "Lua code is GPL V2, GLSL is (c) Beherith",
		layer = 100010, -- lol this isnt even a number
		enabled = false
	}
end

local GL_RGBA32F_ARB = 0x8814
local GL_R32F = 0x822E
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- TODO: 2022.11.30
-- Expose fog params via uniforms:
	-- Fog Color
	-- Global Fog density
	-- Fog Plane Height
	-- Height-based fog density
-- Pre optimization at full screen on Colorado is 190 -> 120fps, after 190->150fps
-- DONE: Fix mixing of shadow marching and noise sampling, with conditional shadow marching
-- Fix colorization based on sun angle
-- DONE: Use a spherical harmonics equation for this?
-- DONE: Fix colorization of height based and distance based fog
-- DONE Use non constant density fog (maybe exponential is better?) (using linear at the moment)
-- Create a better noise texture (also use this for other occasions!)
-- DONE: Expose params to be easily tunable
-- Create quality 'presets' and auto apply them?
-- DONE: better LOS shader usage?
-- DONE: minimap color backscatter
-- DONE: Fix blending of shadowed and non-shadowed
-- DONE handle out-of-map better!
-- DONE: Fix non raytraced fog nonlinearity
-- TODO: Make it also be clouds
-- TODO: handle pullback of min(mapdepth, modeldepth); better than now.
-- TODO: Volumetric "water shadow scattering" pass
-- TODO: Reflections shader
-- TODO: HDR blending
-- VERY IMPORTANT NOTES:
-- WHEN NOT USING RAYTRACING, SET FOG RESOLUTION TO 1!!!!!!!!!
-- TODO: Switch to premultiplied alpha, which is needed for proper raymarchcing compositing:
	-- https://lightrun.com/answers/mrdoob-three-js-incorrect-brightness-when-gl_fragcolor-is-semi-transparent
	-- So gl.Blending(GL.ONE, GL.ONE_MINUS_SRC_ALPHA) -- GL.ONE instead of GL.SRC_ALPHA
	-- Which means that the final, compositing fragment output needs its fragColor.rgb = fragColor.rgb * fragColor.a


-- Most fucked up idea ever:
	-- a simple 2d texture lookup is _still_ faster than a fucking noise gen, even the cheapest goddamned FBM noise too
	-- ping-pong between two textures every gameframe, and render all units into that. What should the texture contain?
	-- Well it should always read the first ping, to be able to decay it
	-- red and blue contain XY offset of all unit's triggered noise swirl shit
	-- green could contain the 'height' of the turbulence
	
	-- 
	-- Alpha of it should contain like a global noise offset, which should blow with the wind, but contain some underlying moderate frequency noise

-- Performance Notes 2023.10.13
	-- Combine Shader eats .35 ms in rez == 2 mode, but only 100 ms in rez >= 3
	-- Total cost at rez = 2 is like 2.4 ms, broken down into:
		-- combine shader 0.35ms
		-- clouds 0.85ms
		-- cloud shadows 0.45ms
		-- uw shadows 0.10 ms
		-- height fog 0.2 ms
		-- rest of the shit 0.4 ms
		-- VGPR Pressure according to RGA tool is 48. This did require some finagling:
			-- layout(binding = 4) uniform sampler2D modelDepths;
			-- layout(set=0, binding = 15) uniform TheBlock{
				-- uniform float windX;
				-- 

-- TODO 20250822
	-- [ ] RMLUI Sliders are 1 update late always 
	-- [ ] Combine shader sample neighbour texels with texelgather

------------- Literature and Reading: ---
-- blue noise sampling:  https://blog.demofox.org/2020/05/10/ray-marching-fog-with-blue-noise/
-- Inigo quliez fog lighting tips: https://iquilezles.org/articles/fog/
-- Analyitic fog density: https://blog.demofox.org/2014/06/22/analytic-fog-density/


---- CONFIGURABLE PARAMETERS: -----------------------------------------



local vsx, vsy = Spring.GetViewGeometry()
local hsx, hsy

local sliderStack = {}

local function AddSlider(name, minval, maxval, step)
end

local function DrawSliders() -- origin is bottom left
	local mx,my,left = Spring.GetMouseStat()
	for i, slider in ipairs(sliderStack) do 
		gl.Color(1,1,1,1)
		gl.Text()
		gl.Rect()
	end
end

local minHeight, maxHeight = Spring.GetGroundExtremes()

local shaderConfig = {
	MAPSIZEX = Game.mapSizeX,
	MAPSIZEZ = Game.mapSizeZ,
	MAPSIZEY = maxHeight,
	VSX = vsx,
	VSY = vsy,
	HSX = hsx,
	HSY = hsy,
}

--- RMLUI STUFF
--- 

local document
widget.rmlContext = nil

local eventCallback = function(ev, ...) Spring.Echo('orig function says', ...) end;

local dm_handle

--- 
--- ----

-- THIS IS UNIFIED BETWEEN FOG SHADER AND COMBINE SHADER
local definesSlidersParamsList = {
	{name = 'RESOLUTION', default = 1, min = 1, max = 8, digits = 0, tooltip = 'Fog resolution divider, 1 = full resolution, 2 = half'},
	--{name = 'MINISHADOWS', default = 0, min = 0, max = 1, digits = 0, tooltip = 'Wether to draw a downsampled shadow sampler'},
	{name = 'OFFSETX', default = 0, min = -4, max = 4, digits = 0, tooltip = 'OFFSETX'},
	{name = 'OFFSETY', default = 0, min = -4, max = 4, digits = 0, tooltip = 'OFFSETY'},
	{name = 'HALFSHIFT', default = 1, min = 0, max = 1, digits = 0, tooltip = 'If the resolution is half, perform a half-pixel shifting'},
	--{name = 'RAYTRACING', default = 1, min = 0, max = 1, digits = 0, tooltip = 'Use any raytracing, 1 = yes, 0 = no'},
	{name = 'HEIGHTNOISESTEPS', default = 8, min = 0, max = 32, digits = 0, tooltip =  'How many times to sample shadows'},
	{name = 'HEIGHTSHADOWSTEPS', default = 12, min = 0, max = 32, digits = 0, tooltip =  'How many times to sample shadows for pure height-based fog'},
	{name = 'UNDERWATERSHADOWSTEPS', default = (minHeight < -20) and 8 or 0, min = 0, max = 64, digits = 0, tooltip =  'How many times to sample shadows for underwater scattering'},
	{name = 'HEIGHTSHADOWQUAD', default = 2, min = 0, max = 2, digits = 0, tooltip =  'How to Quad sample height-based fog'},
	{name = 'SHADOWSAMPLER', default = 1, min = 0, max = 3, digits = 0, tooltip =  '0 use texture fetch, 1 use sampler fetch, 2 use texelfetch'},
	--{name = 'BLUENOISESTRENGTH', default = 1.1, min = 0, max = 1.1, digits = 1, tooltip =  'Amount of blue noise added to shadow sampling'},
	{name = 'TEXTURESAMPLER', default = 1, min = 0, max = 6, digits = 0,  tooltip = '0:None 1=Packed3D 2=Tex2D 3=Tex2D 4=FBM 5=Value3D 6=SimplexPerlin'},
	{name = 'QUADNOISEFETCHING', default = 1, min = 0, max = 1, digits = 0,  tooltip = 'Enable Quad Message Passing [0 or 1]'},
	{name = 'WEIGHTFACTOR', default = 0.56, min = 0, max = 1, digits = 2,  tooltip = 'Squared weight for each texel in PQM'},
	{name = 'CLOUDSTEPS',default = 16, min = 0, max = 64, digits = 0, tooltip = 'How many Cloud samples to take, 0 to disable clouds'},
	{name = 'NOISESCALE', default = 0.3, min = 0.001, max = 0.999, digits = 3, tooltip = 'The tiling frequency of noise'},
	{name = 'NOISETHRESHOLD', default = 0, min = -1, max = 1, digits = 2, tooltip =  'The 0 level of noise'},
	{name = 'CLOUDSHADOWS', default = 8, min = 0, max = 16, digits = 0, tooltip = 'How many rays to cast in the direction of the sun for shadows'},
	{name = 'USEMINIMAP', default = 0, min = 0, max = 1, digits = 0, tooltip = '0 or 1 to use the minimap for back-scatter'},
	{name = 'FULLALPHA',default = 0, min = 0, max = 1, digits = 0, tooltip = 'Show ONLY fog'},
	{name = 'USEDDS', default = 0, min = 0, max = 1, digits = 0, tooltip = 'Use DDS compressed version of packedNoise. Most important when using very high frequencies of LF noise (reduces cache pressure)'},
	{name = 'USELOS', default = 1, min = 0, max = 1, digits = 0, tooltip = 'Use the LOS map at all, 1 = yes, 0 = no'},
	{name = 'LOSREDUCEFOG', default = 0, min = 0, max = 1, digits = 2, tooltip = 'How much less fog there is in LOS , 0 is no height based fog in los, 1 is full fog in los'},
	{name = 'LOSFOGUNDISCOVERED', default = 1.0, min = 0, max = 1, digits= 2, tooltip = 'This specifies how much more fog there should be where the map has not yet been discovered ever (0 is none, 1 is a lot)'},
	{name = 'WINDSTRENGTH', default = 0.01, min = 0, max = 0.1, digits = 2, tooltip = 'Speed multiplier for wind'},
	{name = 'RISERATE', default = 0.025, min = 0.00, max = 0.2, digits = 3, tooltip = 'Rate at which cloud noise rises, in elmos per frame'},
	--{name = 'HEIGHTDENSITY', default = 2, min = 1, max = 10, digits = 2, tooltip = 'How quickly height fog reaches its max density'},
	{name = 'SUNCHROMASHIFT', default = 0.2,  min = -0.5, max = 1, digits = 2, tooltip = 'How much colors are shifted towards sun'},
	{name = 'MINIMAPSCATTER', default = 0.1, min = -0.5, max = 0.5, digits = 2, tooltip = 'How much the minimap color sdditively back-scatters into fog color, 0 is off'},
	{name = 'EASEGLOBAL', default = 2, min = 1, max = 50, digits = 2, tooltip = 'How much to reduce global fog close to camera'},
	{name = 'EASEHEIGHT', default = 1, min = 0.0, max = 5, digits = 2, tooltip = 'How much to reduce height-based fog close to camera'},
	{name = 'COMBINESHADER', default = 1, min = 0, max = 1, digits = 0, tooltip = 'Run the combine shader if RESOLUTION > 1'},
	{name = 'ENABLED', default = 1, min = 0, max = 1, digits = 0, tooltip = 'Dont do anything'},
	
}

for i, shaderDefine in ipairs(definesSlidersParamsList) do 
	-- dont overwrite existing, externally defined values with the defaults:
	if shaderConfig[shaderDefine.name] == nil then 
		shaderConfig[shaderDefine.name] = shaderDefine.default;
	end
end

local fogUniforms = {
	heightFogColor = {0.6,0.7,0.8,0.98}, -- bluish, alpha is the ABSOLUTE MAXIMUM FOG
	cloudGlobalColor = {0.6,0.7,0.8,0.98}, -- bluish, alpha is the ABSOLUTE MAXIMUM FOG
	distanceFogColor = {1.0,0.9,0.8,0.35}, -- yellowish, alpha is power
	shadowedColor = {0.1,0.05,0.1,0.5}, -- purleish tint, alpha is power
	heightFogTop = maxHeight * 0.5 , -- Start of the height thing
	heightFogBottom = 0, -- Start of the height thing
	cloudDensity = 0.01, -- How dense the height-based fog is
	cloudVolumeMin = {0,maxHeight,0,0}, -- XYZ coords of the cloud volume start, along with the bottom density in W
	cloudVolumeMax= {Game.mapSizeX, 2* maxHeight, Game.mapSizeZ,1024}, -- XYZ coords of fog volume end, along with the top density
	scavengerPlane = {Game.mapSizeX, Game.mapSizeZ, 100,100}, -- The assumption here is that we can specify an X and Z limit on fog, and a density transition function. negative numbers should swap plane dir 
	noiseLFParams = {
		0.31, -- high-frequency cloud noise, lower numbers = lower frequency
		0.4, -- noise bias, [-1,1] high numbers denser
		0.77, -- low frequency big cloud noise, lower numbers = lower frequency
		0.0, -- low frequency noise bias, keep between [-1,1]
		},
	noiseHFParams = {
		0.4, -- high-frequency cloud noise, lower numbers = lower frequency
		0.1, -- Pertubation factor
		0.2, -- SpeedX
		0.2, -- SpeedZ
		},

	}
	
local uniformSliderParamsList = {
	{name = 'distanceFogColor', default = fogUniforms.distanceFogColor, min = 0, max = 2, digits = 3, tooltip =  'distanceFogColor, alpha is density multiplier'},
	{name = 'shadowedColor', default = fogUniforms.shadowedColor, min = 0, max = 2, digits = 3, tooltip =  'shadowedColor, Color of the shadowed areas, ideally black, alpha is strength'},
	{name = 'heightFogColor', default = fogUniforms.heightFogColor, min = 0, max = 2, digits = 3, tooltip =  'heightFogColor, alpha is the ABSOLUTE MAXIMUM FOG'},
	{name = 'heightFogTop', default = fogUniforms.heightFogTop, min = math.floor(minHeight), max = math.floor(maxHeight * 2), digits = 0, tooltip =  'heightFogTop, in elmos'},
	{name = 'heightFogBottom', default = fogUniforms.heightFogBottom, min = math.floor(minHeight), max = math.floor(maxHeight), digits = 0, tooltip =  'heightFogBottom, in elmos'},
	{name = 'scavengerPlane', default = fogUniforms.scavengerPlane, min = 0, max = math.max(Game.mapSizeX, Game.mapSizeZ), digits = 0, tooltip =  'Where the scavenger cloud is'},

	{name = 'cloudVolumeMin', default = fogUniforms.cloudVolumeMin, min = 0,max = math.max(Game.mapSizeX, Game.mapSizeZ), digits = 0, tooltip =  'Start of the cloud volume'},
	{name = 'cloudVolumeMax', default = fogUniforms.cloudVolumeMax, min = 0, max = math.max(Game.mapSizeX, Game.mapSizeZ), digits = 0, tooltip =  'End of the cloud volume'},

	{name = 'cloudGlobalColor', default = fogUniforms.cloudGlobalColor, min = 0, max = 2, digits = 3, tooltip =  'cloudGlobalColor, alpha is the ABSOLUTE MAXIMUM FOG'},
	{name = 'cloudDensity', default = fogUniforms.cloudDensity, min = 0.000, max = 0.1, digits = 3, tooltip =  'How dense the clouds are'},
	{name = 'noiseLFParams', default = fogUniforms.noiseLFParams, min = -1, max = 5, digits = 3, tooltip =  '1:Frequency, 2: threshold, 3-4 unused'},
	{name = 'noiseHFParams', default = fogUniforms.noiseHFParams, min = -1, max = 5, digits = 3, tooltip =  '1:Frequency, 2: Perturb, 3: SpeedX, 4: SpeedZ'},
}

local fogUniformSliders = {
	windowtitle = "Fog Uniforms",
	name = "fogUniformSliders",
	left = vsx - 270, 
	right = vsx - 270 + 250,
	bottom = 200,
	top = 1200,
	width = 250, 
	height = 20,
	sliderheight = 20,
	valuetarget = fogUniforms,
	sliderParamsList = uniformSliderParamsList,
	callbackfunc = nil
}

local uniformSlidersLayer, uniformSlidersWindow
	
local fogUniformsBluish = { -- bluish tint, not very good
	heightFogColor = {0.5,0.6,0.7,1}, -- bluish
	distanceFogColor = {1.0,0.9,0.8,1}, -- yellowish
	shadowedColor = {0.1,0.05,0.1,1}, -- purleish tint
	heightFogTop = (math.max(minHeight,0) + maxHeight) /2 ,
	cloudDensity = 0.3,
	}

---------------------------------------------------------------------------
local autoreload = true

--local noisetex3dcube =  "LuaUI/images/noisetextures/noise64_cube_3.dds"
local noisetex3dcube =  "LuaUI/images/noisetextures/cloudy8_256x256x64_L.dds"
--local noisetex3dcube =  "LuaUI/images/noisetextures/worley_rgbnorm_01_asum_128_v1_mip.dds"
local blueNoise64 =  "LuaUI/images/noisetextures/blue_noise_64.tga"
--local uniformNoiseTex =  "LuaUI/images/noisetextures/worley_rgbnorm_01_asum_128_v1_mip.dds"
local uniformNoiseTex =  "LuaUI/images/noisetextures/uniform3d_16x16x16_RGBA.dds"
--local noisetex3dcube =  "LuaUI/images/noisetextures/cloudy8_a_128x128x32_L.dds"
local noisetex3dcube =  "LuaUI/images/noisetextures/uniform3d_16x16x16_L.dds"
local simpledither = "LuaUI/images/noisetextures/rgba_noise_256.tga"
local worley3d128 = "LuaUI/images/noisetextures/worley_rgbnorm_01_asum_128_v1.dds"
local dithernoise2d =  "LuaUI/images/lavadistortion.png"	
local packedNoise =  "LuaUI/images/noisetextures/worley3_256x128x64_RBGA_LONG." .. ((shaderConfig.USEDDS == 1 ) and 'dds' or 'png')


local fogPlaneVAO 
local resolution = 64
local groundFogShader

local combineShader
local fogTexture
local distortiontex = "LuaUI/images/fractal_voronoi_tiled_1024_1.png"

local shadowTexture
local quadVAO
local shadowShader

local combineRectVAO

local LuaShader = gl.LuaShader

local function goodbye(reason) 
	Spring.Echo('Exiting', reason)
	widgetHandler:RemoveWidget()
end

local vsSrcPath = "LuaUI/Shaders/global_fog.vert.glsl"
local fsSrcPath = "LuaUI/Shaders/global_fog.frag.glsl"

local shaderSourceCache = {
		vssrcpath = vsSrcPath,
		fssrcpath = fsSrcPath,
		--gssrcpath = gsSrcPath,
		uniformInt = {
			mapDepths = 0,
			modelDepths = 1,
			heightmapTex = 2,
			infoTex = 3,
			shadowTex = 4,
			noise64cube = 5,
			miniMapTex = 6,
			packedNoise = 7,
			blueNoise64 = 8,
			uniformNoiseTex = 9,
		},
		uniformFloat = {
			windFractFull = {0,0,0,0},
			heightFogColor = fogUniforms.heightFogColor,
			distanceFogColor = fogUniforms.distanceFogColor,
			shadowedColor = fogUniforms.shadowedColor,
			cloudDensity = fogUniforms.cloudDensity, 
			heightFogTop = fogUniforms.heightFogTop,
			heightFogBottom = fogUniforms.heightFogBottom,
		},
		shaderName = "Ground Fog GL4",
		shaderConfig = shaderConfig
	}


local vsSrcPathCombine = "LuaUI/Shaders/global_fog_combine.vert.glsl"
local fsSrcPathCombine = "LuaUI/Shaders/global_fog_combine.frag.glsl"

local combineShaderSourceCache = {
		vssrcpath = vsSrcPathCombine,
		fssrcpath = fsSrcPathCombine,
		--gssrcpath = gsSrcPath,
		uniformInt = { mapDepths = 0, modelDepths = 1,  fogbase = 2, distortion = 3},
		uniformFloat = { gameframe = 0, distortionlevel = 0, resolution = 2},
		shaderName = "Global Fog Combine GL4",
		shaderConfig = shaderConfig,
	}
  

local function makeFogTexture()
	if fogTexture then gl.DeleteTexture(fogTexture) end
	
	vsx, vsy = Spring.GetViewGeometry()
	-- TODO:
	-- We need to ensure that HSX and HSY are even!
	hsx =  math.ceil(vsx / shaderConfig.RESOLUTION )
	hsy =  math.ceil(vsy / shaderConfig.RESOLUTION )
	if shaderConfig.HALFSHIFT == 1 then
		hsx =  math.ceil(math.ceil((vsx +1) / shaderConfig.RESOLUTION )/2) * 2
		hsy =  math.ceil(math.ceil((vsy +1) / shaderConfig.RESOLUTION )/2) * 2
	end
	
	shaderConfig.HSX = hsx
	shaderConfig.HSY = hsy
	shaderConfig.VSX = vsx
	shaderConfig.VSY = vsy
	
	
	combineShaderSourceCache.forceupdate = true
	shaderSourceCache.forceupdate = true
	
	combineShader =  LuaShader.CheckShaderUpdates(combineShaderSourceCache) or combineShader
	
	fogTexture = gl.CreateTexture(hsx, hsy, {
		min_filter = GL.LINEAR,	mag_filter = GL.LINEAR,
		--min_filter = GL.NEAREST,	mag_filter = GL.NEAREST, -- this is purely for debugging
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
		fbo = true,
		format = GL_RGBA32F_ARB, -- we need this to be able to do hdr, if needed. But we dont _really_ need it
  })
	if shadowTexture then gl.DeleteTexture(shadowTexture) end 
  shadowTexture = gl.CreateTexture(math.min(vsx/shaderConfig.RESOLUTION, vsy/shaderConfig.RESOLUTION),math.min( vsx/shaderConfig.RESOLUTION, vsy/shaderConfig.RESOLUTION),{
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
		fbo = true,
		format = GL_R32F,
    })
	Spring.Echo(string.format("MakeFogTexture: vsx=%d, vsy=%d, hsx=%d, hsy=%d, HALFSHIFT=%d", vsx, vsy, hsx, hsy, shaderConfig.HALFSHIFT))
	
end


function widget:ViewResize()
	makeFogTexture()
end

widget:ViewResize()

local function initGL4()
	-- init the VBO
	local planeVBO, numVertices = gl.InstanceVBOTable.makePlaneVBO(1,1,Game.mapSizeX/resolution,Game.mapSizeZ/resolution)
	local planeIndexVBO, numIndices =  gl.InstanceVBOTable.makePlaneIndexVBO(Game.mapSizeX/resolution,Game.mapSizeZ/resolution)
	local quadVBO,numVertices = gl.InstanceVBOTable.makeRectVBO(-1,0,1,-1,0,1,1,0)
	quadVAO = gl.GetVAO()
	quadVAO:AttachVertexBuffer(quadVBO)
  
	fogPlaneVAO = gl.GetVAO()
	fogPlaneVAO:AttachVertexBuffer(planeVBO)
	fogPlaneVAO:AttachIndexBuffer(planeIndexVBO)

	combineRectVAO = gl.InstanceVBOTable.MakeTexRectVAO(-1, -1, 1, 1, 0, 0, 1, 1)
	--local combineRectVBO = gl.InstanceVBOTable.MakeTexRectVAO(-1, -1, 1, 1, 0, 0, 1, 1)
	--combineRectVAO = gl.GetVAO()
	--combineRectVAO:AttachVertexBuffer(combineRectVBO)

	
	groundFogShader =  LuaShader.CheckShaderUpdates(shaderSourceCache)
	if not groundFogShader then goodbye("Failed to compile Ground Fog GL4") end 
	--Spring.Echo("Number of triangles= ", Game.mapSizeX/resolution,Game.mapSizeZ/resolution)
	return true
end

local function SetFogParams(paramname, paramvalue, paramIndex)
	Spring.Echo("SetFogParams",paramname, paramvalue, paramIndex)
	if fogUniforms[paramname] then
		if paramIndex then 
			fogUniforms[paramname][paramIndex] = paramvalue
		else
			fogUniforms[paramname] = paramvalue
		end
	end
end

local combineShaderTriggers = {RESOLUTION = true, HALFSHIFT = true, OFFSETX = true, OFFSETY = true}
local function shaderDefinesChangedCallback(name, value, index, oldvalue)
	Spring.Echo(string.format("shaderDefinesChangedCallback() name=%s, value=%s, shaderConfig[%s]=%s", tostring(name), tostring(value), tostring(name), tostring(shaderConfig[name])))
	if oldvalue == nil or value ~= oldvalue then 
		if shaderConfig[name] then 
			shaderConfig[name] = value
		end
		shaderSourceCache.forceupdate = true
		groundFogShader =  LuaShader.CheckShaderUpdates(shaderSourceCache) or groundFogShader
		if combineShaderTriggers[name]  then 
			makeFogTexture()
			combineShaderSourceCache.forceUpdate = true
			combineShader =  LuaShader.CheckShaderUpdates(combineShaderSourceCache) or combineShader
		end
	end
end

local shaderDefinedSliders = {
	windowtitle = "Fog Defines",
	name = "shaderDefinedSliders",
	left = vsx - 540, 
	bottom = 200, 
	right = vsx - 540 + 250,
	sliderheight = 20,
	valuetarget = shaderConfig,
	sliderParamsList = definesSlidersParamsList,
	callbackfunc = shaderDefinesChangedCallback
}
shaderDefinedSliders.top = shaderDefinedSliders.bottom + shaderDefinedSliders.sliderheight *( #definesSlidersParamsList +3)

local shaderDefinedSlidersLayer, shaderDefinedSlidersWindow

local shadowMinifierShaderSourceCache = {
		vssrcpath = "LuaUI/Shaders/shadow_downsample.vert.glsl",
		fssrcpath = "LuaUI/Shaders/shadow_downsample.frag.glsl",
		--gssrcpath = gsSrcPath,
		uniformInt = { shadowTex = 0},
		uniformFloat = { gameframe = 0, distortionlevel = 0, resolution = 2},
		shaderName = "shadowMinifierShader",
		shaderConfig = {VSX = vsx, VSY = vsy, HSX = hsx, HSY = hsy}
}

local initfps = 1
local lastfps = 1
function widget:Initialize()
	initfps = Spring.GetFPS()
	minHeight, maxHeight = Spring.GetGroundExtremes()
	if WG['infolosapi'] then 
		Spring.Echo("Global Fog using INFOLOS api")
	else
		goodbye("Global Fog REQUIRES Infolos API widget, please enable it first")
		return
	end
	if Spring.GetConfigString("AllowDeferredMapRendering") == '0' or Spring.GetConfigString("AllowDeferredModelRendering") == '0' then
		Spring.Echo('Ground Fog GL4 requires  AllowDeferredMapRendering and AllowDeferredModelRendering to be enabled in springsettings.cfg!')
		widgetHandler:RemoveWidget()
		return
	end
	if initGL4() == false then return end
	
	widget:ViewResize()
	
	-- https://github.com/libretro/common-shaders/blob/master/include/quad-pixel-communication.h
	-- Getting neighbouring pixel info!

	combineShader =  LuaShader.CheckShaderUpdates(combineShaderSourceCache) or combineShader
	if (combineShader == nil) then
	
		widgetHandler:RemoveWidget()
		goodbye("[Global Fog::combineShader] combineShader compilation failed")
		return false
	end
  
	shadowShader  =  LuaShader.CheckShaderUpdates(shadowMinifierShaderSourceCache)
  	if (shadowShader == nil) then
	
		widgetHandler:RemoveWidget()
		goodbye("[Global Fog::shadowShader] shadowShader compilation failed")
		return false
	end
	WG['SetFogParams'] = SetFogParams
	
	if WG['flowui_gl4'] then 
		Spring.Echo(" WG[flowui_gl4] detected")
		if WG['flowui_gl4'].forwardslider then 
			
			local slidercount = 0
			--for 
			shaderDefinedSlidersLayer, shaderDefinedSlidersWindow = WG['flowui_gl4'].requestWidgetLayer(shaderDefinedSliders) -- this is a window
			shaderDefinedSliders.parent = shaderDefinedSlidersWindow
			
			WG['flowui_gl4'].forwardslider(shaderDefinedSliders)
			
			uniformSlidersLayer, uniformSlidersWindow = WG['flowui_gl4'].requestWidgetLayer(fogUniformSliders) -- this is a window
			fogUniformSliders.parent = uniformSlidersWindow
			WG['flowui_gl4'].forwardslider(fogUniformSliders)
			

			--fogUniformSliders = WG['flowui_gl4'].forwardslider(fogUniformSliders)
		end
	end

	if RmlUi then 
		widget.rmlContext = RmlUi.CreateContext(widget.whInfo.name)

				-- use the DataModel handle to set values
		-- only keys declared at the DataModel's creation can be used
		dm_handle = widget.rmlContext:OpenDataModel("data_model_test", {
			exampleValue = 'Changes when clicked',
			-- Functions inside a DataModel cannot be changed later
			-- so instead a function variable external to the DataModel is called and _that_ can be changed
			exampleEventHook = function(...) eventCallback(...) end,
			--[[  -- this crashes
			button2Clicked = function()
				local _target = document:GetElementById('target')
				local _div = document:CreateElement('div')
				_div:SetClass('element', true)
				_div = _target:AppendChild(_div)
				_div.style.width = '20px'
				_div.style.height = '50px'

				local _div_prepend = document:CreateElement('div')
				_div_prepend.inner_rml = "p"
				_div_prepend = _target:InsertBefore(_div_prepend, _div)

				local _div_replace = document:CreateElement('div')
				_div_replace.inner_rml = "r"

				_div = _target:ReplaceChild(_div_replace, _div)
				_div.inner_rml = 'asdf'
				_div = _target:AppendChild(_div)
				_div.style.width = nil
				_div.style.height = ''
			end, 
			]]--
			callShaderDefinesChangedCallback = shaderDefinesChangedCallback,
			my_rect = "",
			context_name_list = "",
		});
 

		eventCallback = function (ev, ...)
			Spring.Echo(ev.parameters.mouse_x, ev.parameters.mouse_y, ev.parameters.button, ...)
			local options = {"ow", "oof!", "stop that!", "clicking go brrrr"}
			dm_handle.exampleValue = options[math.random(1, 4)]

			local textureElement = document:GetElementById('101')
			textureElement.style.color = "red"

			Spring.Echo(textureElement.style.pairs)

			for k, v in textureElement.style:__pairs() do
				Spring.Echo(k .. ': ' .. v)
			end
		end
	end
	
	document = widget.rmlContext:LoadDocument("LuaUi/Widgets/rml_widget_assets/global_fog.rml", widget)

	local slidersDiv = document:GetElementById('fogsliders')
	for i, definesSlider in ipairs(definesSlidersParamsList) do 
		--	{name = 'HALFSHIFT', default = 1, min = 0, max = 1, digits = 0, tooltip = 'If the resolution is half, perform a half-pixel shifting'},

		--[[	
		Range type
		min = number (CN) For the range type, defines the value at the lowest (left or top) end of the slider.
		max = number (CN) For the range type, defines the value at the highest (right or bottom) end of the slider.
		step = number (CN) For the range type, defines the increment that the slider will move by.
		orientation = cdata (CI) For the range type, specifies if it is a vertical or horizontal slider. Values can be horizontal or vertical.
		]]--

		local sliderElement = document:CreateElement('label')
		-- How to right align a div?
		local maxstring = string.format('%.' .. definesSlider.digits .. 'f', definesSlider.max)
		local maxstringPadded = string.format('%5s', maxstring):gsub(' ', '&#x2007;')

		local sliderhtmlstring = string.format('<div class="code" style="text-align: right;"> %s %f <input type="range" id="%s"  min="%f" max="%f" step="%f" value="%f" /> %s </div> ', 
			definesSlider.name,definesSlider.min, definesSlider.name,  definesSlider.min, definesSlider.max, math.pow(10, -1 * definesSlider.digits) , definesSlider.default,maxstringPadded)
		sliderElement.inner_rml = sliderhtmlstring
		-- Add the lister:
		sliderElement:AddEventListener('change', function(event)
			--Spring.Echo(event, event.target_element, event.parameters)
			local newvalue = nil 

			-- The eventproxy userdata object contains the new value, otherwise you can only get the previous value :D 
			if event and event.parameters and event.parameters.value then 
				newvalue = tonumber(event.parameters.value)
			end

			-- https://mikke89.github.io/RmlUiDoc/pages/lua_manual/api_reference.html#Element
			local slider = event.target_element
			if slider.attributes.value == newvalue then 
				Spring.Echo("Slider value did not change", slider.id, slider.attributes.value, newvalue)
				return
			end
			local value = newvalue or tonumber(slider.attributes.value)
			-- Spring.Echo("element changed", element.id, element.min, element.max, element.step, element.value)
			shaderDefinesChangedCallback(slider.id, value, nil, nil)
		end) --data-event-onChange =" callshaderDefinesChangedCallback(\'%s\')"

		slidersDiv:AppendChild(sliderElement)
	end 

	local fogUniformSlidersDiv = document:GetElementById('foguniformsliders')

	for i, uniformSlider in ipairs(uniformSliderParamsList) do 
		local defaultType = type(fogUniforms[uniformSlider.name])
		local defaultValues
		if defaultType == "table" then 
			defaultValues = fogUniforms[uniformSlider.name]
		else
			defaultValues = {fogUniforms[uniformSlider.name]}
		end


		for j, v in ipairs(defaultValues) do 
			local defaultvalue = v or 0.0 

				
			local sliderElement = document:CreateElement('label')
			-- How to right align a div?
			local maxstring = string.format('%.' .. uniformSlider.digits .. 'f', uniformSlider.max)
			local maxstringPadded = string.format('%5s', maxstring):gsub(' ', '&#x2007;')


			local sliderhtmlstring = string.format('<div class="code" style="text-align: right;"> %s-%d %f <input type="range" id="%s"  min="%f" max="%f" step="%f" value="%f" /> %s </div> ', 
				uniformSlider.name,j,uniformSlider.min, uniformSlider.name,  uniformSlider.min, uniformSlider.max, math.pow(10, -1 * uniformSlider.digits) , defaultvalue,maxstringPadded)
			sliderElement.inner_rml = sliderhtmlstring
			-- Add the lister:
			sliderElement:AddEventListener('change', function(event)
				--Spring.Echo(event, event.target_element, event.parameters)
				local newvalue = nil 

				-- The eventproxy userdata object contains the new value, otherwise you can only get the previous value :D 
				if event and event.parameters and event.parameters.value then 
					newvalue = tonumber(event.parameters.value)
				end

				-- https://mikke89.github.io/RmlUiDoc/pages/lua_manual/api_reference.html#Element
				local slider = event.target_element
				if slider.attributes.value == newvalue then 
					Spring.Echo("Slider value did not change", slider.id, slider.attributes.value, newvalue)
					return
				end
				local value = newvalue or tonumber(slider.attributes.value)
				-- Spring.Echo("element changed", element.id, element.min, element.max, element.step, element.value)
				local paramIndex = (defaultType == "table") and j or nil
				SetFogParams(slider.id, value, paramIndex)
			end) --data-event-onChange =" callshaderDefinesChangedCallback(\'%s\')"

			fogUniformSlidersDiv:AppendChild(sliderElement) 
		end
	end

	document:ReloadStyleSheet()  
	document:Show()

	 
	if vsx % 4 ~= 0 or vsy % 4 ~= 0 then
		Spring.Echo(string.format(
			"Global Fog Warning: viewport dimensions are not divisible by 4! vsx=%d, vsy=%d, vsx/2=%d, vsy/2=%d, hsx=%d, hsy=%d",
			vsx, vsy, vsx / 2, vsy / 2, hsx, hsy
		))
	end
	return true
end

function widget:Shutdown()
	if fogTexture then gl.DeleteTexture(fogTexture) end
	WG.SetFogParams = nil
	if fogUniformSliders and fogUniformSliders.Destroy then fogUniformSliders:Destroy() end
	if shaderDefinedSlidersLayer and shaderDefinedSlidersLayer.Destroy then shaderDefinedSlidersLayer:Destroy() end 

	if RmlUi then 
		if document then
			document:Close()
		end
		if widget.rmlContext then
			RmlUi.RemoveContext(widget.whInfo.name)
		end
	end
end
--[[
function widget:GameFrame(n) -- should be done every goddamned draw frame for ultimate smoothness!!!!!
	local windDirX, _, windDirZ, windStrength = Spring.GetWind()
	windX = windX + windDirX * shaderConfig.WINDSTRENGTH
	windZ = windZ + windDirZ * shaderConfig.WINDSTRENGTH
	
	-- This part is to ensure that the fractional part of the noiseOffset fragment shader coordinates dont vanish
	-- This "rolls over" when the noiseOffset would roll over 1
	local windXFract = windX * shaderConfig.NOISESCALE  / 1024.0
	if windXFract > 1 or windXFract < 0 then 
		Spring.Echo("windXFract", windXFract, windX)
		windX = 1024.0 * (windXFract - math.floor(windXFract))/ shaderConfig.NOISESCALE
	end
	local windZFract = windZ * shaderConfig.NOISESCALE / 1024.0
	if windZFract > 1 or windZFract < 0 then 
		Spring.Echo("windZFract", windZFract, windZ)
		windZ = 1024.0 * (windZFract - math.floor(windZFract)) / shaderConfig.NOISESCALE 
	end
end
]]--

local windFractFull = {0,0,0,0} -- fractX, fractZ, fullX, fullZ

local lastGameFrame = Spring.GetGameFrame()
local prevTimeOffset = Spring.GetFrameTimeOffset()
function widget:Update()
	local thisGameFrame = Spring.GetGameFrame()
	local thisTimeOffset = Spring.GetFrameTimeOffset()
	local deltaOffset = math.max(0, thisTimeOffset- prevTimeOffset)
	prevTimeOffset = thisTimeOffset
	local deltaFrame = thisGameFrame - lastGameFrame + deltaOffset
	
	local windDirX, _, windDirZ = Spring.GetWind()
	local windStrength = shaderConfig.WINDSTRENGTH * deltaFrame
	local deltaWindX = windDirX * windStrength
	local deltaWindZ = windDirZ * windStrength
	windFractFull[3] = windFractFull[3] + deltaWindX
	windFractFull[4] = windFractFull[4] + deltaWindZ

	windFractFull[1] = windFractFull[1] + deltaWindX
	windFractFull[2] = windFractFull[2] * deltaWindZ
	
	local noiseScale = shaderConfig.NOISESCALE / 1024.0
	-- assume NOISESCALE is 20
	-- This part is to ensure that the fractional part of the noiseOffset fragment shader coordinates dont vanish
	-- This "rolls over" when the noiseOffset would roll over 1
	local windXFract = windFractFull[1] * noiseScale
	if windXFract > 1 or windXFract < 0 then 
		Spring.Echo("windXFract", windXFract, windFractFull[1])
		windFractFull[1] = 1024.0 * (windXFract - math.floor(windXFract))/ shaderConfig.NOISESCALE
	end
	local windZFract = windFractFull[2] * noiseScale
	if windZFract > 1 or windZFract < 0 then 
		Spring.Echo("windZFract", windZFract, windZ)
		windFractFull[2]  = 1024.0 * (windZFract - math.floor(windZFract)) / shaderConfig.NOISESCALE 
	end
	lastGameFrame = thisGameFrame

end

local toTexture = true

local function renderToTextureFunc() -- this draws the fogspheres onto the texture
	--gl.DepthMask(false) 
	--gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	gl.Blending(GL.ONE, GL.ZERO)
	fogPlaneVAO:DrawElements(GL.TRIANGLES)
end

local function minifyShadowToTextureFunc()
  gl.Texture(0, "$shadow")
  quadVAO:DrawArrays(GL.TRIANGLES)
end

function YCLine(horz, vert)
	local vsx, vsy = Spring.GetViewGeometry()
	if horz then
		gl.Color(1,1,0,1)
		gl.Rect(2 , horz, vsx -2 , horz+1)
		gl.Color(0,1,1,1)
		gl.Rect(2 , horz, vsx -2 , horz-1)
	else
		gl.Color(1,1,0,1)
		gl.Rect(vert , 2, vert+1 ,vsy -2 )
		gl.Color(0,1,1,1)
		gl.Rect(vert , 2, vert-1 ,vsy -2 )
	end
end

function widget:DrawWorld()

	if autoreload then
		groundFogShader =  LuaShader.CheckShaderUpdates(shaderSourceCache) or groundFogShader
		combineShader =  LuaShader.CheckShaderUpdates(combineShaderSourceCache) or combineShader
		shadowShader =  LuaShader.CheckShaderUpdates(shadowMinifierShaderSourceCache) or shadowShader
	end
	if shaderConfig.ENABLED == 0 then 
		
		initfps = Spring.GetFPS()
		return 
	end
	
	gl.DepthMask(false) -- dont write to depth buffer

  --if true then return end
	gl.Culling(GL.FRONT) -- cause our tris are reversed in plane vbo
	
  if shaderConfig.MINISHADOWS == 1 then 
    shadowShader:Activate()
    gl.RenderToTexture(shadowTexture, minifyShadowToTextureFunc)
    shadowShader:Deactivate()
  end
  gl.Texture(0, "$map_gbuffer_zvaltex")
	gl.Texture(1, "$model_gbuffer_zvaltex")
	gl.Texture(2, distortiontex)
	if shaderConfig.USELOS == 1 and WG['infolosapi'].GetInfoLOSTexture then 
		gl.Texture(3, WG['infolosapi'].GetInfoLOSTexture()) --$info:los
	else
		gl.Texture(3, "$info") --$info:los
	end
  if shaderConfig.MINISHADOWS ==1 then 
    gl.Texture(4, shadowTexture)
  else
    gl.Texture(4, "$shadow")
	end
  gl.Texture(5, noisetex3dcube)

	if shaderConfig.USEMINIMAP > 0 then 
		gl.Texture(6, '$minimap')
	end
	packedNoise =  "LuaUI/images/noisetextures/worley20231012_sdf_256x128x64_RBGA_LONG." .. ((shaderConfig.USEDDS == 1 ) and 'dds' or 'tga')
	packedNoise =  "LuaUI/images/noisetextures/worley3_256x128x64_RBGA_LONG." .. ((shaderConfig.USEDDS == 1 ) and 'dds' or 'png')
	gl.Texture(7, packedNoise)
	gl.Texture(8, blueNoise64)
	gl.Texture(9, uniformNoiseTex)
	
	groundFogShader:Activate()
	groundFogShader:SetUniformFloat("windFractFull", windFractFull[1],windFractFull[2],windFractFull[3],windFractFull[4])
	
	for uniformName, uniformValue in pairs(fogUniforms) do 
		local vtype = type(uniformValue)
		if vtype == 'number' then 
			groundFogShader:SetUniformFloat(uniformName, uniformValue)
		elseif vtype == 'table' then 
			groundFogShader:SetUniformFloat(uniformName, uniformValue[1], uniformValue[2], uniformValue[3], uniformValue[4])
		end
	end
	toTexture = shaderConfig.RESOLUTION ~= 1
	if toTexture then 
		gl.RenderToTexture(fogTexture, renderToTextureFunc)
	else
		gl.Blending(GL.ONE, GL.ONE_MINUS_SRC_ALPHA)
		fogPlaneVAO:DrawElements(GL.TRIANGLES)
	end

	groundFogShader:Deactivate()
	
	gl.Culling(GL.BACK) -- cause our tris are reversed in plane vbo
	gl.Culling(false)
	-- glColorMask(false, false, false, false)
	if toTexture and shaderConfig.COMBINESHADER == 1 then 
		gl.Blending(GL.ONE, GL.ONE_MINUS_SRC_ALPHA)
		combineShader:Activate()
		combineShader:SetUniformFloat("resolution", shaderConfig.RESOLUTION)
		--combineShader:SetUniformFloat("distortionlevel", 0.0001) -- 0.001
		gl.Texture(2, fogTexture)
		gl.Texture(3, distortiontex)
		--gl.TexRect(-1, -1, 1, 1, 0, 0, 1, 1)
		combineRectVAO:DrawArrays(GL.TRIANGLES)
		combineShader:Deactivate()
		--gl.TexRect(0, 0, 10000, 10000, 0, 0, 1, 1) -- dis is for debuggin!
	end
	
	for i = 0, 9 do gl.Texture(i, false) end 
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA) -- reset GL state
  	gl.DepthMask(false) --"BK OpenGL state resets", reset to default state
end

local function DumpShaderSource(srccache)
	for keyname, fileextension in pairs({vsSrcComplete = ".vert", fsSrcComplete = '.frag', gsSrcComplete = '.geom'}) do 
		if srccache[keyname] then 
			local outf = io.open(srccache.shaderName .. fileextension,'w')
			--Spring.Echo(srccache[keyname])
			outf:write(srccache[keyname])
			outf:close()
		end
	end
end


function widget:TextCommand(cmd)
	if string.find(cmd, "fogdumpshaders", nil,true) then 
		Spring.Echo("Dumping shaders")
		DumpShaderSource(combineShaderSourceCache)
		DumpShaderSource(shaderSourceCache)
	end
end


if autoreload then 
	function widget:DrawScreen()
			local newfps = math.max(Spring.GetFPS(), 1)
			if shaderSourceCache.updateFlag then 
				shaderSourceCache.updateFlag = nil
				lastfps = newfps
			end
			

			local hasprintf = false
			if groundFogShader.DrawPrintf then 
				groundFogShader.DrawPrintf() 
				hasprintf = true
			end
			if combineShader.DrawPrintf then 
				combineShader.DrawPrintf(nil,nil, -70) 
				hasprintf = true
			end


			local fogdrawus = (1000/newfps - 1000/initfps)
			local fogdrawlast = (1000/lastfps - 1000/initfps)
			if fogdrawlast == 0 then fogdrawlast = 0.001 end
			local debugline = string.format("Fog draw time = %.3f ms, previous = %.3f ms", fogdrawus, fogdrawlast)
			if hasprintf then 
				debugline = debugline .. " (printf ON)"
			end
			local percentChange = 100*fogdrawus/fogdrawlast - 100.0
			debugline = debugline .. "\n" ..  string.format("%.3f delta ms (%.1f%%) since last recompilation \n%.3f ms total draw time\nNo fog FPS = %d, current FPS =%d", fogdrawus-fogdrawlast, percentChange , 1000/newfps, initfps, newfps )
			gl.Text(debugline,  vsx - 800,  80, 16, "d")

	

	end
end