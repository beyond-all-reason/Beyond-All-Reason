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
		layer = -10000, -- lol this isn't even a number
		enabled = true,
	}
end

-- Localized functions for performance
local mathMax = math.max

-- Localized Spring API for performance
local spEcho = Spring.Echo
local spGetGameFrame = Spring.GetGameFrame
local spGetLocalAllyTeamID = Spring.GetLocalAllyTeamID

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
-- It runs every 2nd gameFrame, starting with the first GetInfoLOSTexture call: until a widget asks for a texture
-- nothing is drawn or allocated. Ask in Initialize, so the texture is filled before your first draw.

-- TODO: 2022.12.12
-- [x] make it work?
-- [x] make api share?
-- [x] a clever thing might be to have 1 texture per allyteam?
-- some bugginess with jammer range?

-- TODO 2022.12.20
-- Read miplevels from modrules?

-- TODO 2024.11.19
-- [x] Make the shader have exact visibility per 8 elmo square (hmap - 1)
-- [ ] Make the shader update at updaterate for true smoothness.
-- [ ] When does the LOS texture actually get updated though?
-- [ ] Would need to double-buffer the texture, and perform a swap every (15) gameframes
-- [ ] API must then expose the new and the old texture, and the progress factor between them.
-- [ ] The default 30hz smootheness is far from enough
-- [ ] The delayed approach is fucking stupid.
-- [ ] The mip level should be the 'smallest' mip level possible, and save a fused texture
-- [ ] Note that we must retain the 'never been seen'/ 'never been in radar' functionality

local autoreload = false

local shaderConfig = {
	SAMPLES = 4, -- quality setting
	TEXX = (Game.mapSizeX / 8),
	TEXY = (Game.mapSizeZ / 8),
	RESOLUTION = 2,
	EXACT = 1, -- 1 = exact visibility per 8 elmo square (hmap - 1)
}
---------------------------------------------------------------------------

local outputAlpha = 0.07
local numFastUpdates = 10 -- how many quick updates to do on large-scale changes
local updateRate = 2 -- on each Nth frame
local updateInfoLOSTexture = 0 -- how many updates to do on next draw
local delay = 1

local infoShader
local infoTextures = {} -- A table of allyteam/texture mappings, created on first use (false if that failed)
local newTextures = {} -- allyteams whose texture gets cleared before its first update
local isAllyTeam = {}
local currentAllyTeam = nil
local updating = false -- GameFrame and DrawGenesis are only registered from the first texture request on

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable

local fullScreenQuadVAO = nil

local vsSrcPath = "LuaUI/Shaders/infolos.vert.glsl"
local fsSrcPath = "LuaUI/Shaders/infolos.frag.glsl"

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
	shaderConfig = shaderConfig,
}

local function CreateLosTexture(allyTeam)
	local texture = gl.CreateTexture(shaderConfig.TEXX, shaderConfig.TEXY, {
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
		fbo = true,
		format = GL.RGBA8, -- more than enough
	}) or false
	infoTextures[allyTeam] = texture
	newTextures[allyTeam] = texture and true or nil
	return texture
end

local function StartUpdates()
	updating = true
	if spGetGameFrame() > 0 then -- first asked mid-game: catch up like after an allyteam change
		updateInfoLOSTexture = numFastUpdates
		delay = 0
	end
	widgetHandler:UpdateCallIn("GameFrame")
	widgetHandler:UpdateCallIn("DrawGenesis")
end

local function GetInfoLOSTexture(allyTeam)
	if not updating then
		if not infoShader then -- shut down
			return nil
		end
		StartUpdates()
	end
	allyTeam = allyTeam or currentAllyTeam
	local texture = infoTextures[allyTeam]
	if texture == nil and isAllyTeam[allyTeam] then
		texture = CreateLosTexture(allyTeam)
	end
	return texture
end

local function drawPasses(count, clear)
	if clear then
		gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
	end
	for i = 1, count do
		if shaderConfig.EXACT == 0 then -- only the sampled path reads time
			infoShader:SetUniformFloat("time", (Spring.GetDrawFrame() + (i == count and 0 or math.random())) / 1000)
		end
		fullScreenQuadVAO:DrawArrays(GL.TRIANGLES)
	end
end

local function UpdateInfoLOSTexture(count)
	local texture = infoTextures[currentAllyTeam]
	if texture == nil then
		texture = CreateLosTexture(currentAllyTeam)
	end
	if not texture then
		return
	end
	local clear = newTextures[currentAllyTeam]
	newTextures[currentAllyTeam] = nil

	gl.DepthMask(false) -- dont write to depth buffer
	gl.Culling(false) -- cause our tris are reversed in plane vbo
	gl.Texture(0, "$info:los")
	gl.Texture(1, "$info:airlos")
	gl.Texture(2, "$info:radar")
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	infoShader:Activate()
	-- all passes in one target bind, each one blends onto the one before
	gl.RenderToTexture(texture, drawPasses, count, clear)
	infoShader:Deactivate()
	gl.Texture(0, false)
	gl.Texture(1, false)
	gl.Texture(2, false)
end

function widget:PlayerChanged(playerID)
	local newAllyTeam = spGetLocalAllyTeamID()
	if currentAllyTeam ~= newAllyTeam then -- do a few quick renders
		currentAllyTeam = newAllyTeam
		updateInfoLOSTexture = numFastUpdates
		delay = 5
	end
	if updateInfoLOSTexture > 0 and autoreload then
		spEcho("Fast Updating infolos texture for", currentAllyTeam, updateInfoLOSTexture, "times")
	end
end

function widget:Initialize()
	if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end

	for name, tex in pairs({ LOS = "$info:los", AIRLOS = "$info:airlos", RADAR = "$info:radar" }) do
		local texInfo = gl.TextureInfo(tex)
		shaderConfig[name .. "XSIZE"] = texInfo.xsize
		shaderConfig[name .. "YSIZE"] = texInfo.ysize
	end
	currentAllyTeam = spGetLocalAllyTeamID()

	for _, allyTeam in ipairs(Spring.GetAllyTeamList()) do
		isAllyTeam[allyTeam] = true
	end

	infoShader = LuaShader.CheckShaderUpdates(shaderSourceCache) -- this compiles it
	if not infoShader then
		spEcho("Failed to compile InfoLOS GL4")
		widgetHandler:RemoveWidget()
		return
	end

	fullScreenQuadVAO = InstanceVBOTable.MakeTexRectVAO() --  -1, -1, 1, 0,   0,0,1, 0.5

	-- idle until the first texture request
	widgetHandler:RemoveCallIn("GameFrame")
	widgetHandler:RemoveCallIn("DrawGenesis")

	WG.infolosapi = {}
	WG.infolosapi.GetInfoLOSTexture = GetInfoLOSTexture
	widgetHandler:RegisterGlobal("GetInfoLOSTexture", WG.infolosapi.GetInfoLOSTexture)
end

function widget:Shutdown()
	for _, tex in pairs(infoTextures) do
		if tex then
			gl.DeleteTexture(tex)
		end
	end
	infoTextures = {}
	newTextures = {}
	isAllyTeam = {}
	if infoShader then
		infoShader:Finalize()
		infoShader = nil
	end
	WG.infolosapi = nil
	widgetHandler:DeregisterGlobal("GetInfoLOSTexture")
end

function widget:GameFrame(n)
	if (n % updateRate) == 0 then
		updateInfoLOSTexture = mathMax(1, updateInfoLOSTexture)
	end
end

function widget:DrawGenesis()
	-- keeping outputAlpha identical is a very important trick for never-before-seen areas!
	if updateInfoLOSTexture > 0 then
		if delay > 0 then
			delay = delay - 1
		else
			UpdateInfoLOSTexture(updateInfoLOSTexture)
			updateInfoLOSTexture = 0
		end
	end
end

if autoreload then
	function widget:DrawScreen() -- the debug display output
		infoShader = LuaShader.CheckShaderUpdates(shaderSourceCache) or infoShader
		local texture = infoTextures[currentAllyTeam]
		if not texture then
			return
		end
		gl.Color(1, 1, 1, 1) -- use this to show individual channels of the texture!
		gl.Texture(0, texture)
		gl.Blending(GL.ONE, GL.ZERO)
		gl.Culling(false)
		gl.TexRect(0, 0, shaderConfig.TEXX, shaderConfig.TEXY, 0, 0, 1, 1) -- REMEMBER THAT THIS UPSIDE DOWN!

		gl.Text(tostring(currentAllyTeam), shaderConfig.TEXX, shaderConfig.TEXY, 16)
		gl.Texture(0, false)

		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		if infoShader.DrawPrintf then
			infoShader.DrawPrintf()
		end
	end
end
