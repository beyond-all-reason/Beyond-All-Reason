--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    selector.lua
--  brief:   the widget selector, loads and unloads widgets
--  author:  Dave Rodgers
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- changes:
--   jK (April@2009) - updated to new font system
--   Bluestone (Jan 2015) - added to BA as a widget, added various stuff 
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "Widget Selector",
    desc      = "Widget selection widget",
    author    = "trepan, jK, Bluestone",
    date      = "Jan 8, 2007",
    license   = "GNU GPL, v2 or later",
    layer     = -math.huge,
    handler   = true, 
    enabled   = true  
  }
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

-- relies on a gadget to implement "luarules reloadluaui"
-- relies on custom stuff in widgetHandler to implement blankOutConfig and allowUserWidgets

include("keysym.h.lua")
include("fonts.lua")

local WhiteStr   = "\255\255\255\255"
local RedStr     = "\255\255\001\001"
local GreenStr   = "\255\001\255\001"
local BlueStr    = "\255\001\001\255"
local CyanStr    = "\255\001\255\255"
local YellowStr  = "\255\255\255\001"
local MagentaStr = "\255\255\001\255"

local cutomScale = 1
local sizeMultiplier = 1

local floor = math.floor

local widgetsList = {}
local fullWidgetsList = {}

local vsx, vsy = widgetHandler:GetViewSizes()

local minMaxEntries = 15 
local curMaxEntries = 25

local startEntry = 1
local pageStep  = math.floor(curMaxEntries / 2) - 1

local fontSize = 12
local fontSpace = 7
local yStep = fontSize + fontSpace


local entryFont  = "LuaUI/Fonts/FreeMonoBold_12"
local headerFont  = "LuaUI/Fonts/FreeMonoBold_12"
entryFont  = ":n:" .. entryFont
headerFont = ":n:" .. headerFont

local bgPadding = 6
local bgcorner	= "LuaUI/Images/bgcorner.png"

local maxWidth = 0.01
local borderx = yStep * 0.75
local bordery = yStep * 0.75

local midx = vsx * 0.5
local minx = vsx * 0.4
local maxx = vsx * 0.6
local midy = vsy * 0.5
local miny = vsy * 0.4
local maxy = vsy * 0.6

local sbposx = 0.0
local sbposy = 0.0
local sbsizex = 0.0
local sbsizey = 0.0
local sby1 = 0.0
local sby2 = 0.0
local sbsize = 0.0
local sbheight = 0.0
local activescrollbar = false
local scrollbargrabpos = 0.0

local show = false
local pagestepped = false


local buttons = { --see MouseRelease for which functions are called by which buttons
    [1] = "Reload LuaUI",
    [2] = "Unload ALL Widgets",
    [3] = "Allow/Disallow User Widgets",
    [4] = "Reset LuaUI",
    [5] = "Factory Reset LuaUI",
}

local allowuserwidgets = true
if Spring.GetModOptions and (tonumber(Spring.GetModOptions().allowuserwidgets) or 1) == 0 then
  allowuserwidgets = false
  buttons[3] = ''
end

local titleFontSize = 16
local buttonFontSize = 14
local buttonHeight = 20
local buttonTop = 20 -- offset between top of buttons and bottom of widget

-------------------------------------------------------------------------------

function widget:Initialize()
  widgetHandler.knownChanged = true
  Spring.SendCommands('unbindkeyset f11')

  if allowuserwidgets then
    if widgetHandler.allowUserWidgets then
      buttons[3] = "Disallow User Widgets"
    else
      buttons[3] = "Allow User Widgets"
    end
  end
  if Spring.GetGameFrame() <= 0 then
    Spring.SendLuaRulesMsg('xmas'..((os.date("%m") == "12"  and  os.date("%d") >= "17") and '1' or '0'))
  end
end


-------------------------------------------------------------------------------


local function DrawRectRound(px,py,sx,sy,cs)
	gl.TexCoord(0.8,0.8)
	gl.Vertex(px+cs, py, 0)
	gl.Vertex(sx-cs, py, 0)
	gl.Vertex(sx-cs, sy, 0)
	gl.Vertex(px+cs, sy, 0)
	
	gl.Vertex(px, py+cs, 0)
	gl.Vertex(px+cs, py+cs, 0)
	gl.Vertex(px+cs, sy-cs, 0)
	gl.Vertex(px, sy-cs, 0)
	
	gl.Vertex(sx, py+cs, 0)
	gl.Vertex(sx-cs, py+cs, 0)
	gl.Vertex(sx-cs, sy-cs, 0)
	gl.Vertex(sx, sy-cs, 0)
	
	local offset = 0.07		-- texture offset, because else gaps could show
	local o = offset
	-- top left
	if py <= 0 or px <= 0 then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(px, py, 0)
	gl.TexCoord(o,1-offset)
	gl.Vertex(px+cs, py, 0)
	gl.TexCoord(1-offset,1-offset)
	gl.Vertex(px+cs, py+cs, 0)
	gl.TexCoord(1-offset,o)
	gl.Vertex(px, py+cs, 0)
	-- top right
	if py <= 0 or sx >= vsx then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(sx, py, 0)
	gl.TexCoord(o,1-offset)
	gl.Vertex(sx-cs, py, 0)
	gl.TexCoord(1-offset,1-offset)
	gl.Vertex(sx-cs, py+cs, 0)
	gl.TexCoord(1-offset,o)
	gl.Vertex(sx, py+cs, 0)
	-- bottom left
	if sy >= vsy or px <= 0 then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(px, sy, 0)
	gl.TexCoord(o,1-offset)
	gl.Vertex(px+cs, sy, 0)
	gl.TexCoord(1-offset,1-offset)
	gl.Vertex(px+cs, sy-cs, 0)
	gl.TexCoord(1-offset,o)
	gl.Vertex(px, sy-cs, 0)
	-- bottom right
	if sy >= vsy or sx >= vsx then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(sx, sy, 0)
	gl.TexCoord(o,1-offset)
	gl.Vertex(sx-cs, sy, 0)
	gl.TexCoord(1-offset,1-offset)
	gl.Vertex(sx-cs, sy-cs, 0)
	gl.TexCoord(1-offset,o)
	gl.Vertex(sx, sy-cs, 0)
end

function RectRound(px,py,sx,sy,cs)
	local px,py,sx,sy,cs = math.floor(px),math.floor(py),math.ceil(sx),math.ceil(sy),math.floor(cs)
	
	gl.Texture(bgcorner)
	gl.BeginEnd(GL.QUADS, DrawRectRound, px,py,sx,sy,cs)
	gl.Texture(false)
end


local function UpdateGeometry()
  midx  = vsx * 0.5
  midy  = vsy * 0.5

  local halfWidth = ((maxWidth+2) * fontSize) * sizeMultiplier * 0.5
  minx = floor(midx - halfWidth - (borderx*sizeMultiplier))
  maxx = floor(midx + halfWidth + (borderx*sizeMultiplier))

  local ySize = (yStep * sizeMultiplier) * (#widgetsList)
  miny = floor(midy - (0.5 * ySize)) - ((fontSize+bgPadding+bgPadding)*sizeMultiplier)
  maxy = floor(midy + (0.5 * ySize))
end


local function UpdateListScroll()
  local wCount = #fullWidgetsList
  local lastStart = lastStart or wCount - curMaxEntries + 1
  if (lastStart < 1) then lastStart = 1 end
  if (lastStart > wCount - curMaxEntries + 1) then lastStart = 1 end
  if (startEntry > lastStart) then startEntry = lastStart end
  if (startEntry < 1) then startEntry = 1 end
  
  widgetsList = {}
  local se = startEntry
  local ee = se + curMaxEntries - 1
  local n = 1
  for i = se, ee do
    widgetsList[n],n = fullWidgetsList[i],n+1
  end
end


local function ScrollUp(step)
  startEntry = startEntry - step
  UpdateListScroll()
end


local function ScrollDown(step)
  startEntry = startEntry + step
  UpdateListScroll()
end


function widget:MouseWheel(up, value)
  if not show then return false end
  
  local a,c,m,s = Spring.GetModKeyState()
  if (a or m) then
    return false  -- alt and meta allow normal control
  end
  local step = (s and 4) or (c and 1) or 2
  if (up) then
    ScrollUp(step)
  else
    ScrollDown(step)
  end
  return true
end


local function SortWidgetListFunc(nd1, nd2) --does nd1 come before nd2?
  -- widget profiler on top
  if nd1[1]=="Widget Profiler" then 
    return true 
  elseif nd2[1]=="Widget Profiler" then
    return false
  end
  
  -- mod widgets first, then user widgets
  if (nd1[2].fromZip ~= nd2[2].fromZip) then
    return nd1[2].fromZip  
  end
  
  -- sort by name
  return (nd1[1] < nd2[1]) 
end


local function UpdateList()
  if (not widgetHandler.knownChanged) then
    return
  end
  widgetHandler.knownChanged = false

  local myName = widget:GetInfo().name
  maxWidth = 0
  widgetsList = {}
  for name,data in pairs(widgetHandler.knownWidgets) do
    if (name ~= myName) then
      fullWidgetsList[#fullWidgetsList+1] = { name, data }
      -- look for the maxWidth
      local width = fontSize * gl.GetTextWidth(name)
      if (width > maxWidth) then
        maxWidth = width
      end
    end
  end
  
  maxWidth = (maxWidth / fontSize)

  local myCount = #fullWidgetsList
  if (widgetHandler.knownCount ~= (myCount + 1)) then
    error('knownCount mismatch')
  end

  table.sort(fullWidgetsList, SortWidgetListFunc)

  UpdateListScroll()
  UpdateGeometry()
end


function widget:ViewResize(viewSizeX, viewSizeY)
  vsx = viewSizeX
  vsy = viewSizeY

  if customScale == nil then
	customScale = 1
  end
  sizeMultiplier   = 0.6 + (vsx*vsy / 6000000) * customScale
  
  UpdateGeometry()
end


-------------------------------------------------------------------------------

function widget:KeyPress(key, mods, isRepeat)
  if (show and (key == KEYSYMS.ESCAPE) or
      ((key == KEYSYMS.F11) and not isRepeat and
       not (mods.alt or mods.ctrl or mods.meta or mods.shift))) then
    show = not show
    return true
  end
  if (show and key == KEYSYMS.PAGEUP) then
    ScrollUp(pageStep)
    return true
  end
  if (show and key == KEYSYMS.PAGEDOWN) then
    ScrollDown(pageStep)
    return true
  end
  return false
end
local activeGuishader = false
local scrollbarOffset = -15
function widget:DrawScreen()
  if not show then 
    if activeGuishader and (WG['guishader_api'] ~= nil) then
      activeGuishader = false
      WG['guishader_api'].RemoveRect('widgetselector')
    end
    return
  end
  UpdateList()
  gl.BeginText()
  if (WG['guishader_api'] == nil) then
    activeGuishader = false 
  end
  if (WG['guishader_api'] ~= nil) and not activeGuishader then
    activeGuishader = true
    WG['guishader_api'].InsertRect(minx-(bgPadding*sizeMultiplier), miny-(bgPadding*sizeMultiplier), maxx+(bgPadding*sizeMultiplier), maxy+(bgPadding*sizeMultiplier),'widgetselector')
  end
  borderx = (yStep*sizeMultiplier) * 0.75
  bordery = (yStep*sizeMultiplier) * 0.75

  -- draw the header
  gl.Text("Widget Selector", midx, maxy + ((8 + bgPadding)*sizeMultiplier), titleFontSize*sizeMultiplier, "oc")
  
  local mx,my,lmb,mmb,rmb = Spring.GetMouseState()
  local tcol = WhiteStr
    
  -- draw the -/+ buttons
  if maxx-10 < mx and mx < maxx and maxy < my and my < maxy + ((buttonFontSize + 7)*sizeMultiplier) then
    tcol = '\255\031\031\031'
  end
  gl.Text(tcol.."+", maxx, maxy + ((7 + bgPadding)*sizeMultiplier), buttonFontSize*sizeMultiplier, "or")
  tcol = WhiteStr
  if minx < mx and mx < minx+10 and maxy < my and my < maxy + ((buttonFontSize + 7)*sizeMultiplier) then
    tcol = '\255\031\031\031'
  end
  gl.Text(tcol.."-", minx, maxy + ((7 + bgPadding)*sizeMultiplier), buttonFontSize*sizeMultiplier, "ol")
  tcol = WhiteStr

  -- draw the box
  gl.Color(0,0,0,0.8)
  RectRound(minx-(bgPadding*sizeMultiplier), miny-(bgPadding*sizeMultiplier), maxx+(bgPadding*sizeMultiplier), maxy+(bgPadding*sizeMultiplier), 8*sizeMultiplier)
  
  gl.Color(0.33,0.33,0.33,0.2)
  RectRound(minx, miny, maxx, maxy, 8*sizeMultiplier)
  
  -- draw the text buttons (at the bottom) & their outlines
  for i,name in ipairs(buttons) do
    tcol = WhiteStr
    if minx < mx and mx < maxx and miny - (buttonTop*sizeMultiplier) - i*(buttonHeight*sizeMultiplier) < my and my < miny - (buttonTop*sizeMultiplier) - (i-1)*(buttonHeight*sizeMultiplier) then
      tcol = '\255\031\031\031'
    end
    gl.Text(tcol .. buttons[i], (minx+maxx)/2, miny - (buttonTop*sizeMultiplier) - (i*(buttonHeight*sizeMultiplier)), buttonFontSize*sizeMultiplier, "oc")
  end
  
  
  -- draw the widgets
  local nd = not widgetHandler.tweakMode and self:AboveLabel(mx, my)
  local pointedY = nil
  local pointedEnabled = false
  local pointedName = (nd and nd[1]) or nil
  local posy = maxy - ((yStep+bgPadding)*sizeMultiplier)
  sby1 = posy + ((fontSize + fontSpace)*sizeMultiplier) * 0.5
  for _,namedata in ipairs(widgetsList) do
    local name = namedata[1]
    local data = namedata[2]
    local color = ''
    local pointed = (pointedName == name)
    local order = widgetHandler.orderList[name]
    local enabled = order and (order > 0)
    local active = data.active
    if (pointed and not activescrollbar) then
      pointedY = posy
      pointedEnabled = data.active
      if not pagestepped and (lmb or mmb or rmb) then
        color = WhiteStr
      else
        color = (active  and '\255\128\255\128') or
                (enabled and '\255\255\255\128') or '\255\255\128\128'
      end
    else
      color = (active  and '\255\064\224\064') or
              (enabled and '\255\200\200\064') or '\255\224\064\064'
    end

    local tmpName
    if (data.fromZip) then
      -- FIXME: extra chars not counted in text length
      tmpName = WhiteStr .. '*' .. color .. name .. WhiteStr .. '*'
    else
      tmpName = color .. name
    end

    gl.Text(color..tmpName, midx, posy + (fontSize*sizeMultiplier) * 0.5, fontSize*sizeMultiplier, "vc")
    posy = posy - (yStep*sizeMultiplier)
  end
  
  
  -- scrollbar
  if #widgetsList < #fullWidgetsList then
    sby2 = posy + (yStep * sizeMultiplier) - (fontSpace*sizeMultiplier) * 0.5
    sbheight = sby1 - sby2
    sbsize = sbheight * #widgetsList / #fullWidgetsList 
    if activescrollbar then
    	startEntry = math.max(0, math.min(
    	math.floor(#fullWidgetsList * 
    	((sby1 - sbsize) - 
    	(my - math.min(scrollbargrabpos, sbsize)))
    	 / sbheight + 0.5), 
        #fullWidgetsList - curMaxEntries)) + 1
    end
    local sizex = maxx - minx
    sbposx = minx + sizex + 1.0 + scrollbarOffset
    sbposy = sby1 - sbsize - sbheight * (startEntry - 1) / #fullWidgetsList
    sbsizex = (yStep * sizeMultiplier)
    sbsizey = sbsize
    
    local trianglePadding = 4*sizeMultiplier
    local scrollerPadding = 8*sizeMultiplier
    
    -- background
    --gl.Color(0.0, 0.0, 0.0, 0.2)
	--RectRound(sbposx, miny, sbposx + sbsizex, maxy, 6*sizeMultiplier)
    if (sbposx < mx and mx < sbposx + sbsizex and miny < my and my < maxy) or activescrollbar then
      gl.Color(1,1,1,0.04)
	  RectRound(sbposx, miny, sbposx + sbsizex, maxy, 6*sizeMultiplier)
    end
    
    --[[gl.Color(1.0, 1.0, 1.0, 0.15)
    gl.Shape(GL.TRIANGLES, {
      { v = { sbposx + sbsizex / 2, miny + trianglePadding } },
      { v = { sbposx + trianglePadding, sby2 - 1 - trianglePadding} },
      { v = { sbposx + sbsizex - trianglePadding, sby2 - 1 - trianglePadding} }
    })
    gl.Shape(GL.TRIANGLES, {
      { v = { sbposx + sbsizex / 2, maxy - trianglePadding } },
      { v = { sbposx - trianglePadding + sbsizex, sby2 + sbheight + 1 + trianglePadding} },
      { v = { sbposx + trianglePadding, sby2 + sbheight + 1 + trianglePadding} }
    })]]--
    
    -- scroller
    if (sbposx < mx and mx < sbposx + sbsizex and sby2 < my and my < sby2 + sbheight) then
      gl.Color(1.0, 1.0, 1.0, 0.4) 
      gl.Blending(GL.SRC_ALPHA, GL.ONE)
	  RectRound(sbposx+scrollerPadding, sbposy, sbposx + sbsizex - scrollerPadding, sbposy + sbsizey, 1.75*sizeMultiplier)
      gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
    end
    gl.Color(0.33, 0.33, 0.33, 0.8)
	RectRound(sbposx+scrollerPadding, sbposy, sbposx + sbsizex - scrollerPadding, sbposy + sbsizey, 1.75*sizeMultiplier)
  else
    sbposx = 0.0
    sbposy = 0.0
    sbsizex = 0.0
    sbsizey = 0.0
  end


  -- highlight label
  if (sbposx < mx and mx < sbposx + sbsizex and miny < my and my < maxy) or activescrollbar then
  
  else
    if (pointedY) then
    gl.Color(1.0, 1.0, 1.0, 0.09)
    local xn = minx + 0.5
    local xp = maxx - 0.5
    local yn = pointedY - ((fontSpace * 0.5 + 1)*sizeMultiplier)
    local yp = pointedY + ((fontSize + fontSpace * 0.5 + 1)*sizeMultiplier)
    if scrollbarOffset < 0 then
    	xp = xp + scrollbarOffset
    	--xn = xn - scrollbarOffset
    end
    yn = yn + 0.5
    yp = yp - 0.5
    gl.Blending(GL.SRC_ALPHA, GL.ONE)
    RectRound(xn, yn, xp, yp, 5*sizeMultiplier)
    gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
end
  end
  
  gl.EndText()
end


function widget:MousePress(x, y, button)
  if (Spring.IsGUIHidden()) or not show then
    return false
  end

  UpdateList()

  if button == 1 then
    -- above a button
    if minx < x and x < maxx and miny - (buttonTop*sizeMultiplier) - #buttons*(buttonHeight*sizeMultiplier) < y and y < miny - (buttonTop*sizeMultiplier) then
      return true
    end
    
    -- above the -/+ 
    if maxx-10 < x and x < maxx and maxy + bgPadding < y and y < maxy + ((buttonFontSize + 7 + bgPadding)*sizeMultiplier) then
      return true
    end
    if minx < x and x < minx+10 and maxy + bgPadding < y and y < maxy + ((buttonFontSize + 7 + bgPadding)*sizeMultiplier) then
      return true
    end
    
  -- above the scrollbar
  if ((x >= minx + scrollbarOffset) and (x <= maxx + scrollbarOffset + (yStep * sizeMultiplier))) then
    if ((y >= (maxy - bordery)) and (y <= maxy)) then
      if x > maxx+scrollbarOffset then
        ScrollUp(1)
      else
        ScrollUp(pageStep)
      end
      return true
    elseif ((y >= miny) and (y <= miny + bordery)) then
      if x > maxx+scrollbarOffset then
        ScrollDown(1)
      else
        ScrollDown(pageStep)
      end
      return true
    end
  end
    
    -- above the list    
    if sbposx < x and x < sbposx + sbsizex and sbposy < y and y < sbposy + sbsizey then
      activescrollbar = true
      scrollbargrabpos = y - sbposy
      return true
    elseif sbposx < x and x < sbposx + sbsizex and sby2 < y and y < sby2 + sbheight then
      if y > sbposy + sbsizey then
        startEntry = math.max(1, math.min(startEntry - curMaxEntries, #fullWidgetsList - curMaxEntries + 1))
      elseif y < sbposy then
        startEntry = math.max(1, math.min(startEntry + curMaxEntries, #fullWidgetsList - curMaxEntries + 1))
      end
      UpdateListScroll()
      pagestepped = true
      return true   
    end
  end
  
  local namedata = self:AboveLabel(x, y)
  if (not namedata) then
    show = false
    return false
  end
  
  
  return true
  
end


function widget:MouseMove(x, y, dx, dy, button)
  if show and activescrollbar then
    startEntry = math.max(0, math.min(math.floor((#fullWidgetsList * ((sby1 - sbsize) - (y - math.min(scrollbargrabpos, sbsize))) / sbheight) + 0.5), 
    #fullWidgetsList - curMaxEntries)) + 1
    UpdateListScroll()
    return true
  end
  return false
end


function widget:MouseRelease(x, y, mb)
  if (Spring.IsGUIHidden()) or not show then
    return -1
  end

  UpdateList()
  if pagestepped then
	  pagestepped = false
	  return true
  end
  
  if mb == 1 and activescrollbar then
    activescrollbar = false
    scrollbargrabpos = 0.0
    return -1
  end
  
  if mb == 1 then
    if maxx-10 < x and x < maxx and maxy + bgPadding < y and y < maxy + buttonFontSize + 7 + bgPadding then
      -- + button
      curMaxEntries = curMaxEntries + 1
      UpdateListScroll()
      UpdateGeometry()
      Spring.WarpMouse(x, y+0.5*(fontSize+fontSpace))
      return -1
    end
    if minx < x and x < minx+10 and maxy + bgPadding < y and y < maxy + buttonFontSize + 7 + bgPadding then
      -- - button
      if curMaxEntries > minMaxEntries then
        curMaxEntries = curMaxEntries - 1
        UpdateListScroll()
        UpdateGeometry()
        Spring.WarpMouse(x, y-0.5*(fontSize+fontSpace))
      end
      return -1
    end
  end

  if mb == 1 then
    local buttonID = nil
    for i,_ in ipairs(buttons) do
        if minx < x and x < maxx and miny - (buttonTop*sizeMultiplier) - i*(buttonHeight*sizeMultiplier) < y and y < miny - (buttonTop*sizeMultiplier) - (i-1)*(buttonHeight*sizeMultiplier) then
            buttonID = i
            break
        end
    end
    if buttonID == 1 then
      Spring.SendCommands("luarules reloadluaui")
      return -1
    end
    if buttonID == 2 then
      -- disable all widgets, but don't reload
      for _,namedata in ipairs(fullWidgetsList) do
        widgetHandler:DisableWidget(namedata[1])
      end
      widgetHandler:SaveConfigData()    
      return -1
    end
    if buttonID == 3 and allowuserwidgets then
      -- tell the widget handler that we allow/disallow user widgets and reload
      if widgetHandler.allowUserWidgets then
        widgetHandler.__allowUserWidgets = false
        Spring.Echo("Disallowed user widgets, reloading...")
      else
        widgetHandler.__allowUserWidgets = true
        Spring.Echo("Allowed user widgets, reloading...")      
      end
      Spring.SendCommands("luarules reloadluaui")
      return -1
    end
    if buttonID == 4 then
      Spring.SendCommands("luaui reset")
      return -1
    end
    if buttonID == 5 then
      Spring.SendCommands("luaui factoryreset")
      return -1
    end
  end
  
  local namedata = self:AboveLabel(x, y)
  if (not namedata) then
    return false
  end
  
  local name = namedata[1]
  local data = namedata[2]
  
  if (mb == 1) then
    widgetHandler:ToggleWidget(name)
  elseif ((button == 2) or (button == 3)) then
    local w = widgetHandler:FindWidget(name)
    if (not w) then return -1 end
    if (button == 2) then
      widgetHandler:LowerWidget(w)
    else
      widgetHandler:RaiseWidget(w)
    end
    widgetHandler:SaveConfigData()
  end
  return -1
end


function widget:AboveLabel(x, y)
  if ((x < minx) or (y < (miny + bordery)) or
      (x > maxx) or (y > (maxy - bordery))) then
    return nil
  end
  local count = #widgetsList
  if (count < 1) then return nil end
  
  local i = floor(1 + ((maxy - bordery) - y) / (yStep * sizeMultiplier))
  if     (i < 1)     then i = 1
  elseif (i > count) then i = count end
  
  return widgetsList[i]
end


function widget:IsAbove(x, y)
  if not show then return false end 
  UpdateList()
  if ((x < minx) or (x > maxx + (yStep * sizeMultiplier)) or
      (y < miny - #buttons*buttonHeight) or (y > maxy+bgPadding)) then
    return false
  end
  return true
end


function widget:GetTooltip(x, y)
  if not show then return nil end 

  UpdateList()  
  local namedata = self:AboveLabel(x, y)
  if (not namedata) then
    return '\255\200\255\200'..'Widget Selector\n'    ..
           '\255\255\255\200'..'LMB: toggle widget\n' ..
           '\255\255\200\200'..'MMB: lower  widget\n' ..
           '\255\200\200\255'..'RMB: raise  widget'
  end

  local n = namedata[1]
  local d = namedata[2]

  local order = widgetHandler.orderList[n]
  local enabled = order and (order > 0)
  
  local tt = (d.active and GreenStr) or (enabled  and YellowStr) or RedStr
  tt = tt..n..'\n'
  tt = d.desc   and tt..WhiteStr..d.desc..'\n' or tt
  tt = d.author and tt..BlueStr..'Author:  '..CyanStr..d.author..'\n' or tt
  tt = tt..MagentaStr..d.basename
  if (d.fromZip) then
    tt = tt..RedStr..' (mod widget)'
  end
  return tt
end

function widget:GetConfigData()
    local data = {startEntry=startEntry, curMaxEntries=curMaxEntries, show=show} 
    return data
end

function widget:SetConfigData(data)
    startEntry = data.startEntry or startEntry
    curMaxEntries = data.curMaxEntries or curMaxEntries
    show = data.show or show
end

function widget:TextCommand(s) 
  -- process request to tell the widgetHandler to blank out the widget config when it shuts down
  local token = {}
  local n = 0
  for w in string.gmatch(s, "%S+") do
    n = n + 1
    token[n] = w		
  end
  if n==1 and token[1]=="reset" then
    -- tell the widget handler to reload with a blank config
    widgetHandler.blankOutConfig = true
    Spring.SendCommands("luarules reloadluaui") 
  end
  if n==1 and token[1]=="factoryreset" then
    -- tell the widget handler to disallow user widgets and reload with a blank config
    widgetHandler.__blankOutConfig = true
    widgetHandler.__allowUserWidgets = false
    Spring.SendCommands("luarules reloadluaui") 
  end
end
        


function widget:Shutdown()
  Spring.SendCommands('bind f11 luaui selector') -- if this one is removed or crashes, then have the backup one take over.
  
	if (WG['guishader_api'] ~= nil) then
		WG['guishader_api'].RemoveRect('widgetselector')
	end
end


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
