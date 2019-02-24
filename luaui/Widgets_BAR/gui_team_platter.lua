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

local drawDonuts = false
local spotterOpacity = 0.3
local highlightOpacity = 0.25
local skipOwnTeam  = false
local useSelections = true
local noOverlap = true

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
local spGetMyTeamID          = Spring.GetMyTeamID
local spGetCameraPosition	 = Spring.GetCameraPosition
local spGetGameFrame	     = Spring.GetGameFrame
local spGetAllyTeamList      = Spring.GetAllyTeamList
local spIsGUIHidden          = Spring.IsGUIHidden
local spGetTeamList          = Spring.GetTeamList

local gaiaTeamID = Spring.GetGaiaTeamID()

local spotterImg = ":n:LuaUI/Images/enemyspotter.dds"

local unitConf = {}
local lastUpdatedFrame		= 0
local drawUnits				= {}

local teamColors = {}
local platterCircleList  = 0
local platterSquareList  = 0
local platterTriangleList  = 0
local circleDivs   = 36
local circleOffset = 0


local prevCam = {}
prevCam[1],prevCam[2],prevCam[3] = spGetCameraPosition()

local isSpec = Spring.GetSpectatingState()


local ignoreUnits = {}
for udefID,def in ipairs(UnitDefs) do
  if def.customParams['nohealthbars'] then
    ignoreUnits[udefID] = true
  end
end

local myTeamID = spGetMyTeamID()

local singleTeams = false
if #Spring.GetTeamList()-1  ==  #Spring.GetAllyTeamList()-1 then
  singleTeams = true
end

local sameTeamColors = false
if WG['playercolorpalette'] ~= nil and WG['playercolorpalette'].getSameTeamColors() then
  sameTeamColors = WG['playercolorpalette'].getSameTeamColors()
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
  -- preferred to keep these values the same as fancy unit selections widget
  local scaleFactor = 2.6
  local rectangleFactor = 3.25

  for udid, unitDef in pairs(UnitDefs) do
    local xsize, zsize = unitDef.xsize, unitDef.zsize
    local scale = scaleFactor*( xsize^2 + zsize^2 )^0.5
    local xscale, zscale, shape

    if (unitDef.isBuilding or unitDef.isFactory or unitDef.speed==0) then
      shape = 'square'
      xscale, zscale = rectangleFactor * xsize, rectangleFactor * zsize
    elseif (unitDef.isAirUnit) then
      shape = 'triangle'
      xscale, zscale = scale*1.07, scale*1.07
    elseif (unitDef.modCategories["ship"]) then
      shape = 'circle'
      xscale, zscale = scale*0.82, scale*0.82
    else
      shape = 'circle'
      xscale, zscale = scale, scale
    end

    local radius = Spring.GetUnitDefDimensions(udid).radius
    xscale = (xscale*0.7) + (radius/5)
    zscale = (zscale*0.7) + (radius/5)

    unitConf[udid] = {scale=(xscale+zscale)*1.5, shape=shape}
  end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function DrawTriangleSolid(size)

  gl.BeginEnd(GL.TRIANGLE_FAN, function()

    local width, a1,a2,a2_2
    local radstep = (2.0 * math.pi) / 3

    for i = 1, 3 do
      -- straight piece
      width = 0.75
      i = i + 0.625
      a1 = (i * radstep)
      a2 = ((i+width) * radstep)

      gl.Vertex(0, 0, 0)
      gl.Vertex(math.sin(a2)*size, 1, math.cos(a2)*size)
      gl.Vertex(math.sin(a1)*size, 1, math.cos(a1)*size)

      -- corner piece
      width = 0.35
      i = i + 3
      a1 = (i * radstep)
      a2 = ((i+width) * radstep)
      i = i -0.6
      a2_2 = ((i+width) * radstep)

      gl.Vertex(0, 0, 0)
      gl.Vertex(math.sin(a2_2)*size, 1, math.cos(a2_2)*size)
      gl.Vertex(math.sin(a1)*size, 1, math.cos(a1)*size)
    end

  end)
end

local function DrawSquareSolid(size)
  gl.BeginEnd(GL.TRIANGLE_FAN, function()
    local width, a1,a2,a2_2
    local radstep = (2.0 * math.pi) / 4

    for i = 1, 4 do
      --straight piece
      width = 0.7
      i = i + 0.65
      a1 = (i * radstep)
      a2 = ((i+width) * radstep)

      gl.Vertex(0, 0, 0)
      gl.Vertex(math.sin(a2)*size, 1, math.cos(a2)*size)
      gl.Vertex(math.sin(a1)*size, 1, math.cos(a1)*size)

      --corner piece
      width = 0.3
      i = i + 3
      a1 = (i * radstep)
      a2 = ((i+width) * radstep)
      i = i -0.6
      a2_2 = ((i+width) * radstep)

      gl.Vertex(0, 0, 0)
      gl.Vertex(math.sin(a2_2)*size, 1, math.cos(a2_2)*size)
      gl.Vertex(math.sin(a1)*size, 1, math.cos(a1)*size)
    end

  end)
end

function widget:Initialize()
  platterCircleList = glCreateList(function()
    local radius = 0.6
    glBeginEnd(GL_TRIANGLE_FAN, function()
      local radstep = (2.0 * math.pi) / circleDivs
      for i = 1, circleDivs do
        local a = (i * radstep)
        glVertex(radius*math.sin(a), circleOffset, radius*math.cos(a))
      end
    end)
    glBeginEnd(GL_LINE_LOOP, function()
      local radstep = (2.0 * math.pi) / circleDivs
      for i = 1, circleDivs do
        local a = (i * radstep)
        glVertex(radius*math.sin(a), circleOffset+0.05, radius*math.cos(a))
      end
    end)
  end)

  platterSquareList = glCreateList(function()
    local radius = 0.6
    DrawSquareSolid(radius)
  end)

  platterTriangleList = glCreateList(function()
    local radius = 0.6
    DrawTriangleSolid(radius)
  end)


  spotterList = gl.CreateList(function()
    gl.TexRect(-1, 1, 1, -1)
  end)

  SetupCommandColors(false)
  SetUnitConf()

  WG['teamplatter'] = {}
  WG['teamplatter'].getOpacity = function()
    return spotterOpacity
  end
  WG['teamplatter'].setOpacity = function(value)
    spotterOpacity = value
    teamColors = {}
  end
  WG['teamplatter'].getSkipOwnTeam = function()
    return skipOwnTeam
  end
  WG['teamplatter'].setSkipOwnTeam = function(value)
    skipOwnTeam = value
  end
end


function widget:Shutdown()
  glDeleteList(platterCircleList)
  glDeleteList(platterSquareList)
  glDeleteList(platterTriangleList)
  glDeleteList(spotterList)
  if WG['highlightselunits'] == nil and WG['fancyselectedunits'] == nil then
    SetupCommandColors(true)
  end
  WG['teamplatter'] = nil
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


local function GetTeamColorSet(teamID)
  local colors = teamColors[teamID]
  if (colors) then
    return colors
  end
  local r,g,b = spGetTeamColor(teamID)
  
  colors = {r, g, b, spotterOpacity}
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
    drawUnits[teamID][unitID] = unitConf[unitDefID].scale
  end
end


function widget:PlayerChanged(playerID)
  isSpec = Spring.GetSpectatingState()
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

    if WG['playercolorpalette'] ~= nil then
      if WG['playercolorpalette'].getSameTeamColors and sameTeamColors ~= WG['playercolorpalette'].getSameTeamColors() then
        sameTeamColors = WG['playercolorpalette'].getSameTeamColors()
        teamColors = {}
      end
    elseif sameTeamColors == true then
      sameTeamColors = false
      teamColors = {}
    end
    if not singleTeams and WG['playercolorpalette'] ~= nil and WG['playercolorpalette'].getSameTeamColors() then
      if myTeamID ~= Spring.GetMyTeamID() then
        -- old
        teamColors[myTeamID] = nil
        -- new
        myTeamID = Spring.GetMyTeamID()
        teamColors[myTeamID] = nil
      end
    end
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

  if drawDonuts then
    gl.Texture(spotterImg)
  end
  for _, allyID in ipairs(spGetAllyTeamList()) do
    for _, teamID in ipairs(spGetTeamList(allyID)) do
      if teamID ~= gaiaTeamID and drawUnits[teamID] ~= nil and (not skipOwnTeam or skipOwnTeam and teamID ~= myTeamID)then
        glColor(GetTeamColorSet(teamID))
        for unitID, unitScale in pairs(drawUnits[teamID]) do
          if drawDonuts then
            glDrawListAtUnit(unitID, spotterList, false,  unitScale, unitScale, unitScale, 90, 1,0,0)
          else
            --if unitConf[Spring.GetUnitDefID(unitID)].shape == 'square' then
            --  glDrawListAtUnit(unitID, platterSquareList, false,  unitScale, 1.0, unitScale)
            --elseif unitConf[Spring.GetUnitDefID(unitID)].shape == 'triangle' then
            --  glDrawListAtUnit(unitID, platterTriangleList, false,  unitScale, 1.0, unitScale)
            --else
              glDrawListAtUnit(unitID, platterCircleList, false,  unitScale, 1.0, unitScale)
            --end
          end
        end
      end
    end
  end

  -- mark selected units
  if useSelections then
    glColor(1, 1, 1, highlightOpacity)
    for _,unitID in ipairs(spGetSelectedUnits()) do
      local udefid = spGetUnitDefID(unitID)
      if udefid then
        local unitScale = unitConf[udefid].scale
        if drawDonuts then
          glDrawListAtUnit(unitID, spotterList, false,  unitScale, unitScale, unitScale, 90, 1,0,0)
        else
          --if unitConf[Spring.GetUnitDefID(unitID)].shape == 'square' then
          --  glDrawListAtUnit(unitID, platterSquareList, false,  unitScale, 1.0, unitScale)
          --elseif unitConf[Spring.GetUnitDefID(unitID)].shape == 'triangle' then
          --  glDrawListAtUnit(unitID, platterTriangleList, false,  unitScale, 1.0, unitScale)
          --else
            glDrawListAtUnit(unitID, platterCircleList, false,  unitScale, 1.0, unitScale)
          --end
        end
      end
    end
  end

  glPolygonOffset(false)
  glLineWidth(1.0)
end


function widget:GetConfigData(data)
  savedTable = {}
  savedTable.skipOwnTeam			= skipOwnTeam
  savedTable.spotterOpacity			= spotterOpacity
  return savedTable
end

function widget:SetConfigData(data)
  skipOwnTeam = data.skipOwnTeam or skipOwnTeam
  spotterOpacity = data.spotterOpacity or spotterOpacity
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
