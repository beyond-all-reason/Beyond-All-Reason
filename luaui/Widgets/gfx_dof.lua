local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Depth of Field",
		version = 2.0,
		desc = "Blurs far away objects.",
		author = "aeonios, Shadowfury333 (with some code from Kleber Garcia)",
		date = "Feb. 2019",
		license = "GPL, MIT",
		layer = -100000, --To run after gfx_deferred_rendering.lua
		enabled = false,
	}
end

-- Localized Spring API for performance
local spEcho = Spring.Echo

local highQuality = true -- adds the near (foreground) blur
local autofocus = true
local mousefocus = not autofocus
local focusDepth = 300
local fStop = 2

local autofocusInFocusMultiplier = fStop / 2 -- Autofocus Minimum In-Focus region size
local autofocusPower = 6 -- Autofocus Power (lower = blurrier at range)
local autofocusFocalLength = 0.03 -- Autofocus Focal Length

-----------------------------------------------------------------
-- Engine Functions
-----------------------------------------------------------------

local spGetMouseState = Spring.GetMouseState

local glBlending = gl.Blending
local glCopyToTexture = gl.CopyToTexture
local glCreateFBO = gl.CreateFBO
local glCreateShader = gl.CreateShader
local glCreateTexture = gl.CreateTexture
local glDeleteFBO = gl.DeleteFBO
local glDeleteShader = gl.DeleteShader
local glDeleteTexture = gl.DeleteTexture
local glRawBindFBO = gl.RawBindFBO
local glTexture = gl.Texture
local glTexRect = gl.TexRect
local glUseShader = gl.UseShader
local glUniform = gl.Uniform
local glUniformInt = gl.UniformInt
local glUniformMatrix = gl.UniformMatrix
local glViewport = gl.Viewport

local GL_DEPTH_COMPONENT32 = 0x81A7

local GL_COLOR_ATTACHMENT0_EXT = 0x8CE0
local GL_COLOR_ATTACHMENT1_EXT = 0x8CE1
local GL_COLOR_ATTACHMENT2_EXT = 0x8CE2
local GL_COLOR_ATTACHMENT3_EXT = 0x8CE3

local GL_RGBA16F_ARB = 0x881A
local GL_RG8 = 0x822B

-----------------------------------------------------------------
-- Global Vars
-----------------------------------------------------------------

local maxBlurDistance = 10000 --Distance in Spring units above which autofocus blurring can't happen

-- the blur passes skip tiles of tileSize x tileSize half resolution texels where they cannot change the result
local tileSize = 16

local vsx, vsy, vpx, vpy = Spring.GetViewGeometry()
-- the blur passes run at half resolution; same truncation as gl.CreateTexture, so viewports match the targets
local blurTexSizeX, blurTexSizeY = math.floor(vsx / 2), math.floor(vsy / 2)
local tilesX, tilesY = math.ceil(blurTexSizeX / tileSize), math.ceil(blurTexSizeY / tileSize)

local screenTex, depthTex
local baseBlurTex -- colour and filter radius, read by the far and the near blur
local blurFlagTex -- per texel: far blur, near blur
local intermediateBlurTex0, intermediateBlurTex1, intermediateBlurTex2, intermediateBlurTex3
local finalBlurTex, finalNearBlurTex
local tileFlagTex, tileMaskTex
local baseBlurFBO, intermediateBlurFBO, intermediateNearBlurFBO, finalBlurFBO, finalNearBlurFBO
local tileFlagFBO, tileMaskFBO
local chobbyInterface = false

-- shader pass enums
local shaderPasses = {
	filterSize = 0,
	initialBlur = 1,
	finalBlur = 2,
	initialNearBlur = 3,
	finalNearBlur = 4,
	composition = 5,
	tileFlags = 6,
	tileMask = 7,
}

-- one program per pass, keyed like shaderPasses; compositionLQ skips the near blur
local shaders = {} ---@type table<string, integer>
local resolutionLocs = {} ---@type table<string, integer>
local filterLocs = {} ---@type table<string, integer> -- filter pass uniforms by name
local uniformsDirty = true

-----------------------------------------------------------------

local function CleanupTextures()
	glDeleteFBO(baseBlurFBO)
	glDeleteFBO(intermediateBlurFBO)
	glDeleteFBO(intermediateNearBlurFBO)
	glDeleteFBO(finalBlurFBO)
	glDeleteFBO(finalNearBlurFBO)
	glDeleteFBO(tileFlagFBO)
	glDeleteFBO(tileMaskFBO)
	glDeleteTexture(screenTex)
	glDeleteTexture(depthTex)
	glDeleteTexture(baseBlurTex)
	glDeleteTexture(blurFlagTex)
	glDeleteTexture(intermediateBlurTex0)
	glDeleteTexture(intermediateBlurTex1)
	glDeleteTexture(intermediateBlurTex2)
	glDeleteTexture(intermediateBlurTex3)
	glDeleteTexture(finalBlurTex)
	glDeleteTexture(finalNearBlurTex)
	glDeleteTexture(tileFlagTex)
	glDeleteTexture(tileMaskTex)
	baseBlurFBO, intermediateBlurFBO, intermediateNearBlurFBO, finalBlurFBO, finalNearBlurFBO = nil, nil, nil, nil, nil
	tileFlagFBO, tileMaskFBO = nil, nil
	screenTex, depthTex, baseBlurTex, finalBlurTex, finalNearBlurTex = nil, nil, nil, nil, nil
	intermediateBlurTex0, intermediateBlurTex1, intermediateBlurTex2, intermediateBlurTex3 = nil, nil, nil, nil
	blurFlagTex, tileFlagTex, tileMaskTex = nil, nil, nil
end

local function CreateBlurTexture(format)
	return glCreateTexture(blurTexSizeX, blurTexSizeY, {
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		format = format,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
	})
end

local function InitTextures()
	vsx, vsy, vpx, vpy = Spring.GetViewGeometry()
	blurTexSizeX, blurTexSizeY = math.floor(vsx / 2), math.floor(vsy / 2)
	tilesX, tilesY = math.ceil(blurTexSizeX / tileSize), math.ceil(blurTexSizeY / tileSize)
	uniformsDirty = true

	CleanupTextures()

	screenTex = glCreateTexture(vsx, vsy, {
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
	})

	depthTex = glCreateTexture(vsx, vsy, {
		border = false,
		format = GL_DEPTH_COMPONENT32,
		min_filter = GL.NEAREST,
		mag_filter = GL.NEAREST,
	})

	baseBlurTex = CreateBlurTexture(GL_RGBA16F_ARB)
	blurFlagTex = CreateBlurTexture(GL_RG8)
	intermediateBlurTex0 = CreateBlurTexture(GL_RGBA16F_ARB)
	intermediateBlurTex1 = CreateBlurTexture(GL_RGBA16F_ARB)
	intermediateBlurTex2 = CreateBlurTexture(GL_RGBA16F_ARB)
	finalBlurTex = CreateBlurTexture()

	baseBlurFBO = glCreateFBO({
		color0 = baseBlurTex,
		color1 = blurFlagTex,
		drawbuffers = { GL_COLOR_ATTACHMENT0_EXT, GL_COLOR_ATTACHMENT1_EXT },
	})
	intermediateBlurFBO = glCreateFBO({
		color0 = intermediateBlurTex0,
		color1 = intermediateBlurTex1,
		color2 = intermediateBlurTex2,
		drawbuffers = { GL_COLOR_ATTACHMENT0_EXT, GL_COLOR_ATTACHMENT1_EXT, GL_COLOR_ATTACHMENT2_EXT },
	})
	finalBlurFBO = glCreateFBO({
		color0 = finalBlurTex,
		drawbuffers = { GL_COLOR_ATTACHMENT0_EXT },
	})

	local tileTexParams = { min_filter = GL.NEAREST, mag_filter = GL.NEAREST }
	tileFlagTex = glCreateTexture(tilesX, tilesY, tileTexParams)
	tileMaskTex = glCreateTexture(tilesX, tilesY, tileTexParams)
	tileFlagFBO = glCreateFBO({ color0 = tileFlagTex, drawbuffers = { GL_COLOR_ATTACHMENT0_EXT } })
	tileMaskFBO = glCreateFBO({ color0 = tileMaskTex, drawbuffers = { GL_COLOR_ATTACHMENT0_EXT } })

	if highQuality then
		intermediateBlurTex3 = CreateBlurTexture(GL_RGBA16F_ARB)
		finalNearBlurTex = CreateBlurTexture()
		intermediateNearBlurFBO = glCreateFBO({
			color0 = intermediateBlurTex0,
			color1 = intermediateBlurTex1,
			color2 = intermediateBlurTex2,
			color3 = intermediateBlurTex3,
			drawbuffers = {
				GL_COLOR_ATTACHMENT0_EXT,
				GL_COLOR_ATTACHMENT1_EXT,
				GL_COLOR_ATTACHMENT2_EXT,
				GL_COLOR_ATTACHMENT3_EXT,
			},
		})
		finalNearBlurFBO = glCreateFBO({
			color0 = finalNearBlurTex,
			drawbuffers = { GL_COLOR_ATTACHMENT0_EXT },
		})
	end

	if
		not intermediateBlurTex0
		or not intermediateBlurTex1
		or not intermediateBlurTex2
		or not finalBlurTex
		or not baseBlurTex
		or not blurFlagTex
		or not screenTex
		or not depthTex
		or not baseBlurFBO
		or not intermediateBlurFBO
		or not finalBlurFBO
		or not tileFlagFBO
		or not tileMaskFBO
		or (
			highQuality
			and (
				not intermediateBlurTex3
				or not finalNearBlurTex
				or not intermediateNearBlurFBO
				or not finalNearBlurFBO
			)
		)
	then
		spEcho("Depth of Field: Failed to create textures!")
		widgetHandler:RemoveWidget()
		return
	end
end

function widget:ViewResize(x, y)
	InitTextures()
end

local function reset()
	for _, shader in pairs(shaders) do
		glDeleteShader(shader)
	end
	shaders = {}
	resolutionLocs = {}
	filterLocs = {}

	CleanupTextures()
end

local function CreatePassShader(pass, nearBlur, vertexSrc, fragmentSrc)
	return glCreateShader({
		defines = {
			"#version 150 compatibility\n",
			"#define DEPTH_CLIP01 " .. (Platform.glSupportClipSpaceControl and "1" or "0") .. "\n",

			"#define FILTER_SIZE_PASS " .. shaderPasses.filterSize .. "\n",
			"#define INITIAL_BLUR_PASS " .. shaderPasses.initialBlur .. "\n",
			"#define FINAL_BLUR_PASS " .. shaderPasses.finalBlur .. "\n",
			"#define INITIAL_NEAR_BLUR_PASS " .. shaderPasses.initialNearBlur .. "\n",
			"#define FINAL_NEAR_BLUR_PASS " .. shaderPasses.finalNearBlur .. "\n",
			"#define COMPOSITION_PASS " .. shaderPasses.composition .. "\n",
			"#define TILE_FLAG_PASS " .. shaderPasses.tileFlags .. "\n",
			"#define TILE_MASK_PASS " .. shaderPasses.tileMask .. "\n",
			"#define PASS " .. pass .. "\n",

			"#define BLUR_START_DIST " .. maxBlurDistance .. "\n",
			"#define TILE_SIZE " .. tileSize .. "\n",

			"#define HIGH_QUALITY " .. (nearBlur and "1" or "0") .. "\n",
		},
		vertex = vertexSrc,
		fragment = fragmentSrc,

		uniformInt = { origTex = 0, blurTex0 = 1, blurTex1 = 2, blurTex2 = 3, blurTex3 = 4, tileMask = 5 },
	})
end

local function init()
	reset()

	if glCreateShader == nil then
		spEcho("[Depth of Field::Initialize] removing widget, no shader support")
		widgetHandler:RemoveWidget()
		return false
	end

	local vertexSrc = VFS.LoadFile("LuaUI/Shaders/dof.vs", VFS.RAW_FIRST)
	local fragmentSrc = VFS.LoadFile("LuaUI/Shaders/dof.fs", VFS.RAW_FIRST)
	if not vertexSrc or not fragmentSrc then
		spEcho("Depth of Field: shader files not found")
		widgetHandler:RemoveWidget()
		return false
	end
	for name, pass in pairs(shaderPasses) do
		shaders[name] = CreatePassShader(pass, true, vertexSrc, fragmentSrc)
	end
	shaders.compositionLQ = CreatePassShader(shaderPasses.composition, false, vertexSrc, fragmentSrc)

	for name in pairs(shaderPasses) do
		if not shaders[name] then
			spEcho("Depth of Field: Failed to create shader!")
			spEcho(gl.GetShaderLog())
			widgetHandler:RemoveWidget()
			return false
		end
	end
	if not shaders.compositionLQ then
		spEcho("Depth of Field: Failed to create shader!")
		spEcho(gl.GetShaderLog())
		widgetHandler:RemoveWidget()
		return false
	end

	for name, shader in pairs(shaders) do
		resolutionLocs[name] = gl.GetUniformLocation(shader, "resolution")
	end
	for _, uniform in ipairs({
		"projectionMat",
		"autofocus",
		"autofocusFudgeFactor",
		"autofocusPower",
		"autofocusFocalLength",
		"mousefocus",
		"manualFocusDepth",
		"mouseDepthCoord",
		"fStop",
	}) do
		filterLocs[uniform] = gl.GetUniformLocation(shaders.filterSize, uniform)
	end

	InitTextures()
	return true
end

function widget:Initialize()
	if not init() then
		return
	end
	WG.dof = {}
	WG.dof.getFocusDepth = function()
		return focusDepth
	end
	WG.dof.setFocusDepth = function(value)
		focusDepth = value
		uniformsDirty = true
	end
	WG.dof.getFstop = function()
		return fStop
	end
	WG.dof.setFstop = function(value)
		fStop = value
		autofocusInFocusMultiplier = fStop / 2
		uniformsDirty = true
	end
	WG.dof.getHighQuality = function()
		return highQuality
	end
	WG.dof.setHighQuality = function(value)
		highQuality = value
		InitTextures()
	end
	WG.dof.getAutofocus = function()
		return autofocus
	end
	WG.dof.setAutofocus = function(value)
		autofocus = value
		mousefocus = not autofocus
		uniformsDirty = true
	end
end

function widget:Shutdown()
	reset()
	WG.dof = nil
end

-- uniforms that only change with the view size or the settings; needs a draw callin to bind the programs
local function UpdateUniforms()
	for name, shader in pairs(shaders) do
		glUseShader(shader)
		glUniform(resolutionLocs[name], vsx / 2, vsy / 2)
	end
	glUseShader(shaders.filterSize)
	glUniformInt(filterLocs.autofocus, autofocus and 1 or 0)
	glUniformInt(filterLocs.mousefocus, mousefocus and 1 or 0)
	glUniform(filterLocs.autofocusFudgeFactor, autofocusInFocusMultiplier)
	glUniform(filterLocs.autofocusPower, autofocusPower)
	glUniform(filterLocs.autofocusFocalLength, autofocusFocalLength)
	glUniform(filterLocs.manualFocusDepth, focusDepth / maxBlurDistance)
	glUniform(filterLocs.fStop, fStop)
	uniformsDirty = false
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == "LobbyOverlayActive" then
		chobbyInterface = (msg:sub(1, 19) == "LobbyOverlayActive1")
	end
end

function widget:DrawScreenEffects()
	if chobbyInterface then
		return
	end
	glBlending(false)
	glCopyToTexture(screenTex, 0, 0, vpx, vpy, vsx, vsy) -- the original screen image
	glCopyToTexture(depthTex, 0, 0, vpx, vpy, vsx, vsy) -- the original screen depth

	if uniformsDirty then
		UpdateUniforms()
	end

	-- the blur passes draw at half resolution: the TexRect(0, 0, vsx, vsy) ones in screen space,
	-- the final ones in clip space (their vertex shader skips the matrices)
	local prevFBO = glRawBindFBO(baseBlurFBO)
	glViewport(0, 0, blurTexSizeX, blurTexSizeY)

	-- focus (in the vertex shader) and per-pixel filter radius
	glUseShader(shaders.filterSize)
	glUniformMatrix(filterLocs.projectionMat, "projection")
	if mousefocus then
		local mx, my = spGetMouseState()
		glUniform(filterLocs.mouseDepthCoord, mx / vsx, my / vsy)
	end
	glTexture(0, screenTex)
	glTexture(1, depthTex)
	glTexRect(0, 0, vsx, vsy, false, true)

	-- per tile: whether it has far or near blur, then which blur passes can reach it
	glUseShader(shaders.tileFlags)
	glTexture(0, blurFlagTex)
	glRawBindFBO(tileFlagFBO)
	glViewport(0, 0, tilesX, tilesY)
	glTexRect(0, 0, vsx, vsy, false, true)

	glUseShader(shaders.tileMask)
	glTexture(0, tileFlagTex)
	glRawBindFBO(tileMaskFBO)
	glTexRect(0, 0, vsx, vsy, false, true)

	-- far blur: vertical pass into the R, G, B complex targets, then horizontal
	glUseShader(shaders.initialBlur)
	glTexture(0, baseBlurTex)
	glTexture(5, tileMaskTex)
	glRawBindFBO(intermediateBlurFBO)
	glViewport(0, 0, blurTexSizeX, blurTexSizeY)
	glTexRect(0, 0, vsx, vsy, false, true)

	glUseShader(shaders.finalBlur)
	glTexture(1, intermediateBlurTex0) --R
	glTexture(2, intermediateBlurTex1) --G
	glTexture(3, intermediateBlurTex2) --B
	glRawBindFBO(finalBlurFBO)
	glTexRect(-1 - 0.5 / vsx, 1 + 0.5 / vsy, 1 + 0.5 / vsx, -1 - 0.5 / vsy)

	if highQuality then
		-- near blur, same pair of passes plus an alpha target; its targets must not stay bound for reading
		glUseShader(shaders.initialNearBlur)
		glTexture(1, false)
		glTexture(2, false)
		glTexture(3, false)
		glRawBindFBO(intermediateNearBlurFBO)
		glTexRect(0, 0, vsx, vsy, false, true)

		glUseShader(shaders.finalNearBlur)
		glTexture(1, intermediateBlurTex0) --R
		glTexture(2, intermediateBlurTex1) --G
		glTexture(3, intermediateBlurTex2) --B
		glTexture(4, intermediateBlurTex3) --A
		glRawBindFBO(finalNearBlurFBO)
		glTexRect(-1 - 0.5 / vsx, 1 + 0.5 / vsy, 1 + 0.5 / vsx, -1 - 0.5 / vsy)
	end

	glRawBindFBO(nil, nil, prevFBO)
	glViewport(vpx, vpy, vsx, vsy)

	-- composition: in-focus pixels are discarded, the rest mixes the screen copy with the blurs
	glUseShader(highQuality and shaders.composition or shaders.compositionLQ)
	glTexture(0, screenTex)
	glTexture(1, finalBlurTex)
	glTexture(2, highQuality and finalNearBlurTex or false)
	glTexRect(0, 0, vsx, vsy, false, true)

	glUseShader(0)
	glTexture(0, false)
	glTexture(1, false)
	glTexture(2, false)
	glTexture(3, false)
	glTexture(4, false)
	glTexture(5, false)
	glBlending(true)
end

function widget:GetConfigData()
	return {
		highQuality = highQuality,
		autofocus = autofocus,
		focusDepth = focusDepth,
		fStop = fStop,
		autofocusInFocusMultiplier = autofocusInFocusMultiplier,
		autofocusPower = autofocusPower,
		autofocusFocalLength = autofocusFocalLength,
	}
end

function widget:SetConfigData(data)
	if data.highQuality ~= nil then
		highQuality = data.highQuality
		autofocus = data.autofocus
		mousefocus = not autofocus
		focusDepth = data.focusDepth
		fStop = data.fStop
		autofocusInFocusMultiplier = fStop / 2

		--if data.autofocusInFocusMultiplier then
		--	autofocusInFocusMultiplier = data.autofocusInFocusMultiplier
		--	autofocusPower = data.autofocusPower
		--	autofocusFocalLength = data.autofocusFocalLength
		--end
	end
end
