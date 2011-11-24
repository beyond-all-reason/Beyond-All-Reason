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
    desc      = "XrayShader",
    author    = "trepan",
    date      = "Jul 15, 2007",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Automatically generated local definitions

local GL_ONE                 = GL.ONE
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_SRC_ALPHA           = GL.SRC_ALPHA
local glBlending             = gl.Blending
local glColor                = gl.Color
local glCreateShader         = gl.CreateShader
local glDeleteShader         = gl.DeleteShader
local glDepthTest            = gl.DepthTest
local glFeature              = gl.Feature
local glGetShaderLog         = gl.GetShaderLog
local glPolygonOffset        = gl.PolygonOffset
local glSmoothing            = gl.Smoothing
local glUnit                 = gl.Unit
local glUseShader            = gl.UseShader
local spEcho                 = Spring.Echo
local spGetAllFeatures       = Spring.GetAllFeatures
local spGetTeamColor         = Spring.GetTeamColor
local spGetTeamList          = Spring.GetTeamList
local spGetTeamUnits         = Spring.GetTeamUnits
local spIsUnitVisible        = Spring.IsUnitVisible
local spIsUnitIconic         = Spring.IsUnitIconic


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (not glCreateShader) then
  spEcho("Hardware is incompatible with Xray shader requirements")
  return false
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  simple configuration parameters
--

local edgeExponent = 2.5

local doFeatures = false

local featureColor = { 1, 0, 1 }

-- looks a lot nicer, esp. without FSAA  (but eats into the FPS too much)
local smoothPolys = glSmoothing and true


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local shader


function widget:Shutdown()
  glDeleteShader(shader)
end


function widget:Initialize()

  shader = glCreateShader({

    uniform = {
      edgeExponent = edgeExponent,
    },

    vertex = [[
      // Application to vertex shader
      varying vec3 normal;
      varying vec3 eyeVec;
      varying vec3 color;
      uniform mat4 camera;
      uniform mat4 caminv;

      void main()
      {
        vec4 P = gl_ModelViewMatrix * gl_Vertex;
              
        eyeVec = P.xyz;
              
        normal  = gl_NormalMatrix * gl_Normal;
              
        color = gl_Color.rgb;
              
        gl_Position = gl_ProjectionMatrix * P;
      }
    ]],  
 
    fragment = [[
      varying vec3 normal;
      varying vec3 eyeVec;
      varying vec3 color;

      uniform float edgeExponent;

      void main()
      {
        float opac = dot(normalize(normal), normalize(eyeVec));
        opac = 1.0 - abs(opac);
        opac = pow(opac, edgeExponent);
          
        gl_FragColor.rgb = color;
        gl_FragColor.a = opac;
      }
    ]],
  })

  if (shader == nil) then
    spEcho(glGetShaderLog())
    spEcho("Xray shader compilation failed.")
    widgetHandler:RemoveWidget()
  end
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

function widget:DrawWorld()
  if (smoothPolys) then
    glSmoothing(nil, nil, true)
  end

  glColor(1, 1, 1, 1)

  glUseShader(shader)

  glDepthTest(true)

  glBlending(GL_SRC_ALPHA, GL_ONE)

  glPolygonOffset(-2, -2)

  for _, teamID in ipairs(spGetTeamList()) do
    SetTeamColor(teamID)
    for _, unitID in ipairs(spGetTeamUnits(teamID)) do
      if (spIsUnitVisible(unitID, nil, true)) then
        glUnit(unitID, true)
      end
    end
  end

  if (doFeatures) then
    glColor(featureColor)
    for _, featureID in ipairs(spGetAllFeatures()) do
      glFeature(featureID, true)
    end
  end

  glPolygonOffset(false)

  glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

  glDepthTest(false)

  glUseShader(0)

  glColor(1, 1, 1, 1)

  if (smoothPolys) then
    glSmoothing(nil, nil, false)
  end
end
              

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
