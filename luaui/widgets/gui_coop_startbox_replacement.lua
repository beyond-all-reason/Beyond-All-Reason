--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    minimap_startbox.lua
--  brief:   shows the startboxes in the minimap
--  author:  Dave Rodgers
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "Coop StartBox replacement",
    desc      = "Coop StartBox replacement",
    author    = "trepan, modified by Licho/TheFatController",
    date      = "Mar 17, 2007",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true,  --  loaded by default?
    handler   = true,
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local playerCount = 0
for _, playerID in ipairs(Spring.GetPlayerList(Spring.GetMyTeamID())) do
  if not select(3,Spring.GetPlayerInfo(playerID)) then
    playerCount = playerCount + 1
  end
end

local enabled = tonumber(Spring.GetModOptions().mo_coop) or 0

if (enabled == 0) or (Game.startPosType ~= 2) or (playerCount < 2) then
  return false
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  config options
--

-- assumes that cards which support GL 2.0 don't suck
local drawGroundQuads = (gl.CreateShader ~= nil)

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local gl = gl  --  use a local copy for faster access

local msx = Game.mapSizeX
local msz = Game.mapSizeZ

local xformList = 0
local coneList = 0
local allyTeamGndLists = {}

local gaiaTeamID
local gaiaAllyTeamID

local startTimer = Spring.GetTimer()

local texScale = 512


--------------------------------------------------------------------------------

function widget:Initialize()
  
  -- only show at the beginning
  if (Spring.GetGameFrame() > 1) then
    widgetHandler:RemoveWidget(self)
    return
  end

  -- get the gaia teamID and allyTeamID
  gaiaTeamID = Spring.GetGaiaTeamID()
  if (gaiaTeamID) then
    local _,_,_,_,_,_,atid = Spring.GetTeamInfo(gaiaTeamID)
    gaiaAllyTeamID = atid
  end

  -- flip and scale  (using x & y for gl.Rect())
  xformList = gl.CreateList(function()
    gl.LoadIdentity()
    gl.Translate(0, 1, 0)
    gl.Scale(1 / msx, -1 / msz, 1)
  end)

  -- cone list for world start positions
  coneList = gl.CreateList(function()
    local h = 100
    local r = 25
    local divs = 32
    gl.BeginEnd(GL.TRIANGLE_FAN, function()
      gl.Vertex( 0, h,  0)
      for i = 0, divs do
        local a = i * ((math.pi * 2) / divs)
        local cosval = math.cos(a)
        local sinval = math.sin(a)
        gl.Vertex(r * sinval, 0, r * cosval)
      end
    end)
  end)

  if (drawGroundQuads) then
    for _,at in ipairs(Spring.GetAllyTeamList()) do
      local xn, zn, xp, zp = Spring.GetAllyTeamStartBox(at)
      if (xn and ((xn ~= 0) or (zn ~= 0) or (xp ~= msx) or (zp ~= msz))) then
        allyTeamGndLists[at] = gl.CreateList(function()
          gl.DrawGroundQuad(xn, zn, xp, zp)
        end)
      end
    end
  end
end


function widget:Shutdown()
  gl.DeleteList(xformList)
  gl.DeleteList(coneList)
  for _, gndList in pairs(allyTeamGndLists) do
    gl.DeleteList(gndList)
  end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local teamColors = {}


local function GetTeamColor(teamID)
  local color = teamColors[teamID]
  if (color) then
    return color
  end
  local r,g,b = Spring.GetTeamColor(teamID)
  
  color = { r, g, b }
  teamColors[teamID] = color
  return color
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
  local r,g,b = Spring.GetTeamColor(teamID)
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

function widget:DrawWorld()
  if ((widgetHandler.knownWidgets['MiniMap Start Boxes'] or {}).active) then
    for i, widget in ipairs(widgetHandler.widgets) do
      if (widget:GetInfo().name == 'MiniMap Start Boxes') then
        widgetHandler:RemoveWidget(widget)
      end
    end
  end
  if ((widgetHandler.knownWidgets['StartBox replacement'] or {}).active) then
    for i, widget in ipairs(widgetHandler.widgets) do
      if (widget:GetInfo().name == 'StartBox replacement') then
        widgetHandler:RemoveWidget(widget)
      end
    end
  end
  
  if (Spring.GetGameFrame() > 1) then
    widgetHandler:RemoveWidget(self)
    return
  end

  gl.Fog(false)

  local time = Spring.DiffTimers(Spring.GetTimer(), startTimer)

  -- show all start boxes
  if (drawGroundQuads) then

    gl.PolygonOffset(-25, -2)
    gl.Culling(GL.BACK)
    gl.DepthTest(true)


    for _,at in ipairs(Spring.GetAllyTeamList()) do
      if (true or at ~= gaiaAllyTeamID) then
        local xn, zn, xp, zp = Spring.GetAllyTeamStartBox(at)
        if (xn and ((xn ~= 0) or (zn ~= 0) or (xp ~= msx) or (zp ~= msz))) then
          --alpha = 0.10 + math.abs(((time*3)%1) - 0.5)*0.08
          alpha = 0.15
          if (at == Spring.GetMyAllyTeamID()) then
            color = { 0, 1, 0, alpha }  --  green
          else
            color = { 1, 0, 0, alpha }  --  red
          end
          gl.Color(color)
          gl.CallList(allyTeamGndLists[at])
        end
      end
    end

    gl.Texture(false)
    gl.TexGen(GL.T, false)

    gl.DepthTest(false)
    gl.Culling(false)
    gl.PolygonOffset(false)
  end

  gl.Fog(true)
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:DrawInMiniMap(sx, sz)

  gl.PushMatrix()
  gl.CallList(xformList)

  gl.LineWidth(1.49)

  local gaiaAllyTeamID
  local gaiaTeamID = Spring.GetGaiaTeamID()
  if (gaiaTeamID) then
    local _,_,_,_,_,_,atid = Spring.GetTeamInfo(gaiaTeamID)
    gaiaAllyTeamID = atid
  end

  -- show all start boxes
  for _,at in ipairs(Spring.GetAllyTeamList()) do
    if (at ~= gaiaAllyTeamID) then
      local xn, zn, xp, zp = Spring.GetAllyTeamStartBox(at)
      if (xn and ((xn ~= 0) or (zn ~= 0) or (xp ~= msx) or (zp ~= msz))) then
        local color
        if (at == Spring.GetMyAllyTeamID()) then
          color = { 0, 1, 0, 0.1 }  --  green
        else
          color = { 1, 0, 0, 0.1 }  --  red
        end
        gl.Color(color)
        gl.Rect(xn, zn, xp, zp)
        color[4] = 0.5  --  pump up the volume
        gl.Color(color)
        gl.PolygonMode(GL.FRONT_AND_BACK, GL.LINE)
        gl.Rect(xn, zn, xp, zp)
        gl.PolygonMode(GL.FRONT_AND_BACK, GL.FILL)
      end
    end
  end

  gl.LineWidth(1.0)
  gl.PointSize(1.0)
  gl.PopMatrix()
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
