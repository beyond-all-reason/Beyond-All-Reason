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
    name      = "HighlightUnit",
    desc      = "Highlights the unit or feature under the cursor\n"..
                grey.."Hold "..yellow.."META"..grey..
                " to show the unit or feature name",
    author    = "trepan",
    date      = "Apr 16, 2007",
    license   = "GNU GPL, v2 or later",
    layer     = 5,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Automatically generated local definitions

local GL_BACK                   = GL.BACK
local GL_EYE_LINEAR             = GL.EYE_LINEAR
local GL_EYE_PLANE              = GL.EYE_PLANE
local GL_FILL                   = GL.FILL
local GL_FRONT                  = GL.FRONT
local GL_FRONT_AND_BACK         = GL.FRONT_AND_BACK
local GL_INVERT                 = GL.INVERT
local GL_LINE                   = GL.LINE
local GL_ONE                    = GL.ONE
local GL_ONE_MINUS_SRC_ALPHA    = GL.ONE_MINUS_SRC_ALPHA
local GL_POINT                  = GL.POINT
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
local glDeleteTexture           = gl.DeleteTexture
local glDepthTest               = gl.DepthTest
local glFeature                 = gl.Feature
local glGetTextWidth            = gl.GetTextWidth
local glLineWidth               = gl.LineWidth
local glLogicOp                 = gl.LogicOp
local glPointSize               = gl.PointSize
local glPolygonMode             = gl.PolygonMode
local glPolygonOffset           = gl.PolygonOffset
local glPopMatrix               = gl.PopMatrix
local glPushMatrix              = gl.PushMatrix
local glScale                   = gl.Scale
local glSmoothing               = gl.Smoothing
local glTexCoord                = gl.TexCoord
local glTexGen                  = gl.TexGen
local glText                    = gl.Text
local glTexture                 = gl.Texture
local glTranslate               = gl.Translate
local glUnit                    = gl.Unit
local glVertex                  = gl.Vertex
local spDrawUnitCommands        = Spring.DrawUnitCommands
local spGetFeatureAllyTeam      = Spring.GetFeatureAllyTeam
local spGetFeatureDefID         = Spring.GetFeatureDefID
local spGetFeaturePosition      = Spring.GetFeaturePosition
local spGetFeatureRadius        = Spring.GetFeatureRadius
local spGetFeatureTeam          = Spring.GetFeatureTeam
local spGetModKeyState          = Spring.GetModKeyState
local spGetMouseState           = Spring.GetMouseState
local spGetMyAllyTeamID         = Spring.GetMyAllyTeamID
local spGetMyPlayerID           = Spring.GetMyPlayerID
local spGetMyTeamID             = Spring.GetMyTeamID
local spGetPlayerControlledUnit = Spring.GetPlayerControlledUnit
local spGetPlayerInfo           = Spring.GetPlayerInfo
local spGetTeamColor            = Spring.GetTeamColor
local spGetTeamInfo             = Spring.GetTeamInfo
local spGetUnitAllyTeam         = Spring.GetUnitAllyTeam
local spGetUnitDefID            = Spring.GetUnitDefID
local spGetUnitIsCloaked        = Spring.GetUnitIsCloaked
local spGetUnitTeam             = Spring.GetUnitTeam
local spIsCheatingEnabled       = Spring.IsCheatingEnabled
local spTraceScreenRay          = Spring.TraceScreenRay


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

include("colors.h.lua")
include("fonts.lua")

local font = 'FreeMonoBold'
local fontSize = 16
local fontName = ':n:'..LUAUI_DIRNAME..'Fonts/'..font..'_'..fontSize


local showName = (1 > 0)

local customTex = LUAUI_DIRNAME .. 'Images/highlight_strip.png'
local texName = LUAUI_DIRNAME .. 'Images/highlight_strip.png'
--local texName = 'bitmaps/laserfalloff.tga'

local cylDivs = 64
local cylList = 0

local outlineWidth = 3

local vsx, vsy = widgetHandler:GetViewSizes()
function widget:ViewResize(viewSizeX, viewSizeY)
  vsx = viewSizeX
  vsy = viewSizeY
end

local smoothPolys = (glSmoothing ~= nil) and false


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:Initialize()
  cylList = glCreateList(DrawCylinder, cylDivs)
end


function widget:Shutdown()
  glDeleteList(cylList)
  glDeleteTexture(customTex)
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

local function HilightModel(drawFunc, drawData, outline)
  glDepthTest(true)
  glPolygonOffset(-2, -2)
  glBlending(GL_SRC_ALPHA, GL_ONE)

  if (smoothPolys) then
    glSmoothing(nil, nil, true)
  end

  local scale = 20
  local shift = (2 * widgetHandler:GetHourTimer()) % scale
  glTexCoord(0, 0)
  glTexGen(GL_T, GL_TEXTURE_GEN_MODE, GL_EYE_LINEAR)
  glTexGen(GL_T, GL_EYE_PLANE, 0, (1 / scale), 0, shift)
  glTexture(texName)

  drawFunc(drawData)

  glTexture(false)
  glTexGen(GL_T, false)

  -- more edge highlighting
  if (outline) then
    glLineWidth(outlineWidth)
    glPointSize(outlineWidth)
    glPolygonOffset(10, 100)
    glPolygonMode(GL_FRONT_AND_BACK, GL_POINT)
    drawFunc(drawData)
    glPolygonMode(GL_FRONT_AND_BACK, GL_LINE)
    drawFunc(drawData)
    glPolygonMode(GL_FRONT_AND_BACK, GL_FILL)
    glPointSize(1)
    glLineWidth(1)
  end

  if (smoothPolys) then
    glSmoothing(nil, nil, false)
  end

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
  local outline = (spGetUnitIsCloaked(unitID) ~= true)
  SetUnitColor(unitID, outline and 0.5 or 0.25)
  HilightModel(UnitDrawFunc, unitID, outline)
end


local function HilightFeatureModel(featureID)
  SetFeatureColor(featureID, 0.5)
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

local GetPlayerControlledUnit = spGetPlayerControlledUnit
local GetMyPlayerID           = spGetMyPlayerID
local TraceScreenRay          = spTraceScreenRay
local GetMouseState           = spGetMouseState
local GetUnitDefID            = spGetUnitDefID
local GetFeatureDefID         = spGetFeatureDefID


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local type, data  --  for the TraceScreenRay() call


function widget:Update()
  local mx, my = GetMouseState()
  type, data = TraceScreenRay(mx, my)
end


function widget:DrawWorld()
  if (type == 'feature') then
    HilightFeature(data)
  elseif (type == 'unit') then
    local unitID = GetPlayerControlledUnit(GetMyPlayerID())
    if (data ~= unitID) then
      HilightUnit(data)
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

local teamNames = {}


local function GetTeamName(teamID)
  local name = teamNames[teamID]
  if (name) then
    return name
  end

  local teamNum, teamLeader = spGetTeamInfo(teamID)
  if (teamLeader == nil) then
    return ''
  end

  name = spGetPlayerInfo(teamLeader)
  teamNames[teamID] = name
  return name
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local teamColorStrs = {}


local function GetTeamColorStr(teamID)
  local colorSet = teamColorStrs[teamID]
  if (colorSet) then
    return colorSet[1], colorSet[2]
  end

  local outlineChar = ''
  local r,g,b = spGetTeamColor(teamID)
  if (r and g and b) then
    local function ColorChar(x)
      local c = math.floor(x * 255)
      c = ((c <= 1) and 1) or ((c >= 255) and 255) or c
      return string.char(c)
    end
    local colorStr
    colorStr = '\255'
    colorStr = colorStr .. ColorChar(r)
    colorStr = colorStr .. ColorChar(g)
    colorStr = colorStr .. ColorChar(b)
    local i = (r * 0.299) + (g * 0.587) + (b * 0.114)
    outlineChar = ((i > 0.25) and 'o') or 'O'
    teamColorStrs[teamID] = { colorStr, outlineChar }
    return colorStr, outlineChar
  end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:DrawScreen()
  local a,c,m,s = spGetModKeyState()
  if (not m) then
    return
  end

  local mx, my = GetMouseState()
  local type, data = TraceScreenRay(mx, my)

  local typeStr = ''
  local teamID = nil

  local cheat  = spIsCheatingEnabled()

  if (type == 'unit') then
    local udid = GetUnitDefID(data)
    if (udid == nil) then return end
    local ud = UnitDefs[udid]
    if (ud == nil) then return end
    typeStr = YellowStr .. ud.humanName -- .. ' ' .. CyanStr .. ud.tooltip
    if (cheat) then
      typeStr = typeStr
                .. ' \255\255\128\255(' .. ud.name
                .. ') \255\255\255\255#' .. data
    end
    teamID = spGetUnitTeam(data)
  elseif (type == 'feature') then
    local fdid = GetFeatureDefID(data)
    if (fdid == nil) then return end
    local fd = FeatureDefs[fdid]
    if (fd == nil) then return end
    typeStr = '\255\255\128\255' .. fd.tooltip
    if (cheat) then
      typeStr = typeStr
                .. ' \255\255\255\1(' .. fd.name
                .. ') \255\255\255\255#' .. data
    end
    teamID = spGetFeatureTeam(data)
  end

  local pName = nil
  local colorStr, outlineChar = nil, nil
  if (teamID) then
    pName = GetTeamName(teamID)
    if (pName) then
      colorStr, outlineChar = GetTeamColorStr(teamID)
      if ((colorStr == nil) or (outlineChar == nil)) then
        pName = nil
      end
    end
  end

  local fh = fontHandler
  if (fh.UseFont(fontName)) then

    local f = fh.GetFontSize() * 0.5
    local gx = 12 -- gap x
    local gy = 8  -- gap y

    local lt = fh.GetTextWidth(typeStr)
    local lp = pName and fh.GetTextWidth(pName) or 0
    local lm = (lt > lp) and lt or lp  --  max len

    pName = pName and (colorStr .. pName)

    if ((mx + lm + gx) < vsx) then
      fh.Draw(typeStr, mx + gx, my + gy)
      if (pName) then
        fh.Draw(pName, mx + gx, my - gy - f)
      end
    else
      fh.DrawRight(typeStr, mx - gx, my + gy)
      if (pName) then
        fh.DrawRight(pName, mx - gx, my - gy - f)
      end
    end
  else
    local f = 14
    local gx = 16
    local gy = 8

    local lt = f * glGetTextWidth(typeStr)
    local lp = pName and (f * glGetTextWidth(pName)) or 0
    local lm = (lt > lp) and lt or lp  --  max len

    pName = pName and (colorStr .. pName)

    if ((mx + lm + gx) < vsx) then
      glText(typeStr, mx + gx, my + gy, f, 'o')
      if (pName) then
        glText(pName, mx + gx, my - gy - f, f, outlineChar)
      end
    else
      glText(typeStr, mx - gx, my + gy, f, 'or')
      if (pName) then
        glText(pName, mx - gx, my - gy - f, f, outlineChar .. 'r')
      end
    end
  end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
