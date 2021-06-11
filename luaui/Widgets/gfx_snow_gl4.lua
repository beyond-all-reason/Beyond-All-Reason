function widget:GetInfo()
  return {
    name      = "Snow GL4",
    desc      = "Lets it automaticly snow on snow maps! - also togglable with /snow  (remembers per map)",
    author    = "Floris, Beherith GL4",
    date      = "2021.04.12",
    license   = "GNU GPL, v2 or later",
    layer     = -24,
    enabled   = true  --  loaded by default?
  }
end


-- TODO:

-- fix up for rain too? needs long ass vertical billboards for that
-- fix pause and pregame time calcs

-- configurable params:
-- particle count --done
-- particle texture --done
-- particle size --done
-- particle gravity factor --done
-- particle wind factor --done
-- instance count --done
-- fadeout with alpha -- done
-- 
--------------------------------------------------------------------------------
-- /snow    -- toggles snow on current map (also remembers this)
--------------------------------------------------------------------------------

-- TUNE THESE PARAMS: ----
local minFps					= 22		-- stops snowing at
local maxFps					= 55		-- max particles at
local particleSteps				= 14		-- max steps in diminishing number of particles	(dont use too much steps, creates extra dlist for each step)
local particleMultiplier		= 0.005		-- amount of particles
local customParticleMultiplier  = 1
local windMultiplier			= 4.5
local maxWindSpeed				= 25		-- to keep it real
local gameFrameCountdown		= 120		-- on launch: wait this many frames before adjusting the average fps calc
local particleSize	= 2
local particleSizeSpread	= 2 -- adds on top of particleSize
local gravityMultiplier = 1.0
local gravitySpread = 5 -- adds on top of Gravity Multiplier
local snowFlakesPerInstance = 5000
local maxInstances = 10
local snowTexture = "LuaUI/Images/snow.dds" -- would be superb if this was configurable mapside

-- pregame info message
local autoReduce = false

local fpsDifference = (maxFps-minFps)/particleSteps		-- fps difference need before changing the dlist to one with fewer particles

local snowKeywords = {'snow','frozen','cold','winter','ice','icy','arctic','frost','melt','glacier','mosh_pit','blindside','northernmountains','amarante','cervino','avalanche'}
local snowMaps = {}

-- GL4 things
local snowVBO = nil
local snowVBOSize = snowFlakesPerInstance -- we will create an ambitious 1000 flake vbo,
local snowInstanceVBO = nil
local snowInstanceVBOSize = maxInstances  -- And will modulate snowfall perf by the number of times we redraw the whole shebang
local snowVAO = nil
local snowShader = nil
local shaderCompiled = nil
local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")

local vsSrc = [[
#version 420 core

layout (location = 0) in vec4 snowCoords; // this comes from snowVBO, [x,y,z,0.5-1.5]
layout (location = 1) in vec4 snowParams; // This comes from the snowInstanceVBO
	// snowParams contains [scale, gravity, alphaoverride,nil] // note 2 self, larger particles of snow fall slower than small ones
#define SCALE snowParams.x
#define GRAVITY snowParams.y

uniform vec4 snowuniforms;// = vec4(0.0);
	// .x is snowtime, which is game start + gameSeconds
	// .y is offsetx
	// .z is offsetz
	// .w is
#define OFFSETX snowuniforms.y
#define OFFSETZ snowuniforms.z
#define SNOWTIME snowuniforms.x

layout(std140, binding = 0) uniform UniformMatrixBuffer {
	mat4 screenView;
	mat4 screenProj;
	mat4 screenViewProj;

	mat4 cameraView;
	mat4 cameraProj;
	mat4 cameraViewProj;
	mat4 cameraBillboardProj;

	mat4 cameraViewInv;
	mat4 cameraProjInv;
	mat4 cameraViewProjInv;
};

layout(std140, binding = 1) uniform UniformParamsBuffer {
	vec3 rndVec3; //new every draw frame.
	uint renderCaps; //various render booleans

	vec4 timeInfo; //gameFrame, gameSeconds, drawFrame, frameTimeOffset
	vec4 viewGeometry; //vsx, vsy, vpx, vpy
	vec4 mapSize; //xz, xzPO2

	vec4 fogColor; //fog color
	vec4 fogParams; //fog {start, end, 0.0, scale}
};

out DataVS {
	//vec4 cameraPos;
  float cameraDist;
  float instanceAlpha;
};

void main(void)
{
	vec3 scalePos = snowCoords.xyz *SCALE -2500 ;//* SCALE;
  
  vec4 cameraPos = cameraViewInv[3]; // this is the camera position in world coords

	vec3 pos = scalePos - mod(cameraPos.xyz, SCALE); // I think this tries put the camera and snow into the same world chunk

	pos.y -= SNOWTIME * 0.5 * (GRAVITY); // make snow fall down

	pos.x += sin(SNOWTIME * 1 + SCALE) * 8.0 + OFFSETX; // make snow spin and be blown by wind
	pos.z += cos(SNOWTIME * 1 + SCALE) * 8.0 + OFFSETZ;

	pos = mod(pos, SCALE) - (SCALE * 0.5) + cameraPos.xyz; // this centers the snowfield around the camera, instead of the terrain
  
  pos.y = mod(pos.y, SCALE); // makes snow at ground level go back up

  cameraDist = length(pos - cameraPos.xyz);
  
  float flakeSizeCamera = snowCoords.w * clamp(cameraDist*0.002,0.1, 1.0);  // if flake is very close to camera (e.g. cameradist <00) then clamp down flakesize
	gl_Position = vec4(pos, flakeSizeCamera);
	
  instanceAlpha = snowParams.z;
}

]]

-- billboarding info: https://www.geeks3d.com/20140815/particle-billboarding-with-the-geometry-shader-glsl/
local gsSrc = [[
#version 420 core

layout (points) in;
layout (triangle_strip, max_vertices = 4) out;

layout(std140, binding = 0) uniform UniformMatrixBuffer {
	mat4 screenView;
	mat4 screenProj;
	mat4 screenViewProj;

	mat4 cameraView;
	mat4 cameraProj;
	mat4 cameraViewProj;
	mat4 cameraBillboardProj;

	mat4 cameraViewInv;
	mat4 cameraProjInv;
	mat4 cameraViewProjInv;
};

in DataVS {
	//vec4 cameraPos;
  float cameraDist;
  
  float instanceAlpha;
} dataIn[];

out DataGS {
	vec2 texCoord;
  float instanceAlpha;
};

void main(){
	// TODO: randomly rotate them snowflakes :D
	// TODO: make them sized nicely random too
	// TODO: kill jester
  instanceAlpha = dataIn[0].instanceAlpha;
	vec3 snowPos = gl_in[0].gl_Position.xyz;

  vec4 cameraPos = cameraViewInv[3]; // stack overflow told me that this is the camera position in world coords

	vec3 toCamera = normalize(cameraPos.xyz - snowPos);

  vec3 right = vec3(cameraView[0][0], 
                    cameraView[1][0], 
                    cameraView[2][0]);

  vec3 up = vec3(cameraView[0][1], 
                 cameraView[1][1], 
                 cameraView[2][1]);

  mat4 VP = cameraViewProj;

	float flakesize = gl_in[0].gl_Position.w;

  vec3 va = snowPos - (right + up) * flakesize;
  gl_Position = VP * vec4(va, 1.0);
  texCoord = vec2(0.0, 0.0);
  EmitVertex();  
  
  vec3 vb = snowPos - (right - up) * flakesize;
  gl_Position = VP * vec4(vb, 1.0);
  texCoord = vec2(0.0, 1.0);
  EmitVertex();  

  vec3 vd = snowPos + (right - up) * flakesize;
  gl_Position = VP * vec4(vd, 1.0);
  texCoord = vec2(1.0, 0.0);
  EmitVertex();  

  vec3 vc = snowPos + (right + up) * flakesize;
  gl_Position = VP * vec4(vc, 1.0);
  texCoord = vec2(1.0, 1.0);
  EmitVertex();  
  
  EndPrimitive(); 
}

]]

local fsSrc = [[
#version 420 core

layout(binding = 0) uniform sampler2D colorTexture;
in DataGS {
	vec2 texCoord;
  float instanceAlpha;
};

out vec4 fragColor;
uniform vec4 snowuniforms;// = vec4(0.0);
void main(){
  fragColor = texture(colorTexture,  texCoord);
  fragColor.a = fragColor.a * instanceAlpha;
  //fragColor = vec4(0.0,0.0,0.0,1.0);
  //fragColor.rgb = vec3(0.0,0.0,0.0);
  if (fragColor.a < 0.005) fragColor = vec4(0.0); //avoid discard
}

]]

-- disable for maps that have a keyword but are not snowmaps
snowMaps['sacrifice_v1'] = false

-- disable for maps already containing a snow widget
snowMaps['xenolithic_v4'] = false
snowMaps['thecoldplace'] = false


local widgetDisabledSnow = false

local startTimer = Spring.GetTimer()
local diffTime = 0

local spGetFPS					= Spring.GetFPS
local averageFps				= 60

local offsetX = 0
local offsetZ = 0
local prevOsClock = os.clock()

local enabled = false
local previousFps				= (maxFps + minFps) / 1.75
local particleStep				= math.floor(particleSteps / 1.33)
if particleStep < 1 then particleStep = 1 end
local currentMapname = Game.mapName:lower()

local particleDensityMax = 0
local particleDensity = 0
local previousParticleAmount = particleDensity

----------------------------------------------------------------

local spGetWind            = Spring.GetWind
local glBlending           = gl.Blending
local glDepthTest          = gl.DepthTest
local glTexture            = gl.Texture

----------------------------------------------------------------

local windDirX, _, windDirZ, _ = spGetWind()
local startOsClock = os.clock()


local function removeSnow()
	if shader ~= nil then
		glDeleteShader(shader)
	end
end

function widget:Shutdown()
	removeSnow()
	WG['snow'] = nil
end

-- creating multiple lists per particleType so we can switch to less particles without causing lag

--------------------------------------------------------------------------------

local function init()
	-- abort if not enabled
	if enabled == false then return end

  snowVAO = gl.GetVAO()
  snowVBO = gl.GetVBO(GL.ARRAY_BUFFER,true)
  snowInstanceVBO = gl.GetVBO(GL.ARRAY_BUFFER,false)

  if snowVAO == nil  or snowVBO == nil or snowInstanceVBO == nil then
      Spring.Echo("LuaVAO not supported, disabling Snow GL4")
      widgetHandler:RemoveWidget(self)
  end

  snowVBO:Define(
      snowVBOSize, -- number of snowflake vertices being pushed
      {
        {id = 0, -- which attribute we should be attaching to, number consecutively from 0, max 15
        name = "pos", -- just a helper name
        size = 4, -- the number of floats in this array that constitute 1 element. So for an xyzw, its 4 floats
        },
      }
    )
  local snowVertices = {}
  math.randomseed(2)
  for i=1,snowVBOSize do
      snowVertices[#snowVertices+1] = math.random()
      snowVertices[#snowVertices+1] = math.random()
      snowVertices[#snowVertices+1] = math.random()
      snowVertices[#snowVertices+1] = particleSize + math.random() * particleSizeSpread
  end
  snowVBO:Upload(snowVertices)

  snowInstanceVBO:Define(
    snowInstanceVBOSize,
    {{
        id = 1,
        name = 'instances',
        size = 4, --number of floats per instance, 4 in this case for a vec4 of [scale, gravity, unused, unused]
        }
    }
  )

  local snowInstances = {}
  local mapgravity = Game.gravity
  for i=1, snowInstanceVBOSize do
    snowInstances[#snowInstances+1] = 5000 + math.random()*2000 --SCALE
    snowInstances[#snowInstances+1] = mapgravity *gravityMultiplier + math.random() * gravitySpread --GRAVITY
    snowInstances[#snowInstances+1] = math.random() -- alpha of this instance, TODO control this as snow instances fade in and out due to load!
    snowInstances[#snowInstances+1] = 0.0 -- unused
  end

  snowInstanceVBO:Upload(snowInstances)

  snowVAO:AttachVertexBuffer(snowVBO)
  snowVAO:AttachInstanceBuffer(snowInstanceVBO)

  snowShader = LuaShader(
    {
      vertex = vsSrc,
      fragment = fsSrc,
      geometry = gsSrc,
      uniformInt = {colorTexture = 0},
      uniformFloat = {
        snowuniforms = {1,1,1,1},
      },
    }
  )
  shaderCompiled = snowShader:Initialize()
  if not shaderCompiled then
    Spring.Echo("Failed to compile Snow GL4 Shader")
    widgetHandler:RemoveWidget(self)
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
  if snowShader and shaderCompiled then snowShader:Finalize() end
  if snowVAO then snowVAO = nil end
  if snowVBO then snowVBO = nil end
  if snowInstanceVBO then snowInstanceVBO = nil end
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

		if true then --obviously enabled :D

      local osClock = os.clock()
			local timePassed = osClock - prevOsClock
			prevOsClock = osClock

			if not isPaused then
				offsetX = offsetX + ((windDirX * windMultiplier) * timePassed)
				offsetZ = offsetZ + ((windDirZ * windMultiplier) * timePassed)
			end

      glDepthTest(GL.LEQUAL)
      glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA) -- this allows blending darker colored snowflake types, not just lighter, e.g ash, volcanic snow, meterorites
      
      glTexture(0, snowTexture)
      snowShader:Activate()

      snowShader:SetUniform("snowuniforms", os.clock() - startOsClock, offsetX, offsetZ, 0.0)
      --Spring.Echo("Drawing Snow")
      snowVAO:DrawArrays(
        GL.POINTS, -- yep points indeed, then geom shader will do the rest
        snowVBOSize, -- the number of elements (vec4s in this case) we wish to dray, in this case, since its 4 floats per vertex, 1 vert per snowlflake this is 1.
        0, -- offset into the array
        snowInstanceVBOSize) -- instance count, TODO: make this the particle instance count! :D

      snowShader:Deactivate()
      gl.Blending(GL.SRC_ALPHA, GL.ONE)
      glTexture(0,false)
      glDepthTest(GL.ALWAYS)
		end
	end
end

function widget:ViewResize()
  gameFrameCountdown = 80
end

--------------------------------------------------------------------------------

function widget:GetConfigData(data)
    return {
		snowMaps = snowMaps,
		averageFps = math.floor(averageFps),
		particleStep = particleStep,
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
