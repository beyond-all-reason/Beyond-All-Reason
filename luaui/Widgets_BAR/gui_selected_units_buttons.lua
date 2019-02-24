--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    gui_selbuttons.lua
--  brief:   adds a selected units button control panel
--  author:  Dave Rodgers
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "Selected Units Buttons",
    desc      = "Buttons for the current selection",
    author    = "trepan, Floris",
    date      = "28 may 2015",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Automatically generated local definitions

local GL_ONE                   = GL.ONE
local GL_ONE_MINUS_SRC_ALPHA   = GL.ONE_MINUS_SRC_ALPHA
local GL_SRC_ALPHA             = GL.SRC_ALPHA
local glBlending               = gl.Blending
local glBeginEnd               = gl.BeginEnd
local glClear                  = gl.Clear
local glColor                  = gl.Color
local glPopMatrix              = gl.PopMatrix
local glPushMatrix             = gl.PushMatrix
local glRect                   = gl.Rect
local glRotate                 = gl.Rotate
local glScale                  = gl.Scale
local glTexRect                = gl.TexRect
local glGetTextWidth           = gl.GetTextWidth
local glGetTextHeight          = gl.GetTextHeight
local glText                   = gl.Text
local glTexture                = gl.Texture
local glTranslate              = gl.Translate
local glUnitDef                = gl.UnitDef
local glVertex                 = gl.Vertex
local spGetModKeyState         = Spring.GetModKeyState
local spGetMouseState          = Spring.GetMouseState
local spGetMyTeamID            = Spring.GetMyTeamID
local spGetSelectedUnits       = Spring.GetSelectedUnits
local spGetSelectedUnitsCounts = Spring.GetSelectedUnitsCounts
local spGetSelectedUnitsSorted = Spring.GetSelectedUnitsSorted
local spGetTeamUnitsSorted     = Spring.GetTeamUnitsSorted
local spSelectUnitArray        = Spring.SelectUnitArray
local spSelectUnitMap          = Spring.SelectUnitMap
local spSendCommands           = Spring.SendCommands
local spIsGUIHidden            = Spring.IsGUIHidden
local spGetSelectedUnitsCount  = Spring.GetSelectedUnitsCount


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------


local ui_opacity = Spring.GetConfigFloat("ui_opacity",0.66)

local bgcorner = ":n:LuaUI/Images/bgcorner.png"
local highlightImg = ":n:LuaUI/Images/button-highlight.dds"

local iconsPerRow = 16		-- not functional yet, I doubt I will put this in

local leftmouseColor = {1, 0.72, 0.25, 0.22}
local middlemouseColor = {1, 1, 1, 0.16}
local rightmouseColor = {1, 0.4, 0.4, 0.2}
--local hoverColor = { 1, 1, 1, 0.25 }

local unitTypes = 0
local countsTable = {}
local activePress = false
local mouseIcon = -1
local currentDef = nil
local prevUnitCount = spGetSelectedUnitsCounts()
local oldUnitpics = false

local iconSizeX = 64
local iconSizeY = 64
local iconImgMult = 0.85

local usedIconSizeX = iconSizeX
local usedIconSizeY = iconSizeY
local rectMinX = 0
local rectMaxX = 0
local rectMinY = 0
local rectMaxY = 0

local backgroundDimentions = {}
local iconMargin = usedIconSizeX / 25		-- changed in ViewResize anyway
local fontSize = iconSizeY * 0.28		-- changed in ViewResize anyway
local picList

local playSounds = true
local leftclick = 'LuaUI/Sounds/buildbar_add.wav'
local middleclick = 'LuaUI/Sounds/buildbar_click.wav'
local rightclick = 'LuaUI/Sounds/buildbar_rem.wav'

local guishaderDisabled = true
if spGetSelectedUnitsCount() > 0 then
  local checkSelectedUnits = true
end
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------


local function updateGuishader()
	if (WG['guishader_api'] ~= nil) then
		if not picList then
			WG['guishader_api'].RemoveRect('selectionbuttons')
            guishaderDisabled = true
		else
			if backgroundDimentions[1] ~= nil then
				WG['guishader_api'].InsertRect(
					backgroundDimentions[1],
					backgroundDimentions[2],
					backgroundDimentions[3],
					backgroundDimentions[4],
					'selectionbuttons'
				)
                guishaderDisabled = false
			end
		end
	end
end

local vsx, vsy = widgetHandler:GetViewSizes()
function widget:ViewResize(viewSizeX, viewSizeY)
  vsx = viewSizeX
  vsy = viewSizeY
  
  usedIconSizeX = math.floor((iconSizeX/2) + ((vsx*vsy) / 115000))
  usedIconSizeY =  math.floor((iconSizeY/2) + ((vsx*vsy) / 115000))
  fontSize = usedIconSizeY * 0.28
  iconMargin = usedIconSizeX / 25
  
  if picList then
    unitCounts = spGetSelectedUnitsCounts()
    gl.DeleteList(picList)
	picList = gl.CreateList(DrawPicList)
  end
end

function cacheUnitIcons()
    if cached == nil then
        gl.Color(1,1,1,0.001)
        for id, unit in pairs(UnitDefs) do
            if oldUnitpics and UnitDefs[id] ~= nil and VFS.FileExists('unitpics/'..UnitDefs[id].name..'.dds') then
                gl.Texture('unitpics/'..UnitDefs[id].name..'.dds')
            else
                gl.Texture('#' .. id)
            end
            gl.TexRect(-1,-1,0,0)
            gl.Texture(false)
        end
        gl.Color(1,1,1,1)
        cached = true
    end
end

local prevMouseIcon
local hoverClock = nil
function widget:DrawScreen()
  cacheUnitIcons()    -- else white icon bug happens
  if picList then
    if (spIsGUIHidden()) then return end
    if mouseIcon ~= prevMouseIcon then
      unitCounts = spGetSelectedUnitsCounts()
      gl.DeleteList(picList)
      picList = gl.CreateList(DrawPicList)
      prevMouseIcon = mouseIcon
    end
    gl.CallList(picList)
    -- draw the highlights
    local x,y,lb,mb,rb = spGetMouseState()
    mouseIcon = MouseOverIcon(x, y)
    if (not widgetHandler:InTweakMode() and (mouseIcon >= 0)) then
      if (lb or mb or rb) then
        if lb then
          DrawIconQuad(mouseIcon, leftmouseColor)  --  click highlight
        elseif mb then
          DrawIconQuad(mouseIcon, middlemouseColor)  --  click highlight
        elseif rb then
          DrawIconQuad(mouseIcon, rightmouseColor)  --  click highlight
        end
      else
        --DrawIconQuad(mouseIcon, hoverColor)  --  hover highlight
      end
      if hoverClock == nil then hoverClock = os.clock() end
      if WG['tooltip'] ~= nil and os.clock() - hoverClock > 0.6 then
        WG['tooltip'].ShowTooltip('selectedunitbuttons', "\255\215\255\215Selected units\n \255\255\255\255Left click\255\210\210\210: Remove all other unit types\n \255\255\255\255Left click + CTRL\255\210\210\210: Select all units of this type on map\n \255\255\255\255Left click + ALT\255\210\210\210: Remove all by 1 unit of this unit type\n \255\255\255\255Right click\255\210\210\210: Remove that unit type from the selection\n \255\255\255\255Right click + CTRL\255\210\210\210: Only remove 1 unit from that unit type\n \255\255\255\255Middle click\255\210\210\210: Move to the center location of the selected unit(s)\n \255\255\255\255Middle click + CTRL\255\210\210\210: Move to the center off whole selection")
      end
    else
      hoverClock = nil
    end
  end
end

function widget:CommandsChanged()
  if spGetSelectedUnitsCount() > 0 then
    checkSelectedUnits = true
    --updateDlist = true
  elseif picList then
    gl.DeleteList(picList)
    picList = nil
    checkSelectedUnits = nil
  end
  if not picList and not guishaderDisabled then
    updateGuishader()
  end
  sec = 0
end

function widget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
  if unitCounts ~= nil and unitCounts[unitDefID] ~= nil then
    if unitCounts[unitDefID] > 1 then
      unitCounts[unitDefID] = unitCounts[unitDefID] - 1
    else
      unitCounts[unitDefID] = nil
    end
    checkSelectedUnits = true
    skipGetUnitCounts = true
  end
end

local sec = 0
local uiOpacitySec = 0.5
function widget:Update(dt)

  uiOpacitySec = uiOpacitySec + dt
  if uiOpacitySec>0.5 then
    uiOpacitySec = 0
    if ui_opacity ~= Spring.GetConfigFloat("ui_opacity",0.66) then
      ui_opacity = Spring.GetConfigFloat("ui_opacity",0.66)
      gl.DeleteList(picList)
      picList = gl.CreateList(DrawPicList)
    end
  end

  sec = sec + dt
  if (checkSelectedUnits and sec>0.09) then
    sec = 0
    if not skipGetUnitCounts then
      unitCounts = spGetSelectedUnitsCounts()
      local equal = true
      if unitCounts.n ~= prevUnitCount.n then
        equal = false
      else
        for udid,count in pairs(unitCounts) do
          if not prevUnitCount[udid] or prevUnitCount[udid] ~= count then
            equal = false
            break
          end
        end
      end
      skipGetUnitCounts = nil
    else
      equal = false
    end
    if not equal and spGetSelectedUnitsCount() > 0 then
      updateDlist = true
    end
  end
  if updateDlist then
    sec = 0
    checkSelectedUnits = nil
    updateDlist = nil
    if picList then
      gl.DeleteList(picList)
    end
    picList = gl.CreateList(DrawPicList)
    updateGuishader()
  end
end


function widget:Initialize()
  WG['selunitbuttons'] = {}
  WG['selunitbuttons'].getOldUnitIcons = function()
    return oldUnitpics
  end
  WG['selunitbuttons'].setOldUnitIcons = function(value)
    oldUnitpics = value
  end
  widget:ViewResize(vsx, vsy)
end

function widget:Shutdown()
  if picList then
    gl.DeleteList(picList)
  end
  WG['selunitbuttons'] = nil
  enabled = false
  updateGuishader()
end


function DrawPicList()
  --Spring.Echo(Spring.GetGameFrame()..'  '..math.random())
  prevUnitCount = unitCounts
  unitCounts = spGetSelectedUnitsCounts()

  unitTypes = unitCounts.n;
  if (unitTypes <= 0) then
    countsTable = {}
    activePress = false
    currentDef  = nil
    return
  end
  
  local xmid = vsx * 0.5
  local width = math.floor(usedIconSizeX * unitTypes)
  rectMinX = math.floor(xmid - (0.5 * width))
  rectMaxX = math.floor(xmid + (0.5 * width))
  rectMinY = 0
  rectMaxY = math.floor(rectMinY + usedIconSizeY)
  
  -- draw background bar
  local xmin = math.floor(rectMinX)
  local xmax = math.floor(rectMinX + (usedIconSizeX * unitTypes))
  if ((xmax < 0) or (xmin > vsx)) then return end  -- bail
  
  local ymin = rectMinY
  local ymax = rectMaxY
  local xmid = (xmin + xmax) * 0.5
  local ymid = (ymin + ymax) * 0.5
  
  backgroundDimentions = {xmin-iconMargin-0.5, ymin, xmax+iconMargin+0.5, ymax+iconMargin-1}
  gl.Color(0,0,0,ui_opacity)
  RectRound(backgroundDimentions[1],backgroundDimentions[2],backgroundDimentions[3],backgroundDimentions[4],usedIconSizeX / 7)
	local borderPadding = iconMargin
	glColor(1,1,1,ui_opacity*0.04)
  RectRound(backgroundDimentions[1]+borderPadding, backgroundDimentions[2]+borderPadding, backgroundDimentions[3]-borderPadding, backgroundDimentions[4]-borderPadding, usedIconSizeX / 9)

  -- draw the buildpics
  unitCounts.n = nil 
  local row = 0 
  local icon = 0
  for udid,count in pairs(unitCounts) do
    if icon % iconsPerRow == 0 then 
		row = row + 1
	end
    DrawUnitDefTexture(udid, icon, count, row)
	icon = icon + 1
  end
end


function DrawUnitDefTexture(unitDefID, iconPos, count, row)
  local usedIconImgMult = iconImgMult
  local ypad2 = -usedIconSizeY/50
  local color = {1, 1, 1, 0.9}
  if mouseIcon ~= -1 then
  	color = {1, 1, 1, 0.75}
  end
  if iconPos == mouseIcon then
  	usedIconImgMult = iconImgMult*1.08
  	color = {1, 1, 1, 1}
  	ypad2 = 0
  end
  local yPad = (usedIconSizeY*(1-usedIconImgMult)) / 2
  local xPad = (usedIconSizeX*(1-usedIconImgMult)) / 2
  
  local xmin = math.floor(rectMinX + (usedIconSizeX * iconPos)) + xPad
  local xmax = xmin + usedIconSizeX - xPad - xPad
  if ((xmax < 0) or (xmin > vsx)) then return end  -- bail
  
  local ymin = rectMinY + yPad
  local ymax = rectMaxY - yPad
  local xmid = (xmin + xmax) * 0.5
  local ymid = (ymin + ymax) * 0.5

  local ud = UnitDefs[unitDefID]
  glColor(color)
  if oldUnitpics and UnitDefs[unitDefID] ~= nil and VFS.FileExists('unitpics/'..UnitDefs[unitDefID].name..'.dds') then
    glTexture('unitpics/'..UnitDefs[unitDefID].name..'.dds')
  else
    glTexture('#' .. unitDefID)
  end
  glTexRect(math.floor(xmin+iconMargin), math.floor(ymin+iconMargin+ypad2), math.ceil(xmax-iconMargin), math.ceil(ymax-iconMargin+ypad2))
  glTexture(false)
  
  if count > 1 then
    -- draw the count text
    local offset = math.ceil((ymax - (ymin+iconMargin+iconMargin)) / 20)
    glText(count, xmax-iconMargin-offset, ymin+iconMargin+iconMargin+offset+(fontSize/16)-(yPad/2) , fontSize, "or")
  end
end


function RectRound(px,py,sx,sy,cs)
	
	local px,py,sx,sy,cs = math.floor(px),math.floor(py),math.ceil(sx),math.ceil(sy),math.floor(cs)
	
	glTexture(false)
	glRect(px+cs, py, sx-cs, sy)
	glRect(sx-cs, py+cs, sx, sy-cs)
	glRect(px+cs, py+cs, px, sy-cs)
	
	if py <= 0 or px <= 0 then glTexture(false) else glTexture(bgcorner) end
	glTexRect(px, py+cs, px+cs, py)		-- top left
	
	if py <= 0 or sx >= vsx then glTexture(false) else glTexture(bgcorner) end
	glTexRect(sx, py+cs, sx-cs, py)		-- top right
	
	if sy >= vsy or px <= 0 then glTexture(false) else glTexture(bgcorner) end
	glTexRect(px, sy-cs, px+cs, sy)		-- bottom left
	
	if sy >= vsy or sx >= vsx then glTexture(false) else glTexture(bgcorner) end
	glTexRect(sx, sy-cs, sx-cs, sy)		-- bottom right
	
	glTexture(false)
end

function DrawIconQuad(iconPos, color)

  local usedIconImgMult = iconImgMult*1.08

  local yPad = (usedIconSizeY*(1-usedIconImgMult)) / 2
  local xPad = (usedIconSizeX*(1-usedIconImgMult)) / 2

  local xmin = math.floor(rectMinX + (usedIconSizeX * iconPos)) + xPad
  local xmax = xmin + usedIconSizeX - xPad - xPad
  if ((xmax < 0) or (xmin > vsx)) then return end  -- bail

  local ymin = rectMinY
  local ymax = rectMaxY - yPad
  local xmid = (xmin + xmax) * 0.5
  local ymid = (ymin + ymax) * 0.5

  gl.Texture(highlightImg)
  gl.Color(color)
  glTexRect(xmin+iconMargin, ymin+iconMargin+iconMargin, xmax-iconMargin, ymax-iconMargin)
  gl.Texture(false)
  
  RectRound(xmin+iconMargin, ymin+iconMargin+iconMargin, xmax-iconMargin, ymax-iconMargin, (xmax-xmin)/15)
  glBlending(GL_SRC_ALPHA, GL_ONE)
  gl.Color(color[1],color[2],color[3],color[4]/2)
  RectRound(xmin+iconMargin, ymin+iconMargin+iconMargin, xmax-iconMargin, ymax-iconMargin, (xmax-xmin)/15)
  glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
end


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

function widget:MousePress(x, y, button)
  mouseIcon = MouseOverIcon(x, y)
  activePress = (mouseIcon >= 0)
  return activePress
end

-------------------------------------------------------------------------------

local function LeftMouseButton(unitDefID, unitTable)
  local alt, ctrl, meta, shift = spGetModKeyState()
  local acted = false
  if (not ctrl) then
    -- select units of icon type
    if (alt or meta) then
      acted = true
      spSelectUnitArray({ unitTable[1] })  -- only 1
    else
      acted = true
      spSelectUnitArray(unitTable)
    end
  else
    -- select all units of the icon type
    local sorted = spGetTeamUnitsSorted(spGetMyTeamID())
    local units = sorted[unitDefID]
    if (units) then
      acted = true
      spSelectUnitArray(units, shift)
    end
  end
  if acted and playSounds then
    Spring.PlaySoundFile(leftclick, 0.75, 'ui')
  end
end


local function MiddleMouseButton(unitDefID, unitTable)
  local alt, ctrl, meta, shift = spGetModKeyState()
  -- center the view
  if (ctrl) then
    -- center the view on the entire selection
    spSendCommands({"viewselection"})
  else
    -- center the view on this type on unit
    local selUnits = spGetSelectedUnits()
    spSelectUnitArray(unitTable)
    spSendCommands({"viewselection"})
    spSelectUnitArray(selUnits)
  end
  if playSounds then
    Spring.PlaySoundFile(middleclick, 0.75, 'ui')
  end
end


local function RightMouseButton(unitDefID, unitTable)
  local alt, ctrl, meta, shift = spGetModKeyState()
  -- remove selected units of icon type
  local selUnits = spGetSelectedUnits()
  local map = {}
  for _,uid in ipairs(selUnits) do map[uid] = true end
  for _,uid in ipairs(unitTable) do
    map[uid] = nil
    if (ctrl) then break end -- only remove 1 unit
  end
  spSelectUnitMap(map)
  if playSounds then
    Spring.PlaySoundFile(rightclick, 0.75, 'ui')
  end
end


-------------------------------------------------------------------------------


function widget:MouseRelease(x, y, button)
  if (not activePress) then
    return -1
  end
  activePress = false
  local icon = MouseOverIcon(x, y)

  local units = spGetSelectedUnitsSorted()
  if (units.n ~= unitTypes) then
    return -1  -- discard this click
  end
  units.n = nil

  local unitDefID = -1
  local unitTable = nil
  local index = 0
  for udid,uTable in pairs(units) do
    if (index == icon) then
      unitDefID = udid
      unitTable = uTable
      break
    end
    index = index + 1
  end
  if (unitTable == nil) then
    return -1
  end
  
  local alt, ctrl, meta, shift = spGetModKeyState()
  
  if (button == 1) then
    LeftMouseButton(unitDefID, unitTable)
  elseif (button == 2) then
    MiddleMouseButton(unitDefID, unitTable)
  elseif (button == 3) then
    RightMouseButton(unitDefID, unitTable)
  end

  return -1
end


function MouseOverIcon(x, y)
  if (unitTypes <= 0) then return -1 end
  if (x < rectMinX)   then return -1 end
  if (x > rectMaxX)   then return -1 end
  if (y < rectMinY)   then return -1 end
  if (y > rectMaxY)   then return -1 end

  local icon = math.floor((x - rectMinX) / usedIconSizeX)
  -- clamp the icon range
  if (icon < 0) then
    icon = 0
  end
  if (icon >= unitTypes) then
    icon = (unitTypes - 1)
  end
  return icon
end


-------------------------------------------------------------------------------


function widget:GetConfigData()
  return {oldUnitpics=oldUnitpics}
end

function widget:SetConfigData(data) --load config
  if (data.oldUnitpics ~= nil) then
    oldUnitpics = data.oldUnitpics
  end
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
