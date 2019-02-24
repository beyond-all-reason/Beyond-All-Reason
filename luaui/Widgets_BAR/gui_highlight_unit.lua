--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    gui_highlight_unit.lua
--  brief:   highlights the unit/feature under the cursor
--  author:  Dave Rodgers
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  local grey   = "\255\192\192\192"
  local yellow = "\255\255\255\128"
  return {
    name      = "Highlight Unit",
    desc      = "Highlights the unit or feature under the cursor\n",
    author    = "trepan",
    date      = "Apr 16, 2007",
    license   = "GNU GPL, v2 or later",
    layer     = 5,
    enabled   = true  --  loaded by default?
  }
end

local drawFeatureHighlight	= false
local unitAlpha				= 0.2
local featureAlpha			= 0.14

local useShader = true
local edgeExponent = 1.25
local shaderUnitAlphaMultiplier = 0.7

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local GL_BACK                   = GL.BACK
local GL_EYE_LINEAR             = GL.EYE_LINEAR
local GL_EYE_PLANE              = GL.EYE_PLANE
local GL_FRONT                  = GL.FRONT
local GL_INVERT                 = GL.INVERT
local GL_ONE                    = GL.ONE
local GL_ONE_MINUS_SRC_ALPHA    = GL.ONE_MINUS_SRC_ALPHA
local GL_QUAD_STRIP             = GL.QUAD_STRIP
local GL_SRC_ALPHA              = GL.SRC_ALPHA
local GL_T                      = GL.T
local GL_TEXTURE_GEN_MODE       = GL.TEXTURE_GEN_MODE
local GL_TRIANGLE_FAN           = GL.TRIANGLE_FAN
local glBeginEnd                = gl.BeginEnd
local glBlending                = gl.Blending
local glCallList                = gl.CallList
local glColor                   = gl.Color
local glCreateList              = gl.CreateList
local glCulling                 = gl.Culling
local glDeleteList              = gl.DeleteList
local glDepthTest               = gl.DepthTest
local glFeature                 = gl.Feature
local glLogicOp                 = gl.LogicOp
local glPolygonOffset           = gl.PolygonOffset
local glPopMatrix               = gl.PopMatrix
local glPushMatrix              = gl.PushMatrix
local glScale                   = gl.Scale
local glTexCoord                = gl.TexCoord
local glTexGen                  = gl.TexGen
local glTexture                 = gl.Texture
local glTranslate               = gl.Translate
local glUnit                    = gl.Unit
local glVertex                  = gl.Vertex
local spDrawUnitCommands        = Spring.DrawUnitCommands
local spGetFeatureDefID         = Spring.GetFeatureDefID
local spGetFeaturePosition      = Spring.GetFeaturePosition
local spGetFeatureRadius        = Spring.GetFeatureRadius
local spGetModKeyState          = Spring.GetModKeyState
local spGetMouseState           = Spring.GetMouseState
local spGetMyAllyTeamID         = Spring.GetMyAllyTeamID
local spGetMyPlayerID           = Spring.GetMyPlayerID
local spGetMyTeamID             = Spring.GetMyTeamID
local spGetPlayerControlledUnit = Spring.GetPlayerControlledUnit
local spGetUnitAllyTeam         = Spring.GetUnitAllyTeam
local spGetUnitTeam             = Spring.GetUnitTeam
local spTraceScreenRay          = Spring.TraceScreenRay

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


local texName = 'LuaUI/Images/highlight_strip.png'

local cylDivs = 64
local cylList = 0

local vsx, vsy = widgetHandler:GetViewSizes()
function widget:ViewResize(viewSizeX, viewSizeY)
  vsx = viewSizeX
  vsy = viewSizeY
end


function CreateHighlightShader()
  if shader then
    gl.DeleteShader(shader)
  end
  if gl.CreateShader ~= nil then
    shader = gl.CreateShader({

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
          opac = pow(opac, edgeExponent)*0.4;

          gl_FragColor.rgb = color + opac);
          gl_FragColor.a = opac;

        }
      ]],
    })
  end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:Initialize()
  cylList = glCreateList(DrawCylinder, cylDivs)
  CreateHighlightShader()
end


function widget:Shutdown()
  glDeleteList(cylList)
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function DrawCylinder(divs)
  local cos = math.cos
  local sin = math.sin
  local divRads = (2.0 * math.pi) / divs
  -- top
  glBeginEnd(GL_TRIANGLE_FAN, function()
    for i = 1, divs do
      local a = i * divRads
      glVertex(sin(a), 1.0, cos(a))
    end
  end)
  -- bottom
  glBeginEnd(GL_TRIANGLE_FAN, function()
    for i = 1, divs do
      local a = -i * divRads
      glVertex(sin(a), -1.0, cos(a))
    end
  end)
  -- sides
  glBeginEnd(GL_QUAD_STRIP, function()
    for i = 0, divs do
      local a = i * divRads
      glVertex(sin(a),  1.0, cos(a))
      glVertex(sin(a), -1.0, cos(a))
    end
  end)
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function HilightModel(drawFunc, drawData)
  glDepthTest(true)
  glPolygonOffset(-2, -2)
  glBlending(GL_SRC_ALPHA, GL_ONE)

  local scale = 35
  local shift = (2 * widgetHandler:GetHourTimer()) % scale
  glTexCoord(0, 0)
  glTexGen(GL_T, GL_TEXTURE_GEN_MODE, GL_EYE_LINEAR)
  glTexGen(GL_T, GL_EYE_PLANE, 0, (1 / scale), 0, shift)
  glTexture(texName)

  drawFunc(drawData)

  glTexture(false)
  glTexGen(GL_T, false)

  glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
  glPolygonOffset(false)
  glDepthTest(false)
end


--------------------------------------------------------------------------------

local function SetUnitColor(unitID, alpha)
  local teamID = spGetUnitTeam(unitID)
  if (teamID == nil) then
    glColor(1.0, 0.0, 0.0, alpha) -- red
  elseif (teamID == spGetMyTeamID()) then
    glColor(0.0, 1.0, 1.0, alpha) -- cyan
  elseif (spGetUnitAllyTeam(unitID) == spGetMyAllyTeamID()) then
    glColor(0.0, 1.0, 0.0, alpha) -- green
  else
    glColor(1.0, 0.0, 0.0, alpha) -- red
  end
end


local function SetFeatureColor(featureID, alpha)
  glColor(1.0, 0.0, 1.0, alpha) -- purple
  do return end  -- FIXME -- wait for feature team/allyteam resolution

  local allyTeamID = spGetFeatureAllyTeam(featureID)
  if ((allyTeamID == nil) or (allyTeamID < 0)) then
    glColor(1.0, 1.0, 1.0, alpha) -- white
  elseif (allyTeamID == spGetMyAllyTeamID()) then
    glColor(0.0, 1.0, 1.0, alpha) -- cyan
  else
    glColor(1.0, 0.0, 0.0, alpha) -- red
  end
end


local function UnitDrawFunc(unitID)
  glUnit(unitID, true)
end


local function FeatureDrawFunc(featureID)
  glFeature(featureID, true)
end


local function HilightUnit(unitID)
  --local outline = (spGetUnitIsCloaked(unitID) ~= true)
  SetUnitColor(unitID, (useShader and shader) and unitAlpha*shaderUnitAlphaMultiplier or unitAlpha)
  HilightModel(UnitDrawFunc, unitID)
end


local function HilightFeatureModel(featureID)
  SetFeatureColor(featureID, (useShader and shader) and featureAlpha*shaderUnitAlphaMultiplier or featureAlpha)
  HilightModel(FeatureDrawFunc, featureID, true)
end


local function HilightFeature(featureID)
  local fDefID = spGetFeatureDefID(featureID)
  local fd = FeatureDefs[fDefID]
  if (fd == nil) then return end

  if (fd.drawType == 0) then
    HilightFeatureModel(featureID)
    return
  end

  local radius = spGetFeatureRadius(featureID)
  if (radius == nil) then
    return
  end

  local px, py, pz = spGetFeaturePosition(featureID)
  if (px == nil) then return end

  local yScale = 4
  glPushMatrix()
  glTranslate(px, py, pz)
  glScale(radius, yScale * radius, radius)
  -- FIXME: needs an 'inside' check

  glDepthTest(true)
  glLogicOp(GL_INVERT)

  glCulling(GL_FRONT)
  glCallList(cylList)

  glCulling(GL_BACK)
  glCallList(cylList)

  glLogicOp(false)
  glCulling(false)
  glDepthTest(false)

  glPopMatrix()
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local type, data  --  for the TraceScreenRay() call


function widget:Update()
  local mx, my = spGetMouseState()
  type, data = spTraceScreenRay(mx, my)
end


function widget:DrawWorld()
  if Spring.IsGUIHidden() then return end
  if drawFeatureHighlight and (type == 'feature') then
    HilightFeature(data)
    if useShader and shader then
      gl.UseShader(shader)
      HilightModel(FeatureDrawFunc, data)
      gl.UseShader(0)
    end
  elseif (type == 'unit') then
    local unitID = spGetPlayerControlledUnit(spGetMyPlayerID())
    if data ~= unitID and not Spring.IsUnitIcon(data) then

      HilightUnit(data)

      if useShader and shader then
        gl.UseShader(shader)
        HilightModel(UnitDrawFunc, data)
        gl.UseShader(0)
      end
      -- also draw the unit's command queue
      local a,c,m,s = spGetModKeyState()
      if (m) then
        spDrawUnitCommands(data)
      end
    end
  end
end


widget.DrawWorldReflection = widget.DrawWorld

widget.DrawWorldRefraction = widget.DrawWorld


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
