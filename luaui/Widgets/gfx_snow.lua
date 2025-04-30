local widget = widget ---@type Widget

function widget:GetInfo()
  return {
    name      = "Snow",
    desc      = "Lets it automaticly snow on snow maps! - also togglable with /snow  (remembers per map)",
    author    = "Floris (original: trepan, Argh)",
    date      = "29 may 2015",
    license   = "GNU GPL, v2 or later",
    layer     = -24,
    enabled   = true
  }
end

--------------------------------------------------------------------------------
-- /snow    -- toggles snow on current map (also remembers this)
--------------------------------------------------------------------------------

-- local vsx,vsy = Spring.GetViewGeometry()

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

local fpsDifference = (maxFps-minFps)/particleSteps		-- fps difference need before changing the dlist to one with fewer particles

local snowTexture = "LuaUI/Images/snow.dds"

VFS.Include("luarules/configs/map_biomes.lua")
--[[
local snowKeywords = {'snow','frozen','cold','winter','ice','icy','arctic','frost','melt','glacier','mosh_pit','blindside','northernmountains','amarante','cervino','avalanche'}
local snowMaps = {}

-- disable for maps that have a keyword but are not snowmaps
snowMaps['sacrifice_v1'] = false

-- disable for maps already containing a snow widget
snowMaps['xenolithic_v4'] = false
snowMaps['thecoldplace'] = false
]]

local particleTypes = {}
table.insert(particleTypes, {
		gravity = 50,
		scale = 5500
})
table.insert(particleTypes, {
		gravity = 44,
		scale = 5500
})
table.insert(particleTypes, {
		gravity = 58,
		scale = 5500
})
table.insert(particleTypes, {
		gravity = 62,
		scale = 6600
})
table.insert(particleTypes, {
		gravity = 47,
		scale = 6600
})
table.insert(particleTypes, {
		gravity = 54,
		scale = 6600
})

local widgetDisabledSnow = false

local shader
local shaderTimeLoc
local shaderCamPosLoc
local shaderScaleLoc
local shaderSpeedLoc

local startTimer = Spring.GetTimer()
local diffTime = 0

local spGetFPS					= Spring.GetFPS
local averageFps				= 60

local camX,camY,camZ
local vsx, vsy					= gl.GetViewSizes()
local particleScale	= 1

local offsetX = 0
local offsetZ = 0
local prevOsClock = os.clock()

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

local glBlending           = gl.Blending
local glCallList           = gl.CallList
local glDepthTest          = gl.DepthTest
local glDeleteList         = gl.DeleteList
local glTexture            = gl.Texture
local glGetShaderLog       = gl.GetShaderLog
local glCreateShader       = gl.CreateShader
local glDeleteShader       = gl.DeleteShader
local glUseShader          = gl.UseShader
local glUniform            = gl.Uniform
local glGetUniformLocation = gl.GetUniformLocation
local glResetState = gl.ResetState

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local windDirX, _, windDirZ, _ = spGetWind()
local startOsClock = os.clock()

local function removeParticleLists()
	if particleLists[1] ~= nil then
		for layer=1, 3 do
			for step=1, particleSteps do
				glDeleteList(particleLists[layer][step])
			end
		end
		particleLists = {}
	end
end

local function removeSnow()
	removeParticleLists()
	if shader ~= nil then
		glDeleteShader(shader)
	end
end

function widget:Shutdown()
	removeSnow()
	WG['snow'] = nil
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


local function init()
	-- abort if not enabled
	if enabled == false then return end

	if (glCreateShader == nil) then
		Spring.Echo("[Snow widget:Initialize] no shader support")
		widgetHandler:RemoveWidget()
		return
	end

	shader = glCreateShader({
		vertex = [[
	  		#version 150 compatibility
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

local function getWindSpeed()
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
	widget:ViewResize()

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
		if enabled or widgetDisabledSnow  then
			CreateParticleLists()
		end
	end
	WG['snow'].setAutoReduce = function(value)
		autoReduce = value
		if autoReduce == false then
			enabled = true
			particleStep = particleSteps
			widgetDisabledSnow = false
		else
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

	startOsClock = os.clock()
	-- check for keywords
	local keywordFound = false
	for _,keyword in pairs(snowKeywords) do
		if string.find(currentMapname, keyword, nil, true) then
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

function widget:GameFrame(gameFrame)
	if not enabled and not widgetDisabledSnow then return end

	if gameFrameCountdown <= 0 then
		if gameFrame%31==0 then
			getWindSpeed()
		end
		if gameFrame%44==0 then
			averageFps = ((averageFps * 19) + spGetFPS()) / 20
			if averageFps < 1 then averageFps = 1 end
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
						if particleStep < 1 then particleStep = 1 end
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
	enabled = false
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

			glTexture(snowTexture)
			for particleType, pt in pairs(particleTypes) do
				glUniform(shaderScaleLoc, pt.scale*particleScale)
				glUniform(shaderSpeedLoc, pt.gravity, offsetX, offsetZ)
				glCallList(particleLists[particleType][particleStep])
			end
			glTexture(false)

			gl.PointParameter(1, 0, 0, 0, 1e9, 1)
			gl.PointSize(1.0)
			gl.PointSprite(false, false)
			glResetState()
			glUseShader(0)
		end
	end
end

function widget:ViewResize()
	vsx,vsy = Spring.GetViewGeometry()


	if particleLists[#particleTypes] ~= nil then
		CreateParticleLists()
		gameFrameCountdown = 80
		--particleScale = (0.60 + (vsx*vsy / 8000000)) * particleScaleMultiplier
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetConfigData(data)
    return {
		snowMaps = snowMaps,
		averageFps = math.floor(averageFps),
		articleStep = particleStep,
		gameframe = Spring.GetGameFrame(),
		customParticleMultiplier = customParticleMultiplier,
		autoReduce = autoReduce
	}
end

function widget:SetConfigData(data)
	if data.snowMaps ~= nil 	then  snowMaps = data.snowMaps end
	if data.customParticleMultiplier ~= nil 	then  customParticleMultiplier = data.customParticleMultiplier end
	if data.autoReduce ~= nil 	then  autoReduce = data.autoReduce end
	if data.gameframe ~= nil and data.gameframe > 0	then
		if data.averageFps ~= nil 	then
			averageFps = data.averageFps
		end
		if data.particleStep ~= nil and data.gameframe ~= nil and Spring.GetGameFrame() > 0 then
			particleStep = data.particleStep
			if particleStep < 1 then particleStep = 1 end
			if particleStep > particleSteps then particleStep = particleSteps end
		end
	end
end

function widget:TextCommand(command)
    if string.find(command, "snow", nil, true) == 1  and  string.len(command) == 4 then
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
