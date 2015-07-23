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
    name      = "SelectionButtons",
    desc      = "Buttons for the current selection (incomplete)",
    author    = "trepan, Floris",
    date      = "28 may 2015",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = false  --  loaded by default?
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


include("colors.h.lua")

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local bgcorner = ":n:"..LUAUI_DIRNAME.."Images/bgcorner.png"
local highlightImg = ":n:"..LUAUI_DIRNAME.."Images/button-highlight.dds"

local iconsPerRow = 16		-- not functional yet, I doubt I will put this in

local backgroundColor = {0,0,0,0.18}
local highlightColor = {1, 0.7, 0.2, 0.35}
local hoverColor = { 1, 1, 1, 0.22 }

local unitTypes = 0
local countsTable = {}
local activePress = false
local mouseIcon = -1
local currentDef = nil

local iconSizeX = 68
local iconSizeY = math.floor(iconSizeX * 0.94)

local usedIconSizeX = iconSizeX
local usedIconSizeY = iconSizeY
local rectMinX = 0
local rectMaxX = 0
local rectMinY = 0
local rectMaxY = 0


local enabled = true
local backgroundDimentions = {}
local iconMargin = usedIconSizeX / 15		-- changed in ViewResize anyway
local fontSize = iconSizeY * 0.33		-- changed in ViewResize anyway
local picList

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------


local function updateGuishader()
	if (WG['guishader_api'] ~= nil) then
		if not enabled then
			WG['guishader_api'].RemoveRect('selectionbuttons')
		else
			if backgroundDimentions[1] ~= nil then
				WG['guishader_api'].InsertRect(
					backgroundDimentions[1],
					backgroundDimentions[2],
					backgroundDimentions[3],
					backgroundDimentions[4],
					'selectionbuttons'
				)
			end
		end
	end
end

local vsx, vsy = widgetHandler:GetViewSizes()
function widget:ViewResize(viewSizeX, viewSizeY)
  vsx = viewSizeX
  vsy = viewSizeY
  
  usedIconSizeX = math.floor((iconSizeX/2) + ((vsx*vsy) / 115000))
  usedIconSizeY = math.floor(usedIconSizeX * 0.89)
  fontSize = usedIconSizeY * 0.33
  iconMargin = usedIconSizeX / 15
  
  if picList then
    gl.DeleteList(picList)
	picList = gl.CreateList(DrawPicList)
  end
end

function widget:DrawScreen()
	enabled = false
	if (not spIsGUIHidden()) then
	  if picList then
		  local unitCounts = spGetSelectedUnitsCounts()
		  local icon = -1
		  for udid,count in pairs(unitCounts) do
			icon = icon + 1
		  end
		  if icon > 0 then
			enabled = true
			gl.CallList(picList)
			-- draw the highlights
			local x,y,lb,mb,rb = spGetMouseState()
			local mouseIcon = MouseOverIcon(x, y)
			if (not widgetHandler:InTweakMode() and (mouseIcon >= 0)) then
			  if (lb or mb or rb) then
				DrawIconQuad(mouseIcon, highlightColor)  --  click highlight
			  else
				DrawIconQuad(mouseIcon, hoverColor)  --  hover highlight
			  end
		  end
		end
	  end    
	end
	updateGuishader()
end

function widget:CommandsChanged()
  if picList then
    gl.DeleteList(picList)
  end
  picList = gl.CreateList(DrawPicList) 
end

function widget:Initialize()
  picList = gl.CreateList(DrawPicList) 
end

function widget:Shutdown()
  if picList then
    gl.DeleteList(picList)
  end
  enabled = false
  updateGuishader()
end

function DrawPicList()
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
  if backgroundColor[4] > 0 then
    local icon = -1
    for udid,count in pairs(unitCounts) do
      icon = icon + 1
    end
    local xmin = math.floor(rectMinX)
    local xmax = math.floor(rectMinX + (usedIconSizeX * icon))
    if ((xmax < 0) or (xmin > vsx)) then return end  -- bail
    
    local ymin = rectMinY
    local ymax = rectMaxY
    local xmid = (xmin + xmax) * 0.5
    local ymid = (ymin + ymax) * 0.5
    
    backgroundDimentions = {xmin-iconMargin-0.5, ymin, xmax+iconMargin+0.5, ymax+iconMargin+iconMargin-1}
    gl.Color(backgroundColor)
    RectRound(backgroundDimentions[1],backgroundDimentions[2],backgroundDimentions[3],backgroundDimentions[4],usedIconSizeX / 7)
  end
  
  
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
  local xmin = math.floor(rectMinX + (usedIconSizeX * iconPos))
  local xmax = xmin + usedIconSizeX
  if ((xmax < 0) or (xmin > vsx)) then return end  -- bail
  
  local ymin = rectMinY
  local ymax = rectMaxY
  local xmid = (xmin + xmax) * 0.5
  local ymid = (ymin + ymax) * 0.5

  local ud = UnitDefs[unitDefID] 

  glColor(1, 1, 1, 1)
  glTexture('#' .. unitDefID)
  glTexRect(math.floor(xmin+iconMargin), math.floor(ymin+iconMargin+iconMargin), math.ceil(xmax-iconMargin), math.ceil(ymax))
  glTexture(false)

  -- draw the count text
  local offset = math.ceil((ymax - (ymin+iconMargin+iconMargin)) / 20)
  glText(count, xmax-iconMargin-offset, ymin+iconMargin+iconMargin+offset+(fontSize/16) , fontSize, "or")
end


function RectRound(px,py,sx,sy,cs)
	
	local px,py,sx,sy,cs = math.floor(px),math.floor(py),math.ceil(sx),math.ceil(sy),math.floor(cs)
	
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
  local xmin = rectMinX + (usedIconSizeX * iconPos)
  local xmax = xmin + usedIconSizeX
  local ymin = rectMinY
  local ymax = rectMaxY
  
  gl.Texture(highlightImg)
  gl.Color(color)
  glTexRect(xmin+iconMargin, ymin+iconMargin+iconMargin, xmax-iconMargin, ymax-iconMargin+iconMargin)
  gl.Texture(false)
  
  RectRound(xmin+iconMargin, ymin+iconMargin+iconMargin, xmax-iconMargin, ymax-iconMargin+iconMargin, (xmax-xmin)/15)
  glBlending(GL_SRC_ALPHA, GL_ONE)
  gl.Color(color[1],color[2],color[3],color[4]/2)
  RectRound(xmin+iconMargin, ymin+iconMargin+iconMargin, xmax-iconMargin, ymax-iconMargin+iconMargin, (xmax-xmin)/15)
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
  if (not ctrl) then
    -- select units of icon type
    if (alt or meta) then
      spSelectUnitArray({ unitTable[1] })  -- only 1
    else
      spSelectUnitArray(unitTable)
    end
  else
    -- select all units of the icon type
    local sorted = spGetTeamUnitsSorted(spGetMyTeamID())
    local units = sorted[unitDefID]
    if (units) then
      spSelectUnitArray(units, shift)
    end
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

function widget:IsAbove(x, y)
  local icon = MouseOverIcon(x, y)
  if (icon < 0) then
    return false
  end
  return true
end


function widget:GetTooltip(x, y)
  local ud = currentDef
  if (not ud) then
    return ''
  end
  return ud.humanName .. ' - ' .. ud.tooltip
end


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
