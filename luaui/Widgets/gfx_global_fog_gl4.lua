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
-- Use a spherical harmonics equation for this?
-- DONE: Fix colorization of height based and distance based fog
-- Use non constant density fog (maybe exponential is better?) 
-- Create a better noise texture (also use this for other occasions!)
-- Expose params to be easily tunable
-- Create quality 'presets' and auto apply them?
-- copy the whole self-illumination and shading thing from the fog volumes gl4 shader?
-- DONE: better LOS shader usage?
-- minimap color backscatter
-- handle out-of-map better!


------------- Literature and Reading: ---
-- blue noise sampling:  https://blog.demofox.org/2020/05/10/ray-marching-fog-with-blue-noise/
-- Inigo quliez fog lighting tips: https://iquilezles.org/articles/fog/
-- Analyitic fog density: https://blog.demofox.org/2014/06/22/analytic-fog-density/


---- CONFIGURABLE PARAMETERS: -----------------------------------------


local shaderConfig = {
	-- These are static parameters, cannot be changed during runtime
	RAYMARCHSTEPS = 32, -- must be at least one, quite expensive
	RESOLUTION = 2, -- THIS IS EXTREMELY IMPORTANT and specifies the fog plane resolution as a whole! 1 = max, 2 = half, 4 = quarter etc.
	NOISESAMPLES = 6, -- how many samples of 3D noise to take
	NOISESCALE = 1.2, -- The tiling pattern of noise
	NOISETHRESHOLD = -0.0, -- The 0 level of noise
	LOSREDUCEFOG = 0, -- how much less fog there is in LOS , 0 is no height based fog in los, 1 is full fog in los
	USEMINIMAP = 1, -- 0 or 1 to use the minimap for back-scatter
	MINIMAPSCATTER = 0.1, -- How much the minimap color sdditively back-scatters into fog color, 0 is off

}


local shaderConfigNoNoise = {
	-- These are static parameters, cannot be changed during runtime
	RAYMARCHSTEPS = 32, -- must be at least one, quite expensive
	RESOLUTION = 2, -- THIS IS EXTREMELY IMPORTANT and specifies the fog plane resolution as a whole! 1 = max, 2 = half, 4 = quarter etc.
	NOISESAMPLES = 6, -- how many samples of 3D noise to take
	NOISESCALE = 1.2,
	NOISETHRESHOLD = -0.0,
	LOSREDUCEFOG = 0,	
	MINIMAPSCATTER = 0.15, -- How much the minimap color back-scatters into fog color, 0 is off
}
--shaderConfig = shaderConfigNoNoise

local minHeight, maxHeight = Spring.GetGroundExtremes()
local fogUniforms = {
	fogGlobalColor = {0.29,0.23,0.17,1}, -- bluish
	fogSunColor = {1.0,0.9,0.8,1}, -- yellowish
	fogShadowedColor = {0.1,0.05,0.1,1}, -- purleish tint
	fogPlaneHeight = (math.max(minHeight,0) + maxHeight) /1.7 ,
	fogGlobalDensity = 0.50,
	fogGroundDensity = 0.15,
	fogExpFactor = -0.000110, -- yes these are small negative numbers
	noiseParams = {
		1.4, -- high-frequency cloud noise, lower numbers = lower frequency
		0.2, -- noise bias, [-1,1] high numbers denser
		1.2, -- low frequency big cloud noise, lower numbers = lower frequency
		0.0,
		},
	}
	
local fogUniformsBluish = { -- bluish tint, not very good
	fogGlobalColor = {0.5,0.6,0.7,1}, -- bluish
	fogSunColor = {1.0,0.9,0.8,1}, -- yellowish
	fogShadowedColor = {0.1,0.05,0.1,1}, -- purleish tint
	fogPlaneHeight = (math.max(minHeight,0) + maxHeight) /2 ,
	fogGlobalDensity = 1.0,
	fogGroundDensity = 0.3,
	fogExpFactor = -0.0001, -- yes these are small negative numbers
	noiseParams = {
		4.2, -- high-frequency cloud noise, lower numbers = lower frequency
		0.0, -- noise bias, [-1,1] high numbers denser
		1.5, -- low frequency big cloud noise, lower numbers = lower frequency
		0.0,
		},
	}

---------------------------------------------------------------------------
local autoreload = true

--local noisetex3dcube =  "LuaUI/images/noise64_cube_3.dds"
--local noisetex3dcube =  "LuaUI/images/noisetextures/cloudy8_256x256x64_L.dds"
local noisetex3dcube =  "LuaUI/images/noisetextures/cloudy8_a_128x128x32_L.dds"
local simpledither = "LuaUI/images/rgba_noise_256.tga"
local worley3d128 = "LuaUI/images/worley_rgbnorm_01_asum_128_v1.dds"
local dithernoise2d =  "LuaUI/images/lavadistortion.png"

local fogPlaneVAO 
local resolution = 64
local groundFogShader

local vsx, vsy
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
			worley3d3level = 7,
		},
		uniformFloat = {
			windX = 0,
			windZ = 0,
			fogGlobalColor = fogUniforms.fogGlobalColor,
			fogSunColor = fogUniforms.fogSunColor,
			fogShadowedColor = fogUniforms.fogShadowedColor,
			fogGlobalDensity = fogUniforms.fogGlobalDensity,
			fogGroundDensity = fogUniforms.fogGroundDensity, 
			fogPlaneHeight = fogUniforms.fogPlaneHeight,
			fogExpFactor = fogUniforms.fogExpFactor,
		},
		shaderName = "Ground Fog GL4",
		shaderConfig = shaderConfig
	}



function widget:ViewResize()
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

function widget:Initialize()
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
	
	combineShader = LuaShader({
		--while this vertex shader seems to do nothing, it actually does the very important world space to screen space mapping for gl.TexRect!
		vertex = [[
			#version 150 compatibility
			void main(void)
			{
				gl_TexCoord[0] = gl_MultiTexCoord0;
				gl_Position    = gl_Vertex;
				gl_Position.z  = 0.0; // Can change depth here? hue hue
			} ]],
		fragment = [[
			#version 150 compatibility
			uniform sampler2D fogbase;
			uniform sampler2D distortion;
			uniform float gameframe;
			uniform float distortionlevel;
			void main(void) {
				vec2 distUV = gl_TexCoord[0].st * 4 + vec2(0, - gameframe*4);
				//distUV = vec2(0.0);
				vec4 dist = (texture2D(distortion, distUV) * 2.0 - 1.0) * distortionlevel;
				vec4 dx = dFdx(dist);
				vec4 dy = dFdy(dist);
				
				gl_FragColor = texture2D(fogbase, gl_TexCoord[0].st + dist.xy);
			}
		]],
		uniformInt = { fogbase = 0, distortion = 1},
		uniformFloat = { gameframe = 0, distortionlevel = 0},
	})
	
	shaderCompiled = combineShader:Initialize()
	if (shaderCompiled == nil) then
		goodbye("[Global Fog::combineShader] combineShader compilation failed")
		return
	end
	WG['SetFogParams'] = SetFogParams
end

function widget:Shutdown()
	if fogTexture then gl.DeleteTexture(fogTexture) end
	WG.SetFogParams = nil
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
	gl.Clear(GL.COLOR_BUFFER_BIT)
	gl.DepthMask(false) 
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	fogPlaneVAO:DrawElements(GL.TRIANGLES)
end

function widget:DrawWorld() 

	if autoreload then
		groundFogShader =  LuaShader.CheckShaderUpdates(shaderSourceCache) or groundFogShader
	end
	gl.DepthMask(false) -- dont write to depth buffer

	gl.Culling(GL.FRONT) -- cause our tris are reversed in plane vbo
	gl.Texture(0, "$map_gbuffer_zvaltex")
	gl.Texture(1, "$model_gbuffer_zvaltex")
	gl.Texture(2, "$heightmap")
	if shaderConfig.LOSREDUCEFOG < 1 and WG['infolosapi'].GetInfoLOSTexture then 
		gl.Texture(3, WG['infolosapi'].GetInfoLOSTexture()) --$info:los
	else
		gl.Texture(3, "$info") --$info:los
	end
	gl.Texture(4, "$shadow")
	gl.Texture(5, noisetex3dcube)

	if shaderConfig.USEMINIMAP > 0 then 
		gl.Texture(6, '$minimap')
	end

	gl.Texture(7, worley3d128)
	
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
	
	if toTexture then 
		gl.RenderToTexture(fogTexture, renderToTextureFunc)
	else
		fogPlaneVAO:DrawElements(GL.TRIANGLES)
	end

	groundFogShader:Deactivate()
	
	for i = 0, 7 do gl.Texture(i, false) end 
	gl.Culling(false)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	-- glColorMask(false, false, false, false)
	if toTexture then 
		local alt, ctrl, meta, shft = Spring.GetModKeyState()	
		if shft then
			gl.Blending(GL.ONE, GL.ZERO)
		else
			gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		end
		combineShader:Activate()
		combineShader:SetUniformFloat("gameframe", Spring.GetGameFrame()/1000)
		combineShader:SetUniformFloat("distortionlevel", 0.0001) -- 0.001
		gl.Texture(0, fogTexture)
		gl.Texture(1, distortiontex)
		gl.TexRect(-1, -1, 1, 1, 0, 0, 1, 1)
		combineShader:Deactivate()
		--gl.TexRect(0, 0, 10000, 10000, 0, 0, 1, 1) -- dis is for debuggin!
		gl.Texture(0, false)
		gl.Texture(1, false)
	end
  gl.DepthMask(false) --"BK OpenGL state resets", reset to default state
end
