function widget:GetInfo()
  return {
    name      = "Order menu",
    desc      = "",
    author    = "Floris",
    date      = "April 2020",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true
  }
end


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local showIcons = false
local colorize = 0
local playSounds = true
local posY = 0.7635
local width = 0.23
local height = 0.16
local cellMargin = 0.055
local bgBorder = 0.0033
local bgMargin = 0.0058
local cmdColor = {
  Move = {0.64,1,0.64},
  Stop = {1,0.33,0.33},
  Attack = {1,0.55,0.4},
  ManualFire = {1,0.7,0.7},
  Patrol = {0.73,0.73,1},
  Fight = {1,0.66,1},
  Guard = {0.25,0.9,1},
  --Wait = {0.8,0.8,0.8},
  Repair = {1,1,0.82},
  Reclaim = {0.88,1,0.88},
  Restore = {0.77,1,0.77},
  Capture = {1,0.88,0.45},
  --['Set Target'] = {1,1,0.5},
  --['Cancel Target'] = {1,1,0.5},
  --Mex = {0.9,0.9,0.9},
}

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local fontfile = "fonts/" .. Spring.GetConfigString("bar_font", "Poppins-Regular.otf")
local vsx,vsy = Spring.GetViewGeometry()
local fontfileScale = (0.5 + (vsx*vsy / 5700000))
local fontfileSize = 36
local fontfileOutlineSize = 8
local fontfileOutlineStrength = 1.3
local font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)
local fontfile2 = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
local font2 = gl.LoadFont(fontfile2, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)
local loadedFontSize = fontfileSize*fontfileScale

local bgcorner = ":l:LuaUI/Images/bgcorner.png"
local barGlowCenterTexture = ":l:LuaUI/Images/barglow-center.png"
local barGlowEdgeTexture   = ":l:LuaUI/Images/barglow-edge.png"

local sound_button = 'LuaUI/Sounds/buildbar_waypoint.wav'

local ui_opacity = tonumber(Spring.GetConfigFloat("ui_opacity",0.66) or 0.66)

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
local glTexture = gl.Texture
local glTexRect = gl.TexRect
local glColor = gl.Color
local glRect = gl.Rect

local isSpec = Spring.GetSpectatingState()
local cursorTextures = {}

local function convertColor(r,g,b)
  return string.char(255, (r*255), (g*255), (b*255))
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

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

function setupCellGrid()
  local oldColls = colls
  local oldRows = rows
  local cmdCount = #cmds
  if cmdCount <= 16 then
    colls = 4
    rows = 4
  elseif cmdCount <= 20 then
    colls = 5
    rows = 4
  elseif cmdCount <= 25 then
    colls = 5
    rows = 5
  elseif cmdCount <= 30 then
    colls = 5
    rows = 6
  elseif cmdCount <= 36 then
    colls = 6
    rows = 6
  elseif cmdCount <= 42 then
    colls = 6
    rows = 7
  else
    colls = 7
    rows = 7
  end

  if oldColls ~= colls or oldRows ~= rows then
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

  if WG['red_buildmenu'] and WG['red_buildmenu'].getConfigLargeUnitIcons and WG['red_buildmenu'].getConfigLargeUnitIcons() then
      width = 0.248
      height = 0.193
  else
      width = 0.23
      height = 0.16
  end
  width = width / (vsx/vsy) * 1.78		-- make smaller for ultrawide screens

  vsx,vsy = Spring.GetViewGeometry()
  backgroundRect = {0, (posY-height)*vsy, width*vsx, posY*vsy}
  activeRect = {0 + (bgMargin*vsy), ((posY-height)+bgMargin)*vsy, (width*vsx)-(bgMargin*vsy), (posY-bgMargin)*vsy}

  widget:Shutdown()

  local newFontfileScale = (0.5 + (vsx*vsy / 5700000))
  if fontfileScale ~= newFontfileScale then
    fontfileScale = newFontfileScale
    gl.DeleteFont(font)
    font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)
    gl.DeleteFont(font2)
    font2 = gl.LoadFont(fontfile2, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)
    loadedFontSize = fontfileSize*fontfileScale
  end

end


function widget:Initialize()
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
  if WG['guishader'] then
    WG['guishader'].DeleteDlist('ordermenu')
  end
  dlistOrders = gl.DeleteList(dlistOrders)
end

local uiOpacitySec = 0
function widget:Update(dt)
  uiOpacitySec = uiOpacitySec + dt
  if uiOpacitySec > 0.5 then
    uiOpacitySec = 0
    if ui_opacity ~= Spring.GetConfigFloat("ui_opacity",0.66) then
      ui_opacity = Spring.GetConfigFloat("ui_opacity",0.66)
    end

    disableInput = isSpec
    if Spring.IsGodModeEnabled() then
      disableInput = false
    end
  end
end


local function DrawRectRound(px,py,sx,sy,cs, tl,tr,br,bl)
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

  local offset = 0.15		-- texture offset, because else gaps could show

  -- bottom left
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
function RectRound(px,py,sx,sy,cs, tl,tr,br,bl)		-- (coordinates work differently than the RectRound func in other widgets)
  gl.Texture(bgcorner)
  gl.BeginEnd(GL_QUADS, DrawRectRound, px,py,sx,sy,cs, tl,tr,br,bl)
  gl.Texture(false)
end

function IsOnRect(x, y, BLcornerX, BLcornerY,TRcornerX,TRcornerY)
  return x >= BLcornerX and x <= TRcornerX and y >= BLcornerY and y <= TRcornerY
end

function drawOrders()
  -- background
  local padding = bgBorder*vsy
  glColor(0,0,0,ui_opacity)
  RectRound(backgroundRect[1],backgroundRect[2],backgroundRect[3],backgroundRect[4], padding*2)
  glColor(1,1,1,0.05)
  RectRound(backgroundRect[1]+padding, backgroundRect[2]+padding, backgroundRect[3]-padding, backgroundRect[4]-padding, padding*1.33)

  padding = (bgBorder*vsy) * 0.5
  local numCells = #cmds
  if numCells > #cellRects then
    numCells = #cellRects
  end

  local cellInnerWidth = (cellRects[1][3]-cellMarginPx) - (cellRects[1][1]+cellMarginPx)--(width*vsx/colls)-cellMarginPx-cellMarginPx-padding-padding
  local cellInnerHeight = (cellRects[1][4]-cellMarginPx) - (cellRects[1][2]+cellMarginPx)--(height*vsy/rows)-cellMarginPx-cellMarginPx-padding-padding
  font2:Begin()
  for cell=1, numCells do
    local cmd = cmds[cell]

    -- order button background
    if WG['guishader'] then
      glColor(0.6,0.6,0.6,0.5)
    else
      glColor(0.5,0.5,0.5,0.75)
    end
    RectRound(cellRects[cell][1]+cellMarginPx, cellRects[cell][2]+cellMarginPx, cellRects[cell][3]-cellMarginPx, cellRects[cell][4]-cellMarginPx, padding*1.5 ,2,2,2,2)
    glColor(0.09,0.09,0.09,0.66)
    if activeCmd and activeCmd == cmd.name then
      glColor(1,1,1,0.66)
    end
    RectRound(cellRects[cell][1]+cellMarginPx+padding, cellRects[cell][2]+cellMarginPx+padding, cellRects[cell][3]-cellMarginPx-padding, cellRects[cell][4]-cellMarginPx-padding, padding ,2,2,2,2)

    -- icon
    if showIcons then
      if cursorTextures[cmd.cursor] == nil then
        local cursorTexture = 'anims/icexuick_200/cursor'..string.lower(cmd.cursor)..'_0.png'
        cursorTextures[cmd.cursor] = VFS.FileExists(cursorTexture) and cursorTexture or false
      end
      if cursorTextures[cmd.cursor] then
        local cursorTexture = 'anims/icexuick_200/cursor'..string.lower(cmd.cursor)..'_0.png'
        if VFS.FileExists(cursorTexture) then
          Spring.Echo(cursorTexture)
          local s = 0.45
          local halfsize = s * ((cellRects[cell][4]-cellMarginPx-padding)-(cellRects[cell][2]+cellMarginPx+padding))
          --local midPosX = (cellRects[cell][3]-cellMarginPx-padding) - halfsize - (halfsize*((1-s-s)/2))
          --local midPosY = (cellRects[cell][4]-cellMarginPx-padding) - (((cellRects[cell][4]-cellMarginPx-padding)-(cellRects[cell][2]+cellMarginPx+padding)) / 2)
          local midPosX = (cellRects[cell][3]-cellMarginPx-padding) - (((cellRects[cell][3]-cellMarginPx-padding) - (cellRects[cell][1]+cellMarginPx+padding)) / 2)
          local midPosY = (cellRects[cell][4]-cellMarginPx-padding) - (((cellRects[cell][4]-cellMarginPx-padding)-(cellRects[cell][2]+cellMarginPx+padding)) / 2)
          glColor(1,1,1,0.66)
          glTexture(''..cursorTexture)
          glTexRect(midPosX-halfsize,  midPosY-halfsize,  midPosX+halfsize,  midPosY+halfsize)
        end
      end
    end

    -- text
    if not showIcons or not cursorTextures[cmd.cursor] then
      local text = string_gsub(cmd.name, "\n", " ")
      if cmd.params[1] and cmd.params[cmd.params[1]+2] then
        text = cmd.params[cmd.params[1]+2]
      end
      local fontSize = cellInnerWidth / font:GetTextWidth(' '..text..' ')
      if fontSize > cellInnerWidth / 6 then
        fontSize = cellInnerWidth / 6
      end
      local fontHeight = font:GetTextHeight(text)*fontSize
      local fontHeightOffset = fontHeight*0.34
      if cmd.type == 5 then  -- state cmds (fire at will, etc)
        fontHeightOffset = fontHeight*0.22
      end
      local textColor = "\255\225\225\225"
      if colorize > 0 and cmdColor[cmd.name] then
        local part = (1/colorize)
        local grey = (0.9*(part-1))
        textColor = convertColor((grey + cmdColor[cmd.name][1]) / part, (grey + cmdColor[cmd.name][2]) / part, (grey + cmdColor[cmd.name][3]) / part)
      end
      if activeCmd and activeCmd == cmd.name then
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
      local stateWidth = cellInnerWidth / statecount
      local stateHeight = cellInnerHeight * 0.145
      local stateMargin = stateWidth*0.07
      local glowSize = stateHeight * 5.5
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
          r,g,b,a = 0,0,0,0.3  -- default off state
        end
        glColor(r,g,b,a)
        local x1 = cellRects[cell][1] + cellMarginPx + padding + (stateWidth*(i-1)) + (i==1 and 0 or stateMargin)
        local y1 = cellRects[cell][2] + cellMarginPx + padding
        local x2 = cellRects[cell][1] + cellMarginPx - padding + (stateWidth*i) - (i==statecount and 0 or stateMargin)
        local y2 = cellRects[cell][2] + cellMarginPx + stateHeight
        if rows < 6 then  -- fancy fitting rectrounds
          RectRound(x1, y1, x2, y2, padding,
                  (i==1 and 0 or 2), (i==statecount and 0 or 2), (i==statecount and 2 or 0), (i==1 and 2 or 0))
        else
          glRect(x1,y1,x2,y2)
        end
        -- fancy active state glow
        if rows < 6 and  i == curstate then
          glColor(r,g,b,0.075)
          glTexture(barGlowCenterTexture)
          glTexRect(x1, y1 - glowSize, x2, y2 + glowSize)
          glTexture(barGlowEdgeTexture)
          glTexRect(x1-(glowSize*2), y1 - glowSize, x1, y2 + glowSize)
          glTexRect(x2+(glowSize*2), y1 - glowSize, x2, y2 + glowSize)
        end
      end
    end
  end
  font2:End()
end

local clickCountDown = 2
function widget:DrawScreen()
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
  if IsOnRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
    Spring.SetMouseCursor('cursornormal')
      for cell=1, #cellRects do
        if cmds[cell] then
          if IsOnRect(x, y, cellRects[cell][1], cellRects[cell][2], cellRects[cell][3], cellRects[cell][4]) then
            local cmd = cmds[cell]
            WG['tooltip'].ShowTooltip('ordermenu', cmd.tooltip)
            cellHovered = cell
            -- draw highlight under the button
            if not disableInput then
              local padding = (bgBorder*vsy) * 0.5
              glColor(1,1,1,1)
              RectRound(cellRects[cell][1]+cellMarginPx, cellRects[cell][2]+cellMarginPx, cellRects[cell][3]-cellMarginPx, (cellRects[cell][4]-cellMarginPx), padding*1.5 ,2,2,2,2)
              break
            end
          end
        else
          break
        end
    end
  end

  -- scan for state changes (they are delayed cause need to go to the server and confirmed back)
  if not doUpdate and os_clock() - lastUpdate > 0.15 then
    local i = 0
    for index,cmd in pairs(spGetActiveCmdDescs()) do
      if type(cmd) == "table" and cmd.type == 5 and not hiddencmds[cmd.id] then
        i = i + 1
        if cmds[i] and cmds[i].params[1] ~= cmd.params[1] then
          doUpdate = true
          break
        end
      end
    end
  end

  -- make all cmd's fit in the grid
  if doUpdate then
    lastUpdate = os_clock()
    RefreshCommands()
  end

  if #cmds == 0 then
    if WG['guishader'] then
      WG['guishader'].DeleteDlist('ordermenu')
    end
  else
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
    if cellHovered and not disableInput then
      local padding = (bgBorder*vsy) * 0.5
      glColor(1,1,1,0.09)
      RectRound(cellRects[cellHovered][1]+cellMarginPx, cellRects[cellHovered][2]+cellMarginPx, cellRects[cellHovered][3]-cellMarginPx, (cellRects[cellHovered][4]-cellMarginPx), padding*1.5 ,2,2,2,2)
    end

    -- clicked cell effect
    if clickedCellTime and cmds[clickedCell] then
      local cell = clickedCell
      local padding = (bgBorder*vsy) * 0.5
      local alpha = 0.3 - ((os_clock()-clickedCellTime) / 0.4)
      if alpha > 0 then
        if activeCmd and activeCmd == cmds[cell].name then
          glColor(0,0,0,alpha)
        else
          glColor(1,1,1,alpha)
        end
        RectRound(cellRects[cell][1]+cellMarginPx, cellRects[cell][2]+cellMarginPx, cellRects[cell][3]-cellMarginPx, (cellRects[cell][4]-cellMarginPx), padding*1.5 ,2,2,2,2)
      else
        clickedCellTime = nil
      end
    end

    -- background blur
    if WG['guishader'] then
      dlistGuishader = gl.CreateList( function()
        RectRound(backgroundRect[1],backgroundRect[2],backgroundRect[3],backgroundRect[4], (bgBorder*vsy)*2)
      end)
      WG['guishader'].InsertDlist(dlistGuishader, 'ordermenu')
    end
  end
  doUpdate = nil
end

function widget:MousePress(x, y, button)
  if #cmds > 0 then
    if IsOnRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
      if not disableInput then
        for cell=1, #cellRects do
          local cmd = cmds[cell]
          if cmd then
            if IsOnRect(x, y, cellRects[cell][1], cellRects[cell][2], cellRects[cell][3], cellRects[cell][4]) then
              if playSounds then
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

                Spring.PlaySoundFile(sound_button, 0.6, 'ui')
                Spring.SetActiveCommand(Spring.GetCmdDescIndex(cmd.id),button,true,false,Spring.GetModKeyState())
              end
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