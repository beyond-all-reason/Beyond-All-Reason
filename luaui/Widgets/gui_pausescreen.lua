function widget:GetInfo()
	return {
		name = "Pause Screen",
		desc = "Darkens and slightly desaturate the screen when paused",
		author = "Floris",
		date = "sept 2016",
		license = "GNU GPL v2",
		layer = 99999999,
		enabled = true
	}
end


local maxAlpha = 0.65
local maxShaderAlpha = 0.3
local maxNonShaderAlpha = 0.12            --background alpha when shaders arent availible
local boxWidth = 200
local boxHeight = 35
local slideTime = 0.12
local autoFadeTime = 1



local spGetGameSpeed = Spring.GetGameSpeed
local spGetGameState = Spring.GetGameState
local spGetGameFrame = Spring.GetGameFrame

local glColor = gl.Color
local glTexture = gl.Texture
local glScale = gl.Scale
local glPopMatrix = gl.PopMatrix
local glPushMatrix = gl.PushMatrix
local glTranslate = gl.Translate
local glTexRect = gl.TexRect
local glRect = gl.Rect
local glUseShader = gl.UseShader
local glCopyToTexture = gl.CopyToTexture
local glUniform = gl.Uniform
local glGetUniformLocation = gl.GetUniformLocation

local osClock = os.clock

local vsx, vsy = Spring.GetViewGeometry()

local blurScreen = false    -- makes use of guishader api widget

local pauseTimestamp = -10 --start or end of pause
local lastPause = false
local widgetInitTime = osClock()
local previousDrawScreenClock = osClock()
local paused = false
local lastGameFrame = spGetGameFrame()
local lastGameFrameTime = os.clock() + 10

local shaderAlpha = 0
local screencopy, shaderProgram
local chobbyInterface, alphaLoc, showPauseScreen, nonShaderAlpha
local gameover = false
local noNewGameframes = false


--intensity formula based on http://alienryderflex.com/hsp.html
local fragmentShaderSource = {
	washed = [[
		uniform sampler2D screencopy;
		uniform float alpha;

		float getIntensity(vec4 color) {
		  vec3 intensityVector = color.rgb * vec3(0.66,0.66,0.66);
		  return length(intensityVector);
		}

		void main() {
		  vec2 texCoord = vec2(gl_TextureMatrix[0] * gl_TexCoord[0]);
		  vec4 origColor = texture2D(screencopy, texCoord);
		  float intensity = getIntensity(origColor);
		  intensity = intensity * 1.15;
		  float multi = intensity * 0.9;
		  if (intensity > 1) intensity = 1;
		  if (intensity < 0.5) {
				if (intensity < 0.2) {
				  gl_FragColor = vec4(multi*0.22, multi*0.22, multi*0.22, alpha);
				} else if (intensity < 0.35) {
				  gl_FragColor = vec4(multi*0.32, multi*0.32, multi*0.32, alpha);
				} else {
				  gl_FragColor = vec4(multi*0.55, multi*0.55, multi*0.55, alpha);
				}
		  } else {
				if (intensity < 0.75) {
					gl_FragColor = vec4(multi*0.7, multi*0.7, multi*0.7, alpha);
				} else {
				  gl_FragColor = vec4(multi*0.82, multi*0.82, multi*0.82, alpha);
				}
		  }
		}
	]],
}

function widget:GameOver()
	gameover = true
end

function widget:Update(dt)
	local now = osClock()
	local gameFrame = spGetGameFrame()
	previousDrawScreenClock = now

	local diffPauseTime = (now - pauseTimestamp)

	if (not paused and lastPause) or (paused and not lastPause) then
		--pause switch
		pauseTimestamp = osClock()
		if diffPauseTime <= slideTime then
			pauseTimestamp = pauseTimestamp - (slideTime - (diffPauseTime / slideTime) * slideTime)
		end
	end

	if paused and not lastPause then
		--new pause
		if widgetInitTime + 5 > now then
			-- so if you do /luaui reload when paused, it wont re-animate
			pauseTimestamp = now - (slideTime + autoFadeTime)
		end
	end

	lastPause = paused

	local _, gameSpeed, isPaused = spGetGameSpeed()
	if not gameover and gameSpeed == 0 then
		-- when host (admin) paused its just gamespeed 0
		paused = true
	else
		paused = false
	end

	if spGetGameState and select(3, spGetGameState()) then
		paused = true
	end

	-- admin pause / game freeze
	if not paused and gameFrame > 0 and not gameover then
		if lastGameFrame == gameFrame then
			if now - lastGameFrameTime > 1 then
				if not noNewGameframes then
					pauseTimestamp = now - (slideTime + autoFadeTime)
				end
				paused = true
				noNewGameframes = true
			else
				noNewGameframes = false
			end
		else
			lastGameFrame = gameFrame
			lastGameFrameTime = now
			paused = false
			noNewGameframes = false
		end
	end
end

function widget:Initialize()
	widget:ViewResize(vsx, vsy)

	local _, gameSpeed, isPaused = spGetGameSpeed()
	if gameSpeed == 0 then
		-- when host admin paused its just gamespeed 0
		paused = true
	end

	if gl.CreateShader then
		shaderProgram = gl.CreateShader(
			{
				fragment = fragmentShaderSource.washed,
				uniformInt = {
					screencopy = 0,
				},
			}
		)
		if shaderProgram then
			alphaLoc = glGetUniformLocation(shaderProgram, "alpha")
		end
	else
		Spring.Echo("<Screen Shader>: GLSL not supported.")
	end
end

function widget:Shutdown()
	if shaderProgram then
		gl.DeleteShader(shaderProgram)
	end
end

function widget:GamePaused(playerID, isGamePaused)
	paused = isGamePaused
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1, 19) == 'LobbyOverlayActive1')
	end
end

local function drawPause()
	local now = osClock()
	local diffPauseTime = (now - pauseTimestamp)

	local progress
	if paused then
		progress = (now - pauseTimestamp) / slideTime
	else
		progress = 1 - ((now - pauseTimestamp) / slideTime)
	end
	if progress > 1 then
		progress = 1
	end
	if progress < 0 then
		progress = 0
	end
	shaderAlpha = progress * maxShaderAlpha
	nonShaderAlpha = progress * maxNonShaderAlpha

	if not shaderProgram then
		glColor(0, 0, 0, nonShaderAlpha)
		glRect(0, 0, vsx, vsy)
	end
end

function widget:DrawScreen()
	if chobbyInterface then
		return
	end
	if Spring.IsGUIHidden() then
		return
	end

	local now = osClock()

	if paused or (now - pauseTimestamp) <= slideTime then
		showPauseScreen = true
		drawPause()
		if blurScreen and WG['guishader'] then
			WG['guishader'].InsertRect(0, 0, vsx, vsy, 'pausescreen')
		end
	else
		showPauseScreen = false
		if blurScreen and WG['guishader'] then
			WG['guishader'].RemoveRect('pausescreen')
		end
	end
end

function widget:ViewResize(viewSizeX, viewSizeY)
	vsx, vsy = viewSizeX, viewSizeY

	screencopy = gl.CreateTexture(vsx, vsy, {
		border = false,
		min_filter = GL.NEAREST,
		mag_filter = GL.NEAREST,
	})
end

function widget:DrawScreenEffects()
	if Spring.IsGUIHidden() then
		return
	end
	if shaderProgram and showPauseScreen then
		glCopyToTexture(screencopy, 0, 0, 0, 0, vsx, vsy)
		glTexture(0, screencopy)
		glUseShader(shaderProgram)
		glUniform(alphaLoc, shaderAlpha)
		glTexRect(0, vsy, vsx, 0)
		glTexture(0, false)
		glUseShader(0)
	end
end
