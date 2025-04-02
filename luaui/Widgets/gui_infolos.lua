
--------------------------------------------------------------------------------
local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Infolos API",
		version = 3,
		desc = "Draws the info texture needed for many shaders",
		author = "Beherith",
		date = "2022.12.12",
		license = "Lua code is GPL V2, GLSL is (c) Beherith",
		layer = -10000, -- lol this isnt even a number
		enabled = true
	}
end

local GL_RGBA32F_ARB = 0x8814
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- About:
	-- This API presents an easy -to-use smoothed LOS texture for other widgets to do their shading based on
	-- It exploits truncation of values during blending to provide prevradar and prevlos values too!
	-- The RED channel contains LOS level, where
		-- 0.2-1.0 is LOS level
		-- < 0.2 is _never_been_in_los!
	-- the GREEN channel contains AIRLOS level
		-- 0.2-1.0 is LOS level
		-- < 0.2 is _never_been_in_los!

	-- the BLUE channel contains RADAR coverage
		-- < 0.2 = never been in radar
		-- fragColor.b = 0.2 + 0.8 * clamp(0.75 * radarJammer.r - 0.5 * (radarJammer.g - 0.5),0,1);
		-- >0.2 = radar coverage
		-- <0.5 = jammer
	-- It runs every gameFrame



-- TODO: 2022.12.12
	-- make it work?
	-- make api share?
	-- a clever thing might be to have 1 texture per allyteam?
	-- some bugginess with jammer range?

-- TODO 2022.12.20
	-- Read miplevels from modrules?

local autoreload = false
---- CONFIGURABLE PARAMETERS: -----------------------------------------

local shaderConfig = {
	SAMPLES = 4, -- quality setting
	RESOLUTION = 2, -- Number of times to downsample (fraction of heightmap rez!)
}
---------------------------------------------------------------------------

local alwaysColor, losColor, radarColor, jamColor, radarColor2 = Spring.GetLosViewColors() --unused
local outputAlpha = 0.07
local numFastUpdates = 10	 -- how many quick updates to do on large-scale changes
local updateRate = 2 -- on each Nth frame
local updateInfoLOSTexture = 0 -- how many updates to do on next draw
local delay = 1

local infoShader
local infoTextures = {} -- A table of allyteam/texture mappings
local currentAllyTeam = nil

local texX, texY
local luaShaderDir = "LuaUI/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")

local vsSrcPath = "LuaUI/Shaders/infolos.vert.glsl"
local fsSrcPath = "LuaUI/Shaders/infolos.frag.glsl"

local miplevels = {2^3, 2^4, 2^3, 1} -- los, airlos and radar mip levels

local shaderSourceCache = {
		vssrcpath = vsSrcPath,
		fssrcpath = fsSrcPath,
		uniformFloat = {
			outputAlpha = outputAlpha,
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

local function GetInfoLOSTexture(allyTeam)
	return infoTextures[allyTeam or currentAllyTeam]
end

local function CreateLosTexture()
	return gl.CreateTexture(texX, texY, {
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
		fbo = true,
		format = GL.RGBA8, -- more than enough
		})
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

local function UpdateInfoLOSTexture(count)
	gl.DepthMask(false) -- dont write to depth buffer
	gl.Culling(false) -- cause our tris are reversed in plane vbo
	infoShader:Activate()
	infoShader:SetUniformFloat("outputAlpha", outputAlpha)
	for i = 1, count do
		if i == count then
			infoShader:SetUniformFloat("time", (Spring.GetDrawFrame() + 0) / 1000)
		else
			infoShader:SetUniformFloat("time", (Spring.GetDrawFrame() + math.random()) / 1000)
		end
		gl.RenderToTexture(infoTextures[currentAllyTeam], renderToTextureFunc)
	end
	infoShader:Deactivate()
	gl.DepthMask(false) --"BK OpenGL state resets", reset to default state
end


function widget:PlayerChanged(playerID)
	local newAllyTeam = Spring.GetMyAllyTeamID()
	if currentAllyTeam ~= newAllyTeam then -- do a few quick renders
		currentAllyTeam = newAllyTeam
		updateInfoLOSTexture = numFastUpdates
		delay = 5
	end
	if updateInfoLOSTexture > 0 and autoreload  then
		Spring.Echo("Fast Updating infolos texture for", currentAllyTeam, updateInfoLOSTexture, "times")
	end
end

function widget:Initialize()
	if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end
	--local alwaysColor, losColor, radarColor, jamColor, radarColor2 = Spring.GetLosViewColors()
	texX = (Game.mapSizeX/8)/shaderConfig.RESOLUTION
	texY = (Game.mapSizeZ/8)/shaderConfig.RESOLUTION

	for name, tex in pairs({LOS = "$info:los", AIRLOS = "$info:airlos", RADAR = "$info:radar" }) do
		local texInfo = gl.TextureInfo(tex)
		shaderConfig[name .. 'XSIZE'] = texInfo.xsize
		shaderConfig[name .. 'YSIZE'] = texInfo.ysize
	end
	currentAllyTeam = Spring.GetMyAllyTeamID()

	for _, a in ipairs(Spring.GetAllyTeamList()) do
		infoTextures[a] = CreateLosTexture()
	end


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

function widget:GameFrame(n)
	if (n % updateRate) == 0 then
		updateInfoLOSTexture = math.max(1,updateInfoLOSTexture)
	end
end

function widget:Update()
end

--local lastUpdate = Spring.GetTimer()

function widget:DrawWorldPreUnit()
	-- local nowtime = Spring.GetTimer()
	-- local deltat = Spring.DiffTimers(nowtime, lastUpdate)
	-- keeping outputAlpha identical is a very important trick for never-before-seen areas!
	-- outputAlpha = math.clamp(deltat, 0.07, 1)
	-- Spring.Echo(deltat,outputAlpha)


	if updateInfoLOSTexture > 0 then
		if delay > 0 then
			delay = delay -1
		else
			UpdateInfoLOSTexture(updateInfoLOSTexture)
			updateInfoLOSTexture = 0
			delay = 0
		end
	end
end

function widget:DrawScreen() -- the debug display output
	if autoreload then
		infoShader = LuaShader.CheckShaderUpdates(shaderSourceCache) or infoShader
		gl.Color(1,1,1,1) -- use this to show individual channels of the texture!
		gl.Texture(0, infoTextures[currentAllyTeam])
		gl.Blending(GL.ONE, GL.ZERO)
		gl.TexRect(0, 0, texX, texY, 0, 1, 1, 0)

		gl.Text(tostring(currentAllyTeam), texX, texY,16)
		gl.Texture(0,"$info:los")
		gl.TexRect(texX, 0, texX + shaderConfig['LOSXSIZE'], shaderConfig['LOSYSIZE'], 0, 1, 1, 0)
		gl.Texture(0,false)
	end
end
