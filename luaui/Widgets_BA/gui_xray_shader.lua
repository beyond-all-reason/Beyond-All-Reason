--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    gui_xray_shader.lua
--  brief:   xray shader
--  author:  Dave Rodgers
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "XrayShader",
    desc      = "Highlights/shades all units, highlight diminishes on closeup. Fades out and disables at low fps. ",
    author    = "Floris (original by: trepan)",
    date      = "22 february 2015",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = false  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

local edgeExponent = 5

local zMin = 0
local zMax = 5000

local diminishAtFps		= 1
local disableAtFps		= 1		-- not acurate

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local GL_ONE                 = GL.ONE
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_SRC_ALPHA           = GL.SRC_ALPHA
local glBlending             = gl.Blending
local glColor                = gl.Color
local glCreateShader         = gl.CreateShader
local glDeleteShader         = gl.DeleteShader
local glDepthTest            = gl.DepthTest
local glGetShaderLog         = gl.GetShaderLog
local glPolygonOffset        = gl.PolygonOffset
local glSmoothing            = gl.Smoothing
local glUnit                 = gl.Unit
local glUseShader            = gl.UseShader
local spEcho                 = Spring.Echo
local spGetTeamColor         = Spring.GetTeamColor
local spGetTeamList          = Spring.GetTeamList
local spGetTeamUnits         = Spring.GetTeamUnits
local spIsUnitVisible        = Spring.IsUnitVisible


local spGetUnitTeam			= Spring.GetUnitTeam
local spGetVisibleUnits  	= Spring.GetVisibleUnits
local spGetCameraPosition	= Spring.GetCameraPosition
local spGetUnitPosition  	= Spring.GetUnitPosition
local spGetGameFrame	 	= Spring.GetGameFrame
local spGetAllyTeamList  	= Spring.GetAllyTeamList
local spGetUnitAllyTeam  	= Spring.GetUnitAllyTeam
local spIsGUIHidden      	= Spring.IsGUIHidden
local spGetUnitDefID     	= Spring.GetUnitDefID
local spGetFPS     		    = Spring.GetFPS

local lastUpdatedFrame		= 0
local drawUnits				= {}

local usedEdgeExponent = edgeExponent
local prevCam = {}
prevCam[1],prevCam[2],prevCam[3] = spGetCameraPosition()

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (not glCreateShader) then
  spEcho("Hardware is incompatible with Xray shader requirements")
  return false
end

local shader


local shaderFragZMinLoc = nil
local shaderFragZMaxLoc = nil

function widget:Shutdown()
  glDeleteShader(shader)
end


function widget:Initialize()

  shader = glCreateShader({

    uniform = {
      edgeExponent = usedEdgeExponent,
      fragZMin = zMin,
      fragZMax = zMax,
    },

    vertex = [[
      varying vec3 normal;
      varying vec3 eyeVec;
      varying vec3 color;
      varying vec3 position;
      uniform mat4 camera;
      uniform mat4 caminv;

      void main()
      {
        vec4 P = gl_ModelViewMatrix * gl_Vertex;
              
        eyeVec = P.xyz;
              
        normal  = gl_NormalMatrix * gl_Normal;
              
        color = gl_Color.rgb;
              
        gl_Position = gl_ProjectionMatrix * P;
        position = gl_Position;
      }
    ]],  
 
    fragment = [[
	#version 120
      varying vec3 normal;
      varying vec3 eyeVec;
      varying vec3 color;
      varying vec3 position;

      uniform float edgeExponent;
      uniform float fragZMin;
      uniform float fragZMax;

      void main()
      {
        float opac = dot(normalize(normal), normalize(eyeVec));
        opac = (1.0 - abs(opac));
        opac = pow(opac, edgeExponent) * clamp((position.z - fragZMin) / max(fragZMax - fragZMin,0.01),0.0,1.0);
          
        gl_FragColor.rgb = color + (opac*1.1);
        gl_FragColor.a = 0.015+opac;
      }
    ]],
  })

  if (shader == nil) then
    spEcho(glGetShaderLog())
    spEcho("Xray shader compilation failed.")
    widgetHandler:RemoveWidget(self)
  end
  shaderFragZMinLoc = gl.GetUniformLocation(shader, "fragZMin")
  shaderFragZMaxLoc = gl.GetUniformLocation(shader, "fragZMax")
  shaderEdgeExponentLoc = gl.GetUniformLocation(shader, "edgeExponent")
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  utility routine
--

local teamColors = {}

local function SetTeamColor(teamID)
  local color = teamColors[teamID]
  if (color) then
    glColor(color)
    return
  end
  local r,g,b = spGetTeamColor(teamID)
  if (r and g and b) then
    color = { r, g, b }
    teamColors[teamID] = color
    glColor(color)
    return
  end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local teams = {}
function widget:DrawWorld()
	
	if usedEdgeExponent > 15 then return end
	
	glColor(1, 1, 1, 0.7)
	glUseShader(shader)
	glDepthTest(true)
	glBlending(GL_SRC_ALPHA, GL_ONE)
	glPolygonOffset(-1, -1)
	

	gl.Uniform(shaderFragZMinLoc, zMin)
	gl.Uniform(shaderFragZMaxLoc, zMax)
	gl.Uniform(shaderEdgeExponentLoc, usedEdgeExponent)
  
	for _, teamID in ipairs(teams) do
		if drawUnits[teamID] ~= nil then
			SetTeamColor(teamID)
			local unitCount = #drawUnits[teamID]
			for i=1, unitCount do
				glUnit(drawUnits[teamID][i], true)
			end
		end
	end
	
	glPolygonOffset(false)
	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	glDepthTest(false)
	glUseShader(0)
	glColor(1, 1, 1, 0.7)
end
              

local sec = 0
local sceduledCheck = false
local updateTime = 0.66
local averageFps = spGetFPS()
local prevClock = os.clock()
function widget:Update(dt)
	sec=sec+dt
	local camX, camY, camZ = spGetCameraPosition()
	if camX ~= prevCam[1] or  camY ~= prevCam[2] or  camZ ~= prevCam[3] then
		sceduledCheck = true
	end
	local fps = spGetFPS()
	if os.clock() - prevClock > 0.2 then
		averageFps = averageFps + ((fps - averageFps) / 70)
		local multiplier = ((averageFps * (averageFps - diminishAtFps)/(diminishAtFps - disableAtFps))/100) + 1
		usedEdgeExponent = edgeExponent / (multiplier^4.5)
		if usedEdgeExponent < edgeExponent then
			usedEdgeExponent = edgeExponent
		end
		prevClock = os.clock()
		--Spring.Echo(math.floor(averageFps).."   "..usedEdgeExponent)
	end
	if (sec>1/updateTime and lastUpdatedFrame ~= spGetGameFrame() or (sec>1/(updateTime*5) and sceduledCheck)) then
		sec = 0
		teams = spGetTeamList()
		checkAllUnits()
		lastUpdatedFrame = spGetGameFrame()
		sceduledCheck = false
		updateTime =  fps / 14
		if updateTime < 0.66 then 
			updateTime = 0.66
		end
	end
	prevCam[1],prevCam[2],prevCam[3] = camX,camY,camZ
end


function checkAllUnits()
	drawUnits = {}
	for _, unitID in ipairs(spGetVisibleUnits(-1,nil,false)) do
		local teamID = spGetUnitTeam(unitID)
		local unitDefIDValue = spGetUnitDefID(unitID)
		if (unitDefIDValue) then
			if drawUnits[teamID] == nil then
				drawUnits[teamID] = {}
			end
			drawUnits[teamID][#drawUnits[teamID]+1] = unitID
		end
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
