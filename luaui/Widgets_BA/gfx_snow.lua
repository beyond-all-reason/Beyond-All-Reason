
function widget:GetInfo()
  return {
    name      = "Snow",
    desc      = "Lets it automaticly snow on snow maps! - also togglable with /snow  (remembers per map)",
    author    = "Floris (original: trepan, Argh)",
    date      = "29 may 2015",
    license   = "GNU GPL, v2 or later",
    layer     = -24,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- /snow    -- toggles snow on current map (also remembers this)

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local minFps					= 22		-- stops snowing at
local maxFps					= 55		-- max particles at
local particleSteps				= 14		-- max steps in diminishing number of particles	(dont use too much steps, creates extra dlist for each step)
local particleMultiplier		= 0.005		-- amount of particles
local customParticleMultiplier  = 1
local windMultiplier			= 4.5
local maxWindSpeed				= 25		-- to keep it real
local gameFrameCountdown		= 120		-- on launch: wait this many frames before adjusting the average fps calc
local particleScaleMultiplier	= 1

-- pregame info message
local autoReduce = true
local fadetime = 13
local fadetimeThreshold = 30
local textStartOpacity = 0.6

local fpsDifference 			= (maxFps-minFps)/particleSteps		-- fps difference need before changing the dlist to one with fewer particles

local snowTexFolder = "LuaUI/Images/snow/"

local snowKeywords = {'snow','frozen','cold','winter','ice','icy','arctic','frost','melt','glacier','mosh_pit','blindside','northernmountains','amarante'}

local snowMaps = {}

-- disable for maps that have a keyword but are not snowmaps
snowMaps['sacrifice_v1'] = false

-- disable for maps already containing a snow widget
snowMaps['xenolithic_v4'] = false
snowMaps['thecoldplace'] = false


local particleTypes = {}
table.insert(particleTypes, {
		texture = 'snow1.dds',
		gravity = 50,
		scale = 5500
})
table.insert(particleTypes, {
		texture = 'snow2.dds',
		gravity = 44,
		scale = 5500
})
table.insert(particleTypes, {
		texture = 'snow3.dds',
		gravity = 58,
		scale = 5500
})
table.insert(particleTypes, {
		texture = 'snow4.dds',
		gravity = 62,
		scale = 6600
})
table.insert(particleTypes, {
		texture = 'snow5.dds',
		gravity = 47,
		scale = 6600
})
table.insert(particleTypes, {
		texture = 'snow6.dds',
		gravity = 54,
		scale = 6600
})

local avgFpsInit = false

local math_random = math.random
local math_randomseed = math.randomseed

local shader
local shaderTimeLoc
local shaderCamPosLoc
local shaderScaleLoc
local shaderSpeedLoc

local startTimer = Spring.GetTimer()
local diffTime = 0

local spGetFPS					= Spring.GetFPS
local averageFps				= 60
local spGetVisibleUnits			= Spring.GetVisibleUnits
local spGetVisibleFeatures		= Spring.GetVisibleFeatures

local firstPos = 0
local secondPos = 0
local thirdPos = 0
local camX,camY,camZ
local vsx, vsy					= gl.GetViewSizes()
local particleScale	= 1
local startTime = os.clock()

local offsetX = 0
local offsetZ = 0
local prevOsClock = os.clock()
local gameStarted = false

local enabled = false
local previousFps				= (maxFps + minFps) / 1.75
local particleStep				= math.floor(particleSteps / 1.33)
if particleStep < 1 then particleStep = 1 end
local currentMapname = Game.mapName:lower()
local particleLists = {}
local particleDensityMax = 0
local particleDensity = 0
local previousParticleAmount = particleDensity

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local spGetWind            = Spring.GetWind
local spGetGameFrame       = Spring.GetGameFrame

local glBeginEnd           = gl.BeginEnd
local glVertex             = gl.Vertex
local glColor              = gl.Color
local glBlending           = gl.Blending
local glTranslate          = gl.Translate
local glCallList           = gl.CallList
local glDepthTest          = gl.DepthTest
local glCreateList         = gl.CreateList
local glDeleteList         = gl.DeleteList
local glTexture            = gl.Texture
local glGetShaderLog       = gl.GetShaderLog
local glCreateShader       = gl.CreateShader
local glDeleteShader       = gl.DeleteShader
local glUseShader          = gl.UseShader
local glUniformMatrix      = gl.UniformMatrix
local glUniformInt         = gl.UniformInt
local glUniform            = gl.Uniform
local glGetUniformLocation = gl.GetUniformLocation
local glGetActiveUniforms  = gl.GetActiveUniforms
local glBeginEnd = gl.BeginEnd
local glPointSprite = gl.PointSprite
local glPointSize = gl.PointSize
local glPointParameter = gl.PointParameter
local glResetState = gl.ResetState
local GL_POINTS = GL.POINTS

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


local windDirX, _, windDirZ, _ = spGetWind()
local startOsClock = os.clock()


function widget:Shutdown()
	removeSnow()
end

function removeSnow()
	removeParticleLists()
	if shader ~= nil then
		glDeleteShader(shader)
	end
end

function removeParticleLists()
	if particleLists[1] ~= nil then
		for layer=1, 3 do
			for step=1, particleSteps do
				glDeleteList(particleLists[layer][step])
			end
		end
		particleLists = {}
	end
end

-- creating multiple lists per particleType so we can switch to less particles without causing lag
local function CreateParticleLists()
	removeParticleLists()
	particleDensityMax	= math.floor(((vsx * vsy) * (particleMultiplier*customParticleMultiplier)) / #particleTypes)
	particleDensity		= particleDensityMax * ((averageFps-minFps) / maxFps)
	for particleType, pt in pairs(particleTypes) do
		particleLists[particleType] = {}
		for step=1, particleSteps do
			--local density = (particleDensityMax/particleSteps) * step
			local particles = math.floor(((particleDensityMax/particleSteps) * step) / (((particleSteps+(particleSteps/2)) - step) / (particleSteps/2)))
			particleLists[particleType][step] = gl.CreateList(function()
				local tmpRand = math.random()
				math.randomseed(particleType)
				gl.BeginEnd(GL.POINTS, function()
				  for i = 1, particles do
					local x = math.random()
					local y = math.random()
					local z = math.random()
					local w = math.random()
					local w = 1
					gl.Vertex(x, y, z, w)
				  end
				end)
				math.random(1e9 * tmpRand)
			end)
		end
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


function init()
	
	-- abort if not enabled
	if enabled == false then return end
	
	if (glCreateShader == nil) then
		Spring.Echo("[Snow widget:Initialize] no shader support")
		widgetHandler:RemoveWidget()
		return
	end

	shader = glCreateShader({
		vertex = [[
			uniform float time;
			uniform float scale;
			uniform vec3 speed;
			uniform vec3 camPos;
			void main(void)
			{
				vec3 scalePos = vec3(gl_Vertex) * scale;

				gl_FrontColor = vec4(0.8,0.8,0.9,0.66 * cos(scalePos.y));

				vec3 pos = scalePos - mod(camPos, scale);
				pos.y -= time * 0.5 * (speed.x * (2.0 + gl_Vertex.w));

				pos.x += (sin(time*1.5)*3) + speed.y;
				pos.z += (cos(time*1.5)*3) + speed.z;

				if (pos.x >= 1) {
					pos.x -= 1;
				}
				if (pos.x < 0) {
					pos.x += 1;
				}
				if (pos.z >= 1) {
					pos.z -= 1;
				}
				if (pos.z < 0) {
					pos.z += 1;
				}
				pos = mod(pos, scale) - (scale * 0.5) + camPos;
				
				vec4 eyePos = gl_ModelViewMatrix * vec4(pos, 1.0);
						
				gl_PointSize = (1.0 + gl_Vertex.w) * 5000.0 / length(eyePos);

				gl_Position = gl_ProjectionMatrix * eyePos;
			}
		]],
		uniform = {
			time   = diffTime,
			scale  = 0,
			speed  = {0,0,0},
			camPos = {0,0,0},
		},
	})

	if (shader == nil) then
		Spring.Echo("[Snow widget:Initialize] particle shader compilation failed")
		Spring.Echo(glGetShaderLog())
		widgetHandler:RemoveWidget()
		return
	end
	
	shaderTimeLoc			= glGetUniformLocation(shader, 'time')
	shaderCamPosLoc			= glGetUniformLocation(shader, 'camPos')

	shaderScaleLoc			= glGetUniformLocation(shader, 'scale')
	shaderSpeedLoc			= glGetUniformLocation(shader, 'speed')
	
	if particleLists[1] == nil then
		CreateParticleLists()
	end
end


function getWindSpeed()
	windDirX, _, windDirZ, _ = spGetWind()
	
	-- cap windspeed while preserving direction
	if windDirX > maxWindSpeed and windDirX > windDirZ then
		windDirZ = (windDirZ / windDirX) * maxWindSpeed
		windDirX = maxWindSpeed
	elseif windDirZ > maxWindSpeed and windDirZ > windDirX then
		windDirX = (windDirX / windDirZ) * maxWindSpeed
		windDirZ = maxWindSpeed
	end
end

function widget:Initialize()

	WG['snow'] = {}
	WG['snow'].getSnowMap = function()
		if enabled or widgetDisabledSnow then
			return true
		else
			return false
		end
	end
	WG['snow'].setMultiplier = function(value)
		customParticleMultiplier = value
		CreateParticleLists()
	end
	WG['snow'].setAutoReduce = function(value)
		autoReduce = value
		if autoReduce == false then
			enabled = true
			particleStep = particleSteps
			widgetDisabledSnow = false
		else
			avgFpsInit = true
			averageFps = spGetFPS()
		end
	end
	WG['snow'].setSnowMap = function(value)
		snowMaps[currentMapname] = value
		enabled = value
		if value then
			init()
		else
			removeSnow()
		end
	end

	if spGetGameFrame() > 0 then
		gameStarted = true
	end
	
	drawinfolist = gl.CreateList( function()
		local text = "Snowing less when FPS gets lower \n"
		local text2 = "/snow to toggle snow... for this map \n".."disable 'Snow' widget... for all maps "
		local fontSize = 30
		--local textWidth = gl.GetTextWidth(text)*fontSize
		local textHeight = gl.GetTextHeight(text)*fontSize
		--gl.Text(text, -textWidth/2, -textHeight/2, fontSize, "")
		gl.Text(text, 0, textHeight/2, fontSize, "c")
		gl.Text(text2, 0, -textHeight/1.6, fontSize*0.8, "c")
	end)
	
	startOsClock = os.clock()
	-- check for keywords
	local keywordFound = false
	for _,keyword in pairs(snowKeywords) do
		if string.find(currentMapname, keyword) then
			enabled = true
			keywordFound = true
			break
		end
	end
	-- check for remembered snow state
	if snowMaps[currentMapname] ~= nil then
		if snowMaps[currentMapname] == true then
			enabled = true
		elseif snowMaps[currentMapname] == false then
			enabled = false
		end
	end
	-- save enabled snow state
	if enabled and keywordFound then
		snowMaps[currentMapname] = true
	end
	
	getWindSpeed()
	init()
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local widgetDisabledSnow = false
function widget:GameFrame(gameFrame)
	if gameFrame == 1 then
		gameStarted = true
		if drawinfolist ~= nil then
			gl.DeleteList(drawinfolist)
		end
	end

	if not enabled and not widgetDisabledSnow then return end
	
	if gameFrameCountdown <= 0 then
		if gameFrame%31==0 then
			getWindSpeed()
		end
		if gameFrame%44==0 then
			averageFps = ((averageFps * 19) + spGetFPS()) / 20
			if averageFps < 1 then averageFps = 1 end
			--Spring.Echo(particleStep.."  avg fps:  "..averageFps)
		end
		if gameFrame%88==0 and autoReduce then
			if averageFps >= previousFps+fpsDifference or averageFps <= previousFps-fpsDifference then
				local particleAmount = (averageFps-minFps) / (maxFps-minFps)
				if particleAmount > 1 then 
					particleAmount = 1 
				end
				if previousParticleAmount ~= particleAmount then
					previousParticleAmount = particleAmount
					previousFps = averageFps
					if particleAmount <= 1/particleSteps then 
						enabled = false
						widgetDisabledSnow = true
					else
						particleDensity = math.floor(particleDensityMax * particleAmount)
						if particleDensity > particleDensityMax then particleDensity = particleDensityMax end
						particleStep = math.floor(particleDensity / (particleDensityMax / particleSteps))
						if particleStep < 1 then particeStep = 1 end
						enabled = true
						widgetDisabledSnow = false
					end
				end
			end
		end
	else
		gameFrameCountdown = gameFrameCountdown - 1
	end
end

function widget:Shutdown()
	if drawinfolist ~= nil then
		gl.DeleteList(drawinfolist)
	end
end

function widget:DrawScreen()
	if not enabled or not autoReduce then return end

	if not gameStarted and snowMaps[currentMapname] ~= nil and snowMaps[currentMapname] then
		if not avgFpsInit then
			avgFpsInit = true
			averageFps = spGetFPS()
		end
		local now = os.clock()
		local opacityMultiplier = (((startTime+fadetimeThreshold) - now) / fadetime)
		if opacityMultiplier > 1 then opacityMultiplier = 1 end
		
		if opacityMultiplier > 0 then
			gl.PushMatrix()
			gl.Translate(vsx/2, vsy/1.5, 0)
			gl.Scale(widgetScale,widgetScale,0)
			gl.Color(1,1,1,textStartOpacity*opacityMultiplier)
			gl.CallList(drawinfolist)
			gl.PopMatrix()
		end
	end
end

local pausedTime = 0
local lastFrametime = Spring.GetTimer()
function widget:DrawWorld()
	if not enabled then return end

	local _, _, isPaused = Spring.GetGameSpeed()
	if isPaused then
		pausedTime = pausedTime + Spring.DiffTimers(Spring.GetTimer(), lastFrametime)
	end
	lastFrametime = Spring.GetTimer()
	if os.clock() - startOsClock > 0.5 then		-- delay to prevent no textures being shown
		if shader ~= nil and particleLists[#particleTypes] ~= nil and particleLists[#particleTypes][particleStep] ~= nil then
			glUseShader(shader)	
			camX,camY,camZ = Spring.GetCameraPosition()
			diffTime = Spring.DiffTimers(lastFrametime, startTimer) - pausedTime

			glUniform(shaderTimeLoc,diffTime * 1)
			glUniform(shaderCamPosLoc, camX, camY, camZ)
			
			glDepthTest(true)
			glBlending(GL.SRC_ALPHA, GL.ONE)
			
			gl.PointSprite(true, true)
			gl.PointSize(10.0)
			gl.PointParameter(0, 0, 0.001, 0, 1e9, 1)
			
			local osClock = os.clock()
			local timePassed = osClock - prevOsClock
			prevOsClock = osClock

			if not isPaused then
				offsetX = offsetX + ((windDirX * windMultiplier) * timePassed)
				offsetZ = offsetZ + ((windDirZ * windMultiplier) * timePassed)
			end
			
			for particleType, pt in pairs(particleTypes) do
				glTexture(snowTexFolder..pt.texture)
				glUniform(shaderScaleLoc, pt.scale*particleScale)
				glUniform(shaderSpeedLoc, pt.gravity, offsetX, offsetZ)
				glCallList(particleLists[particleType][particleStep])
				glTexture(false)
			end
			
			gl.PointParameter(1, 0, 0, 0, 1e9, 1)
			gl.PointSize(1.0)
			gl.PointSprite(false, false)
			glResetState()
			glUseShader(0)
		end
	end
end

function widget:ViewResize(newX,newY)
	vsx, vsy = newX, newY
	widgetScale = (0.55 + (vsx*vsy / 10000000))
	if particleLists[#particleTypes] ~= nil then
		CreateParticleLists()
		gameFrameCountdown = 80
		--particleScale = (0.60 + (vsx*vsy / 8000000)) * particleScaleMultiplier
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetConfigData(data)
    savedTable = {}
    savedTable.snowMaps	= snowMaps
    savedTable.averageFps = math.floor(averageFps)
    savedTable.particleStep = particleStep
    savedTable.gameframe = Spring.GetGameFrame()
	savedTable.customParticleMultiplier = customParticleMultiplier
	savedTable.autoReduce = autoReduce
    return savedTable
end

function widget:SetConfigData(data)
	if data.snowMaps ~= nil 	then  snowMaps = data.snowMaps end
	if data.customParticleMultiplier ~= nil 	then  customParticleMultiplier = data.customParticleMultiplier end
	if data.autoReduce ~= nil 	then  autoReduce = data.autoReduce end
	if data.gameframe ~= nil and data.gameframe > 0	then
		if data.averageFps ~= nil 	then  
			averageFps = data.averageFps
			avgFpsInit = true
		end
		if data.particleStep ~= nil and data.gameframe ~= nil and Spring.GetGameFrame() > 0 then  
			particleStep = data.particleStep
			if particleStep < 1 then particleStep = 1 end
			if particleStep > particleSteps then particleStep = particleSteps end
		end
	end
end

function widget:TextCommand(command)
    if (string.find(command, "snow") == 1  and  string.len(command) == 4) then
		if snowMaps[currentMapname] == nil or snowMaps[currentMapname] == false then
			snowMaps[currentMapname] = true
			enabled = true
			Spring.Echo("Snow widget: snow enabled for this map. (Snow wont show when average fps is below "..minFps..".)")
			init()
		else
			snowMaps[currentMapname] = false
			enabled = false
			Spring.Echo("Snow widget: snow disabled for this map.")
			removeSnow()
		end
	end
end
