local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Pause Screen",
		desc = "Displays an overlay when the game is paused",
		author = "Floris",
		date = "sept 2016",
		license = "GNU GPL, v2 or later",
		version = "1.35",
		layer = 999999,
		enabled = true,
		modalExempt = true, -- some windows pause the game, so this has to stay visible
	}
end

-- Overlay look options; all off gives the default look
-- weigh red/green/blue by perceived brightness (HSP) instead of equally; greys stay the same
local USE_PERCEIVED_LUMA = true ---@type boolean
-- smooth tone curve through the 5 grey levels instead of hard steps (no contour lines)
local SMOOTH_TONE = false ---@type boolean
-- 0 = off, 1 = overlay ~1.8x stronger and darker towards the corners
local VIGNETTE = 1 ---@type number
-- multiplies the grey layer, e.g. { 0.90, 0.97, 1.10 } for a cool look
local TINT = { 1, 1, 1 } ---@type number[]

-- Localized Spring API for performance
local spGetViewGeometry = Spring.GetViewGeometry
local spGetGameSpeed = Spring.GetGameSpeed
local spGetGameFrame = Spring.GetGameFrame
local spGetGameRulesParam = Spring.GetGameRulesParam
local spIsGUIHidden = Spring.IsGUIHidden

local glColor = gl.Color
local glTexture = gl.Texture
local glPopMatrix = gl.PopMatrix
local glPushMatrix = gl.PushMatrix
local glTranslate = gl.Translate
local glTexRect = gl.TexRect
local glRect = gl.Rect
local glUseShader = gl.UseShader
local glUniform = gl.Uniform
local glCallList = gl.CallList

local osClock = os.clock

----------------------------------------------------------------------------------

-- CONFIGURATION

local fontfile = "fonts/unlisted/Xolonium.otf"
local fontfileSize = 35
local fontfileOutlineSize = 6
local fontfileOutlineStrength = 1.3

local sizeMultiplier = 1
local maxShaderAlpha = 0.25
local maxNonShaderAlpha = 0.12 --background alpha when shaders aren't available
local boxWidth = 200
local boxHeight = 35
local slideTime = 0.12
local fadeToTextAlpha = 0.33
local fontSizeHeadline = 30
local autoFadeTime = 1
local pollInterval = 0.1 -- seconds between pause/freeze checks while nothing is shown

local vsx, vsy = spGetViewGeometry()
local font ---@type LuaFont?
local fontfileScale = 0.0
local usedSizeMultiplier = 1.0
local textX, textY, slideDistance = 0.0, 0.0, 0.0
local textList ---@type integer?
local cachedPauseText

local pauseTimestamp = -10.0 --start or end of pause
local paused = false
local visible = false -- paused, or still sliding out
local slideX = 0.0
local shaderAlpha = 0.0
local nonShaderAlpha = 0.0
local widgetInitTime = osClock()
local lastGameFrame = spGetGameFrame()
local lastGameFrameTime = osClock() + 10
local pollTimer = 0.0
local gameover = false

local shaderProgram ---@type integer?
local alphaLoc, uniformAlpha
local effectsCallIn = true -- DrawScreenEffects is registered (only while the overlay shows)

local textColor = { 1.0, 1.0, 1.0, fadeToTextAlpha }
local outlineColor = { 0.0, 0.0, 0.0, fadeToTextAlpha / 2.25 }

--intensity formula based on http://alienryderflex.com/hsp.html
local fragmentShaderSource = [[
	#version 150 compatibility
	//__DEFINES__
	uniform sampler2D screencopy;
	uniform float alpha;

	void main() {
		vec2 uv = gl_TexCoord[0].st;
		vec3 origColor = texture2D(screencopy, uv).rgb;
	#ifdef PERCEIVED_LUMA
		// scaled so a grey gets the same intensity as the equal weights below
		float intensity = sqrt(dot(origColor * origColor, vec3(0.299, 0.587, 0.114))) * (0.66 * 1.15 * 1.7320508);
	#else
		float intensity = length(origColor * vec3(0.66)) * 1.15;
	#endif
	#ifdef SMOOTH_TONE
		// linear between the band centres of the levels below
		float t = clamp(intensity, 0.1, 0.875);
		float level = t < 0.275 ? mix(0.22, 0.32, (t - 0.1) / 0.175)
			: (t < 0.425 ? mix(0.32, 0.55, (t - 0.275) / 0.15)
			: (t < 0.625 ? mix(0.55, 0.7, (t - 0.425) / 0.2) : mix(0.7, 0.82, (t - 0.625) / 0.25)));
	#else
		float level = intensity < 0.5
			? (intensity < 0.2 ? 0.22 : (intensity < 0.35 ? 0.32 : 0.55))
			: (intensity < 0.75 ? 0.7 : 0.82);
	#endif
		vec3 grey = vec3(intensity * 0.9 * level);
		float a = alpha;
	#ifdef VIGNETTE
		vec2 size = vec2(textureSize(screencopy, 0));
		vec2 d = (uv * 2.0 - 1.0) * vec2(size.x / size.y, 1.0);
		float v = smoothstep(0.3, 1.0, length(d) / length(vec2(size.x / size.y, 1.0))) * VIGNETTE;
		grey *= 1.0 - 0.35 * v;
		a = min(a * (1.0 + 0.8 * v), 1.0);
	#endif
	#ifdef TINT
		grey = min(grey * TINT, 1.0);
	#endif
		gl_FragColor = vec4(grey, a);
	}
]]

local function shaderDefines()
	local defines = {}
	if USE_PERCEIVED_LUMA then
		defines[#defines + 1] = "#define PERCEIVED_LUMA"
	end
	if SMOOTH_TONE then
		defines[#defines + 1] = "#define SMOOTH_TONE"
	end
	if VIGNETTE > 0 then
		defines[#defines + 1] = string.format("#define VIGNETTE %.4f", VIGNETTE)
	end
	if TINT[1] ~= 1 or TINT[2] ~= 1 or TINT[3] ~= 1 then
		defines[#defines + 1] = string.format("#define TINT vec3(%.4f, %.4f, %.4f)", TINT[1], TINT[2], TINT[3])
	end
	return table.concat(defines, "\n")
end

local function setEffectsCallIn(active)
	if active ~= effectsCallIn then
		effectsCallIn = active
		if active then
			widgetHandler:UpdateCallIn("DrawScreenEffects")
		else
			widgetHandler:RemoveCallIn("DrawScreenEffects")
		end
	end
end

local function clearTextList()
	if textList then
		gl.DeleteList(textList)
		textList = nil
	end
end

local function drawText(textFont)
	textFont:Begin()
	textFont:SetOutlineColor(outlineColor)
	textFont:SetTextColor(textColor)
	textFont:Print(cachedPauseText, textX, textY, fontSizeHeadline * usedSizeMultiplier, "O")
	textFont:End()
end

local function updateAnimation(now)
	local diffPauseTime = now - pauseTimestamp
	local progress = diffPauseTime / slideTime
	if not paused then
		progress = 1 - progress
	end
	if progress > 1 then
		progress = 1
	elseif progress < 0 then
		progress = 0
	end
	shaderAlpha = progress * maxShaderAlpha
	nonShaderAlpha = progress * maxNonShaderAlpha

	if diffPauseTime <= slideTime then
		-- sliding in from the right, or out to it
		slideX = slideDistance * (paused and (1 - diffPauseTime / slideTime) or (diffPauseTime / slideTime))
	else
		slideX = 0
		if not paused then
			visible = false
			setEffectsCallIn(false)
		end
	end
end

-- No overlay and no "paused" text for non-player pauses.
local function isGadgetPaused()
	return spGetGameRulesParam("gamePaused") == 1
end

local function setPaused(state, now)
	if state == paused then
		return
	end
	paused = state
	local diffPauseTime = now - pauseTimestamp
	if state and widgetInitTime + 5 > now then
		-- so if you do /luaui reload when paused, it won't re-animate
		pauseTimestamp = now - (slideTime + autoFadeTime)
	elseif diffPauseTime <= slideTime then
		-- turning around mid-slide
		pauseTimestamp = now - (slideTime - diffPauseTime)
	else
		pauseTimestamp = now
	end
	if state and not visible then
		visible = true
		setEffectsCallIn(shaderProgram ~= nil)
	end
	updateAnimation(now)
end

local function pollPauseState(now)
	local gameFrame = spGetGameFrame()
	if not visible and (gameFrame == 0 or gameover) then
		return
	end

	local _, gameSpeed, isPaused = spGetGameSpeed()
	-- when host (admin) paused its just gamespeed 0
	local state = isPaused or (not gameover and gameSpeed == 0)
	if state then
		-- a pause is not a freeze: the freeze timer starts once the game runs again
		if lastGameFrameTime < now then
			lastGameFrameTime = now
		end
	elseif gameFrame > 0 and not gameover then
		-- admin pause / game freeze: no new game frames for a second
		if gameFrame ~= lastGameFrame then
			lastGameFrame = gameFrame
			lastGameFrameTime = now
		elseif now - lastGameFrameTime > 1 then
			state = true
		end
	end
	setPaused(state and not isGadgetPaused(), now)
end

function widget:GameOver()
	gameover = true
end

function widget:GamePaused(playerID, isGamePaused)
	setPaused(isGamePaused and not isGadgetPaused(), osClock())
end

function widget:Update(dt)
	if not visible then
		pollTimer = pollTimer + dt
		if pollTimer < pollInterval then
			return
		end
	end
	pollTimer = 0

	local now = osClock()
	pollPauseState(now)
	if visible then
		updateAnimation(now)
	end
end

function widget:DrawScreen()
	if not visible then
		return
	end

	if not shaderProgram then
		glColor(0, 0, 0, nonShaderAlpha)
		glRect(0, 0, vsx, vsy)
	end

	--draw text
	if not gameover then
		local list = textList
		if not list then
			cachedPauseText = cachedPauseText or BAR.I18N("ui.pauseScreen.paused")
			list = gl.CreateList(drawText, font)
			textList = list
		end
		if slideX ~= 0 then
			glPushMatrix()
			glTranslate(slideX, 0, 0)
			glCallList(list)
			glPopMatrix()
		else
			glCallList(list)
		end
	end
end

function widget:DrawScreenEffects()
	if shaderAlpha <= 0 or not shaderProgram or not WG.screencopymanager or spIsGUIHidden() then
		return
	end
	local screencopy = WG.screencopymanager.GetScreenCopy()
	if screencopy then
		glTexture(0, screencopy)
		glUseShader(shaderProgram)
		if uniformAlpha ~= shaderAlpha then
			uniformAlpha = shaderAlpha
			glUniform(alphaLoc, shaderAlpha)
		end
		glTexRect(0, vsy, vsx, 0)
		glTexture(0, false)
		glUseShader(0)
		-- CAS runs after this and rewrites the screen from the shared copy, which has to include this overlay
		WG.screencopymanager.InvalidateScreenCopy()
	end
end

function widget:ViewResize()
	vsx, vsy = spGetViewGeometry()
	usedSizeMultiplier = (0.5 + ((vsx * vsy) / 5500000)) * sizeMultiplier

	local newFontfileScale = (0.5 + (vsx * vsy / 5700000))
	if fontfileScale ~= newFontfileScale then
		fontfileScale = newFontfileScale
		clearTextList()
		if font then
			gl.DeleteFont(font)
		end
		font = gl.LoadFont(
			fontfile,
			fontfileSize * fontfileScale,
			fontfileOutlineSize * fontfileScale,
			fontfileOutlineStrength
		)
	end

	-- the text box, scaled by usedSizeMultiplier around the screen centre
	local wndX1 = (vsx / 2) - boxWidth
	local wndY1 = (vsy / 2) + boxHeight
	local wndX2 = (vsx / 2) + boxWidth
	local wndY2 = (vsy / 2) - boxHeight
	textX = (vsx / 2) + (wndX1 + (wndX2 - wndX1) * 0.33 - (vsx / 2)) * usedSizeMultiplier
	textY = (vsy / 2) + (wndY2 + (wndY1 - wndY2) * 0.4 - (vsy / 2)) * usedSizeMultiplier
	slideDistance = vsx - wndX1
	clearTextList()
end

function widget:LanguageChanged()
	cachedPauseText = nil
	clearTextList()
end

function widget:FontsChanged()
	clearTextList()
end

function widget:Initialize()
	widget:ViewResize(vsx, vsy)

	if gl.CreateShader then
		shaderProgram = gl.CreateShader({
			fragment = fragmentShaderSource:gsub("//__DEFINES__", shaderDefines()),
			uniformInt = {
				screencopy = 0,
			},
		})
		if shaderProgram then
			alphaLoc = gl.GetUniformLocation(shaderProgram, "alpha")
		else
			Spring.Echo("Pause Screen: shader failed to compile: " .. tostring(gl.GetShaderLog()))
		end
	else
		Spring.Echo("<Screen Shader>: GLSL not supported.")
	end

	local _, gameSpeed, isPaused = spGetGameSpeed()
	-- when host admin paused its just gamespeed 0
	setPaused((gameSpeed == 0 or isPaused) and not isGadgetPaused(), osClock())
	setEffectsCallIn(visible and shaderProgram ~= nil)
end

function widget:Shutdown()
	clearTextList()
	if font then
		gl.DeleteFont(font)
	end
	if shaderProgram then
		gl.DeleteShader(shaderProgram)
	end
end
