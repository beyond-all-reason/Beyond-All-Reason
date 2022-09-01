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
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local vsx, vsy, chobbyInterface
local ivsx = 1.0
local ivsy = 1.0
local screenratio = 1.0
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1, 19) == 'LobbyOverlayActive1')
	end
end

function widget:ViewResize()
	vsx, vsy = gl.GetViewSizes()
	ivsx = 1.0 / vsx --we can do /n here!
	ivsy = 1.0 / vsy
	if Spring.GetMiniMapDualScreen() == 'left' then
		vsx = vsx / 2
	end
	if Spring.GetMiniMapDualScreen() == 'right' then
		vsx = vsx / 2
	end
	screenratio = vsy / vsx --so we dont overdraw and only always draw a square
end

widget:ViewResize()

-- GL4 notes:
local shaderConfig = {
	MIERAYLEIGHRATIO = 0.1,
	RAYMARCHSTEPS = 4, -- must be at least one
	USE3DNOISE = 1,
	USEDEFERREDBUFFERS = 1, 
	RESOLUTION = 1,
	FOGTOP = 300,
}

local globalFogColor = {0.8,0.8,0.8,1}

local noisetex3dcube =  "LuaUI/images/noise64_cube_3.dds"
local simpledither = "LuaUI/images/rgba_noise_256.tga"
local worley3d128 = "LuaUI/images/worley_rgbnorm_01_asum_128_v1.dds"
local dithernoise2d =  "LuaUI/images/lavadistortion.png"

local fogPlaneVAO 
local resolution = 64
local groundFogShader

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
			globalFogColor = {1,1,1,1},
		},
		shaderName = "Ground Fog GL4",
		shaderConfig = shaderConfig
	}

local function checkShaderUpdates(shadersourcecache, delaytime)
	-- todo: extract shaderconfig
	if shadersourcecache.lastshaderupdate == nil or 
		Spring.DiffTimers(Spring.GetTimer(), shadersourcecache.lastshaderupdate) > (delaytime or 0.5) then 
		shadersourcecache.lastshaderupdate = Spring.GetTimer()
		local vsSrcNew = shadersourcecache.vssrcpath and VFS.LoadFile(shadersourcecache.vssrcpath)
		local fsSrcNew = shadersourcecache.fssrcpath and VFS.LoadFile(shadersourcecache.fssrcpath)
		local gsSrcNew = shadersourcecache.gssrcpath and VFS.LoadFile(shadersourcecache.gssrcpath)
		if  vsSrcNew == shadersourcecache.vsSrc and 
			fsSrcNew == shadersourcecache.fsSrc and 
			gsSrcNew == shadersourcecache.gsSrc and 
			not forceupdate then 
			--Spring.Echo("No change in shaders")
			return nil
		else
			local compilestarttime = Spring.GetTimer()
			shadersourcecache.vsSrc = vsSrcNew
			shadersourcecache.fsSrc = fsSrcNew
			shadersourcecache.gsSrc = gsSrcNew
			
			local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
			local shaderDefines = LuaShader.CreateShaderDefinesString(shadersourcecache.shaderConfig)
			if vsSrcNew then 
				vsSrcNew = vsSrcNew:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
				vsSrcNew = vsSrcNew:gsub("//__DEFINES__", shaderDefines)
			end
			if fsSrcNew then 
				fsSrcNew = fsSrcNew:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
				fsSrcNew = fsSrcNew:gsub("//__DEFINES__", shaderDefines)
			end
			if gsSrcNew then 
				gsSrcNew = gsSrcNew:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
				gsSrcNew = gsSrcNew:gsub("//__DEFINES__", shaderDefines)
			end
			local reinitshader =  LuaShader(
				{
				vertex = vsSrcNew,
				fragment = fsSrcNew,
				geometry = gsSrcNew,
				uniformInt = shadersourcecache.uniformInt,
				uniformFloat = shadersourcecache.uniformFloat,
				},
				shadersourcecache.shaderName
			)
			local shaderCompiled = reinitshader:Initialize()
			
			Spring.Echo(shadersourcecache.shaderName, " recompiled in ", Spring.DiffTimers(Spring.GetTimer(), compilestarttime, true), "ms at", Spring.GetGameFrame(), "success", shaderCompiled or false)
			if shaderCompiled then 
				reinitshader.ignoreUnkUniform = true
				return reinitshader
			else
				return nil
			end
		end
	end
	return nil
end

 
local function initGL4()
	-- init the VBO
	local planeVBO, numVertices = makePlaneVBO(1,1,Game.mapSizeX/resolution,Game.mapSizeZ/resolution)
	local planeIndexVBO, numIndices =  makePlaneIndexVBO(Game.mapSizeX/resolution,Game.mapSizeZ/resolution)
	fogPlaneVAO = gl.GetVAO()
	fogPlaneVAO:AttachVertexBuffer(planeVBO)
	fogPlaneVAO:AttachIndexBuffer(planeIndexVBO)
	
	groundFogShader =  checkShaderUpdates(shaderSourceCache)
	if not groundFogShader then goodbye("Failed to compile Ground Fog GL4") end 
	Spring.Echo("Number of triangles= ", Game.mapSizeX/resolution,Game.mapSizeZ/resolution)
	return true
end

function widget:Initialize()
	if Spring.GetConfigString("AllowDeferredMapRendering") == '0' or Spring.GetConfigString("AllowDeferredModelRendering") == '0' then
		Spring.Echo('Ground Fog GL4 requires  AllowDeferredMapRendering and AllowDeferredModelRendering to be enabled in springsettings.cfg!')
		widgetHandler:RemoveWidget()
		return
	end
	if initGL4() == false then return end
	WG['groundfoggl4'] = {}
	WG['groundfoggl4'].AddPointLight = AddPointLight
	widgetHandler:RegisterGlobal('AddPointLight', WG['groundfoggl4'].AddPointLight)
end

function widget:Shutdown()
	-- TODO: delete the VBOs and shaders like a good boy 
end

local windX = 0
local windZ = 0
function widget:GameFrame(n)
	local windDirX, _, windDirZ, windStrength = Spring.GetWind()
	windX = windX + windDirX *  0.016
	windZ = windZ + windDirZ * 0.016	
end

function widget:Update()
end

function widget:DrawWorld() 
	-- We are drawing in world space, probably a bad idea but hey
	--	glBlending(GL.DST_COLOR, GL.ONE) -- Set add blending mode
	groundFogShader =  checkShaderUpdates(shaderSourceCache) or groundFogShader
	
	
	local alt, ctrl, meta, shft = Spring.GetModKeyState()	
	if ctrl then
		gl.Blending(GL.SRC_ALPHA, GL.ONE)
	else
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	end
	gl.Culling(GL.BACK)
	gl.Culling(false)
	gl.DepthTest(GL.LEQUAL)
	gl.DepthMask(false)
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
	groundFogShader:SetUniformFloat("globalFogColor", globalFogColor[1], globalFogColor[2],globalFogColor[3],globalFogColor[4])
	
	
	fogPlaneVAO:DrawElements(GL.TRIANGLES)

	groundFogShader:Deactivate()
	
	for i = 0, 8 do gl.Texture(i, false) end 
	gl.Culling(GL.BACK)
	gl.DepthTest(true)
	gl.DepthMask(true)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
end
