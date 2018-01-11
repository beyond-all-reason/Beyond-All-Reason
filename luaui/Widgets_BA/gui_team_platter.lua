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
    author    = "Floris (original: trepan)",
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
local spGetVisibleUnits      = Spring.GetVisibleUnits
local spGetSelectedUnits     = Spring.GetSelectedUnits
local spGetTeamColor         = Spring.GetTeamColor
local spGetUnitDefID         = Spring.GetUnitDefID
local spGetUnitTeam          = Spring.GetUnitTeam
local spSendCommands         = Spring.SendCommands

local spGetCameraPosition	  = Spring.GetCameraPosition
local spGetGameFrame	      = Spring.GetGameFrame
local spGetAllyTeamList       = Spring.GetAllyTeamList
local spIsGUIHidden           = Spring.IsGUIHidden
local spGetTeamList           = Spring.GetTeamList

local gaiaTeamID = Spring.GetGaiaTeamID()

local unitConf = {}
local lastUpdatedFrame		= 0
local drawUnits				= {}

local teamColors = {}
local platterList  = 0
local circleDivs   = 36
local circleOffset = 0

local prevCam = {}
prevCam[1],prevCam[2],prevCam[3] = spGetCameraPosition()


-- preferred to keep these values the same as fancy unit selections widget
local rectangleFactor		= 2.4
local scalefaktor			= 1.8

local ignoreUnits = {}
for udefID,def in ipairs(UnitDefs) do
  if def.customParams['nohealthbars'] then
    ignoreUnits[udefID] = true
  end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


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
        glVertex(math.sin(a), circleOffset+0.05, math.cos(a))
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


local visibleUnits = {}
local visibleUnitsCount = 0
function checkAllUnits()
  drawUnits = {}
  visibleUnits = spGetVisibleUnits(-1, 50, false)
  visibleUnitsCount = #visibleUnits
  for i=1, visibleUnitsCount do
    checkUnit(visibleUnits[i])
  end
end

function checkUnit(unitID)
  local teamID = spGetUnitTeam(unitID)
  local unitDefID = spGetUnitDefID(unitID)
  if ignoreUnits[unitDefID] ~= nil then
    return
  end
  if (unitDefID) then
    if drawUnits[teamID] == nil then
      drawUnits[teamID] = {}
    end
    drawUnits[teamID][unitID] = unitConf[unitDefID]
  end
end


local sec = 0
local sceduledCheck = false
local updateTime = 1
function widget:Update(dt)
  sec=sec+dt
  local camX, camY, camZ = spGetCameraPosition()
  if camX ~= prevCam[1] or  camY ~= prevCam[2] or  camZ ~= prevCam[3] then
    sceduledCheck = true
  end
  if (sec>1/updateTime and lastUpdatedFrame ~= spGetGameFrame() or (sec>1/(updateTime*5) and sceduledCheck)) then
    sec = 0
    checkAllUnits()
    lastUpdatedFrame = spGetGameFrame()
    sceduledCheck = false
    updateTime = Spring.GetFPS() / 15
    if updateTime < 0.66 then
      updateTime = 0.66
    end
  end
  prevCam[1],prevCam[2],prevCam[3] = camX,camY,camZ
end


function widget:DrawWorldPreUnit()
  if spIsGUIHidden() then return end

  glLineWidth(3.0)
  glDepthTest(true)
  glPolygonOffset(-100, -2)

  for _, allyID in ipairs(spGetAllyTeamList()) do
    for _, teamID in ipairs(spGetTeamList(allyID)) do
      if teamID ~= gaiaTeamID and drawUnits[teamID] ~= nil then
        glColor(GetTeamColorSet(teamID))
        for unitID, unitScale in pairs(drawUnits[teamID]) do
          glDrawListAtUnit(unitID, platterList, false,  unitScale, 1.0, unitScale)
        end
      end
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
