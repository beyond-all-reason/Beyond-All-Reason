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
		layer = -99999992,
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
	-- 
	
---- CONFIGURABLE PARAMETERS: -----------------------------------------

local shaderConfig = {
	-- These are static parameters, cannot be changed during runtime
	RAYMARCHSTEPS = 64, -- must be at least one, quite expensive
	USE3DNOISE = 1, -- It might be sufficient to subsample ray steps by this
	RESOLUTION = 2, -- THIS IS EXTREMELY IMPORTANT and specifies the fog plane resolution as a whole!
	FOGTOP = 300, -- deprecated
}

local minHeight, maxHeight = Spring.GetGroundExtremes()
local fogUniforms = {
	globalFogColor = {0.8,0.8,0.8,1},
	fogPlaneHeight = (math.max(minHeight,0) + maxHeight) /2 ,
	fogGlobalDensity = 1.0,
	fogGroundDensity = 1.0,
	fogExpFactor = -0.0001 -- yes these are small negative numbers
	}

---------------------------------------------------------------------------
local autoreload = true

local noisetex3dcube =  "LuaUI/images/noise64_cube_3.dds"
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
			dithernoise2d = 6,
			simpledither = 7,
			worley3d3level = 8,
		},
		uniformFloat = {
			fadeDistance = 300000,
			windX = 0,
			windZ = 0,
			globalFogColor = fogUniforms.globalFogColor,
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
	Spring.Echo("Number of triangles= ", Game.mapSizeX/resolution,Game.mapSizeZ/resolution)
	return true
end

local function SetFogParams(paramname, paramvalue)
	Spring.Echo("SetFogParams",paramname, paramvalue)
	if fogUniforms[paramname] then
		fogUniforms[paramname] = paramvalue
	end
end

function widget:Initialize()
	minHeight, maxHeight = Spring.GetGroundExtremes()
	shaderConfig.FOGTOP = (math.max(minHeight,0) + maxHeight ) /2 
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
			} ]],
		fragment = [[
			#version 150 compatibility
			uniform sampler2D fogbase;
			uniform sampler2D distortion;
			uniform float gameframe;
			uniform float distortionlevel;
			void main(void) {
				vec2 distUV = gl_TexCoord[0].st * 4 + vec2(0, - gameframe*4);
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

	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)	
	
	--gl.Blending(true);
	--gl.BlendFuncSeparate(GL.SRC_ALPHA, GL.DST_ALPHA, GL.SRC_ALPHA, GL.ONE);
	--gl.BlendEquation(GL_FUNC_ADD);
	
	--gl.Culling(GL.FRONT)
	fogPlaneVAO:DrawElements(GL.TRIANGLES)
	--gl.Culling(GL.BACK)
end

local function renderToTextureClear() -- this func is needed to clear the render target
	gl.Blending(GL.ZERO, GL.ZERO)
	gl.Color(1,1,1,1)
	gl.TexRect(-1, -1, 1, 1, 0, 0, 1, 1)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
end

function widget:DrawWorld() 
	-- We are drawing in world space, probably a bad idea but hey
	--	glBlending(GL.DST_COLOR, GL.ONE) -- Set add blending mode
	if autoreload then
		groundFogShader =  LuaShader.CheckShaderUpdates(shaderSourceCache) or groundFogShader
	end
	
	if toTexture then 
		gl.RenderToTexture(fogTexture, renderToTextureClear)
	end
	
	
	local alt, ctrl, meta, shft = Spring.GetModKeyState()	
	if ctrl then
		gl.Blending(GL.SRC_ALPHA, GL.ONE)
	else
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	end
	gl.Culling(GL.BACK)
	gl.Culling(false)
	gl.DepthTest(GL.LEQUAL)
	gl.DepthMask(false) --"BK OpenGL state resets", default is already false, could remove
	gl.Texture(0, "$map_gbuffer_zvaltex")
	gl.Texture(1, "$model_gbuffer_zvaltex")
	gl.Texture(2, "$heightmap")
	gl.Texture(3, "$info")
	gl.Texture(4, "$shadow")
	gl.Texture(5, noisetex3dcube)
	gl.Texture(6, dithernoise2d)
	gl.Texture(7, simpledither)
	gl.Texture(8, worley3d128)

	--Spring.Echo(screenCopyTex)
	
	groundFogShader:Activate()
	groundFogShader:SetUniformFloat("windX", windX)
	groundFogShader:SetUniformFloat("windZ", windZ)
	groundFogShader:SetUniformFloat("globalFogColor", fogUniforms.globalFogColor[1], fogUniforms.globalFogColor[2],fogUniforms.globalFogColor[3],fogUniforms.globalFogColor[4])
	for uniformName, uniformValue in pairs(fogUniforms) do 
		if type(uniformValue) == 'number' then 
			groundFogShader:SetUniformFloat(uniformName, uniformValue)
		end
	end
	
	if toTexture then 
		gl.RenderToTexture(fogTexture, renderToTextureFunc)
	else
		fogPlaneVAO:DrawElements(GL.TRIANGLES)
	end

	groundFogShader:Deactivate()
	
	for i = 0, 8 do gl.Texture(i, false) end 
	gl.Culling(GL.BACK)
	gl.DepthTest(true)
	gl.DepthMask(true) --"BK OpenGL state resets", need for toTexture block?
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	
	if toTexture then 
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
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
