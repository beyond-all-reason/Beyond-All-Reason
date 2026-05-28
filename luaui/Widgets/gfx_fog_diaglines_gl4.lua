local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name    = "Fog Diagonal Lines GL4",
		desc    = "Sharp screen-space diagonal lines over fog-of-war areas",
		author  = "ix",
		date    = "2026.04.29",
		license = "GPL V2",
		layer   = 0,
		enabled = true,
	}
end

local spEcho = Spring.Echo
local spGetMapDrawMode = Spring.GetMapDrawMode
local spGetGameFrame = Spring.GetGameFrame

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable

-- Tunables
local strength       = 0.30  -- 0 = lines off, 1 = full opacity
local lineFreq       = 42.0  -- elmos per line cycle (world-space; lines anchor to ground and grow with zoom)
local lineWidth      = 0.38  -- 0..1 fraction of cycle that is line; lower = thinner lines + bigger gaps
local lineSharpness  = 0.19  -- smoothstep half-width at the edge (smaller = sharper, auto-widened when zoomed out)
local scrollSpeed    = 0.008  -- cycles per second

-- Smoothing tunables (temporal blend toward live engine coverage)
local accumUpdateRate = 2     -- update accumulator every N gameframes
local accumBlendAlpha = 0.18  -- per-update fraction of new coverage; lower = smoother but laggier
local accumFastBlendCount = 6 -- how many fast updates to do at startup / on ally team change

local lineColor = { 0.0, 0.0, 0.0 }  -- black

local diagShader = nil
local accumShader = nil
local coverageTex = nil
local accumTexX, accumTexY = 0, 0
local pendingUpdates = 0
local needsClear = true
local fullScreenQuadVAO = nil

local mapMipScale = 64 -- approx LOS-mip cell size in elmos (8 * 2^losMipLevel with losMipLevel=3)

local diagShaderSourceCache = {
	vssrcpath = "LuaUI/Shaders/fog_diaglines.vert.glsl",
	fssrcpath = "LuaUI/Shaders/fog_diaglines.frag.glsl",
	uniformInt = {
		mapDepths   = 0,
		coverageTex = 1,
	},
	uniformFloat = {
		lineColor     = { 0, 0, 0, 0.7 },
		lineFreq      = lineFreq,
		lineWidth     = lineWidth,
		lineSharpness = lineSharpness,
		scrollSpeed   = scrollSpeed,
	},
	shaderName = "Fog Diagonal Lines GL4",
	shaderConfig = {},
}

local accumShaderSourceCache = {
	vssrcpath = "LuaUI/Shaders/fog_diaglines_accum.vert.glsl",
	fssrcpath = "LuaUI/Shaders/fog_diaglines_accum.frag.glsl",
	uniformInt = {
		losTex   = 0,
		radarTex = 1,
	},
	uniformFloat = {
		blendAlpha = accumBlendAlpha,
	},
	shaderName = "Fog Diagonal Lines Accumulator GL4",
	shaderConfig = {},
}

local function updateAccumulator(count)
	if not accumShader or not coverageTex then return end
	gl.DepthMask(false)
	gl.Culling(false)
	gl.DepthTest(false)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	accumShader:Activate()
	accumShader:SetUniformFloat("blendAlpha", accumBlendAlpha)
	for i = 1, count do
		gl.RenderToTexture(coverageTex, function()
			gl.Texture(0, "$info:los")
			gl.Texture(1, "$info:radar")
			fullScreenQuadVAO:DrawArrays(GL.TRIANGLES)
			gl.Texture(0, false)
			gl.Texture(1, false)
		end)
	end
	accumShader:Deactivate()
end

function widget:Initialize()
	if not gl.CreateShader then
		widgetHandler:RemoveWidget()
		return
	end

	diagShader = LuaShader.CheckShaderUpdates(diagShaderSourceCache)
	if not diagShader or not diagShader:Initialize() then
		spEcho("Fog Diagonal Lines GL4: failed to compile/initialize main shader")
		widgetHandler:RemoveWidget()
		return
	end

	accumShader = LuaShader.CheckShaderUpdates(accumShaderSourceCache)
	if not accumShader or not accumShader:Initialize() then
		spEcho("Fog Diagonal Lines GL4: failed to compile/initialize accumulator shader")
		widgetHandler:RemoveWidget()
		return
	end

	-- Accumulator runs at the LOS info-texture resolution. Match the engine's
	-- $info:los dimensions so each accumulator texel covers exactly one
	-- LOS-mip cell.
	local losTexInfo = gl.TextureInfo("$info:los")
	accumTexX = losTexInfo and losTexInfo.xsize or math.floor(Game.mapSizeX / mapMipScale)
	accumTexY = losTexInfo and losTexInfo.ysize or math.floor(Game.mapSizeZ / mapMipScale)

	coverageTex = gl.CreateTexture(accumTexX, accumTexY, {
		format    = GL.RGBA8,
		fbo       = true,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s    = GL.CLAMP_TO_EDGE,
		wrap_t    = GL.CLAMP_TO_EDGE,
	})
	if not coverageTex then
		spEcho("Fog Diagonal Lines GL4: failed to create coverage accumulator texture")
		widgetHandler:RemoveWidget()
		return
	end

	fullScreenQuadVAO = InstanceVBOTable.MakeTexRectVAO()

	-- Burst a few quick updates so the accumulator catches up to the current
	-- coverage state immediately rather than fading in over several seconds.
	pendingUpdates = accumFastBlendCount
	needsClear = true

	WG.fogdiaglines = {
		getStrength = function() return strength end,
		setStrength = function(value) strength = math.max(0, math.min(1, value or 0)) end,
	}
end

function widget:Shutdown()
	WG.fogdiaglines = nil
	if coverageTex then gl.DeleteTexture(coverageTex) end
	coverageTex = nil
	diagShader = nil
	accumShader = nil
	fullScreenQuadVAO = nil
end

function widget:PlayerChanged()
	-- New ally team or vision share change → catch up quickly.
	pendingUpdates = math.max(pendingUpdates, accumFastBlendCount)
end

function widget:GameFrame(n)
	if (n % accumUpdateRate) == 0 then
		pendingUpdates = math.max(pendingUpdates, 1)
	end
end

function widget:DrawGenesis()
	if not coverageTex or not accumShader or not fullScreenQuadVAO then return end
	if needsClear then
		gl.RenderToTexture(coverageTex, function()
			gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
		end)
		needsClear = false
	end
	if pendingUpdates > 0 then
		updateAccumulator(pendingUpdates)
		pendingUpdates = 0
	end
end

function widget:DrawWorldPreUnit()
	if not diagShader or not fullScreenQuadVAO or not coverageTex then return end
	if strength <= 0.001 or spGetMapDrawMode() ~= "los" then return end

	gl.Texture(0, "$map_gbuffer_zvaltex")
	gl.Texture(1, coverageTex)

	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	gl.Culling(false)
	gl.DepthTest(false)
	gl.DepthMask(false)

	diagShader:Activate()
	diagShader:SetUniformFloat("lineColor", lineColor[1], lineColor[2], lineColor[3], strength)
	diagShader:SetUniformFloat("lineFreq", lineFreq)
	diagShader:SetUniformFloat("lineWidth", lineWidth)
	diagShader:SetUniformFloat("lineSharpness", lineSharpness)
	diagShader:SetUniformFloat("scrollSpeed", scrollSpeed)
	fullScreenQuadVAO:DrawArrays(GL.TRIANGLES)
	diagShader:Deactivate()

	gl.DepthTest(true)
	for i = 0, 1 do gl.Texture(i, false) end
end

function widget:GetConfigData()
	return { strength = strength }
end

function widget:SetConfigData(data)
	if data.strength ~= nil then strength = data.strength end
end
