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
    name      = "MiniMap Start Boxes",
    desc      = "MiniMap Start Boxes",
    author    = "trepan, jK",
    date      = "2007-2009",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (Game.startPosType ~= 2) then
  return false
end

if (Spring.GetGameFrame() > 1) then
  widgetHandler:RemoveWidget()
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  config options
--

-- enable simple version by default though
local drawGroundQuads = true


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local gl = gl  --  use a local copy for faster access

local msx = Game.mapSizeX
local msz = Game.mapSizeZ

local xformList = 0
local coneList = 0
local startboxDListStencil = 0
local startboxDListColor = 0

local gaiaTeamID
local gaiaAllyTeamID

local startTimer = Spring.GetTimer()

local texName = LUAUI_DIRNAME .. 'Images/highlight_strip.png'
local texScale = 512

--------------------------------------------------------------------------------

GL.KEEP = 0x1E00
GL.INCR_WRAP = 0x8507
GL.DECR_WRAP = 0x8508
GL.INCR = 0x1E02
GL.DECR = 0x1E03
GL.INVERT = 0x150A

local stencilBit1 = 0x01
local stencilBit2 = 0x10

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function DrawMyBox(minX,minY,minZ, maxX,maxY,maxZ)
  gl.BeginEnd(GL.QUADS, function()
    --// top
    gl.Vertex(minX, maxY, minZ);
    gl.Vertex(maxX, maxY, minZ);
    gl.Vertex(maxX, maxY, maxZ);
    gl.Vertex(minX, maxY, maxZ);
    --// bottom
    gl.Vertex(minX, minY, minZ);
    gl.Vertex(minX, minY, maxZ);
    gl.Vertex(maxX, minY, maxZ);
    gl.Vertex(maxX, minY, minZ);
  end);
  gl.BeginEnd(GL.QUAD_STRIP, function()
    --// sides
    gl.Vertex(minX, minY, minZ);
    gl.Vertex(minX, maxY, minZ);
    gl.Vertex(minX, minY, maxZ);
    gl.Vertex(minX, maxY, maxZ);
    gl.Vertex(maxX, minY, maxZ);
    gl.Vertex(maxX, maxY, maxZ);
    gl.Vertex(maxX, minY, minZ);
    gl.Vertex(maxX, maxY, minZ);
    gl.Vertex(minX, minY, minZ);
    gl.Vertex(minX, maxY, minZ);
  end);
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:Initialize()
  -- only show at the beginning
  if (Spring.GetGameFrame() > 1) then
    widgetHandler:RemoveWidget()
    return
  end

  -- get the gaia teamID and allyTeamID
  gaiaTeamID = Spring.GetGaiaTeamID()
  if (gaiaTeamID) then
    local _,_,_,_,_,atid = Spring.GetTeamInfo(gaiaTeamID)
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
    startboxDListStencil = gl.CreateList(function()
      local minY,maxY = Spring.GetGroundExtremes()
      minY = minY - 200; maxY = maxY + 100;
      for _,at in ipairs(Spring.GetAllyTeamList()) do
        if (true or at ~= gaiaAllyTeamID) then
          local xn, zn, xp, zp = Spring.GetAllyTeamStartBox(at)
          if (xn and ((xn ~= 0) or (zn ~= 0) or (xp ~= msx) or (zp ~= msz))) then

            if (at == Spring.GetMyAllyTeamID()) then
              gl.StencilMask(stencilBit2);
              gl.StencilFunc(GL.ALWAYS, 0, stencilBit2);
            else
              gl.StencilMask(stencilBit1);
              gl.StencilFunc(GL.ALWAYS, 0, stencilBit1);
            end
            DrawMyBox(xn,minY,zn, xp,maxY,zp)

          end
        end
      end
    end)

    startboxDListColor = gl.CreateList(function()
      local minY,maxY = Spring.GetGroundExtremes()
      minY = minY - 200; maxY = maxY + 100;
      for _,at in ipairs(Spring.GetAllyTeamList()) do
        if (true or at ~= gaiaAllyTeamID) then
          local xn, zn, xp, zp = Spring.GetAllyTeamStartBox(at)
          if (xn and ((xn ~= 0) or (zn ~= 0) or (xp ~= msx) or (zp ~= msz))) then

            if (at == Spring.GetMyAllyTeamID()) then
              gl.Color( 0, 1, 0, 0.3 )  --  green
              gl.StencilMask(stencilBit2);
              gl.StencilFunc(GL.NOTEQUAL, 0, stencilBit2);
            else
              gl.Color( 1, 0, 0, 0.3 )  --  red
              gl.StencilMask(stencilBit1);
              gl.StencilFunc(GL.NOTEQUAL, 0, stencilBit1);
            end
            DrawMyBox(xn,minY,zn, xp,maxY,zp)

          end
        end
      end
    end)
  end
end


function widget:Shutdown()
  gl.DeleteList(xformList)
  gl.DeleteList(coneList)
  gl.DeleteList(startboxDListStencil)
  gl.DeleteList(startboxDListColor)
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
    return colorStr, "s",outlineChar
  end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function DrawStartboxes3dWithStencil()
  gl.DepthMask(false);
  if (gl.DepthClamp) then gl.DepthClamp(true); end

  gl.DepthTest(true);
  gl.StencilTest(true);
  gl.ColorMask(false, false, false, false);
  gl.Culling(false);

  gl.StencilOp(GL.KEEP, GL.INVERT, GL.KEEP);

  gl.CallList(startboxDListStencil);   --// draw

  gl.Culling(GL.BACK);
  gl.DepthTest(false);

  gl.ColorMask(true, true, true, true);

  gl.CallList(startboxDListColor);   --// draw

  if (gl.DepthClamp) then gl.DepthClamp(false); end
  gl.StencilTest(false);
  gl.DepthTest(true);
  gl.Culling(false);
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:DrawWorld()
  gl.Fog(false)

  local time = Spring.DiffTimers(Spring.GetTimer(), startTimer)

  -- show the ally startboxes
  DrawStartboxes3dWithStencil()

  -- show the team start positions
  for _, teamID in ipairs(Spring.GetTeamList()) do
    local _,leader = Spring.GetTeamInfo(teamID)
    local _,_,spec = Spring.GetPlayerInfo(leader)
    if ((not spec) and (teamID ~= gaiaTeamID)) then
      local x, y, z = Spring.GetTeamStartPosition(teamID)
      if (x ~= nil and x > 0 and z > 0 and y > -500) then
        local color = GetTeamColor(teamID)
        local alpha = 0.5 + math.abs(((time * 3) % 1) - 0.5)
        gl.PushMatrix()
        gl.Translate(x, y, z)
        gl.Color(color[1], color[2], color[3], alpha)
        gl.CallList(coneList)
        gl.PopMatrix()
      end
    end
  end

  gl.Fog(true)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:DrawScreenEffects()
  -- show the names over the team start positions
  gl.Fog(false)
  gl.BeginText()
  for _, teamID in ipairs(Spring.GetTeamList()) do
    local _,leader = Spring.GetTeamInfo(teamID)
    local name,_,spec = Spring.GetPlayerInfo(leader)
    if ((not spec) and (teamID ~= gaiaTeamID)) then
      local colorStr, outlineStr = GetTeamColorStr(teamID)
      local x, y, z = Spring.GetTeamStartPosition(teamID)
      if (x ~= nil and x > 0 and z > 0 and y > -500) then
        local sx, sy, sz = Spring.WorldToScreenCoords(x, y + 120, z)
        if (sz < 1) then
          gl.Text(colorStr .. name, sx, sy, 18, 'cs')
        end
      end
    end
  end
  gl.EndText()
  gl.Fog(true)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:DrawInMiniMap(sx, sz)
  -- only show at the beginning
  if (Spring.GetGameFrame() > 1) then
    widgetHandler:RemoveWidget()
  end

  gl.PushMatrix()
  gl.CallList(xformList)

  gl.LineWidth(1.49)

  local gaiaAllyTeamID
  local gaiaTeamID = Spring.GetGaiaTeamID()
  if (gaiaTeamID) then
    local _,_,_,_,_,atid = Spring.GetTeamInfo(gaiaTeamID)
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

  gl.PushAttrib(GL_HINT_BIT)
  gl.Smoothing(true) --enable point smoothing

  -- show the team start positions
  for _, teamID in ipairs(Spring.GetTeamList()) do
    local _,leader = Spring.GetTeamInfo(teamID)
    local _,_,spec = Spring.GetPlayerInfo(leader)
    if ((not spec) and (teamID ~= gaiaTeamID)) then
      local x, y, z = Spring.GetTeamStartPosition(teamID)
      if (x ~= nil and x > 0 and z > 0 and y > -500) then
        local color = GetTeamColor(teamID)
        local r, g, b = color[1], color[2], color[3]
        local time = Spring.DiffTimers(Spring.GetTimer(), startTimer)
        local i = 2 * math.abs(((time * 3) % 1) - 0.5)
        gl.PointSize(11)
        gl.Color(i, i, i)
        gl.BeginEnd(GL.POINTS, gl.Vertex, x, z)
        gl.PointSize(7.5)
        gl.Color(r, g, b)
        gl.BeginEnd(GL.POINTS, gl.Vertex, x, z)
      end
    end
  end

  gl.LineWidth(1.0)
  gl.PointSize(1.0)
  gl.PopAttrib() --reset point smoothing
  gl.PopMatrix()
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
