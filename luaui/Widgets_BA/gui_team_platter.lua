--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    gui_team_platter.lua
--  brief:   team colored platter for all visible units
--  author:  Dave Rodgers
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "TeamPlatter",
    desc      = "Shows a team color platter above all visible units",
    author    = "trepan",
    date      = "Apr 16, 2007",
    license   = "GNU GPL, v2 or later",
    layer     = 5,
    enabled   = false  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Automatically generated local definitions

local GL_LINE_LOOP           = GL.LINE_LOOP
local GL_TRIANGLE_FAN        = GL.TRIANGLE_FAN
local glBeginEnd             = gl.BeginEnd
local glColor                = gl.Color
local glCreateList           = gl.CreateList
local glDeleteList           = gl.DeleteList
local glDepthTest            = gl.DepthTest
local glDrawListAtUnit       = gl.DrawListAtUnit
local glLineWidth            = gl.LineWidth
local glPolygonOffset        = gl.PolygonOffset
local glVertex               = gl.Vertex
local spGetAllUnits          = Spring.GetAllUnits
local spGetVisibleUnits      = Spring.GetVisibleUnits
local spGetGroundNormal      = Spring.GetGroundNormal
local spGetSelectedUnits     = Spring.GetSelectedUnits
local spGetTeamColor         = Spring.GetTeamColor
local spGetUnitBasePosition  = Spring.GetUnitBasePosition
local spGetUnitDefID         = Spring.GetUnitDefID
local spGetUnitTeam          = Spring.GetUnitTeam
local spIsUnitVisible        = Spring.IsUnitVisible
local spSendCommands         = Spring.SendCommands

local spIsGUIHidden = Spring.IsGUIHidden

local unitConf = {}

-- preferred to keep these values the same as fancy unit selections widget
local rectangleFactor		= 2.4
local scalefaktor			= 1.8

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local GetGaiaTeamID = Spring.GetGaiaTeamID () --+++
function widget:PlayerChanged() --+++
	GetGaiaTeamID = Spring.GetGaiaTeamID () --+++
end --+++

local function SetupCommandColors(state)
  local alpha = state and 1 or 0
  local f = io.open('cmdcolors.tmp', 'w+')
  if (f) then
    f:write('unitBox  0 1 0 ' .. alpha)
    f:close()
    spSendCommands({'cmdcolors cmdcolors.tmp'})
  end
  os.remove('cmdcolors.tmp')
end


function SetUnitConf()
  for udid, unitDef in pairs(UnitDefs) do
    local xsize, zsize = unitDef.xsize, unitDef.zsize
    local scale = scalefaktor*( xsize^2 + zsize^2 )^0.5
    local xscale, zscale

    if (unitDef.isBuilding or unitDef.isFactory or unitDef.speed==0) then
      xscale, zscale = rectangleFactor * xsize, rectangleFactor * zsize
    else
      xscale, zscale = scale, scale
    end
    unitConf[udid] = 8 + (xscale+zscale)*1.5
  end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local teamColors = {}

local trackSlope = true

local platterList  = 0
local circleDivs   = 36
local circleOffset = 0

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:Initialize()
  platterList = glCreateList(function()
    glBeginEnd(GL_TRIANGLE_FAN, function()
      local radstep = (2.0 * math.pi) / circleDivs
      for i = 1, circleDivs do
        local a = (i * radstep)
        glVertex(math.sin(a), circleOffset, math.cos(a))
      end
    end)
    glBeginEnd(GL_LINE_LOOP, function()
      local radstep = (2.0 * math.pi) / circleDivs
      for i = 1, circleDivs do
        local a = (i * radstep)
        glVertex(math.sin(a), circleOffset, math.cos(a))
      end
    end)
  end)

  SetupCommandColors(false)
  SetUnitConf()
end


function widget:Shutdown()
  glDeleteList(platterList)
  SetupCommandColors(true)
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


local function GetTeamColorSet(teamID)
  local colors = teamColors[teamID]
  if (colors) then
    return colors
  end
  local r,g,b = spGetTeamColor(teamID)
  
  colors = {r, g, b, 0.33}
  teamColors[teamID] = colors
  return colors
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:DrawWorldPreUnit()
  if spIsGUIHidden() then return end

  glLineWidth(3.0)
  glDepthTest(false)
  glPolygonOffset(-50, -2)

  for _,unitID in ipairs(spGetVisibleUnits(-1, 50, false)) do
    local teamID = spGetUnitTeam(unitID)
    if (teamID and teamID~=GetGaiaTeamID) then
      local udid = spGetUnitDefID(unitID)
      local radius = unitConf[udid]
      glColor(GetTeamColorSet(teamID))
      glDrawListAtUnit(unitID, platterList, false,  radius, 1.0, radius)
    end
  end
  
  glPolygonOffset(false)

  -- Mark selected units
  local alpha = 0.27
  glColor(1, 1, 1, alpha)
  for _,unitID in ipairs(spGetSelectedUnits()) do
    glDrawListAtUnit(unitID, platterList, false, unitConf[spGetUnitDefID(unitID)], 1.0, radius)
  end

  glLineWidth(1.0)
end
              

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
