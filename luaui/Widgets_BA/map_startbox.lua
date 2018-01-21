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
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "Start Boxes",
    desc      = "Displays Start Boxes and Start Points",
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
  widgetHandler:RemoveWidget(self)
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

local useThickLeterring		= true
local heightOffset			= 50
local fontSize				= 18
local fontShadow			= true		-- only shows if font has a white outline
local shadowOpacity			= 0.35
local font = gl.LoadFont("LuaUI/Fonts/FreeSansBold.otf", 55, 10, 10)
local shadowFont = gl.LoadFont("LuaUI/Fonts/FreeSansBold.otf", 55, 38, 1.6)

local infotext = "Pick a startspot within the green area, and click the Ready button. (F4 shows metal spots)"
local infotextFontsize = 20
local infotextWidth = gl.GetTextWidth(infotext) * infotextFontsize

local comnameList = {}
local drawShadow = fontShadow
local usedFontSize = fontSize

local vsx,vsy = Spring.GetViewGeometry()

local gl = gl  --  use a local copy for faster access

local msx = Game.mapSizeX
local msz = Game.mapSizeZ

local xformList = 0
local coneList = 0
local startboxDListStencil = 0
local startboxDListColor = 0

local isSpec = Spring.GetSpectatingState() or Spring.IsReplay()

local gaiaTeamID
local gaiaAllyTeamID

local startTimer = Spring.GetTimer()

local texName = 'LuaUI/Images/highlight_strip.png'
local texScale = 512


local GetUnitTeam        		= Spring.GetUnitTeam
local GetTeamInfo        		= Spring.GetTeamInfo
local GetPlayerInfo      		= Spring.GetPlayerInfo
local GetPlayerList    		    = Spring.GetPlayerList
local GetTeamColor       		= Spring.GetTeamColor
local GetVisibleUnits    		= Spring.GetVisibleUnits
local GetUnitDefID       		= Spring.GetUnitDefID
local GetAllUnits        		= Spring.GetAllUnits
local IsUnitInView	 	 		= Spring.IsUnitInView
local GetCameraPosition  		= Spring.GetCameraPosition
local GetUnitPosition    		= Spring.GetUnitPosition
local GetFPS					= Spring.GetFPS

local glPushMatrix      		= gl.PushMatrix
local glPopMatrix       		= gl.PopMatrix
local glDepthTest        		= gl.DepthTest
local glAlphaTest        		= gl.AlphaTest
local glColor            		= gl.Color
local glText             		= gl.Text
local glTranslate        		= gl.Translate
local glBillboard        		= gl.Billboard
local glDrawFuncAtUnit   		= gl.DrawFuncAtUnit
local glDrawListAtUnit   		= gl.DrawListAtUnit
local GL_GREATER     	 		= GL.GREATER
local GL_SRC_ALPHA				= GL.SRC_ALPHA	
local GL_ONE_MINUS_SRC_ALPHA	= GL.ONE_MINUS_SRC_ALPHA
local glBlending          		= gl.Blending
local glScale          			= gl.Scale

local glCreateList				= gl.CreateList
local glBeginEnd				= gl.BeginEnd
local glDeleteList				= gl.DeleteList
local glCallList				= gl.CallList

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


local function createComnameList(x, y, name, teamID, color)
	comnameList[teamID] = {}
	comnameList[teamID]['x'] = math.floor(x)
	comnameList[teamID]['y'] = math.floor(y)
	comnameList[teamID]['list'] = gl.CreateList( function()
		local outlineColor = {0,0,0,1}
		if (color[1] + color[2]*1.2 + color[3]*0.4) < 0.8 then
			outlineColor = {1,1,1,1}
		end
		if useThickLeterring then
			if outlineColor[1] == 1 and fontShadow then
			  glTranslate(0, -(usedFontSize/44), 0)
			  shadowFont:Begin()
			  shadowFont:SetTextColor({0,0,0,shadowOpacity})
			  shadowFont:SetOutlineColor({0,0,0,shadowOpacity})
			  shadowFont:Print(name, x, y, usedFontSize, "con")
			  shadowFont:End()
			  glTranslate(0, (usedFontSize/44), 0)
			end
			font:SetTextColor(outlineColor)
			font:SetOutlineColor(outlineColor)
			
			font:Print(name, x-(usedFontSize/38), y-(usedFontSize/33), usedFontSize, "con")
			font:Print(name, x+(usedFontSize/38), y-(usedFontSize/33), usedFontSize, "con")
		end
		font:Begin()
		font:SetTextColor(color)
		font:SetOutlineColor(outlineColor)
		font:Print(name, x, y, usedFontSize, "con")
		font:End()
	end)
end

local function DrawName(x, y, name, teamID, color)
	-- not optimal, everytime you move camera the x and y are different so it has to recreate the drawlist
	if comnameList[teamID] == nil or comnameList[teamID]['x'] ~= math.floor(x) or comnameList[teamID]['y'] ~= math.floor(y) then		-- using floor because the x and y values had a a tiny change each frame
		if comnameList[teamID] ~= nil then
			gl.DeleteList(comnameList[teamID]['list'])
		end
		createComnameList(x, y, name, teamID, color)
	end
	glCallList(comnameList[teamID]['list'])
end

function widget:Initialize()
  -- only show at the beginning
  if (Spring.GetGameFrame() > 1) then
    widgetHandler:RemoveWidget(self)
    return
  end

  infotextList = gl.CreateList(function()
		gl.Color(1,1,1,0.5)
		gl.Text(infotext, 0,0, infotextFontsize, "cno")
  end)
  
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
      minY = minY - 200; maxY = maxY + 500;
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
            DrawMyBox(xn-1,minY,zn-1, xp+1,maxY,zp+1)

          end
        end
      end
    end)

    startboxDListColor = gl.CreateList(function()
      local minY,maxY = Spring.GetGroundExtremes()
      minY = minY - 200; maxY = maxY + 500;
      for _,at in ipairs(Spring.GetAllyTeamList()) do
        if (true or at ~= gaiaAllyTeamID) then
          local xn, zn, xp, zp = Spring.GetAllyTeamStartBox(at)
          if (xn and ((xn ~= 0) or (zn ~= 0) or (xp ~= msx) or (zp ~= msz))) then

            if (at == Spring.GetMyAllyTeamID()) then
              gl.Color( 0, 1, 0, 0.22 )  --  green
              gl.StencilMask(stencilBit2);
              gl.StencilFunc(GL.NOTEQUAL, 0, stencilBit2);
            else
              gl.Color( 1, 0, 0, 0.22 )  --  red
              gl.StencilMask(stencilBit1);
              gl.StencilFunc(GL.NOTEQUAL, 0, stencilBit1);
            end
            DrawMyBox(xn-1,minY,zn-1, xp+1,maxY,zp+1)

          end
        end
      end
    end)
  end
end



function widget:Shutdown()
  gl.DeleteList(infotextList)
  gl.DeleteList(xformList)
  gl.DeleteList(coneList)
  gl.DeleteList(startboxDListStencil)
  gl.DeleteList(startboxDListColor)
  removeTeamLists()
end


function removeTeamLists()
  for _, teamID in ipairs(Spring.GetTeamList()) do
    if comnameList[teamID] ~= nil then
      gl.DeleteList(comnameList[teamID]['list'])
      comnameList[teamID] = nil
    end
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
  --gl.Fog(false)

  local time = Spring.DiffTimers(Spring.GetTimer(), startTimer)

  -- show the ally startboxes
  DrawStartboxes3dWithStencil()

  -- show the team start positions
  for _, teamID in ipairs(Spring.GetTeamList()) do
    local _,leader = Spring.GetTeamInfo(teamID)
    local _,_,spec = Spring.GetPlayerInfo(leader)
    if ((not spec) and (teamID ~= gaiaTeamID)) then
      local x, y, z = Spring.GetTeamStartPosition(teamID)
	  local isNewbie = (Spring.GetTeamRulesParam(teamID, 'isNewbie') == 1) -- =1 means the startpoint will be replaced and chosen by initial_spawn
	  if (x ~= nil and x > 0 and z > 0 and y > -500) and not isNewbie then
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

  --gl.Fog(true)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:DrawScreenEffects()
  -- show the names over the team start positions
  --gl.Fog(false)
  for _, teamID in ipairs(Spring.GetTeamList()) do
    local _,leader = Spring.GetTeamInfo(teamID)
    local name,_,spec = Spring.GetPlayerInfo(leader)
	local isNewbie = (Spring.GetTeamRulesParam(teamID, 'isNewbie') == 1) -- =1 means the startpoint will be replaced and chosen by initial_spawn
    if (name ~= nil) and ((not spec) and (teamID ~= gaiaTeamID)) and not isNewbie then
      local colorStr, outlineStr = GetTeamColorStr(teamID)
      local x, y, z = Spring.GetTeamStartPosition(teamID)
      if (x ~= nil and x > 0 and z > 0 and y > -500) then
        local sx, sy, sz = Spring.WorldToScreenCoords(x, y + 120, z)
        if (sz < 1) then
          
			DrawName(sx, sy, name, teamID, GetTeamColor(teamID))
	
        end
      end
    end
  end
  --gl.Fog(true)
end


function widget:DrawScreen()
	if not isSpec then
		gl.PushMatrix()
			gl.Translate(vsx/2, vsy/6.2, 0)
			gl.Scale(1*widgetScale, 1*widgetScale, 1)
		  gl.CallList(infotextList)
	  gl.PopMatrix()
  end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:DrawInMiniMap(sx, sz)
  -- only show at the beginning
  if (Spring.GetGameFrame() > 1) then
    widgetHandler:RemoveWidget(self)
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
  --gl.Smoothing(true) --enable point smoothing

  -- show the team start positions
  for _, teamID in ipairs(Spring.GetTeamList()) do
    local _,leader = Spring.GetTeamInfo(teamID)
    local _,_,spec = Spring.GetPlayerInfo(leader)
    if ((not spec) and (teamID ~= gaiaTeamID)) then
      local x, y, z = Spring.GetTeamStartPosition(teamID)
	  local isNewbie = (Spring.GetTeamRulesParam(teamID, 'isNewbie') == 1) -- =1 means the startpoint will be replaced and chosen by initial_spawn
	  if (x ~= nil and x > 0 and z > 0 and y > -500) and not isNewbie then
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


function widget:ViewResize(x, y)
  vsx,vsy = x,y
  widgetScale = (0.75 + (vsx*vsy / 7500000))
  removeTeamLists()
  usedFontSize = fontSize/1.44 + (fontSize * ((vsx*vsy / 10000000)))
end


-- reset needed when waterlevel has changed by gadget (modoption)
if (Spring.GetModOptions() ~= nil and Spring.GetModOptions().map_waterlevel ~= 0) then
  local resetsec = 0
  local resetted = false
  function widget:Update(dt)
    if not resetted then
      resetsec = resetsec + dt
      if resetsec > 1 then
        resetted = true
        widget:Shutdown()
        widget:Initialize()
      end
    end
  end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
