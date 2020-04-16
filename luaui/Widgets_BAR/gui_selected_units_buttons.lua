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

local fontfile = "fonts/" .. Spring.GetConfigString("bar_font", "Poppins-Regular.otf")
local vsx,vsy = Spring.GetViewGeometry()
local fontfileScale = (0.75 + (vsx*vsy / 7000000))
local fontfileSize = 36
local fontfileOutlineSize = 7
local fontfileOutlineStrength = 1.3
local font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)


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
local glText                   = gl.Text
local glTexture                = gl.Texture
local glTranslate              = gl.Translate
local glUnitDef                = gl.UnitDef
local glVertex                 = gl.Vertex
local spGetModKeyState         = Spring.GetModKeyState
local spGetMouseState          = Spring.GetMouseState
local spGetMyTeamID            = Spring.GetMyTeamID
local spGetSelectedUnits       = Spring.GetSelectedUnits
local spGetSelectedUnitsCount  = Spring.GetSelectedUnitsCount
local spGetSelectedUnitsCounts = Spring.GetSelectedUnitsCounts
local spGetSelectedUnitsSorted = Spring.GetSelectedUnitsSorted
local spGetTeamUnitsSorted     = Spring.GetTeamUnitsSorted
local spSelectUnitArray        = Spring.SelectUnitArray
local spSelectUnitMap          = Spring.SelectUnitMap
local spSendCommands           = Spring.SendCommands
local spIsGUIHidden            = Spring.IsGUIHidden

local unitNames = {}
local unitHumanNames = {}
for unitDefID, unitDef in pairs(UnitDefs) do
  unitNames[unitDefID] = unitDef.name
  unitHumanNames[unitDefID] = unitDef.humanName
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local ui_opacityMultiplier = 0.6
local ui_opacity = tonumber(Spring.GetConfigFloat("ui_opacity",0.66) or 0.66) * ui_opacityMultiplier

local bgcorner = ":l:LuaUI/Images/bgcorner.png"
local highlightImg = ":l:LuaUI/Images/button-highlight.dds"

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
local alternativeUnitpics = false

local hasAlternativeUnitpic = {}
local unitBuildPic = {}
for id, def in pairs(UnitDefs) do
  unitBuildPic[id] = def.buildpicname
  if VFS.FileExists('unitpics/alternative/'..def.name..'.png') then
    hasAlternativeUnitpic[id] = true
  end
end

local iconSizeX = 76
local iconSizeY = 76
local iconImgMult = 0.85

local usedIconSizeX = iconSizeX
local usedIconSizeY = iconSizeY
local rectMinX = 0
local rectMaxX = 0
local rectMinY = 0
local rectMaxY = 0

local prevMouseIcon
local hoverClock = nil

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
	if WG['guishader'] then
		if not picList then
            WG['guishader'].RemoveDlist('selectionbuttons')
            guishaderDisabled = true
        else
			if backgroundDimentions[1] ~= nil then
                if dlistGuishader ~= nil then
                  WG['guishader'].RemoveDlist('selectionbuttons')
                  gl.DeleteList(dlistGuishader)
                end
                dlistGuishader = gl.CreateList( function()
                  RectRound(backgroundDimentions[1], backgroundDimentions[2], backgroundDimentions[3], backgroundDimentions[4], usedIconSizeX / 8)
                  WG['guishader'].InsertDlist(dlistGuishader, 'selectionbuttons')
                end)
                guishaderDisabled = false
			end
		end
	end
end

local selectedUnits = Spring.GetSelectedUnits()
local selectedUnitsCount = Spring.GetSelectedUnitsCount()
local selectedUnitsCounts = Spring.GetSelectedUnitsCounts()
local selectionChanged = true
function widget:SelectionChanged(sel)
  selectedUnits = sel
  selectedUnitsCount = Spring.GetSelectedUnitsCount()
  selectedUnitsCounts = Spring.GetSelectedUnitsCounts()
  selectionChanged = true
end


local vsx, vsy = widgetHandler:GetViewSizes()
function widget:ViewResize(n_vsx,n_vsy)
  vsx,vsy = Spring.GetViewGeometry()
  iconsPerRow = math.floor(8 * (vsx / vsy))
  local newFontfileScale = (0.5 + (vsx*vsy / 5700000))
  if (fontfileScale ~= newFontfileScale) then
    fontfileScale = newFontfileScale
    gl.DeleteFont(font)
    font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)
  end

  usedIconSizeX = math.floor((iconSizeX/2) + ((vsx*vsy) / 115000))
  usedIconSizeY =  math.floor((iconSizeY/2) + ((vsx*vsy) / 115000))
  fontSize = usedIconSizeY * 0.28
  iconMargin = usedIconSizeX / 25
  
  if picList then
    gl.DeleteList(picList)
	picList = gl.CreateList(DrawPicList)
  end
end

function cacheUnitIcons()
    if cached == nil then
        gl.Color(1,1,1,0.001)
        for id, unit in pairs(UnitDefs) do
          if alternativeUnitpics and hasAlternativeUnitpic[id] then
            gl.Texture(':lcr96,96:unitpics/alternative/'..unitBuildPic[id])
          else
            --gl.Texture('#' .. id)
            gl.Texture(':lcr96,96:unitpics/'..unitBuildPic[id])
          end
            gl.TexRect(-1,-1,0,0)
            gl.Texture(false)
        end
        gl.Color(1,1,1,1)
        cached = true
    end
end

function widget:RecvLuaMsg(msg, playerID)
  if msg:sub(1,18) == 'LobbyOverlayActive' then
    chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
  end
end

function widget:DrawScreen()
  if chobbyInterface then return end
  cacheUnitIcons()    -- else white icon bug happens
  if picList then
    if (spIsGUIHidden()) then return end

    if mouseIcon ~= prevMouseIcon then
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
      Spring.SetMouseCursor('cursornormal')
      if WG['tooltip'] ~= nil and mouseIcon then
        local unitName = ' --- '
        local i = 0
        for udid,count in pairs(selectedUnitsCounts) do
          if type(udid) == 'number' then
            if i == mouseIcon then
              unitName = unitHumanNames[udid]
              break
            end
            i = i + 1
          end
        end
        WG['tooltip'].ShowTooltip('selectedunitbuttons_unit', "\255\215\255\215"..unitName, x, backgroundDimentions[4]+(usedIconSizeY*0.4))
      end
      if WG['tooltip'] ~= nil and os.clock() - hoverClock > 0.6 then
        local text = "\255\215\255\215Selected units\n \255\255\255\255Left click\255\210\210\210: Select\n \255\255\255\255   + CTRL\255\210\210\210: Select units of this type on map\n \255\255\255\255   + ALT\255\210\210\210: Remove all by 1 unit of this unit type\n \255\255\255\255Right click\255\210\210\210: Remove\n \255\255\255\255    + CTRL\255\210\210\210: Remove only 1 unit from that unit type\n \255\255\255\255Middle click\255\210\210\210: Move to center location\n \255\255\255\255    + CTRL\255\210\210\210: Move to center off whole selection"
        local textHeight, desc, numLines = font:GetTextHeight(text)
        WG['tooltip'].ShowTooltip('selectedunitbuttons', text, vsx, backgroundDimentions[4]+(usedIconSizeY*1.3) + (textHeight*numLines*15*fontfileScale))
      end
    else
      hoverClock = nil
    end
  end
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

local uiOpacitySec = 0
local selChangedSec = 0
function widget:Update(dt)
  uiOpacitySec = uiOpacitySec + dt
  if uiOpacitySec>0.5 then
    uiOpacitySec = 0
    if ui_opacity ~= (Spring.GetConfigFloat("ui_opacity",0.66) * ui_opacityMultiplier) then
      ui_opacity = Spring.GetConfigFloat("ui_opacity",0.66) * ui_opacityMultiplier
      gl.DeleteList(picList)
      picList = gl.CreateList(DrawPicList)
    end
  end

  selChangedSec = selChangedSec + dt
  if selectionChanged and selChangedSec>0.1 then
    selChangedSec = 0
    selectionChanged = nil
    if picList then
      gl.DeleteList(picList)
      picList = nil
    end
    if selectedUnitsCount > 0 then
      picList = gl.CreateList(DrawPicList)
    end
    updateGuishader()
  end
end


function widget:Initialize()
  WG['selunitbuttons'] = {}
  WG['selunitbuttons'].getAlternativeIcons = function()
    return alternativeUnitpics
  end
  WG['selunitbuttons'].setAlternativeIcons = function(value)
    alternativeUnitpics = value
  end
  widget:ViewResize(vsx, vsy)
end

function widget:Shutdown()
  if picList then
    gl.DeleteList(picList)
    picList = nil
  end
  gl.DeleteFont(font)
  WG['selunitbuttons'] = nil
  enabled = false
  updateGuishader()
end

local startFromIcon = 0
function DrawPicList()
  if selectedUnitsCount == 0 then return end
  --Spring.Echo(Spring.GetGameFrame()..'  '..math.random())

  unitTypes = selectedUnitsCounts.n;
  displayedUnitTypes = unitTypes
  if displayedUnitTypes > iconsPerRow then
    displayedUnitTypes = iconsPerRow
  end

  if (unitTypes <= 0) then
    countsTable = {}
    activePress = false
    currentDef  = nil
    return
  end
  
  local xmid = vsx * 0.5
  local width = math.floor(usedIconSizeX * displayedUnitTypes)
  rectMinX = math.floor(xmid - (0.5 * width))
  rectMaxX = math.floor(xmid + (0.5 * width))
  rectMinY = 0
  rectMaxY = math.floor(rectMinY + usedIconSizeY)
  
  -- draw background bar
  local xmin = math.floor(rectMinX)
  local xmax = math.floor(rectMinX + (usedIconSizeX * displayedUnitTypes))


  if unitTypes > 16 then
    -- back button
    if startFromIcon > 0 then
      xmin = xmin - usedIconSizeX
    end
    -- forward button
    if startFromIcon + iconsPerRow < unitTypes then
      xmax = xmax + usedIconSizeX
    end
  end

  if ((xmax < 0) or (xmin > vsx)) then return end  -- bail
  local ymin = rectMinY
  local ymax = rectMaxY
  local xmid = (xmin + xmax) * 0.5
  local ymid = (ymin + ymax) * 0.5

  backgroundDimentions = {xmin-iconMargin-0.5, ymin, xmax+iconMargin+0.5, ymax+iconMargin-1}
  --gl.Color(0,0,0,ui_opacity)
  RectRound(backgroundDimentions[1],backgroundDimentions[2],backgroundDimentions[3],backgroundDimentions[4],usedIconSizeX / 8, 1,1,1,1, {0.1,0.1,0.1,ui_opacity}, {0,0,0,ui_opacity})
  local borderPadding = iconMargin*1.4
  --glColor(1,1,1,ui_opacity*0.055)
  RectRound(backgroundDimentions[1]+borderPadding, backgroundDimentions[2]+borderPadding, backgroundDimentions[3]-borderPadding, backgroundDimentions[4]-borderPadding, usedIconSizeX / 12, 1,1,1,1, {0.15,0.15,0.15,ui_opacity*0.2}, {1,1,1,ui_opacity*0.2})

  -- back button
  if startFromIcon > 0 then

  end
  -- forward button
  if startFromIcon + iconsPerRow < unitTypes then

  end

  -- draw the buildpics
  local row = 0
  local icon = 0
  local displayedIcon = 0
  for udid,count in pairs(selectedUnitsCounts) do
    if type(udid) == 'number' then
      if icon >= startFromIcon then
        --if icon % iconsPerRow == 0 then
        --	row = row + 1
        --end
        DrawUnitDefTexture(udid, icon, count, row)
        displayedIcon = displayedIcon + 1
        if displayedIcon >= iconsPerRow then break end
      end
      icon = icon + 1
    end
  end
end

function DrawUnitDefTexture(unitDefID, iconPos, count, row)
  local usedIconImgMult = iconImgMult
  local ypad2 = -usedIconSizeY/50
  local color = {1, 1, 1, 0.9 }
  if (not WG['topbar'] or not WG['topbar'].showingQuit()) then
    if mouseIcon ~= -1 then
      color = {1, 1, 1, 0.7}
    end
    if iconPos == mouseIcon then
      usedIconImgMult = iconImgMult*1.1
      color = {1, 1, 1, 1}
      ypad2 = 0
    end
  end
  local yPad = (usedIconSizeY*(1-usedIconImgMult)) / 3
  local xPad = (usedIconSizeX*(1-usedIconImgMult)) / 3
  
  local xmin = math.floor(rectMinX + (usedIconSizeX * iconPos)) + xPad
  local xmax = xmin + usedIconSizeX - xPad - xPad
  if ((xmax < 0) or (xmin > vsx)) then return end  -- bail
  
  local ymin = rectMinY + yPad
  local ymax = rectMaxY - yPad
  local xmid = (xmin + xmax) * 0.5
  local ymid = (ymin + ymax) * 0.5

  glColor(color)
  if alternativeUnitpics and hasAlternativeUnitpic[unitDefID] then
    glTexture(':lcr96,96:unitpics/alternative/'..unitBuildPic[unitDefID])
  else
    --glTexture('#' .. unitDefID)
    glTexture(':lcr96,96:unitpics/'..unitBuildPic[unitDefID])
  end
  glTexRect(math.floor(xmin+iconMargin), math.floor(ymin+iconMargin+ypad2), math.ceil(xmax-iconMargin), math.ceil(ymax-iconMargin+ypad2))
  glTexture(false)
  
  if count > 1 then
    -- draw the count text
    local offset = math.ceil((ymax - (ymin+iconMargin+iconMargin)) / 20)
    font:Begin()
    font:SetTextColor(0.85,0.85,0.85,1)
    font:Print(count, xmax-(iconMargin*1.3)-offset, ymin+(iconMargin*2.2)+offset+(fontSize/16)-(yPad/2) , fontSize, "or")
    font:End()
  end
end


local function DrawRectRound(px,py,sx,sy,cs, tl,tr,br,bl, c1,c2)
  gl.TexCoord(0.8,0.8)
  if c2 then
    gl.Color(c1[1],c1[2],c1[3],c1[4])
  end
  gl.Vertex(px+cs, py, 0)
  gl.Vertex(sx-cs, py, 0)
  if c2 then
    gl.Color(c2[1],c2[2],c2[3],c2[4])
  end
  gl.Vertex(sx-cs, sy, 0)
  gl.Vertex(px+cs, sy, 0)

  if c2 then
    gl.Color(c1[1],c1[2],c1[3],c1[4])
  end
  gl.Vertex(px, py+cs, 0)
  gl.Vertex(px+cs, py+cs, 0)
  if c2 then
    gl.Color(c2[1],c2[2],c2[3],c2[4])
  end
  gl.Vertex(px+cs, sy-cs, 0)
  gl.Vertex(px, sy-cs, 0)

  if c2 then
    gl.Color(c1[1],c1[2],c1[3],c1[4])
  end
  gl.Vertex(sx, py+cs, 0)
  gl.Vertex(sx-cs, py+cs, 0)
  if c2 then
    gl.Color(c2[1],c2[2],c2[3],c2[4])
  end
  gl.Vertex(sx-cs, sy-cs, 0)
  gl.Vertex(sx, sy-cs, 0)

  local offset = 0.15		-- texture offset, because else gaps could show

  -- bottom left
  if c2 then
    gl.Color(c1[1],c1[2],c1[3],c1[4])
  end
  if ((py <= 0 or px <= 0)  or (bl ~= nil and bl == 0)) and bl ~= 2   then o = 0.5 else o = offset end
  gl.TexCoord(o,o)
  gl.Vertex(px, py, 0)
  gl.TexCoord(o,1-offset)
  gl.Vertex(px+cs, py, 0)
  gl.TexCoord(1-offset,1-offset)
  gl.Vertex(px+cs, py+cs, 0)
  gl.TexCoord(1-offset,o)
  gl.Vertex(px, py+cs, 0)
  -- bottom right
  if ((py <= 0 or sx >= vsx) or (br ~= nil and br == 0)) and br ~= 2   then o = 0.5 else o = offset end
  gl.TexCoord(o,o)
  gl.Vertex(sx, py, 0)
  gl.TexCoord(o,1-offset)
  gl.Vertex(sx-cs, py, 0)
  gl.TexCoord(1-offset,1-offset)
  gl.Vertex(sx-cs, py+cs, 0)
  gl.TexCoord(1-offset,o)
  gl.Vertex(sx, py+cs, 0)
  -- top left
  if c2 then
    gl.Color(c2[1],c2[2],c2[3],c2[4])
  end
  if ((sy >= vsy or px <= 0) or (tl ~= nil and tl == 0)) and tl ~= 2   then o = 0.5 else o = offset end
  gl.TexCoord(o,o)
  gl.Vertex(px, sy, 0)
  gl.TexCoord(o,1-offset)
  gl.Vertex(px+cs, sy, 0)
  gl.TexCoord(1-offset,1-offset)
  gl.Vertex(px+cs, sy-cs, 0)
  gl.TexCoord(1-offset,o)
  gl.Vertex(px, sy-cs, 0)
  -- top right
  if ((sy >= vsy or sx >= vsx)  or (tr ~= nil and tr == 0)) and tr ~= 2   then o = 0.5 else o = offset end
  gl.TexCoord(o,o)
  gl.Vertex(sx, sy, 0)
  gl.TexCoord(o,1-offset)
  gl.Vertex(sx-cs, sy, 0)
  gl.TexCoord(1-offset,1-offset)
  gl.Vertex(sx-cs, sy-cs, 0)
  gl.TexCoord(1-offset,o)
  gl.Vertex(sx, sy-cs, 0)
end
function RectRound(px,py,sx,sy,cs, tl,tr,br,bl, c1,c2)		-- (coordinates work differently than the RectRound func in other widgets)
  gl.Texture(bgcorner)
  gl.BeginEnd(GL.QUADS, DrawRectRound, px,py,sx,sy,cs, tl,tr,br,bl, c1,c2)
  gl.Texture(false)
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
  for i=1,#selUnits do
    map[selUnits[i]] = true
  end
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
    if WG['smartselect'] and not WG['smartselect'].updateSelection then return end
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
  return {alternativeUnitpics=alternativeUnitpics}
end

function widget:SetConfigData(data) --load config
  if (data.alternativeUnitpics ~= nil) then
    alternativeUnitpics = data.alternativeUnitpics
  end
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
