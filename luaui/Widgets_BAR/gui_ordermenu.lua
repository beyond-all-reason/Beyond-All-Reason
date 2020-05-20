function widget:GetInfo()
  return {
    name      = "Order menu",
    desc      = "",
    author    = "Floris",
    date      = "April 2020",
    license   = "GNU GPL, v2 or later",
    layer     = 1,
    enabled   = true
  }
end


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local altPosition = false

local showIcons = false
local colorize = 0
local playSounds = true
local posY = 0.75
local posX = 0
local width = 0
local height = 0
local cellMarginOrg = 0.035
local cellMargin = cellMarginOrg
local bgBorderOrg = 0.0018
local bgBorder = bgBorderOrg
local bgMargin = 0.005
local cmdColorDefault = {0.95,0.95,0.95}
local cmdColor = {
  Move = {0.64,1,0.64},
  Stop = {1,0.3,0.3},
  Attack = {1,0.5,0.35},
  ['Area attack'] = {1,0.35,0.15},
  ManualFire = {1,0.7,0.7},
  Patrol = {0.73,0.73,1},
  Fight = {0.9,0.5,1},
  Resurrect = {1,0.75,1},
  Guard = {0.33,0.92,1},
  Wait = {0.7,0.66,0.6},
  Repair = {1,0.95,0.7},
  Reclaim = {0.86,1,0.86},
  Restore = {0.77,1,0.77},
  Capture = {1,0.85,0.22},
  ['Set Target'] = {1,0.66,0.35},
  ['Cancel Target'] = {0.8,0.55,0.2},
  Mex = {0.93,0.93,0.93},
  ['Upgrade Mex'] = {0.93,0.93,0.93},
  ['Load units'] = {0.1,0.7,1},
  ['Unload units'] = {0,0.5,1},
  ['Land At Airbase'] = {0.4,0.7,0.4},
}

local isStateCmd = {}

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local fontfile = "fonts/" .. Spring.GetConfigString("bar_font", "Poppins-Regular.otf")
local vsx,vsy = Spring.GetViewGeometry()
local fontfileScale = (0.5 + (vsx*vsy / 5700000))
local fontfileSize = 36
local fontfileOutlineSize = 7
local fontfileOutlineStrength = 1.1
--local font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)
local fontfile2 = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
local font2 = gl.LoadFont(fontfile2, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)
local loadedFontSize = fontfileSize*fontfileScale

local barGlowCenterTexture = ":l:LuaUI/Images/barglow-center.png"
local barGlowEdgeTexture   = ":l:LuaUI/Images/barglow-edge.png"

local sound_button = 'LuaUI/Sounds/buildbar_waypoint.wav'

local ui_opacity = tonumber(Spring.GetConfigFloat("ui_opacity",0.66) or 0.66)
local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale",1) or 1)
local glossMult = 1 + (2-(ui_opacity*2))	-- increase gloss/highlight so when ui is transparant, you can still make out its boundaries and make it less flat

local backgroundRect = {}
local activeRect = {}
local cellRects = {}
local cellMarginPx = 0
local cmds = {}
local lastUpdate = os.clock()-1
local rows = 0
local colls = 0
local disableInput = false

local hiddencmds = {
  [76] = true, --load units clone
  [65] = true, --selfd
  [9] = true, --gatherwait
  [8] = true, --squadwait
  [7] = true, --deathwait
  [6] = true, --timewait
  [39812] = true, --raw move
  [34922] = true, -- set unit target
  --[34923] = true, -- set target
}

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local spGetSelectedUnitsCount = Spring.GetSelectedUnitsCount
local spGetActiveCommand = Spring.GetActiveCommand
local spGetActiveCmdDescs = Spring.GetActiveCmdDescs

local string_sub = string.sub
local string_gsub = string.gsub
local os_clock = os.clock

local GL_QUADS = GL.QUADS
local GL_TRIANGLE_FAN = GL.TRIANGLE_FAN
local glBeginEnd = gl.BeginEnd
local glTexture = gl.Texture
local glTexRect = gl.TexRect
local glColor = gl.Color
local glRect = gl.Rect
local glVertex = gl.Vertex
local glBlending = gl.Blending
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_ONE = GL.ONE

local twicePi = math.pi * 2
local mCos = math.cos
local mSin = math.sin
local math_min = math.min

local isSpec = Spring.GetSpectatingState()
local cursorTextures = {}

local function convertColor(r,g,b)
  return string.char(255, (r*255), (g*255), (b*255))
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local function checkGuishader(force)
  if WG['guishader'] then
    if force and dlistGuishader then
      dlistGuishader = gl.DeleteList(dlistGuishader)
    end
    if not dlistGuishader then
      dlistGuishader = gl.CreateList( function()
        RectRound(backgroundRect[1],backgroundRect[2],backgroundRect[3],backgroundRect[4], (bgBorder*vsy)*2)
      end)
      WG['guishader'].InsertDlist(dlistGuishader, 'ordermenu')
    end
  elseif dlistGuishader then
    dlistGuishader = gl.DeleteList(dlistGuishader)
  end
end

function widget:PlayerChanged(playerID)
  isSpec = Spring.GetSpectatingState()
end

local function RefreshCommands()
  local stateCmds = {}
  local otherCmds = {}
  local stateCmdsCount = 0
  local otherCmdsCount = 0
  for index,cmd in pairs(spGetActiveCmdDescs()) do
    if type(cmd) == "table" then
      if cmd.type == 5 then
        isStateCmd[cmd.id] = true
      end
      if not hiddencmds[cmd.id] and cmd.action ~= nil and cmd.type ~= 21 and cmd.type ~= 18 and cmd.type ~= 17 and not cmd.disabled then
        if cmd.type == 20 --build building
          or (string_sub(cmd.action,1,10) == 'buildunit_') then

        elseif cmd.type == 5 then
          stateCmdsCount = stateCmdsCount + 1
          stateCmds[stateCmdsCount] = cmd
        else
          otherCmdsCount = otherCmdsCount + 1
          otherCmds[otherCmdsCount] = cmd
        end
      end
    end
  end
  cmds = {}
  for i=1,stateCmdsCount do
    cmds[i] = stateCmds[i]
  end
  for i=1,otherCmdsCount do
    cmds[i+stateCmdsCount] = otherCmds[i]
  end

  setupCellGrid()
end

function setupCellGrid(force)
  local oldColls = colls
  local oldRows = rows
  local cmdCount = #cmds
  local addColl = ui_scale < 0.85 and -1 or 0
  local addRow = ui_scale < 0.85 and 0 or 0
  if cmdCount <= (4+addColl) * (4+addRow) then
    colls = 4 + addColl
    rows = 4 + addRow
  elseif cmdCount <= (5+addColl) * (4+addRow) then
    colls = 5 + addColl
    rows = 4 + addRow
  elseif cmdCount <= (5+addColl) * (5+addRow) then
    colls = 5 + addColl
    rows = 5 + addRow
  elseif cmdCount <= (5+addColl) * (6+addRow) then
    colls = 5 + addColl
    rows = 6 + addRow
  elseif cmdCount <= (6+addColl) * (6+addRow) then
    colls = 6 + addColl
    rows = 6 + addRow
  elseif cmdCount <= (6+addColl) * (7+addRow) then
    colls = 6 + addColl
    rows = 7 + addRow
  else
    colls = 7 + addColl
    rows = 7 + addRow
  end

  local sizeDivider =  ((colls + rows) / 16)
  cellMargin = (cellMarginOrg / sizeDivider) * ui_scale
  bgBorder = (bgBorderOrg / sizeDivider) * ui_scale

  if minusColumn then
    colls = colls - 1
    rows = rows + 1
  end

  if force or oldColls ~= colls or oldRows ~= rows then
    clickedCell = nil
    clickedCellTime = nil
    clickedCellDesiredState = nil
    cellRects = {}
    local i = 0
    local cellWidth = (activeRect[3] - activeRect[1]) / colls
    local cellHeight = (activeRect[4] - activeRect[2]) / rows
    cellMarginPx = cellHeight * cellMargin
    for row=1, rows do
      for col=1, colls do
        i = i + 1
        cellRects[i] = {
          activeRect[1]+(cellWidth*(col-1)),
          activeRect[4]-(cellHeight*row),
          activeRect[1]+(cellWidth*col),
          activeRect[4]-(cellHeight*(row-1))
        }
      end
    end
  end
end

function widget:ViewResize()
  vsx,vsy = Spring.GetViewGeometry()

  width = 0.23
  height = 0.14

  width = width / (vsx/vsy) * 1.78		-- make smaller for ultrawide screens
  width = width * ui_scale

  if altPosition then
    posY = height
    posX = width + 0.003
  else
    posY = 0.75
    posX = 0
  end

  backgroundRect = {posX*vsx, (posY-height)*vsy, (posX+width)*vsx, posY*vsy}
  activeRect = {(posX*vsx)+(bgMargin*vsy), ((posY-height)+bgMargin)*vsy, ((posX+width)*vsx)-(bgMargin*vsy), (posY-bgMargin)*vsy}

  dlistOrders = gl.DeleteList(dlistOrders)

  checkGuishader(true)
  setupCellGrid(true)
  doUpdate = true

  local newFontfileScale = (0.5 + (vsx*vsy / 5700000))
  if fontfileScale ~= newFontfileScale then
    fontfileScale = newFontfileScale
    --gl.DeleteFont(font)
    --font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)
    gl.DeleteFont(font2)
    font2 = gl.LoadFont(fontfile2, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)
    loadedFontSize = fontfileSize*fontfileScale
  end

end


function widget:Initialize()

  if WG['minimap'] then
    altPosition = WG['minimap'].getEnlarged()
  end

  widget:ViewResize()
  widget:SelectionChanged()

  WG['ordermenu'] = {}
  WG['ordermenu'].getColorize = function()
    return colorize
  end
  WG['ordermenu'].setColorize = function(value)
    doUpdate = true
    colorize = value
    if colorize > 1 then
      colorize = 1
    end
  end
end

function widget:Shutdown()
  if WG['guishader'] and dlistGuishader then
    WG['guishader'].DeleteDlist('ordermenu')
    dlistGuishader = nil
  end
  dlistOrders = gl.DeleteList(dlistOrders)
end

local sec = 0
function widget:Update(dt)
  sec = sec + dt
  if sec > 0.5 then
    sec = 0
    checkGuishader()
    if ui_scale ~= Spring.GetConfigFloat("ui_scale",1) then
      ui_scale = Spring.GetConfigFloat("ui_scale",1)
      widget:ViewResize()
      setupCellGrid(true)
      doUpdate = true
    end
    if ui_opacity ~= Spring.GetConfigFloat("ui_opacity",0.66) then
      ui_opacity = Spring.GetConfigFloat("ui_opacity",0.66)
      glossMult = 1 + (2-(ui_opacity*2))
      doUpdate = true
    end
    if WG['minimap'] and altPosition ~= WG['minimap'].getEnlarged() then
      altPosition = WG['minimap'].getEnlarged()
      widget:ViewResize()
      setupCellGrid(true)
      doUpdate = true
    end

    disableInput = isSpec
    if Spring.IsGodModeEnabled() then
      disableInput = false
    end
  end
end


local function DrawRectRound(px,py,sx,sy,cs, tl,tr,br,bl, c1,c2)
  local csyMult = 1 / ((sy-py)/cs)

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

  -- left side
  if c2 then
    gl.Color(c1[1]*(1-csyMult)+(c2[1]*csyMult),c1[2]*(1-csyMult)+(c2[2]*csyMult),c1[3]*(1-csyMult)+(c2[3]*csyMult),c1[4]*(1-csyMult)+(c2[4]*csyMult))
  end
  gl.Vertex(px, py+cs, 0)
  gl.Vertex(px+cs, py+cs, 0)
  if c2 then
    gl.Color(c2[1]*(1-csyMult)+(c1[1]*csyMult),c2[2]*(1-csyMult)+(c1[2]*csyMult),c2[3]*(1-csyMult)+(c1[3]*csyMult),c2[4]*(1-csyMult)+(c1[4]*csyMult))
  end
  gl.Vertex(px+cs, sy-cs, 0)
  gl.Vertex(px, sy-cs, 0)

  -- right side
  if c2 then
    gl.Color(c1[1]*(1-csyMult)+(c2[1]*csyMult),c1[2]*(1-csyMult)+(c2[2]*csyMult),c1[3]*(1-csyMult)+(c2[3]*csyMult),c1[4]*(1-csyMult)+(c2[4]*csyMult))
  end
  gl.Vertex(sx, py+cs, 0)
  gl.Vertex(sx-cs, py+cs, 0)
  if c2 then
    gl.Color(c2[1]*(1-csyMult)+(c1[1]*csyMult),c2[2]*(1-csyMult)+(c1[2]*csyMult),c2[3]*(1-csyMult)+(c1[3]*csyMult),c2[4]*(1-csyMult)+(c1[4]*csyMult))
  end
  gl.Vertex(sx-cs, sy-cs, 0)
  gl.Vertex(sx, sy-cs, 0)

  -- bottom left
  if c2 then
    gl.Color(c1[1],c1[2],c1[3],c1[4])
  end
  if ((py <= 0 or px <= 0)  or (bl ~= nil and bl == 0)) and bl ~= 2   then
    gl.Vertex(px, py, 0)
  else
    gl.Vertex(px+cs, py, 0)
  end
  gl.Vertex(px+cs, py, 0)
  if c2 then
    gl.Color(c1[1]*(1-csyMult)+(c2[1]*csyMult),c1[2]*(1-csyMult)+(c2[2]*csyMult),c1[3]*(1-csyMult)+(c2[3]*csyMult),c1[4]*(1-csyMult)+(c2[4]*csyMult))
  end
  gl.Vertex(px+cs, py+cs, 0)
  gl.Vertex(px, py+cs, 0)
  -- bottom right
  if c2 then
    gl.Color(c1[1],c1[2],c1[3],c1[4])
  end
  if ((py <= 0 or sx >= vsx) or (br ~= nil and br == 0)) and br ~= 2 then
    gl.Vertex(sx, py, 0)
  else
    gl.Vertex(sx-cs, py, 0)
  end
  gl.Vertex(sx-cs, py, 0)
  if c2 then
    gl.Color(c1[1]*(1-csyMult)+(c2[1]*csyMult),c1[2]*(1-csyMult)+(c2[2]*csyMult),c1[3]*(1-csyMult)+(c2[3]*csyMult),c1[4]*(1-csyMult)+(c2[4]*csyMult))
  end
  gl.Vertex(sx-cs, py+cs, 0)
  gl.Vertex(sx, py+cs, 0)
  -- top left
  if c2 then
    gl.Color(c2[1],c2[2],c2[3],c2[4])
  end
  if ((sy >= vsy or px <= 0) or (tl ~= nil and tl == 0)) and tl ~= 2 then
    gl.Vertex(px, sy, 0)
  else
    gl.Vertex(px+cs, sy, 0)
  end
  gl.Vertex(px+cs, sy, 0)
  if c2 then
    gl.Color(c2[1]*(1-csyMult)+(c1[1]*csyMult),c2[2]*(1-csyMult)+(c1[2]*csyMult),c2[3]*(1-csyMult)+(c1[3]*csyMult),c2[4]*(1-csyMult)+(c1[4]*csyMult))
  end
  gl.Vertex(px+cs, sy-cs, 0)
  gl.Vertex(px, sy-cs, 0)
  -- top right
  if c2 then
    gl.Color(c2[1],c2[2],c2[3],c2[4])
  end
  if ((sy >= vsy or sx >= vsx)  or (tr ~= nil and tr == 0)) and tr ~= 2 then
    gl.Vertex(sx, sy, 0)
  else
    gl.Vertex(sx-cs, sy, 0)
  end
  gl.Vertex(sx-cs, sy, 0)
  if c2 then
    gl.Color(c2[1]*(1-csyMult)+(c1[1]*csyMult),c2[2]*(1-csyMult)+(c1[2]*csyMult),c2[3]*(1-csyMult)+(c1[3]*csyMult),c2[4]*(1-csyMult)+(c1[4]*csyMult))
  end
  gl.Vertex(sx-cs, sy-cs, 0)
  gl.Vertex(sx, sy-cs, 0)
end
function RectRound(px,py,sx,sy,cs, tl,tr,br,bl, c1,c2)		-- (coordinates work differently than the RectRound func in other widgets)
  --gl.Texture(false)
  gl.BeginEnd(GL.QUADS, DrawRectRound, px,py,sx,sy,cs, tl,tr,br,bl, c1,c2)
end

function IsOnRect(x, y, BLcornerX, BLcornerY,TRcornerX,TRcornerY)
  return x >= BLcornerX and x <= TRcornerX and y >= BLcornerY and y <= TRcornerY
end

local function doCircle(x, y, z, radius, sides)
  local sideAngle = twicePi / sides
  glVertex(x, z, y)
  for i = 1, sides+1 do
    local cx = x + (radius * mCos(i * sideAngle))
    local cz = z + (radius * mSin(i * sideAngle))
    glVertex(cx, cz, y)
  end
end

function drawOrders()
  -- background
  local padding = 0.0033*vsy * ui_scale
  RectRound(backgroundRect[1],backgroundRect[2],backgroundRect[3],backgroundRect[4], padding*1.7, 1,1,1,1,{0.05,0.05,0.05,ui_opacity}, {0,0,0,ui_opacity})
  RectRound(backgroundRect[1]+(altPosition and padding or 0), backgroundRect[2]+padding, backgroundRect[3]-padding, backgroundRect[4]-padding, padding, (altPosition and 1 or 0),1,1,0,{0.3,0.3,0.3,ui_opacity*0.2}, {1,1,1,ui_opacity*0.2})

  -- gloss
  glBlending(GL_SRC_ALPHA, GL_ONE)
  RectRound(backgroundRect[1]+(altPosition and padding or 0),backgroundRect[4]-((backgroundRect[4]-backgroundRect[2])*0.16),backgroundRect[3]-padding,backgroundRect[4]-padding, padding, (altPosition and 1 or 0),1,0,0, {1,1,1,0.012*glossMult}, {1,1,1,0.07*glossMult})
  RectRound(backgroundRect[1]+(altPosition and padding or 0),backgroundRect[2]+(altPosition and 0 or padding),backgroundRect[3]-padding,backgroundRect[2]+((backgroundRect[4]-backgroundRect[2])*0.15), padding, 0,0,(altPosition and 0 or 1),0, {1,1,1,0.03*glossMult}, {1,1,1,0})
  glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

  padding = (bgBorder*vsy) * 0.35

  local cellInnerWidth = (cellRects[1][3]-cellMarginPx) - (cellRects[1][1]+cellMarginPx)--(width*vsx/colls)-cellMarginPx-cellMarginPx-padding-padding
  local cellInnerHeight = (cellRects[1][4]-cellMarginPx) - (cellRects[1][2]+cellMarginPx)--(height*vsy/rows)-cellMarginPx-cellMarginPx-padding-padding
  font2:Begin()
  for cell=1, #cmds do
    local cmd = cmds[cell]
    local isActiveCmd = (activeCmd == cmd.name)
    -- order button background
    local color1, color2
    if isActiveCmd then
      color1 = {0.66,0.66,0.66,0.95}
      color2 = {1,1,1,0.95}
    else
      if WG['guishader'] then
        color1 = (cmd.type == 5) and {0.4,0.4,0.4,0.6} or {0.6,0.6,0.6,0.6}
        color2 = {0.8,0.8,0.8,0.6}
      else
        color1 = (cmd.type == 5) and {0.25,0.25,0.25,1} or {0.33,0.33,0.33,1}
        color2 = {0.55,0.55,0.55,0.95}
      end
      RectRound(cellRects[cell][1]+cellMarginPx, cellRects[cell][2]+cellMarginPx, cellRects[cell][3]-cellMarginPx, cellRects[cell][4]-cellMarginPx, padding*1.66 ,2,2,2,2, color1,color2)

      color1 = {0,0,0,0.8}
      color2 = {0,0,0,0.6}
    end
    RectRound(cellRects[cell][1]+cellMarginPx+padding, cellRects[cell][2]+cellMarginPx+padding, cellRects[cell][3]-cellMarginPx-padding, cellRects[cell][4]-cellMarginPx-padding, padding*1.1 ,2,2,2,2, color1,color2)

    -- gloss
    RectRound(cellRects[cell][1]+cellMarginPx+padding, cellRects[cell][4]-cellMarginPx-((cellRects[cell][4]-cellRects[cell][2])*0.4)-padding, cellRects[cell][3]-cellMarginPx-padding, (cellRects[cell][4]-cellMarginPx)-padding, padding*1.1, 2,2,0,0, {1,1,1,0.045}, {1,1,1,0.1})
    RectRound(cellRects[cell][1]+cellMarginPx+padding, cellRects[cell][2]+cellMarginPx+padding, cellRects[cell][3]-cellMarginPx-padding, (cellRects[cell][2]-cellMarginPx)+((cellRects[cell][4]-cellRects[cell][2])*0.4)-padding, padding*1.1, 0,0,2,2, {1,1,1,0.085}, {1,1,1,0})

    -- icon
    if showIcons then
      if cursorTextures[cmd.cursor] == nil then
        local cursorTexture = 'anims/icexuick_200/cursor'..string.lower(cmd.cursor)..'_0.png'
        cursorTextures[cmd.cursor] = VFS.FileExists(cursorTexture) and cursorTexture or false
      end
      if cursorTextures[cmd.cursor] then
        local cursorTexture = 'anims/icexuick_200/cursor'..string.lower(cmd.cursor)..'_0.png'
        if VFS.FileExists(cursorTexture) then
          local s = 0.45
          local halfsize = s * ((cellRects[cell][4]-cellMarginPx-padding)-(cellRects[cell][2]+cellMarginPx+padding))
          --local midPosX = (cellRects[cell][3]-cellMarginPx-padding) - halfsize - (halfsize*((1-s-s)/2))
          --local midPosY = (cellRects[cell][4]-cellMarginPx-padding) - (((cellRects[cell][4]-cellMarginPx-padding)-(cellRects[cell][2]+cellMarginPx+padding)) / 2)
          local midPosX = (cellRects[cell][3]-cellMarginPx-padding) - (((cellRects[cell][3]-cellMarginPx-padding) - (cellRects[cell][1]+cellMarginPx+padding)) / 2)
          local midPosY = (cellRects[cell][4]-cellMarginPx-padding) - (((cellRects[cell][4]-cellMarginPx-padding)-(cellRects[cell][2]+cellMarginPx+padding)) / 2)
          glColor(1,1,1,0.66)
          glTexture(''..cursorTexture)
          glTexRect(midPosX-halfsize,  midPosY-halfsize,  midPosX+halfsize,  midPosY+halfsize)
          glTexture(false)
        end
      end
    end

    if colorize > 0.01 and not isActiveCmd then
      local x1 = cellRects[cell][1] + cellMarginPx
      if cmdColor[cmd.name] == nil then
        cmdColor[cmd.name] = cmdColorDefault
      end
      local y1 = cellRects[cell][2] + cellMarginPx
      local x2 = cellRects[cell][3] - cellMarginPx --x1 + (padding*2.5)
      local y2 = cellRects[cell][2] + cellMarginPx + ((cellRects[cell][4]-cellRects[cell][2])*0.2) --cellRects[cell][4] - cellMarginPx - padding
      RectRound(x1, y1, x2, y2, padding, 0,0,1,1, {cmdColor[cmd.name][1], cmdColor[cmd.name][2], cmdColor[cmd.name][3], 0.18*colorize}, {cmdColor[cmd.name][1], cmdColor[cmd.name][2], cmdColor[cmd.name][3], 0})
      --x1 = cellRects[cell][1] + cellMarginPx
      --y1 = cellRects[cell][2] + cellMarginPx
      --x2 = cellRects[cell][3] - cellMarginPx --x1 + (padding*2.5)
      --y2 = cellRects[cell][2] + cellMarginPx + ((cellRects[cell][4]-cellRects[cell][2])*0.6) --cellRects[cell][4] - cellMarginPx - padding
      --RectRound(x1, y1, x2, y2, padding, 0,0,1,1, {cmdColor[cmd.name][1], cmdColor[cmd.name][2], cmdColor[cmd.name][3], 0.11*colorize}, {cmdColor[cmd.name][1], cmdColor[cmd.name][2], cmdColor[cmd.name][3], 0})
      x1 = cellRects[cell][1] + cellMarginPx
      y2 = cellRects[cell][4] - cellMarginPx
      x2 = cellRects[cell][3] - cellMarginPx --x1 + (padding*2.5)
      y1 = cellRects[cell][4] - cellMarginPx - ((cellRects[cell][4]-cellRects[cell][2])*0.2) --cellRects[cell][4] - cellMarginPx - padding
      RectRound(x1, y1, x2, y2, padding, 0,0,1,1, {cmdColor[cmd.name][1], cmdColor[cmd.name][2], cmdColor[cmd.name][3], 0}, {cmdColor[cmd.name][1], cmdColor[cmd.name][2], cmdColor[cmd.name][3], 0.12*colorize})
    end

    --if cmdColor[cmd.name] then
    --  local s = 0.11
    --  local radius = s * ((cellRects[cell][4]-cellMarginPx-padding)-(cellRects[cell][2]+cellMarginPx+padding))
    --  local posX = cellRects[cell][3]-cellMarginPx-padding - (radius*2)
    --  local posY = cellRects[cell][4]-cellMarginPx-padding - (radius*2)
    --
    --  glColor(cmdColor[cmd.name][1], cmdColor[cmd.name][2], cmdColor[cmd.name][3], 0.75)
    --  glBeginEnd(GL_TRIANGLE_FAN, doCircle, posX, 0, posY, radius, 16)
    --  radius = radius * 0.6
    --  glColor(0,0,0, 0.15)
    --  glBeginEnd(GL_TRIANGLE_FAN, doCircle, posX, 0, posY, radius, 12)
    --end

    -- text
    if not showIcons or not cursorTextures[cmd.cursor] then
      local text = string_gsub(cmd.name, "\n", " ")
      if cmd.params[1] and cmd.params[cmd.params[1]+2] then
        text = cmd.params[cmd.params[1]+2]
      end
      local fontSize = cellInnerWidth / font2:GetTextWidth('  '..text..' ') * math_min(1, (cellInnerHeight/(rows*6)))
      if fontSize > cellInnerWidth / 6.3 then
        fontSize = cellInnerWidth / 6.3
      end
      local fontHeight = font2:GetTextHeight(text)*fontSize
      local fontHeightOffset = fontHeight*0.34
      if cmd.type == 5 then  -- state cmds (fire at will, etc)
        fontHeightOffset = fontHeight*0.22
      end
      local textColor = "\255\233\233\233"
      if colorize > 0 and cmdColor[cmd.name] then
        local part = (1/colorize)
        local grey = (0.93*(part-1))
        textColor = convertColor((grey + cmdColor[cmd.name][1]) / part, (grey + cmdColor[cmd.name][2]) / part, (grey + cmdColor[cmd.name][3]) / part)
      end
      if isActiveCmd then
        textColor = "\255\020\020\020"
      end
      font2:Print(textColor..text, cellRects[cell][1] + ((cellRects[cell][3]-cellRects[cell][1])/2), (cellRects[cell][2] - ((cellRects[cell][2]-cellRects[cell][4])/2) - fontHeightOffset), fontSize, "con")
    end

    -- state lights
    if cmd.type == 5 then  -- state cmds (fire at will, etc)
      local statecount = #cmd.params-1 --number of states for the cmd
      local curstate = cmd.params[1]+1
      local desiredState = nil
      if clickedCellDesiredState and cell == clickedCell then
        desiredState = clickedCellDesiredState + 1
      end
      if curstate == desiredState then
        clickedCellDesiredState = nil
        desiredState = nil
      end
      local statePadding = 0
      local stateWidth = (cellInnerWidth*(1-statePadding)) / statecount
      local stateHeight = cellInnerHeight * 0.145
      local stateMargin = stateWidth*0.07
      local glowSize = stateHeight * 7.5
      local r,g,b,a = 0,0,0,0
      for i=1, statecount do
        if i == curstate or i == desiredState then
          if i == 1 then
            r,g,b,a = 1,0.1,0.1,(i == desiredState and 0.33 or 0.8)
          elseif i == 2 then
            if statecount == 2 then
              r,g,b,a = 0.1,1,0.1,(i == desiredState and 0.22 or 0.8)
            else
              r,g,b,a = 1,1,0.1,(i == desiredState and 0.22 or 0.8)
            end
          else
            r,g,b,a = 0.1,1,0.1,(i == desiredState and 0.26 or 0.8)
          end
        else
          r,g,b,a = 0,0,0,0.35  -- default off state
        end
        glColor(r,g,b,a)
        local x1 = (cellInnerWidth*statePadding) + cellRects[cell][1] + cellMarginPx + padding + (stateWidth*(i-1)) + (i==1 and 0 or stateMargin)
        local y1 = (cellInnerWidth*statePadding) + cellRects[cell][2] + cellMarginPx + padding
        local x2 = cellRects[cell][1] + cellMarginPx - padding + (stateWidth*i) - (i==statecount and 0 or stateMargin)
        local y2 = (cellInnerWidth*statePadding) + cellRects[cell][2] + cellMarginPx + stateHeight
        if rows < 6 then  -- fancy fitting rectrounds
          RectRound(x1, y1, x2, y2, padding,
                  (i==1 and 0 or 2), (i==statecount and 0 or 2), (i==statecount and 2 or 0), (i==1 and 2 or 0))
        else
          glRect(x1,y1,x2,y2)
        end
        -- fancy active state glow
        if rows < 6 and  i == curstate then
          glBlending(GL_SRC_ALPHA, GL_ONE)
          glColor(r,g,b,0.095)
          glTexture(barGlowCenterTexture)
          glTexRect(x1, y1 - glowSize, x2, y2 + glowSize)
          glTexture(barGlowEdgeTexture)
          glTexRect(x1-(glowSize*2), y1 - glowSize, x1, y2 + glowSize)
          glTexRect(x2+(glowSize*2), y1 - glowSize, x2, y2 + glowSize)
          glTexture(false)
          glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
        end
      end
    end
  end
  font2:End()
end

function widget:RecvLuaMsg(msg, playerID)
  if msg:sub(1,18) == 'LobbyOverlayActive' then
    chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
  end
end

local clickCountDown = 2
function widget:DrawScreen()
  if chobbyInterface then return end
  clickCountDown = clickCountDown - 1
  if clickCountDown == 0 then
    doUpdate = true
  end
  prevActiveCmd = activeCmd
  activeCmd = select(4, spGetActiveCommand())
  if activeCmd ~= prevActiveCmd then
    doUpdate = true
  end

  local x,y,b = Spring.GetMouseState()
  local cellHovered
  if not WG['topbar'] or not WG['topbar'].showingQuit() then
    if IsOnRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
      Spring.SetMouseCursor('cursornormal')
      for cell=1, #cellRects do
        if cmds[cell] then
          if IsOnRect(x, y, cellRects[cell][1], cellRects[cell][2], cellRects[cell][3], cellRects[cell][4]) then
            local cmd = cmds[cell]
            WG['tooltip'].ShowTooltip('ordermenu', cmd.tooltip)
            cellHovered = cell

            -- draw highlight under the button
            if not (activeCmd and activeCmd == cmd.name) then
              local padding = (bgBorder*vsy) * 0.5
              glColor(1,1,1,0.8)
              RectRound(cellRects[cell][1]+cellMarginPx, cellRects[cell][2]+cellMarginPx, cellRects[cell][3]-cellMarginPx, (cellRects[cell][4]-cellMarginPx), padding*1.5 ,2,2,2,2)
              break
            end
          end
        else
          break
        end
      end
    end
  end

  -- make all cmd's fit in the grid
  local now = os_clock()
  if doUpdate or (doUpdateClock and now >= doUpdateClock) then
    if doUpdateClock and now >= doUpdateClock then
      doUpdateClock = nil
      doUpdate = true
    end
    doUpdateClock = nil
    lastUpdate = now
    RefreshCommands()
  end

  if #cmds == 0 then
    if dlistGuishader and WG['guishader'] then
      WG['guishader'].RemoveDlist('ordermenu')
    end
  else
    if dlistGuishader and WG['guishader'] then
      WG['guishader'].InsertDlist(dlistGuishader, 'ordermenu')
    end
    if doUpdate then
      dlistOrders = gl.DeleteList(dlistOrders)
    end
    if not dlistOrders then
      dlistOrders = gl.CreateList( function()
        drawOrders()
      end)
    end

    gl.CallList(dlistOrders)

    -- draw highlight on top of button
    if not WG['topbar'] or not WG['topbar'].showingQuit() then
      if cmds and cellHovered then
        local padding = 0
        if cmds[cellHovered] and activeCmd == cmds[cellHovered].name then
          padding = (bgBorder*vsy) * 0.35
        end
        -- gloss highlight
        glBlending(GL_SRC_ALPHA, GL_ONE)
        RectRound(cellRects[cellHovered][1]+cellMarginPx+padding, cellRects[cellHovered][4]-cellMarginPx-((cellRects[cellHovered][4]-cellRects[cellHovered][2])*0.4)-padding, cellRects[cellHovered][3]-cellMarginPx-padding, (cellRects[cellHovered][4]-cellMarginPx)-padding, (bgBorder*vsy) * 0.5*1.5 ,2,2,0,0, {1,1,1,0.09}, {1,1,1,(disableInput and 0.2 or 0.33)})
        RectRound(cellRects[cellHovered][1]+cellMarginPx+padding, cellRects[cellHovered][2]+cellMarginPx+padding, cellRects[cellHovered][3]-cellMarginPx-padding, (cellRects[cellHovered][2]-cellMarginPx)+((cellRects[cellHovered][4]-cellRects[cellHovered][2])*0.35)-padding, (bgBorder*vsy) * 0.5*1.5 ,0,0,2,2, {1,1,1,(disableInput and 0.04 or 0.08)}, {1,1,1,0})
        glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
      end
    end

    -- clicked cell effect
    if clickedCellTime and cmds[clickedCell] then
      local cell = clickedCell
      local isActiveCmd = (cmds[cell].name == activeCmd)
      local padding = (bgBorder*vsy) * 0.5
      local duration = 0.33
      if isActiveCmd then
        duration = 0.45
      elseif cmds[clickedCell].type == 5 then
        duration = 0.6
      end
      local alpha = 0.33 - ((now-clickedCellTime) / duration)
      if alpha > 0 then
        if isActiveCmd then
          glColor(0,0,0,alpha)
        else
          glBlending(GL_SRC_ALPHA, GL_ONE)
          glColor(1,1,1,alpha)
        end
        RectRound(cellRects[cell][1]+cellMarginPx, cellRects[cell][2]+cellMarginPx, cellRects[cell][3]-cellMarginPx, (cellRects[cell][4]-cellMarginPx), padding*1.5 ,2,2,2,2)
      else
        clickedCellTime = nil
      end
      glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
    end
  end
  doUpdate = nil
end


function widget:MousePress(x, y, button)
  if #cmds > 0 and IsOnRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
    if not disableInput then
      for cell=1, #cellRects do
        local cmd = cmds[cell]
        if cmd then
          if IsOnRect(x, y, cellRects[cell][1], cellRects[cell][2], cellRects[cell][3], cellRects[cell][4]) then
            clickCountDown = 2
            clickedCell = cell
            clickedCellTime = os_clock()

            -- remember desired state: only works for a single cell at a time, because there is no way to re-identify a cell when the selection changes
            if cmd.type == 5 then
              if button == 1 then
                clickedCellDesiredState = cmd.params[1]+1
                if clickedCellDesiredState >= #cmd.params-1 then
                  clickedCellDesiredState = 0
                end
              else
                clickedCellDesiredState = cmd.params[1]-1
                if clickedCellDesiredState < 0 then
                  clickedCellDesiredState = #cmd.params-1
                end
              end
              doUpdate = true
            end

            if playSounds then
              Spring.PlaySoundFile(sound_button, 0.6, 'ui')
            end
            Spring.SetActiveCommand(Spring.GetCmdDescIndex(cmd.id),button,true,false,Spring.GetModKeyState())
            break
          end
        else
          break
        end
      end
    end
    return true
  end
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdOpts, cmdParams, cmdTag)
  if isStateCmd[cmdID] then
    if not hiddencmds[cmdID] and doUpdateClock == nil then
      doUpdateClock = os_clock() + 0.01
    end
  end
end

function widget:SelectionChanged(sel)
  SelectedUnitsCount = spGetSelectedUnitsCount()
  clickCountDown = 2
end


function widget:GetConfigData() --save config
  return {colorize=colorize}
end

function widget:SetConfigData(data) --load config
  if data.colorize ~= nil then
    colorize = data.colorize
  end
end