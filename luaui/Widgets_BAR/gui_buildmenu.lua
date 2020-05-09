function widget:GetInfo()
  return {
    name      = "Buildmenu",
    desc      = "",
    author    = "Floris",
    date      = "April 2020",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true,
    handler   = true,
  }
end


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local bgBorderOrg = 0.0035
local bgBorder = bgBorderOrg
local bgMargin = 0.005
local showPrice = true
local showRadarIcon = true
local showShortcuts = false
local makeFancy = true
local dynamicIconsize = true
local defaultColls = 5
local minColls = 5
local maxColls = 6

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local buildStartKey = 98
local buildNextKey = 110
local buildKeys = {113, 119, 101, 114, 116, 97, 115, 100, 102, 103, 122, 120, 99, 118, 98}
local buildLetters = {"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"}

local sound_queue_add = 'LuaUI/Sounds/buildbar_add.wav'
local sound_queue_rem = 'LuaUI/Sounds/buildbar_rem.wav'
local sound_button = 'LuaUI/Sounds/buildbar_waypoint.wav'

local fontfile = "fonts/" .. Spring.GetConfigString("bar_font", "Poppins-Regular.otf")
local vsx,vsy = Spring.GetViewGeometry()
local fontfileScale = (0.5 + (vsx*vsy / 5700000))
local fontfileSize = 36
local fontfileOutlineSize = 7
local fontfileOutlineStrength = 1.55
local font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)
local fontfile2 = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
local font2 = gl.LoadFont(fontfile2, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)
local loadedFontSize = fontfileSize*fontfileScale

local barGlowCenterTexture = ":l:LuaUI/Images/barglow-center.png"
local barGlowEdgeTexture   = ":l:LuaUI/Images/barglow-edge.png"

local ui_opacity = tonumber(Spring.GetConfigFloat("ui_opacity",0.66) or 0.66)
local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale",1) or 1)

local backgroundRect = {0,0,0,0}
local currentTooltip = ''
local colls = 5
local rows = 5
local minimapHeight = 0.235
local minimapEnlarged = false
local posY = 0
local posY2 = 0
local width = 0
local height = 0
local selectedBuilderCount = 0
local selectedBuilders = {}
local cellRects = {}
local cmds = {}
local lastUpdate = os.clock()-1
local currentPage = 1
local pages = 1
local paginatorRects = {}

WG.hoverID = nil

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local spGetSelectedUnitsCount = Spring.GetSelectedUnitsCount
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetActiveCommand = Spring.GetActiveCommand
local spGetActiveCmdDescs = Spring.GetActiveCmdDescs
local spGetCurrentTooltip = Spring.GetCurrentTooltip
local spGetUnitDefID = Spring.GetUnitDefID

local SelectedUnitsCount = spGetSelectedUnitsCount()

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

local glCreateTexture = gl.CreateTexture
local glActiveTexture = gl.ActiveTexture
local glCopyToTexture = gl.CopyToTexture
local glRenderToTexture = gl.RenderToTexture

local isSpec = Spring.GetSpectatingState()
local disableInput = isSpec

local function convertColor(r,g,b)
  return string.char(255, (r*255), (g*255), (b*255))
end

function wrap(str, limit)
  limit = limit or 72
  local here = 1
  local buf = ""
  local t = {}
  str:gsub("(%s*)()(%S+)()",
    function(sp, st, word, fi)
      if fi-here > limit then
        --# Break the line
        here = st
        t[#t+1] = buf
        buf = word
      else
        buf = buf..sp..word  --# Append
      end
    end)
  --# Tack on any leftovers
  if(buf ~= "") then
    t[#t+1] = buf
  end
  return t
end

local alternativeUnitpics = false
local hasAlternativeUnitpic = {}
local unitBuildPic = {}
local unitEnergyCost = {}
local unitMetalCost = {}
local unitGroup = {}
local isBuilder = {}
local unitHumanName = {}
local unitDescriptionLong = {}
local unitTooltip = {}
local unitIconType = {}
for unitDefID, unitDef in pairs(UnitDefs) do
  unitHumanName[unitDefID] = unitDef.humanName
  if unitDef.customParams.description_long then
    unitDescriptionLong[unitDefID] = wrap(unitDef.customParams.description_long, 58)
  end
  unitTooltip[unitDefID] = unitDef.tooltip
  unitIconType[unitDefID] = unitDef.iconType
  unitEnergyCost[unitDefID] = unitDef.energyCost
  unitMetalCost[unitDefID] = unitDef.metalCost
  unitGroup = {}
  unitBuildPic[unitDefID] = unitDef.buildpicname
  if VFS.FileExists('unitpics/alternative/'..unitDef.name..'.png') then
    hasAlternativeUnitpic[unitDefID] = true
  end
  if unitDef.buildSpeed > 0 and unitDef.buildOptions[1] then
    isBuilder[unitDefID] = true
  end
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

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

  local offset = 0.15		-- texture offset, because else gaps could show

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

local function checkGuishader(force)
  if WG['guishader'] then
    if force and dlistGuishader then
      dlistGuishader = gl.DeleteList(dlistGuishader)
    end
    if not dlistGuishader then
      dlistGuishader = gl.CreateList( function()
        RectRound(backgroundRect[1],backgroundRect[2],backgroundRect[3],backgroundRect[4], (bgBorder*vsy)*2)
      end)
      WG['guishader'].InsertDlist(dlistGuishader, 'buildmenu')
    end
  elseif dlistGuishader then
    dlistGuishader = gl.DeleteList(dlistGuishader)
  end
end

function widget:PlayerChanged(playerID)
  isSpec = Spring.GetSpectatingState()
end

local function RefreshCommands()
  cmds = {}
  cmdsCount = 0
  for index,cmd in pairs(spGetActiveCmdDescs()) do
    if type(cmd) == "table" then
      if string_sub(cmd.action,1,10) == 'buildunit_' then -- not cmd.disabled and cmd.type == 20 or
        cmdsCount = cmdsCount + 1
        cmds[cmdsCount] = cmd
      end
    end
  end
end


function widget:ViewResize()
  vsx,vsy = Spring.GetViewGeometry()

  if WG['minimap'] then
    minimapEnlarged = WG['minimap'].getEnlarged()
    minimapHeight = WG['minimap'].getHeight()
  end

  posY = 0.606
  posY2 = 0.1445
  if minimapEnlarged then
    posY = math.max(0.4615, (vsy-minimapHeight)/vsy) - 0.0064
  end
  height = (posY - posY2)
  width = 0.23

  width = width / (vsx/vsy) * 1.78		-- make smaller for ultrawide screens
  width = width * ui_scale

  backgroundRect = {0, (posY-height)*vsy, width*vsx, posY*vsy}

  checkGuishader(true)

  clear()
  doUpdate = true

  local newFontfileScale = (0.5 + (vsx*vsy / 5700000)) * ui_scale
  if fontfileScale ~= newFontfileScale then
    fontfileScale = newFontfileScale
    gl.DeleteFont(font)
    font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)
    gl.DeleteFont(font2)
    font2 = gl.LoadFont(fontfile2, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)
    loadedFontSize = fontfileSize*fontfileScale
  end

end


local function hijacklayout()
  local function dummylayouthandler(xIcons, yIcons, cmdCount, commands) --gets called on selection change
    widgetHandler.commands = commands
    widgetHandler.commands.n = cmdCount
    widgetHandler:CommandsChanged() --call widget:CommandsChanged()
    local iconList = {[1337]=9001}
    local custom_cmdz = widgetHandler.customCommands
    return "", xIcons, yIcons, {}, custom_cmdz, {}, {}, {}, {}, {}, iconList
  end
  widgetHandler:ConfigLayoutHandler(dummylayouthandler) --override default build/ordermenu layout
  Spring.ForceLayoutUpdate()
end

function widget:Initialize()
  hijacklayout()
  if Script.LuaRules('GetIconTypes') then
    iconTypesMap = Script.LuaRules.GetIconTypes()
  end
  widget:ViewResize()
  widget:SelectionChanged(spGetSelectedUnits())

  WG['buildmenu'] = {}
  WG['buildmenu'].getMakeFancy = function()
    return makeFancy
  end
  WG['buildmenu'].setMakeFancy = function(value)
    makeFancy = value
    doUpdate = true
  end
  WG['buildmenu'].getShowPrice = function()
    return showPrice
  end
  WG['buildmenu'].setShowPrice = function(value)
    showPrice = value
    doUpdate = true
  end
  WG['buildmenu'].getShowRadarIcon = function()
    return showRadarIcon
  end
  WG['buildmenu'].setShowRadarIcon = function(value)
    showRadarIcon = value
    doUpdate = true
  end
  WG['buildmenu'].getShowShortcuts = function()
    return showShortcuts
  end
  WG['buildmenu'].setShowShortcuts = function(value)
    showShortcuts = value
    doUpdate = true
  end
  WG['buildmenu'].getDynamicIconsize = function()
    return dynamicIconsize
  end
  WG['buildmenu'].setDynamicIconsize = function(value)
    dynamicIconsize = value
    doUpdate = true
  end
  WG['buildmenu'].getMinColls = function()
    return minColls
  end
  WG['buildmenu'].setMinColls = function(value)
    minColls = value
    doUpdate = true
  end
  WG['buildmenu'].getMaxColls = function()
    return maxColls
  end
  WG['buildmenu'].setMaxColls = function(value)
    maxColls = value
    doUpdate = true
  end
  WG['buildmenu'].getDefaultColls = function()
    return defaultColls
  end
  WG['buildmenu'].setDefaultColls = function(value)
    defaultColls = value
    doUpdate = true
  end
  WG['buildmenu'].getAlternativeIcons = function()
    return alternativeUnitpics
  end
  WG['buildmenu'].setAlternativeIcons = function(value)
    alternativeUnitpics = value
    doUpdate = true
  end
end

function clear()
  dlistBuildmenu = gl.DeleteList(dlistBuildmenu)
end

function widget:Shutdown()
  if hijackedlayout and not WG['red_buildmenu'] then
    widgetHandler:ConfigLayoutHandler(true)
    Spring.ForceLayoutUpdate()
  end
  clear()
  if WG['guishader'] and dlistGuishader then
    WG['guishader'].DeleteDlist('buildmenu')
    dlistGuishader = nil
  end
  WG['buildmenu'] = nil
end

local uiOpacitySec = 0
function widget:Update(dt)
  uiOpacitySec = uiOpacitySec + dt
  if uiOpacitySec > 0.33 then
    doUpdate = true -- remove this when properly refreshing
    uiOpacitySec = 0
    checkGuishader()
    if ui_scale ~= Spring.GetConfigFloat("ui_scale",1) then
      ui_scale = Spring.GetConfigFloat("ui_scale",1)
      widget:ViewResize()
      doUpdate = true
    end
    if ui_opacity ~= Spring.GetConfigFloat("ui_opacity",0.66) then
      ui_opacity = Spring.GetConfigFloat("ui_opacity",0.66)
      clear()
      doUpdate = true
    end
    if WG['minimap'] and minimapEnlarged ~= WG['minimap'].getEnlarged() then
      widget:ViewResize()
      doUpdate = true
    end

    disableInput = isSpec
    if Spring.IsGodModeEnabled() then
      disableInput = false
    end
  end
end

function drawBuildmenu()
  -- background
  padding = bgBorder*vsy * ui_scale
  RectRound(backgroundRect[1],backgroundRect[2],backgroundRect[3],backgroundRect[4], padding*1.7, 1,1,1,1,{0.05,0.05,0.05,ui_opacity}, {0,0,0,ui_opacity})
  RectRound(backgroundRect[1], backgroundRect[2]+padding, backgroundRect[3]-padding, backgroundRect[4]-padding, padding*1, 0,1,1,0,{0.3,0.3,0.3,ui_opacity*0.2}, {1,1,1,ui_opacity*0.2})

  local activeArea = {backgroundRect[1], backgroundRect[2]+padding, backgroundRect[3]-padding, backgroundRect[4]-padding}
  local contentHeight = activeArea[4]-activeArea[2]
  local contentWidth = activeArea[3]-activeArea[1]

  -- determine grid size
  if not dynamicIconsize then
    colls = defaultColls
    cellSize = contentWidth/colls
    rows = math.floor(contentHeight/cellSize)
  else
    colls = minColls
    cellSize = contentWidth/colls
    rows = math.floor(contentHeight/cellSize)
    if minColls < maxColls then
      while cmdsCount > rows*colls do
        colls = colls + 1
        cellSize = contentWidth/colls
        rows = math.floor(contentHeight/cellSize)
        if colls == maxColls then
          break
        end
      end
    end
  end

  -- adjust grid size when pages are needed
  local paginatorCellHeight = contentHeight-(rows*cellSize)
  if cmdsCount > colls*rows then
    --currentPage = 1
    pages = math.ceil(cmdsCount / (colls*rows))
    -- remove a row if there isnt enough room for the paginator UI
    if paginatorCellHeight < (0.06*(1-((colls/4)*0.25)))*vsy then
      rows = rows - 1
      paginatorCellHeight = contentHeight-(rows*cellSize)
    end
  else
    currentPage = 1
    pages = 1
  end

  -- there are globals so it can be used for the hover highlight
  cellPadding = cellSize * 0.008
  iconPadding = cellSize * 0.02
  cellInnerSize = cellSize-cellPadding-cellPadding
  radariconSize = cellInnerSize * 0.29
  radariconOffset = (cellInnerSize * 0.027) + cellPadding+iconPadding
  local priceFontSize = cellInnerSize*0.18

  local textureDetail = math.max(80, math.ceil(160*(1-((colls/4)*0.15))) )
  local radariconTextureDetail = math.max(28, math.ceil(120*(1-((colls/4)*0.4))) )

  cellRects = {}
  local numCellsPerPage = rows*colls
  local cellRectID = numCellsPerPage * (currentPage-1)
  local maxCellRectID = numCellsPerPage * currentPage
  if maxCellRectID > cmdsCount then
    maxCellRectID = cmdsCount
  end
  font2:Begin()
  local iconCount = 0
  for row=1, rows do
    if cellRectID >= maxCellRectID then
      break
    end
    for coll=1, colls do
      if cellRectID >= maxCellRectID then
        break
      end
      iconCount = iconCount + 1
      cellRectID = cellRectID + 1
      local uDefID = cmds[cellRectID].id*-1
      cellRects[cellRectID] = {
        activeArea[1] + ((coll-1)*cellSize),
        activeArea[4] - ((row)*cellSize),
        activeArea[1] + ((coll)*cellSize),
        activeArea[4] - ((row-1)*cellSize)
      }

      -- encapsulating cell background
      --RectRound(cellRects[cellRectID][1]+cellPadding, cellRects[cellRectID][2]+cellPadding, cellRects[cellRectID][3]-cellPadding, cellRects[cellRectID][4]-cellPadding, cellSize*0.03, 1,1,1,1, {0.3,0.3,0.3,0.95},{0.22,0.22,0.22,0.95})

      -- unit icon
      glColor(1,1,1,1)
      glTexture(':lr'..textureDetail..','..textureDetail..':unitpics/'..((alternativeUnitpics and hasAlternativeUnitpic[uDefID]) and 'alternative/' or '')..unitBuildPic[uDefID])
      glTexRect(cellRects[cellRectID][1]+cellPadding+iconPadding, cellRects[cellRectID][2]+cellPadding+iconPadding, cellRects[cellRectID][3]-cellPadding-iconPadding, cellRects[cellRectID][4]-cellPadding-iconPadding)

      if makeFancy then

        -- lighten top
        glBlending(GL_SRC_ALPHA, GL_ONE)
        -- glossy half
        --RectRound(cellRects[cellRectID][1]+iconPadding, cellRects[cellRectID][4]-iconPadding-(cellInnerSize*0.5), cellRects[cellRectID][3]-iconPadding, cellRects[cellRectID][4]-iconPadding, cellSize*0.03, 1,1,0,0,{1,1,1,0.1}, {1,1,1,0.18})
        RectRound(cellRects[cellRectID][1]+cellPadding+iconPadding, cellRects[cellRectID][4]-cellPadding-iconPadding-(cellInnerSize*0.66), cellRects[cellRectID][3]-cellPadding-iconPadding, cellRects[cellRectID][4]-cellPadding-iconPadding, cellSize*0.03, 0,0,0,0,{1,1,1,0}, {1,1,1,0.2})
        glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

        -- extra darken gradually
        RectRound(cellRects[cellRectID][1]+cellPadding+iconPadding, cellRects[cellRectID][2]+cellPadding+iconPadding, cellRects[cellRectID][3]-cellPadding-iconPadding, cellRects[cellRectID][4]-cellPadding-iconPadding, cellSize*0.03, 0,0,0,0,{0,0,0,0.12}, {0,0,0,0})
      end

      -- darken price background gradually
      if showPrice then
        RectRound(cellRects[cellRectID][1]+cellPadding+iconPadding, cellRects[cellRectID][2]+cellPadding+iconPadding, cellRects[cellRectID][3]-cellPadding-iconPadding, cellRects[cellRectID][2]+cellPadding+iconPadding+(cellInnerSize*0.415), cellSize*0.03, 0,0,0,0,{0,0,0,(makeFancy and 0.22 or 0.3)}, {0,0,0,0})
      end

      -- radar icon
      if showRadarIcon then
        glColor(1,1,1,0.9)
        glTexture(':lr'..radariconTextureDetail..','..radariconTextureDetail..':'..iconTypesMap[unitIconType[uDefID]])
        glTexRect(cellRects[cellRectID][3]-radariconOffset-radariconSize, cellRects[cellRectID][2]+radariconOffset, cellRects[cellRectID][3]-radariconOffset, cellRects[cellRectID][2]+radariconOffset+radariconSize)
      end

      glTexture(false)

      -- price
      if showPrice then
        --doCircle(x, y, z, radius, sides)
        font2:Print("\255\245\245\245"..unitMetalCost[uDefID].."\n\255\255\255\000"..unitEnergyCost[uDefID], cellRects[cellRectID][1]+cellPadding+(cellInnerSize*0.05), cellRects[cellRectID][2]+cellPadding+(priceFontSize*1.4), priceFontSize, "o")
      end

      -- shortcuts
      if showShortcuts then
        --local text = ''
        --if iconCount < 15 then
        --  text = buildLetters[buildStartKey-96].." - "
        --  if buildKeys[iconCount] then
        --    text = text .. buildLetters[buildKeys[iconCount]-96]
        --  else
        --    text = ''
        --  end
        --else
        --  text = buildLetters[buildNextKey-96].." - "
        --  if buildKeys[iconCount-15] then
        --    text = text .. buildLetters[buildKeys[iconCount-15]-96]
        --  else
        --    text = ''
        --  end
        --end
        --font2:Print("\255\155\155\255"..text, cellRects[cellRectID][1]+cellPadding+(cellInnerSize*0.05), cellRects[cellRectID][4]-cellPadding-priceFontSize, priceFontSize, "o")
      end

      -- factory queue number
      if cmds[cellRectID].params[1] then
        font2:Print("\255\190\255\190"..cmds[cellRectID].params[1],
                cellRects[cellRectID][1]+cellPadding+(cellInnerSize*0.92),
                cellRects[cellRectID][2]+cellPadding+(cellInnerSize*0.66),
                cellInnerSize*0.33, "ro"
        )
      end

      -- active / selected
      if activeCmd and activeCmd == cmds[cellRectID].name then
        glBlending(GL_SRC_ALPHA, GL_ONE)
        glColor(1,0.85,0.2,0.66)
        glTexture(':lr128,128:unitpics/'..unitBuildPic[uDefID])
        glTexRect(cellRects[cellRectID][1]+cellPadding+iconPadding, cellRects[cellRectID][2]+cellPadding+iconPadding, cellRects[cellRectID][3]-cellPadding-iconPadding, cellRects[cellRectID][4]-cellPadding-iconPadding)
        glTexture(false)
        glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
      end
    end
  end

  -- paginator
  if pages == 1 then
    paginatorRects = {}
  else
    local paginatorFontSize = math.max(0.016*vsy, paginatorCellHeight*0.2)
    local paginatorCellWidth = contentWidth*0.3
    paginatorRects[1] = {activeArea[1], activeArea[2], activeArea[1]+paginatorCellWidth, activeArea[2]+paginatorCellHeight}
    paginatorRects[2] = {activeArea[3]-paginatorCellWidth, activeArea[2], activeArea[3], activeArea[2]+paginatorCellHeight}
    RectRound(paginatorRects[1][1]+cellPadding, paginatorRects[1][2]+cellPadding, paginatorRects[1][3]-cellPadding, paginatorRects[1][4]-cellPadding, cellSize*0.03, 1,1,1,1,{0.21,0.21,0.21,1}, {0.27,0.27,0.27,1})
    RectRound(paginatorRects[2][1]+cellPadding, paginatorRects[2][2]+cellPadding, paginatorRects[2][3]-cellPadding, paginatorRects[2][4]-cellPadding, cellSize*0.03, 1,1,1,1,{0.21,0.21,0.21,1}, {0.27,0.27,0.27,1})
    RectRound(paginatorRects[1][1]+cellPadding+iconPadding, paginatorRects[1][2]+cellPadding+iconPadding, paginatorRects[1][3]-cellPadding-iconPadding, paginatorRects[1][4]-cellPadding-iconPadding, cellSize*0.02, 1,1,1,1,{0,0,0,0.34}, {0,0,0,0.17})
    RectRound(paginatorRects[2][1]+cellPadding+iconPadding, paginatorRects[2][2]+cellPadding+iconPadding, paginatorRects[2][3]-cellPadding-iconPadding, paginatorRects[2][4]-cellPadding-iconPadding, cellSize*0.02, 1,1,1,1,{0,0,0,0.34}, {0,0,0,0.17})
    -- glossy half
    RectRound(paginatorRects[1][1]+cellPadding, paginatorRects[1][4]-cellPadding-((paginatorRects[1][4]-paginatorRects[1][2])*0.5), paginatorRects[1][3]-cellPadding, paginatorRects[1][4]-cellPadding, cellSize*0.03, 1,1,0,0,{1,1,1,0.045}, {1,1,1,0.15})
    RectRound(paginatorRects[2][1]+cellPadding, paginatorRects[2][4]-cellPadding-((paginatorRects[2][4]-paginatorRects[1][2])*0.5), paginatorRects[2][3]-cellPadding, paginatorRects[2][4]-cellPadding, cellSize*0.03, 1,1,0,0,{1,1,1,0.045}, {1,1,1,0.15})
    -- glossy bottom
    RectRound(paginatorRects[1][1]+cellPadding, paginatorRects[1][2]+cellPadding, paginatorRects[1][3]-cellPadding, paginatorRects[1][2]+cellPadding+((paginatorRects[1][4]-paginatorRects[1][2])*0.18), cellSize*0.03, 0,0,1,1,{1,1,1,0.06}, {1,1,1,0})
    RectRound(paginatorRects[2][1]+cellPadding, paginatorRects[2][2]+cellPadding, paginatorRects[2][3]-cellPadding, paginatorRects[2][2]+cellPadding+((paginatorRects[2][4]-paginatorRects[1][2])*0.18), cellSize*0.03, 0,0,1,1,{1,1,1,0.06}, {1,1,1,0})
    -- left arrow
    --local arrowHalfsize = paginatorCellHeight * 0.12
    --RectRound((paginatorRects[1][1]+(paginatorCellWidth*0.5))-(arrowHalfsize*1.5), (paginatorRects[1][2]+(paginatorCellHeight*0.5)), (paginatorRects[1][1]+(paginatorCellWidth*0.5))+arrowHalfsize+arrowHalfsize, (paginatorRects[1][2]+(paginatorCellHeight*0.5))+arrowHalfsize, arrowHalfsize*0.5, 1,0,0,0,{1,1,1,0.22}, {1,1,1,0.33})
    --RectRound((paginatorRects[1][1]+(paginatorCellWidth*0.5))-(arrowHalfsize*1.5), (paginatorRects[1][2]+(paginatorCellHeight*0.5))-arrowHalfsize, (paginatorRects[1][1]+(paginatorCellWidth*0.5))+arrowHalfsize+arrowHalfsize, (paginatorRects[1][2]+(paginatorCellHeight*0.5)), arrowHalfsize*0.5, 0,0,0,1,{1,1,1,0.1}, {1,1,1,0.18})
    -- right arrow
    --RectRound((paginatorRects[2][1]+(paginatorCellWidth*0.5))-(arrowHalfsize*1.5), (paginatorRects[2][2]+(paginatorCellHeight*0.5)), (paginatorRects[2][1]+(paginatorCellWidth*0.5))+(arrowHalfsize*1.5), (paginatorRects[2][2]+(paginatorCellHeight*0.5))+arrowHalfsize, arrowHalfsize*0.5, 0,1,0,0,{1,1,1,0.22}, {1,1,1,0.33})
    --RectRound((paginatorRects[2][1]+(paginatorCellWidth*0.5))-(arrowHalfsize*1.5), (paginatorRects[2][2]+(paginatorCellHeight*0.5))-arrowHalfsize, (paginatorRects[2][1]+(paginatorCellWidth*0.5))+(arrowHalfsize*1.5), (paginatorRects[2][2]+(paginatorCellHeight*0.5)), arrowHalfsize*0.5, 0,0,1,0,{1,1,1,0.1}, {1,1,1,0.18})

    font2:Print("\255\245\245\245"..currentPage.."  \\  "..pages, contentWidth*0.5, activeArea[2]+(paginatorCellHeight*0.5)-(paginatorFontSize*0.25), paginatorFontSize, "co")
  end

  font2:End()
end


function widget:DrawScreen()
  prevActiveCmd = activeCmd
  activeCmd = select(4, spGetActiveCommand())
  if activeCmd ~= prevActiveCmd then
    doUpdate = true
  end

  if selectedBuilderCount <= 0 then
    if WG['guishader'] and dlistGuishader then
      WG['guishader'].RemoveDlist('buildmenu')
    end
  else
    local x,y,b = Spring.GetMouseState()

    if doUpdate then
      lastUpdate = os_clock()
      clear()
      RefreshCommands()
      doUpdate = nil
    end

    if WG['guishader'] and dlistGuishader then
      WG['guishader'].InsertDlist(dlistGuishader, 'buildmenu')
    end
    if not dlistBuildmenu then
      dlistBuildmenu = gl.CreateList( function()
        drawBuildmenu()
      end)
    end
    gl.CallList(dlistBuildmenu)


    -- hover
    if not WG['topbar'] or not WG['topbar'].showingQuit() then
      if IsOnRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
        Spring.SetMouseCursor('cursornormal')

        local paginatorHovered = false
        if paginatorRects[1] and IsOnRect(x, y, paginatorRects[1][1], paginatorRects[1][2], paginatorRects[1][3], paginatorRects[1][4]) then
          paginatorHovered = 1
        end
        if paginatorRects[2] and IsOnRect(x, y, paginatorRects[2][1], paginatorRects[2][2], paginatorRects[2][3], paginatorRects[2][4]) then
          paginatorHovered = 2
        end
        if paginatorHovered then
          if WG['tooltip'] then
            local text = "\255\240\240\240"..(paginatorHovered == 1 and "previous page" or "next page")
            WG['tooltip'].ShowTooltip('buildmenu', text)
          end
          RectRound(paginatorRects[paginatorHovered][1]+cellPadding, paginatorRects[paginatorHovered][2]+cellPadding, paginatorRects[paginatorHovered][3]-cellPadding, paginatorRects[paginatorHovered][4]-cellPadding, cellSize*0.03, 1,1,1,1,{1,1,1,0}, {1,1,1,(b and 0.35 or 0.15)})
          RectRound(paginatorRects[paginatorHovered][1]+cellPadding, paginatorRects[paginatorHovered][4]-cellPadding-((paginatorRects[paginatorHovered][4]-paginatorRects[paginatorHovered][2])*0.5), paginatorRects[paginatorHovered][3]-cellPadding, paginatorRects[paginatorHovered][4]-cellPadding, cellSize*0.03, 1,1,0,0,{1,1,1,0.045}, {1,1,1,0.15})
          RectRound(paginatorRects[paginatorHovered][1]+cellPadding, paginatorRects[paginatorHovered][2]+cellPadding, paginatorRects[paginatorHovered][3]-cellPadding, paginatorRects[paginatorHovered][2]+cellPadding+((paginatorRects[paginatorHovered][4]-paginatorRects[paginatorHovered][2])*0.18), cellSize*0.03, 0,0,1,1,{1,1,1,0.06}, {1,1,1,0})
        end

        for cellRectID, cellRect in pairs(cellRects) do
          if IsOnRect(x, y, cellRect[1], cellRect[2], cellRect[3], cellRect[4]) then
            local uDefID = cmds[cellRectID].id*-1
            WG.hoverID = uDefID

            local alt, ctrl, meta, shift = Spring.GetModKeyState()
            if WG['tooltip'] and not meta then  -- when meta: unitstats does the tooltip
              local text = "\255\215\255\215"..unitHumanName[uDefID].."\n\255\240\240\240"..unitTooltip[uDefID]
              WG['tooltip'].ShowTooltip('buildmenu', text)
            end

            -- highlight
            glBlending(GL_SRC_ALPHA, GL_ONE)
            if b and not disableInput then
              glColor(1,1,1,0.3)
            else
              glColor(1,1,1,0.15)
            end
            glTexture(':lr128,128:unitpics/'..unitBuildPic[uDefID])
            glTexRect(cellRects[cellRectID][1]+cellPadding+iconPadding, cellRects[cellRectID][2]+cellPadding+iconPadding, cellRects[cellRectID][3]-cellPadding-iconPadding, cellRects[cellRectID][4]-cellPadding-iconPadding)
            glTexture(false)
            --top
            RectRound(cellRects[cellRectID][1]+cellPadding, cellRects[cellRectID][4]-cellPadding-(cellInnerSize*0.5), cellRects[cellRectID][3]-cellPadding, cellRects[cellRectID][4]-cellPadding, cellSize*0.03, 1,1,0,0,{1,1,1,0.0}, {1,1,1,0.13})
            -- bottom
            RectRound(cellRects[cellRectID][1]+cellPadding, cellRects[cellRectID][2]+cellPadding, cellRects[cellRectID][3]-cellPadding, cellRects[cellRectID][2]+cellPadding+(cellInnerSize*0.15), cellSize*0.03, 0,0,1,1,{1,1,1,0.1}, {1,1,1,0})
            glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
            break
          end
        end
      end
    end
  end
end


function widget:SelectionChanged(sel)
  if SelectedUnitsCount ~= spGetSelectedUnitsCount() then
    SelectedUnitsCount = spGetSelectedUnitsCount()
  end
  selectedBuilderCount = 0
  selectedBuilders = {}
  if SelectedUnitsCount > 0 then
    for _,unitID in pairs(sel) do
      if isBuilder[spGetUnitDefID(unitID)] then
        selectedBuilders[unitID] = true
        selectedBuilderCount = selectedBuilderCount + 1
        doUpdate = true
      end
    end
  end
end


function widget:MousePress(x, y, button)
  if selectedBuilderCount > 0 and IsOnRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
    local paginatorHovered = false
    if paginatorRects[1] and IsOnRect(x, y, paginatorRects[1][1], paginatorRects[1][2], paginatorRects[1][3], paginatorRects[1][4]) then
      currentPage = currentPage - 1
      if currentPage < 1 then
        currentPage = pages
        doUpdate = true
      end
    end
    if paginatorRects[2] and IsOnRect(x, y, paginatorRects[2][1], paginatorRects[2][2], paginatorRects[2][3], paginatorRects[2][4]) then
      currentPage = currentPage + 1
      if currentPage > pages then
        currentPage = 1
        doUpdate = true
      end
    end
    if not disableInput then
      for cellRectID, cellRect in pairs(cellRects) do
        if cmds[cellRectID].id and IsOnRect(x, y, cellRect[1], cellRect[2], cellRect[3], cellRect[4]) then
          if button ~= 3 then
            Spring.PlaySoundFile(sound_queue_add, 0.75, 'ui')
            Spring.SetActiveCommand(Spring.GetCmdDescIndex(cmds[cellRectID].id),1,true,false,Spring.GetModKeyState())
          else
            Spring.PlaySoundFile(sound_queue_rem, 0.75, 'ui')
            Spring.SetActiveCommand(Spring.GetCmdDescIndex(cmds[cellRectID].id),3,false,true,Spring.GetModKeyState())
          end
          doUpdate = true
          return true
        end
      end
    end
    return true
  end
end


function widget:GetConfigData() --save config
  return {
    showPrice = showPrice,
    showRadarIcon = showRadarIcon,
    dynamicIconsize = dynamicIconsize,
    minColls = minColls,
    maxColls = maxColls,
    defaultColls = defaultColls,
    showShortcuts = showShortcuts,
    makeFancy = makeFancy,
    alternativeUnitpics = alternativeUnitpics,
  }
end

function widget:SetConfigData(data) --load config
  if data.showPrice ~= nil then
    showPrice = data.showPrice
  end
  if data.showRadarIcon ~= nil then
    showRadarIcon = data.showRadarIcon
  end
  if data.dynamicIconsize ~= nil then
    dynamicIconsize = data.dynamicIconsize
  end
  if data.minColls ~= nil then
    minColls = data.minColls
  end
  if data.maxColls ~= nil then
    maxColls = data.maxColls
  end
  if data.defaultColls ~= nil then
    defaultColls = data.defaultColls
  end
  if data.showShortcuts ~= nil then
    showShortcuts = data.showShortcuts
  end
  if data.makeFancy ~= nil then
    makeFancy = data.makeFancy
  end
  if data.alternativeUnitpics ~= nil then
    alternativeUnitpics = data.alternativeUnitpics
  end
end
