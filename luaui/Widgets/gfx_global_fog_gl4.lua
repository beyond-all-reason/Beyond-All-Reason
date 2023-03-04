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
		layer = 99992, -- lol this isnt even a number
		enabled = false
	}
end

local GL_RGBA32F_ARB = 0x8814
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
-- handle out-of-map better!
-- DONE: Fix non raytraced fog nonlinearity
-- TODO: Make it also be clouds
-- TODO: handle pullback of min(mapdepth, modeldepth); better than now.
-- VERY IMPORTANT NOTES:
-- WHEN NOT USING RAYTRACING, SET FOG RESOLUTION TO 1!!!!!!!!!

-- Most fucked up idea ever:
	-- a simple 2d texture lookup is _still_ faster than a fucking noise gen, even the cheapest goddamned FBM noise too
	-- ping-pong between two textures every gameframe, and render all units into that. What should the texture contain?
	-- Well it should always read the first ping, to be able to decay it
	-- red and blue contain XY offset of all unit's triggered noise swirl shit
	-- green could contain the 'height' of the turbulence
	
	-- 
	-- Alpha of it should contain like a global noise offset, which should blow with the wind, but contain some underlying moderate frequency noise

------------- Literature and Reading: ---
-- blue noise sampling:  https://blog.demofox.org/2020/05/10/ray-marching-fog-with-blue-noise/
-- Inigo quliez fog lighting tips: https://iquilezles.org/articles/fog/
-- Analyitic fog density: https://blog.demofox.org/2014/06/22/analytic-fog-density/


---- CONFIGURABLE PARAMETERS: -----------------------------------------


local vsx, vsy = Spring.GetViewGeometry()

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
}

local definesSlidersParamsList = {
	{name = 'RESOLUTION', default = 1, min = 1, max = 8, digits = 0, tooltip = 'Fog resolution divider, 1 = full resolution, 2 = half'},
	{name = 'RAYTRACING', default = 1, min = 0, max = 1, digits = 0, tooltip = 'Use any raytracing, 1 = yes, 0 = no'},
	{name = 'SHADOWMARCHSTEPS', default = 32, min = 1, max = 128, digits = 0, tooltip =  'How many times to sample shadows'},
	{name = 'HEIGHTSHADOWSTEPS', default = 12, min = 0, max = 64, digits = 0, tooltip =  'How many times to sample shadows for pure height-based fog'},
	{name = 'HEIGHTSHADOWQUAD', default = 2, min = 0, max = 2, digits = 0, tooltip =  'How to Quad sample height-based fog'},
	{name = 'SHADOWSAMPLER', default = 2, min = 0, max = 3, digits = 0, tooltip =  '0 use texture fetch, 1 use sampler fetch, 2 use texelfetch'},
	{name = 'BLUENOISESTRENGTH', default = 1.1, min = 0, max = 1.1, digits = 1, tooltip =  'Amount of blue noise added to shadow sampling'},
	{name = 'TEXTURESAMPLER', default = 1, min = 0, max = 6, digits = 0,  tooltip = '0:None 1=Packed3D 2=Tex2D 3=Tex2D 4=FBM 5=Value3D 6=SimplexPerlin'},
	{name = 'QUADNOISEFETCHING', default = 1, min = 0, max = 1, digits = 0,  tooltip = 'Enable Quad Message Passing [0 or 1]'},
	{name = 'NOISESAMPLES',default = 16, min = 1, max = 64, digits = 0, tooltip = 'How many samples of 3D noise to take'},
	{name = 'NOISESCALE', default = 0.2, min = 0, max = 2, digits = 2, tooltip = 'The tiling frequency of noise'},
	{name = 'NOISETHRESHOLD', default = 0, min = -1, max = 1, digits = 2, tooltip =  'The 0 level of noise'},
	{name = 'USELOS', default = 1, min = 0, max = 1, digits = 0, tooltip = 'Use the LOS map at all, 1 = yes, 0 = no'},
	{name = 'USEMINIMAP', default = 0, min = 0, max = 1, digits = 0, tooltip = '0 or 1 to use the minimap for back-scatter'},
	{name = 'FULLALPHA',default = 0, min = 0, max = 1, digits = 0, tooltip = 'Show ONLY fog'},
	{name = 'USEDDS', default = 0, min = 0, max = 1, digits = 0, tooltip = 'Use DDS compressed version of packedNoise'},
	{name = 'LOSREDUCEFOG', default = 0, min = 0, max = 1, digits = 2, tooltip = 'How much less fog there is in LOS , 0 is no height based fog in los, 1 is full fog in los'},
	{name = 'LOSFOGUNDISCOVERED', default = 1.0, min = 0, max = 1, digits= 2, tooltip = 'This specifies how much more fog there should be where the map has not yet been discovered ever (0 is none, 1 is a lot)'},
	{name = 'WINDSTRENGTH', default = 1.0, min = 0, max = 4, digits = 2, tooltip = 'Speed multiplier for wind'},
	{name = 'HEIGHTDENSITY', default = 2, min = 1, max = 10, digits = 2, tooltip = 'How quickly height fog reaches its max density'},
	{name = 'SUNCHROMASHIFT', default = 0.2,  min = -0.5, max = 1, digits = 2, tooltip = 'How much colors are shifted towards sun'},
	{name = 'MINIMAPSCATTER', default = 0.1, min = -0.5, max = 0.5, digits = 2, tooltip = 'How much the minimap color sdditively back-scatters into fog color, 0 is off'},
	{name = 'EASEGLOBAL', default = 2, min = 1, max = 50, digits = 2, tooltip = 'How much to reduce global fog close to camera'},
	{name = 'EASEHEIGHT', default = 1, min = 0.0, max = 5, digits = 2, tooltip = 'How much to reduce height-based fog close to camera'},
	{name = 'CLOUDSHADOWS', default = 8, min = 0, max = 16, digits = 0, tooltip = 'How many rays to cast in the direction of the sun for shadows'},
}

for i, shaderDefine in ipairs(definesSlidersParamsList) do 
	-- dont overwrite existing, externally defined values with the defaults:
	if shaderConfig[shaderDefine.name] == nil then 
		shaderConfig[shaderDefine.name] = shaderDefine.default;
	end
end

local fogUniforms = {
	fogGlobalColor = {0.6,0.7,0.8,0.98}, -- bluish, alpha is the ABSOLUTE MAXIMUM FOG
	fogSunColor = {1.0,0.9,0.8,0.35}, -- yellowish, alpha is power
	fogShadowedColor = {0.1,0.05,0.1,0.5}, -- purleish tint, alpha is power
	fogPlaneTop = (math.max(minHeight,0) + maxHeight) /1.7 , -- Start of the height thing
	fogPlaneBottom = 100, -- Start of the height thing
	fogGlobalDensity = 1.50, -- How dense the global fog is
	fogGroundDensity = 0.25, -- How dense the height-based fog is
	fogExpFactor = 1.0, -- Overall density multiplier
	cloudVolumeMin = {0,maxHeight/2,0,0}, -- XYZ coords of the fog volume start, along with the bottom density in W
	cloudVolumeMax= {Game.mapSizeX, maxHeight, Game.mapSizeZ,0}, -- XYZ coords of fog volume end, along with the top density
	scavengerPlane = {Game.mapSizeX, Game.mapSizeZ, 100,100}, -- The assumption here is that we can specify an X and Z limit on fog, and a density transition function. negative numbers should swap plane dir 
	noiseParams = {
		1.4, -- high-frequency cloud noise, lower numbers = lower frequency
		0.2, -- noise bias, [-1,1] high numbers denser
		0.77, -- low frequency big cloud noise, lower numbers = lower frequency
		0.0, -- low frequency noise bias, keep between [-1,1]
		},

	}
	

local fogUniformSliders = {
	windowtitle = "Fog Uniforms",
	name = "fogUniformSliders",
	left = vsx - 270, 
	right = vsx - 270 + 250,
	bottom = 200,
	top = 900,
	width = 250, 
	height = 20,
	sliderheight = 20,
	valuetarget = fogUniforms,
	sliderParamsList = {
		{name = 'fogGlobalColor', min = 0, max = 1, digits = 3, tooltip =  'fogGlobalColor, alpha is the ABSOLUTE MAXIMUM FOG'},
		{name = 'fogSunColor', min = 0, max = 1, digits = 3, tooltip =  'fogSunColor, alpha is power'},
		{name = 'fogShadowedColor', min = 0, max = 1, digits = 3, tooltip =  'fogShadowedColor'},
		{name = 'fogPlaneTop', min = math.floor(minHeight), max = math.floor(maxHeight * 2), digits = 0, tooltip =  'fogPlaneTop, in elmos'},
		{name = 'fogPlaneBottom', min = math.floor(minHeight), max = math.floor(maxHeight), digits = 0, tooltip =  'fogPlaneBottom, in elmos'},
		
		{name = 'cloudVolumeMin', min = 0,max = math.max(Game.mapSizeX, Game.mapSizeZ), digits = 0, tooltip =  'Start of the cloud volume'},
		{name = 'cloudVolumeMax', min = 0, max = math.max(Game.mapSizeX, Game.mapSizeZ), digits = 0, tooltip =  'End of the cloud volume'},
		{name = 'scavengerPlane', min = 0, max = math.max(Game.mapSizeX, Game.mapSizeZ), digits = 0, tooltip =  'Where the scavenger cloud is'},
		
		{name = 'fogGlobalDensity', min = 0.01, max = 10, digits = 2, tooltip =  'How dense the global fog is'},
		{name = 'fogGroundDensity', min = 0.01, max = 1, digits = 2, tooltip =  'How dense the height-based fog is'},
		{name = 'fogExpFactor', min = 0.000, max = 5, digits = 2, tooltip =  'Overall density multiplier'},
		{name = 'noiseParams', min = -1, max = 5, digits = 3, tooltip =  'High and low frequency gain, bias multipliers'},
	},
	callbackfunc = nil
}

local uniformSlidersLayer, uniformSlidersWindow
	
local fogUniformsBluish = { -- bluish tint, not very good
	fogGlobalColor = {0.5,0.6,0.7,1}, -- bluish
	fogSunColor = {1.0,0.9,0.8,1}, -- yellowish
	fogShadowedColor = {0.1,0.05,0.1,1}, -- purleish tint
	fogPlaneTop = (math.max(minHeight,0) + maxHeight) /2 ,
	fogGlobalDensity = 1.0,
	fogGroundDensity = 0.3,
	fogExpFactor = -0.0001, -- yes these are small negative numbers
	noiseParams = {
		4.2, -- high-frequency cloud noise, lower numbers = lower frequency
		0.1, -- noise bias, [-1,1] high numbers denser
		1.5, -- low frequency big cloud noise, lower numbers = lower frequency
		0.0,
		},
	}

---------------------------------------------------------------------------
local autoreload = true

--local noisetex3dcube =  "LuaUI/images/noisetextures/noise64_cube_3.dds"
local noisetex3dcube =  "LuaUI/images/noisetextures/cloudy8_256x256x64_L.dds"
local noisetex3dcube =  "LuaUI/images/noisetextures/worley_rgbnorm_01_asum_128_v1_mip.dds"
local blueNoise64 =  "LuaUI/images/noisetextures/blue_noise_64.tga"
local uniformNoiseTex =  "LuaUI/images/noisetextures/uniform3d_16x16x16_RGBA.dds"
--local noisetex3dcube =  "LuaUI/images/noisetextures/cloudy8_a_128x128x32_L.dds"
local simpledither = "LuaUI/images/noisetextures/rgba_noise_256.tga"
local worley3d128 = "LuaUI/images/noisetextures/worley_rgbnorm_01_asum_128_v1.dds"
local dithernoise2d =  "LuaUI/images/lavadistortion.png"

local fogPlaneVAO 
local resolution = 64
local groundFogShader

local combineShader
local fogTexture
local distortiontex = "LuaUI/images/fractal_voronoi_tiled_1024_1.png"


local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")

local function goodbye(reason) 
	Spring.Echo('Exiting', reason)
	widgetHandler:RemoveWidget()
end

local vsSrcPath = "LuaUI/Widgets/Shaders/global_fog.vert.glsl"
local fsSrcPath = "LuaUI/Widgets/Shaders/global_fog.frag.glsl"

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
			windX = 0,
			windZ = 0,
			fogGlobalColor = fogUniforms.fogGlobalColor,
			fogSunColor = fogUniforms.fogSunColor,
			fogShadowedColor = fogUniforms.fogShadowedColor,
			fogGlobalDensity = fogUniforms.fogGlobalDensity,
			fogGroundDensity = fogUniforms.fogGroundDensity, 
			fogPlaneTop = fogUniforms.fogPlaneTop,
			fogPlaneBottom = fogUniforms.fogPlaneBottom,
			fogExpFactor = fogUniforms.fogExpFactor,
		},
		shaderName = "Ground Fog GL4",
		shaderConfig = shaderConfig
	}

local function makeFogTexture()
	vsx, vsy = Spring.GetViewGeometry()

	if fogTexture then gl.DeleteTexture(fogTexture) end

	fogTexture = gl.CreateTexture(vsx/ shaderConfig.RESOLUTION, vsy/shaderConfig.RESOLUTION, {
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
		fbo = true,
		format = GL_RGBA32F_ARB,
		})
end


function widget:ViewResize()
	makeFogTexture()
end

widget:ViewResize()

local function initGL4()
	-- init the VBO
	local planeVBO, numVertices = makePlaneVBO(1,1,Game.mapSizeX/resolution,Game.mapSizeZ/resolution)
	local planeIndexVBO, numIndices =  makePlaneIndexVBO(Game.mapSizeX/resolution,Game.mapSizeZ/resolution)
	fogPlaneVAO = gl.GetVAO()
	fogPlaneVAO:AttachVertexBuffer(planeVBO)
	fogPlaneVAO:AttachIndexBuffer(planeIndexVBO)
	
	groundFogShader =  LuaShader.CheckShaderUpdates(shaderSourceCache)
	if not groundFogShader then goodbye("Failed to compile Ground Fog GL4") end 
	--Spring.Echo("Number of triangles= ", Game.mapSizeX/resolution,Game.mapSizeZ/resolution)
	return true
end

local function SetFogParams(paramname, paramvalue, paramIndex)
	Spring.Echo("SetFogParams",paramname, paramvalue)
	if fogUniforms[paramname] then
		if paramIndex then 
			fogUniforms[paramname][paramIndex] = paramvalue
		else
			fogUniforms[paramname] = paramvalue
		end
	end
end

local function shaderDefinesChangedCallback(name, value, index, oldvalue)
	--Spring.Echo("shaderDefinesChangedCallback()", name, value, shaderConfig[name])
	if value ~= oldvalue then 
		shaderSourceCache.forceupdate = true
		groundFogShader =  LuaShader.CheckShaderUpdates(shaderSourceCache) or groundFogShader
		if name == 'RESOLUTION' then 
			makeFogTexture()
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

local vsSrcPathCombine = "LuaUI/Widgets/Shaders/global_fog_combine.vert.glsl"
local fsSrcPathCombine = "LuaUI/Widgets/Shaders/global_fog_combine.frag.glsl"

local combineShaderSourceCache = {
		vssrcpath = vsSrcPathCombine,
		fssrcpath = fsSrcPathCombine,
		--gssrcpath = gsSrcPath,
		uniformInt = { mapDepths = 0, modelDepths = 1,  fogbase = 2, distortion = 3},
		uniformFloat = { gameframe = 0, distortionlevel = 0, resolution = 2},
		shaderName = "Ground Fog Combine GL4",
		shaderConfig = {VSX =vsx, VSY = vsy}
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

	combineShader =  LuaShader.CheckShaderUpdates(combineShaderSourceCache)
	if (combineShader == nil) then
	
		widgetHandler:RemoveWidget()
		goodbye("[Global Fog::combineShader] combineShader compilation failed")
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
	
	if vsx%4~=0 or vsy%4 ~= 0 then 
		Spring.Echo("Global Fog Warning: viewport is not even!", vsx, vsy)
	end
	return true
end

function widget:Shutdown()
	if fogTexture then gl.DeleteTexture(fogTexture) end
	WG.SetFogParams = nil
	if fogUniformSliders.Destroy then fogUniformSliders:Destroy() end
	if shaderDefinedSlidersLayer.Destroy then shaderDefinedSlidersLayer:Destroy() end 
end

local windX = 0
local windZ = 0
function widget:GameFrame(n)
	local windDirX, _, windDirZ, windStrength = Spring.GetWind()
	windX = windX + windDirX *  0.016
	windZ = windZ + windDirZ * 0.016	
end

function widget:Update()
	--SetFogParams("fogGroundDensity", 0.1)
end

local toTexture = true

local function renderToTextureFunc() -- this draws the fogspheres onto the texture
	--gl.DepthMask(false) 
	--gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	gl.Blending(GL.ONE, GL.ZERO)
	fogPlaneVAO:DrawElements(GL.TRIANGLES)
end

function widget:DrawWorld() 

	if autoreload then
		groundFogShader =  LuaShader.CheckShaderUpdates(shaderSourceCache) or groundFogShader
		combineShader =  LuaShader.CheckShaderUpdates(combineShaderSourceCache) or combineShader
	end
	gl.DepthMask(false) -- dont write to depth buffer

	gl.Culling(GL.FRONT) -- cause our tris are reversed in plane vbo
	gl.Texture(0, "$map_gbuffer_zvaltex")
	gl.Texture(1, "$model_gbuffer_zvaltex")
	gl.Texture(2, distortiontex)
	if shaderConfig.USELOS == 1 and WG['infolosapi'].GetInfoLOSTexture then 
		gl.Texture(3, WG['infolosapi'].GetInfoLOSTexture()) --$info:los
	else
		gl.Texture(3, "$info") --$info:los
	end
	gl.Texture(4, "$shadow")
	gl.Texture(5, noisetex3dcube)

	if shaderConfig.USEMINIMAP > 0 then 
		gl.Texture(6, '$minimap')
	end
	local packedNoise =  "LuaUI/images/noisetextures/worley3_256x128x64_RBGA_LONG." .. ((shaderConfig.USEDDS == 1 ) and 'dds' or 'png')
	gl.Texture(7, packedNoise)
	gl.Texture(8, blueNoise64)
	gl.Texture(9, uniformNoiseTex)
	
	groundFogShader:Activate()
	groundFogShader:SetUniformFloat("windX", windX)
	groundFogShader:SetUniformFloat("windZ", windZ)
	
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
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		fogPlaneVAO:DrawElements(GL.TRIANGLES)
	end

	groundFogShader:Deactivate()
	
	gl.Culling(false)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	-- glColorMask(false, false, false, false)
	if toTexture then 
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		combineShader:Activate()
		combineShader:SetUniformFloat("resolution", shaderConfig.RESOLUTION)
		--combineShader:SetUniformFloat("distortionlevel", 0.0001) -- 0.001
		gl.Texture(2, fogTexture)
		gl.Texture(3, distortiontex)
		gl.TexRect(-1, -1, 1, 1, 0, 0, 1, 1)
		combineShader:Deactivate()
		--gl.TexRect(0, 0, 10000, 10000, 0, 0, 1, 1) -- dis is for debuggin!
	end
	for i = 0, 8 do gl.Texture(i, false) end 
  gl.DepthMask(false) --"BK OpenGL state resets", reset to default state
end

function widget:DrawScreen()
	if autoreload then 
		local newfps = Spring.GetFPS()
		if shaderSourceCache.updateFlag then 
			shaderSourceCache.updateFlag = nil
			lastfps = newfps
		end
		local fogdrawus = (1000/newfps - 1000/initfps)
		local fogdrawlast = (1000/lastfps - 1000/initfps)
		gl.Text(string.format("fog %.3f ms last %.3f ms", fogdrawus, fogdrawlast),  vsx - 600,  100, 16, "d")
		gl.Text(string.format("%.3f dms  %.1fpct", fogdrawus-fogdrawlast, 100*fogdrawus/fogdrawlast  ),  vsx - 600,  80, 16, "d")
	end
end