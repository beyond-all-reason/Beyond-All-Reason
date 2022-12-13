
--------------------------------------------------------------------------------
function widget:GetInfo()
	return {
		name = "Infolos API",
		version = 3,
		desc = "Draws the info texture needed for many shaders",
		author = "Beherith",
		date = "2022.12.12",
		license = "Lua code is GPL V2, GLSL is (c) Beherith",
		layer = -10000, -- lol this isnt even a number
		enabled = false
	}
end

local GL_RGBA32F_ARB = 0x8814
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- About:
	-- This API presents an easy -to-use smoothed LOS texture for other widgets to do their shading based on
	-- The RED channel contains LOS level, where 0.33 = airlos
	-- the GREEN channel contains AIRLOS level
	-- the BLUE channel contains RADAR coverage
		-- 0.5 = no radar
		-- >0.5 = radar coverage
		-- <0.5 = jammer
	-- It runs every gameFrame
-- TODO: 2022.12.12
	-- make it work?
	-- make api share?
	-- a clever thing might be to have 1 texture per allyteam?
	-- some bugginess with jammer range?

local autoreload = false
---- CONFIGURABLE PARAMETERS: -----------------------------------------

local shaderConfig = {
	SAMPLES = 4, -- quality setting
	RESOLUTION = 2, -- Number of times to downsample (fraction of heightmap rez!)
}
---------------------------------------------------------------------------

local alwaysColor, losColor, radarColor, jamColor, radarColor2 = Spring.GetLosViewColors() --unused
local outputAlpha = 0.07
local infoShader
local infoTexture
local texX, texY
local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")

local vsSrcPath = "LuaUI/Widgets/Shaders/infolos.vert.glsl"
local fsSrcPath = "LuaUI/Widgets/Shaders/infolos.frag.glsl"

local miplevels = {2^3, 2^4, 2^3, 1} -- los, airlos and radar mip levels

local shaderSourceCache = {
		vssrcpath = vsSrcPath,
		fssrcpath = fsSrcPath,
		uniformFloat = {
			outputAlpha = 0.1,
			time = 1.0,
		},
		uniformInt = {
			tex0 = 0,
			tex1 = 1,
			tex2 = 2,
			tex3 = 3,
		},
		textures = {
			[0] = "$info:los",
			[1] = "$info:airlos",
			[2] = "$info:radar",
		},
		shaderName = "InfoLOS GL4",
		shaderConfig = shaderConfig
	}

local function GetInfoLOSTexture()
	return infoTexture
end

function widget:Initialize()
	local alwaysColor, losColor, radarColor, jamColor, radarColor2 = Spring.GetLosViewColors()
	texX = (Game.mapSizeX/8)/shaderConfig.RESOLUTION
	texY = (Game.mapSizeZ/8)/shaderConfig.RESOLUTION
	
	for name, tex in pairs({LOS = "$info:los", AIRLOS = "$info:airlos", RADAR = "$info:radar" }) do
		local texInfo = gl.TextureInfo(tex)
		shaderConfig[name .. 'XSIZE'] = texInfo.xsize
		shaderConfig[name .. 'YSIZE'] = texInfo.ysize
		Spring.Debug.TableEcho(texInfo)
	end
	
	
	infoTexture = gl.CreateTexture(texX, texY, {
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
		fbo = true,
		format = GL.RGBA8, -- more than enough
		})
		
	infoShader =  LuaShader.CheckShaderUpdates(shaderSourceCache)
	shaderCompiled = infoShader:Initialize()
	if not shaderCompiled then Spring.Echo("Failed to compile InfoLOS GL4") end 
	

	
	WG['infolosapi'] = {}
	WG['infolosapi'].GetInfoLOSTexture = GetInfoLOSTexture
	widgetHandler:RegisterGlobal('GetInfoLOSTexture', WG['infolosapi'].GetInfoLOSTexture)
end

function widget:Shutdown()
	if infoTexture then gl.DeleteTexture(infoTexture) end
	WG['infolosapi'] = nil
	widgetHandler:DeregisterGlobal('GetInfoLOSTexture')
end

local updateInfoLOSTexture
function widget:GameFrame(n)
	if (n%1) == 0 then 
		updateInfoLOSTexture = true
	end
end

function widget:Update()
end

local function renderToTextureFunc() -- this draws the fogspheres onto the texture
	--gl.DepthMask(false) 
	gl.Texture(0, "$info:los")
	gl.Texture(1, "$info:airlos")
	gl.Texture(2, "$info:radar") --$info:los
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	gl.TexRect(-1, -1, 1, 1, 0, 0, 1, 1)
	gl.Texture(0, false)
	gl.Texture(1, false)
	gl.Texture(2, false)
	gl.Texture(3, false)
end

local lastUpdate = Spring.GetTimer()

function widget:DrawWorldPreUnit() 
	local nowtime = Spring.GetTimer()
	local deltat = Spring.DiffTimers(nowtime, lastUpdate)
	-- keeping outputAlpha identical is a very important trick for never-before-seen areas!
	--outputAlpha = math.min(1.0, math.max(0.07,deltat))
	--Spring.Echo(deltat,outputAlpha)
	if outputAlpha > 0.07 or deltat > outputAlpha then updateInfoLOSTexture = true end 
	if updateInfoLOSTexture then
		lastUpdate = nowtime

		gl.DepthMask(false) -- dont write to depth buffer
		gl.Culling(false) -- cause our tris are reversed in plane vbo
		infoShader:Activate()
		infoShader:SetUniformFloat("outputAlpha", outputAlpha)
		infoShader:SetUniformFloat("time", Spring.GetDrawFrame() / 1000)
		gl.RenderToTexture(infoTexture, renderToTextureFunc)
		infoShader:Deactivate()
		updateInfoLOSTexture = false
		gl.DepthMask(false) --"BK OpenGL state resets", reset to default state
	end
end

function widget:DrawScreen() -- the debug display output
	if autoreload then 
		infoShader = LuaShader.CheckShaderUpdates(shaderSourceCache) or infoShader
		gl.Color(1,1,1,1) -- use this to show individual channels of the texture!
		gl.Texture(0, infoTexture)
		gl.Blending(GL.ONE, GL.ZERO)
		gl.TexRect(0, 0, texX, texY, 0, 0, 1, 1)
	end
end