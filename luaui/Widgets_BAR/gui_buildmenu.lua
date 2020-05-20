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
local showTooltip = true
local makeFancy = true
local dynamicIconsize = true
local defaultColls = 5
local minColls = 5
local maxColls = 6

local defaultCellZoom = 0.025
local rightclickCellZoom = 0.045
local clickCellZoom = 0.035
local hoverCellZoom = 0.055
local clickSelectedCellZoom = 0.11
local selectedCellZoom = 0.12

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
local glossMult = 1 + (2-(ui_opacity*2))	-- increase gloss/highlight so when ui is transparant, you can still make out its boundaries and make it less flat

local isSpec = Spring.GetSpectatingState()
local myTeamID = Spring.GetMyTeamID()
local myPlayerID = Spring.GetMyPlayerID()

local buildQueue = {}
local disableInput = isSpec
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
local preGamestartPlayer = Spring.GetGameFrame() == 0 and not isSpec
local gameStarted = Spring.GetGameFrame() > 0

local isSpec = Spring.GetSpectatingState()
local myTeamID = Spring.GetMyTeamID()
local myPlayerID = Spring.GetMyPlayerID()

local teamList = Spring.GetTeamList()

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local spIsUnitSelected = Spring.IsUnitSelected
local spGetSelectedUnitsCount = Spring.GetSelectedUnitsCount
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetActiveCommand = Spring.GetActiveCommand
local spGetActiveCmdDescs = Spring.GetActiveCmdDescs
local spGetCurrentTooltip = Spring.GetCurrentTooltip
local spGetUnitDefID = Spring.GetUnitDefID
local spGetTeamStartPosition = Spring.GetTeamStartPosition
local spGetTeamRulesParam =Spring.GetTeamRulesParam
local spGetGroundHeight = Spring.GetGroundHeight
local glDepthTest = gl.DepthTest

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

function table_invert(t)
  local s={}
  for k,v in pairs(t) do
    s[v]=k
  end
  return s
end

-- used for pregame build queue, for switch faction buildings
local armToCore = {
  [UnitDefNames["armmex"].id] = UnitDefNames["cormex"].id,
  [UnitDefNames["armuwmex"].id] = UnitDefNames["coruwmex"].id,
  [UnitDefNames["armsolar"].id] = UnitDefNames["corsolar"].id,
  [UnitDefNames["armwin"].id] = UnitDefNames["corwin"].id,
  [UnitDefNames["armtide"].id] = UnitDefNames["cortide"].id,
  [UnitDefNames["armllt"].id] = UnitDefNames["corllt"].id,
  [UnitDefNames["armrad"].id] = UnitDefNames["corrad"].id,
  [UnitDefNames["armrl"].id] = UnitDefNames["corrl"].id,
  [UnitDefNames["armtl"].id] = UnitDefNames["cortl"].id,
  [UnitDefNames["armsonar"].id] = UnitDefNames["corsonar"].id,
  [UnitDefNames["armfrt"].id] = UnitDefNames["corfrt"].id,
  [UnitDefNames["armlab"].id] = UnitDefNames["corlab"].id,
  [UnitDefNames["armvp"].id] = UnitDefNames["corvp"].id,
  [UnitDefNames["armsy"].id] = UnitDefNames["corsy"].id,
  [UnitDefNames["armmstor"].id] = UnitDefNames["cormstor"].id,
  [UnitDefNames["armestor"].id] = UnitDefNames["corestor"].id,
  [UnitDefNames["armmakr"].id] = UnitDefNames["cormakr"].id,
  [UnitDefNames["armeyes"].id] = UnitDefNames["coreyes"].id,
  [UnitDefNames["armdrag"].id] = UnitDefNames["cordrag"].id,
  [UnitDefNames["armdl"].id] = UnitDefNames["cordl"].id,
  [UnitDefNames["armap"].id] = UnitDefNames["corap"].id,
  [UnitDefNames["armfrad"].id] = UnitDefNames["corfrad"].id,
  [UnitDefNames["armuwms"].id] = UnitDefNames["coruwms"].id,
  [UnitDefNames["armuwes"].id] = UnitDefNames["coruwes"].id,
  [UnitDefNames["armfmkr"].id] = UnitDefNames["corfmkr"].id,
  [UnitDefNames["armfdrag"].id] = UnitDefNames["corfdrag"].id,
  [UnitDefNames["armptl"].id] = UnitDefNames["corptl"].id,
}
local coreToArm = table_invert(armToCore)

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
local isFactory = {}
local unitHumanName = {}
local unitDescriptionLong = {}
local unitTooltip = {}
local unitIconType = {}
local isMex = {}
local unitMaxWeaponRange = {}
for unitDefID, unitDef in pairs(UnitDefs) do
  unitHumanName[unitDefID] = unitDef.humanName
  if unitDef.maxWeaponRange > 16 then
    unitMaxWeaponRange[unitDefID] = unitDef.maxWeaponRange
  end
  if unitDef.customParams.description_long then
    unitDescriptionLong[unitDefID] = wrap(unitDef.customParams.description_long, 58)
  end
  unitTooltip[unitDefID] = unitDef.tooltip
  unitIconType[unitDefID] = unitDef.iconType
  unitEnergyCost[unitDefID] = unitDef.energyCost
  unitMetalCost[unitDefID] = unitDef.metalCost
  unitGroup = {}
  unitBuildPic[unitDefID] = unitDef.buildpicname
  if VFS.FileExists('unitpics/alternative/'..string.gsub(unitDef.buildpicname, '(.*/)', '')) then
    hasAlternativeUnitpic[unitDefID] = true
  end
  if unitDef.buildSpeed > 0 and unitDef.buildOptions[1] then
    isBuilder[unitDefID] = true
  end
  if unitDef.isFactory then
    isFactory[unitDefID] = true
  end
  if unitDef.extractsMetal > 0 then
    isMex[unitDefID] = true
  end
end


-- load all icons to prevent briefly showing white unit icons
local cachedIconsize = {}
function cacheUnitIcons()
  local minC = minColls
  local maxC = maxColls
  if not dynamicIconsize then
    minC = defaultColls
    maxC = defaultColls
  end
  if minC > maxC then maxC = minC end -- just to be sure

  local colls = minC
  while colls <= maxC do
    if not cachedIconsize[colls] then
      local textureDetail = math.max(80, math.ceil(160*(1-((colls/4)*0.15))) )  -- must be same formula as used in drawBuildmenu()
      cachedIconsize[colls] = true
      gl.Color(1,1,1,0.001)
      for id, unit in pairs(UnitDefs) do
        if alternativeUnitpics and hasAlternativeUnitpic[id] then
          gl.Texture(':lr'..textureDetail..','..textureDetail..':unitpics/alternative/'..unitBuildPic[id])
        else
          gl.Texture(':lr'..textureDetail..','..textureDetail..':unitpics/'..unitBuildPic[id])
        end
        gl.TexRect(-1,-1,0,0)
        gl.Texture(false)
      end
      gl.Color(1,1,1,1)
    end
    colls = colls + 1
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

local function RectQuad(px,py,sx,sy,offset)
  gl.TexCoord(offset,1-offset)
  gl.Vertex(px, py, 0)
  gl.TexCoord(1-offset,1-offset)
  gl.Vertex(sx, py, 0)
  gl.TexCoord(1-offset,offset)
  gl.Vertex(sx, sy, 0)
  gl.TexCoord(offset,offset)
  gl.Vertex(px, sy, 0)
end
function DrawRect(px,py,sx,sy,zoom)
  gl.BeginEnd(GL.QUADS, RectQuad, px,py,sx,sy,zoom)
end

local function RectRoundQuad(px,py,sx,sy,cs, tl,tr,br,bl, offset)
  local csyMult = 1 / ((sy-py)/cs)

  local function drawTexCoordVertex(x, y)
    local yc = 1-((y-py) / (sy-py))
    local xc = (offset*0.5) + ((x-px) / (sx-px)) + (-offset*((x-px) / (sx-px)))
    yc = 1-(offset*0.5) - ((y-py) / (sy-py)) + (offset*((y-py) / (sy-py)))
    gl.TexCoord(xc, yc)
    gl.Vertex(x, y, 0)
  end

  -- mid section
  drawTexCoordVertex(px+cs, py)
  drawTexCoordVertex(sx-cs, py)
  drawTexCoordVertex(sx-cs, sy)
  drawTexCoordVertex(px+cs, sy)

  -- left side
  drawTexCoordVertex(px, py+cs)
  drawTexCoordVertex(px+cs, py+cs)
  drawTexCoordVertex(px+cs, sy-cs)
  drawTexCoordVertex(px, sy-cs)

  -- right side
  drawTexCoordVertex(sx, py+cs)
  drawTexCoordVertex(sx-cs, py+cs)
  drawTexCoordVertex(sx-cs, sy-cs)
  drawTexCoordVertex(sx, sy-cs)

  -- bottom left
  if ((py <= 0 or px <= 0)  or (bl ~= nil and bl == 0)) and bl ~= 2   then
    drawTexCoordVertex(px, py)
  else
    drawTexCoordVertex(px+cs, py)
  end
  drawTexCoordVertex(px+cs, py)
  drawTexCoordVertex(px+cs, py+cs)
  drawTexCoordVertex(px, py+cs)
  -- bottom right
  if ((py <= 0 or sx >= vsx) or (br ~= nil and br == 0)) and br ~= 2 then
    drawTexCoordVertex(sx, py)
  else
    drawTexCoordVertex(sx-cs, py)
  end
  drawTexCoordVertex(sx-cs, py)
  drawTexCoordVertex(sx-cs, py+cs)
  drawTexCoordVertex(sx, py+cs)
  -- top left
  if ((sy >= vsy or px <= 0) or (tl ~= nil and tl == 0)) and tl ~= 2 then
    drawTexCoordVertex(px, sy)
  else
    drawTexCoordVertex(px+cs, sy)
  end
  drawTexCoordVertex(px+cs, sy)
  drawTexCoordVertex(px+cs, sy-cs)
  drawTexCoordVertex(px, sy-cs)
  -- top right
  if ((sy >= vsy or sx >= vsx)  or (tr ~= nil and tr == 0)) and tr ~= 2 then
    drawTexCoordVertex(sx, sy)
  else
    drawTexCoordVertex(sx-cs, sy)
  end
  drawTexCoordVertex(sx-cs, sy)
  drawTexCoordVertex(sx-cs, sy-cs)
  drawTexCoordVertex(sx, sy-cs)
end
function DrawTexRectRound(px,py,sx,sy,cs, tl,tr,br,bl, zoom)
  gl.BeginEnd(GL.QUADS, RectRoundQuad, px,py,sx,sy,cs, tl,tr,br,bl, zoom)
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
  myTeamID = Spring.GetMyTeamID()
  myPlayerID = Spring.GetMyPlayerID()
end

local function RefreshCommands()
  cmds = {}
  cmdsCount = 0
  if preGamestartPlayer then
    if startDefID then
      -- mimmick output of spGetActiveCmdDescs
      for i,udefid in pairs(UnitDefs[startDefID].buildOptions) do
        cmdsCount = cmdsCount + 1
        cmds[cmdsCount] = {
          id = udefid*-1,
          name = UnitDefs[udefid].name,
          params = {}
        }
      end
    end

  else
    for index,cmd in pairs(spGetActiveCmdDescs()) do
      if type(cmd) == "table" then
        if string_sub(cmd.action,1,10) == 'buildunit_' then -- not cmd.disabled and cmd.type == 20 or
          cmdsCount = cmdsCount + 1
          cmds[cmdsCount] = cmd
        end
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

  -- Get our starting unit
  if preGamestartPlayer then
    SetBuildFacing()
    local mySide = select(5,Spring.GetTeamInfo(myTeamID,false))
    if mySide and mySide ~= '' then -- Don't run unless we know what faction the player is
      startDefID = UnitDefNames[Spring.GetSideData(mySide)].id
    end
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
  WG['buildmenu'].getShowTooltip = function()
    return showTooltip
  end
  WG['buildmenu'].setShowTooltip = function(value)
    showTooltip = value
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
    cachedIconsize = {}   -- re-cache icons
  end
  WG['buildmenu'].factionChange = function(unitDefID)
    startDefID = unitDefID
    doUpdate = true
  end
end

function clear()
  dlistBuildmenu = gl.DeleteList(dlistBuildmenu)
  dlistBuildmenuBg = gl.DeleteList(dlistBuildmenuBg)
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

-- update queue number
function widget:UnitFromFactory(unitID, unitDefID, unitTeam, factID, factDefID, userOrders)
  if spIsUnitSelected(factID) then
    doUpdateClock = os_clock() + 0.01
  end
end

local uiOpacitySec = 0
function widget:Update(dt)
  uiOpacitySec = uiOpacitySec + dt
  if uiOpacitySec > 0.33 then
    uiOpacitySec = 0
    checkGuishader()
    if ui_scale ~= Spring.GetConfigFloat("ui_scale",1) then
      ui_scale = Spring.GetConfigFloat("ui_scale",1)
      cachedIconsize = {}
      widget:ViewResize()
      doUpdate = true
    end
    if ui_opacity ~= Spring.GetConfigFloat("ui_opacity",0.66) then
      ui_opacity = Spring.GetConfigFloat("ui_opacity",0.66)
      glossMult = 1 + (2-(ui_opacity*2))
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

function drawBuildmenuBg()
  WG['buildmenu'].selectedID = nil

  -- background
  padding = 0.0033*vsy * ui_scale
  RectRound(backgroundRect[1],backgroundRect[2],backgroundRect[3],backgroundRect[4], padding*1.7, 1,1,1,1,{0.05,0.05,0.05,ui_opacity}, {0,0,0,ui_opacity})
  RectRound(backgroundRect[1], backgroundRect[2]+padding, backgroundRect[3]-padding, backgroundRect[4]-padding, padding*1, 0,1,1,0,{0.3,0.3,0.3,ui_opacity*0.2}, {1,1,1,ui_opacity*0.2})

  -- gloss
  glBlending(GL_SRC_ALPHA, GL_ONE)
  RectRound(backgroundRect[1], backgroundRect[4]-padding-((backgroundRect[4]-backgroundRect[2])*0.07), backgroundRect[3]-padding, backgroundRect[4]-padding, padding*1, 0,1,0,0, {1,1,1,0.012*glossMult}, {1,1,1,0.07*glossMult})
  RectRound(backgroundRect[1], backgroundRect[2]+padding, backgroundRect[3]-padding, backgroundRect[2]+padding+((backgroundRect[4]-backgroundRect[2])*0.045), padding*1, 0,0,1,0, {1,1,1,0.025*glossMult}, {1,1,1,0})
  glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
end

local function drawCell(cellRectID, usedZoom)
  local uDefID = cmds[cellRectID].id*-1
  local cellIsSelected = (activeCmd and cmds[cellRectID] and activeCmd == cmds[cellRectID].name)

  if not usedZoom then
    usedZoom = cellIsSelected and selectedCellZoom or defaultCellZoom
  end

  -- encapsulating cell background
  --RectRound(cellRects[cellRectID][1]+cellPadding, cellRects[cellRectID][2]+cellPadding, cellRects[cellRectID][3]-cellPadding, cellRects[cellRectID][4]-cellPadding, cellSize*0.03, 1,1,1,1, {0.3,0.3,0.3,0.95},{0.22,0.22,0.22,0.95})

  -- unit icon
  glColor(1,1,1,1)
  glTexture(':lr'..textureDetail..','..textureDetail..':unitpics/'..((alternativeUnitpics and hasAlternativeUnitpic[uDefID]) and 'alternative/' or '')..unitBuildPic[uDefID])
  --glTexRect(cellRects[cellRectID][1]+cellPadding+iconPadding, cellRects[cellRectID][2]+cellPadding+iconPadding, cellRects[cellRectID][3]-cellPadding-iconPadding, cellRects[cellRectID][4]-cellPadding-iconPadding)
  DrawTexRectRound(
    cellRects[cellRectID][1]+cellPadding+iconPadding,
    cellRects[cellRectID][2]+cellPadding+iconPadding,
    cellRects[cellRectID][3]-cellPadding-iconPadding,
    cellRects[cellRectID][4]-cellPadding-iconPadding,
    cornerSize, 1,1,1,1,
    usedZoom
  )
  glTexture(false)

  if makeFancy then

    -- lighten top
    glBlending(GL_SRC_ALPHA, GL_ONE)
    -- glossy half
    --RectRound(cellRects[cellRectID][1]+iconPadding, cellRects[cellRectID][4]-iconPadding-(cellInnerSize*0.5), cellRects[cellRectID][3]-iconPadding, cellRects[cellRectID][4]-iconPadding, cellSize*0.03, 1,1,0,0,{1,1,1,0.1}, {1,1,1,0.18})
    RectRound(cellRects[cellRectID][1]+cellPadding+iconPadding, cellRects[cellRectID][4]-cellPadding-iconPadding-(cellInnerSize*0.66), cellRects[cellRectID][3]-cellPadding-iconPadding, cellRects[cellRectID][4]-cellPadding-iconPadding, cornerSize, 1,1,0,0,{1,1,1,0}, {1,1,1,0.2})
    glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

    -- extra darken gradually
    RectRound(cellRects[cellRectID][1]+cellPadding+iconPadding, cellRects[cellRectID][2]+cellPadding+iconPadding, cellRects[cellRectID][3]-cellPadding-iconPadding, cellRects[cellRectID][4]-cellPadding-iconPadding, cornerSize, 0,0,1,1,{0,0,0,0.12}, {0,0,0,0})
  end

  -- darken price background gradually
  if showPrice and (not alternativeUnitpics or makeFancy) then
    RectRound(cellRects[cellRectID][1]+cellPadding+iconPadding, cellRects[cellRectID][2]+cellPadding+iconPadding, cellRects[cellRectID][3]-cellPadding-iconPadding, cellRects[cellRectID][2]+cellPadding+iconPadding+(cellInnerSize*0.415), cornerSize, 0,0,1,1,{0,0,0,(makeFancy and 0.22 or 0.3)}, {0,0,0,0})
  end

  -- radar icon
  if showRadarIcon then
    glColor(1,1,1,0.9)
    glTexture(':lr'..radariconTextureDetail..','..radariconTextureDetail..':'..iconTypesMap[unitIconType[uDefID]])
    glTexRect(cellRects[cellRectID][3]-radariconOffset-radariconSize, cellRects[cellRectID][2]+radariconOffset, cellRects[cellRectID][3]-radariconOffset, cellRects[cellRectID][2]+radariconOffset+radariconSize)
    glTexture(false)
  end

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
    local pad = cellInnerSize * 0.03
    local textWidth = (font2:GetTextWidth(cmds[cellRectID].params[1]..'  ') * cellInnerSize*0.29)
    local pad2 = (alternativeUnitpics and pad or 0)
    RectRound(cellRects[cellRectID][3]-cellPadding-iconPadding-textWidth-pad2, cellRects[cellRectID][4]-cellPadding-iconPadding-(cellInnerSize*0.365)-pad2, cellRects[cellRectID][3]-cellPadding-iconPadding, cellRects[cellRectID][4]-cellPadding-iconPadding, cellSize*0.08, 0,0,0,1,{0.11,0.11,0.11,0.88}, {0.18,0.18,0.18,0.88})
    RectRound(cellRects[cellRectID][3]-cellPadding-iconPadding-textWidth-pad2+pad, cellRects[cellRectID][4]-cellPadding-iconPadding-(cellInnerSize*0.365)-pad2+pad, cellRects[cellRectID][3]-cellPadding-iconPadding-pad2, cellRects[cellRectID][4]-cellPadding-iconPadding-pad2, cellSize*0.06, 0,0,0,1,{1,1,1,0.1}, {1,1,1,0.1})
    font2:Print("\255\190\255\190"..cmds[cellRectID].params[1],
            cellRects[cellRectID][1]+cellPadding+(cellInnerSize*0.94)-pad2,
            cellRects[cellRectID][2]+cellPadding+(cellInnerSize*0.715)-pad2,
            cellInnerSize*0.29, "ro"
    )
  end
  -- active / selected
  if cellIsSelected then
    WG['buildmenu'].selectedID = uDefID
    glBlending(GL_SRC_ALPHA, GL_ONE)
    glColor(1,0.85,0.2,0.66)
    glTexture(':lr128,128:unitpics/'..((alternativeUnitpics and hasAlternativeUnitpic[uDefID]) and 'alternative/' or '')..unitBuildPic[uDefID])
    DrawTexRectRound(
            cellRects[cellRectID][1]+cellPadding+iconPadding,
            cellRects[cellRectID][2]+cellPadding+iconPadding,
            cellRects[cellRectID][3]-cellPadding-iconPadding,
            cellRects[cellRectID][4]-cellPadding-iconPadding,
            cornerSize, 1,1,1,1,
            usedZoom
    )
    glTexture(false)
    glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
  end
end

function drawBuildmenu()
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
  cellPadding = cellSize * 0.007
  iconPadding = cellSize * 0.02
  cornerSize = (cellPadding+iconPadding)*0.8
  cellInnerSize = cellSize-cellPadding-cellPadding
  radariconSize = cellInnerSize * 0.29
  radariconOffset = (cellInnerSize * 0.027) + cellPadding+iconPadding
  priceFontSize = cellInnerSize*0.18

  radariconTextureDetail = math.max(28, math.ceil(120*(1-((colls/4)*0.4))) )
  textureDetail = math.max(80, math.ceil(160*(1-((colls/4)*0.15))) )  -- NOTE: if changed: update formula used in cacheUnitIcons func

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

      drawCell(cellRectID)
    end
  end

  -- paginator
  if pages == 1 then
    paginatorRects = {}
  else
    local paginatorFontSize = math.max(0.016*vsy, paginatorCellHeight*0.2)
    local paginatorCellWidth = contentWidth*0.3
    paginatorRects[1] = {activeArea[1], activeArea[2], activeArea[1]+paginatorCellWidth, activeArea[2]+paginatorCellHeight-cellPadding}
    paginatorRects[2] = {activeArea[3]-paginatorCellWidth, activeArea[2], activeArea[3], activeArea[2]+paginatorCellHeight-cellPadding}

    RectRound(paginatorRects[1][1]+cellPadding, paginatorRects[1][2]+cellPadding, paginatorRects[1][3]-cellPadding, paginatorRects[1][4]-cellPadding, cellSize*0.03, 1,1,1,1,{0.28,0.28,0.28,WG['guishader'] and 0.66 or 0.8}, {0.36,0.36,0.36,WG['guishader'] and 0.66 or 0.88})
    RectRound(paginatorRects[2][1]+cellPadding, paginatorRects[2][2]+cellPadding, paginatorRects[2][3]-cellPadding, paginatorRects[2][4]-cellPadding, cellSize*0.03, 1,1,1,1,{0.28,0.28,0.28,WG['guishader'] and 0.66 or 0.8}, {0.36,0.36,0.36,WG['guishader'] and 0.66 or 0.88})
    RectRound(paginatorRects[1][1]+cellPadding+iconPadding, paginatorRects[1][2]+cellPadding+iconPadding, paginatorRects[1][3]-cellPadding-iconPadding, paginatorRects[1][4]-cellPadding-iconPadding, cellSize*0.02, 1,1,1,1,{0,0,0,WG['guishader'] and 0.48 or 0.55}, {0,0,0,WG['guishader'] and 0.45 or 0.55})
    RectRound(paginatorRects[2][1]+cellPadding+iconPadding, paginatorRects[2][2]+cellPadding+iconPadding, paginatorRects[2][3]-cellPadding-iconPadding, paginatorRects[2][4]-cellPadding-iconPadding, cellSize*0.02, 1,1,1,1,{0,0,0,WG['guishader'] and 0.48 or 0.55}, {0,0,0,WG['guishader'] and 0.45 or 0.55})

    -- glossy half
    glBlending(GL_SRC_ALPHA, GL_ONE)
    RectRound(paginatorRects[1][1]+cellPadding, paginatorRects[1][4]-cellPadding-((paginatorRects[1][4]-paginatorRects[1][2])*0.5), paginatorRects[1][3]-cellPadding, paginatorRects[1][4]-cellPadding, cellSize*0.03, 1,1,0,0,{1,1,1,0.03}, {1,1,1,0.18})
    RectRound(paginatorRects[2][1]+cellPadding, paginatorRects[2][4]-cellPadding-((paginatorRects[2][4]-paginatorRects[1][2])*0.5), paginatorRects[2][3]-cellPadding, paginatorRects[2][4]-cellPadding, cellSize*0.03, 1,1,0,0,{1,1,1,0.03}, {1,1,1,0.18})

    -- glossy bottom
    RectRound(paginatorRects[1][1]+cellPadding, paginatorRects[1][2]+cellPadding, paginatorRects[1][3]-cellPadding, paginatorRects[1][2]+cellPadding+((paginatorRects[1][4]-paginatorRects[1][2])*0.25), cellSize*0.03, 0,0,1,1,{1,1,1,0.06}, {1,1,1,0})
    RectRound(paginatorRects[2][1]+cellPadding, paginatorRects[2][2]+cellPadding, paginatorRects[2][3]-cellPadding, paginatorRects[2][2]+cellPadding+((paginatorRects[2][4]-paginatorRects[1][2])*0.25), cellSize*0.03, 0,0,1,1,{1,1,1,0.06}, {1,1,1,0})
    glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

    font2:Print("\255\245\245\245"..currentPage.."  \\  "..pages, contentWidth*0.5, activeArea[2]+(paginatorCellHeight*0.5)-(paginatorFontSize*0.25), paginatorFontSize, "co")
  end

  font2:End()
end


function widget:RecvLuaMsg(msg, playerID)
  if msg:sub(1,18) == 'LobbyOverlayActive' then
    chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
  end
end

local function GetBuildingDimensions(uDefID, facing)
  local bDef = UnitDefs[uDefID]
  if (facing % 2 == 1) then
    return 4 * bDef.zsize, 4 * bDef.xsize
  else
    return 4 * bDef.xsize, 4 * bDef.zsize
  end
end

local function DrawBuilding(buildData, borderColor, buildingAlpha, drawRanges)
  local bDefID, bx, by, bz, facing = buildData[1], buildData[2], buildData[3], buildData[4], buildData[5]
  local bw, bh = GetBuildingDimensions(bDefID, facing)

  gl.DepthTest(false)
  gl.Color(borderColor)

  gl.Shape(GL.LINE_LOOP, {{v={bx - bw, by, bz - bh}},
                          {v={bx + bw, by, bz - bh}},
                          {v={bx + bw, by, bz + bh}},
                          {v={bx - bw, by, bz + bh}}})

  if drawRanges then

    if isMex[bDefID] then
      gl.Color(1.0, 0.3, 0.3, 0.7)
      gl.DrawGroundCircle(bx, by, bz, Game.extractorRadius, 50)
    end

    local wRange = unitMaxWeaponRange[bDefID]
    if wRange then
      gl.Color(1.0, 0.3, 0.3, 0.7)
      gl.DrawGroundCircle(bx, by, bz, wRange, 40)
    end
  end

  gl.DepthTest(GL.LEQUAL)
  gl.DepthMask(true)
  gl.Color(1.0, 1.0, 1.0, buildingAlpha)

  gl.PushMatrix()
  gl.LoadIdentity()
  gl.Translate(bx, by, bz)
  gl.Rotate(90 * facing, 0, 1, 0)
  gl.UnitShape(bDefID, Spring.GetMyTeamID(), false, false, true)
  gl.PopMatrix()

  gl.Lighting(false)
  gl.DepthTest(false)
  gl.DepthMask(false)
end

local function DrawUnitDef(uDefID, uTeam, ux, uy, uz, scale)
  gl.Color(1,1,1,1)
  gl.DepthTest(GL.LEQUAL)
  gl.DepthMask(true)
  gl.Lighting(true)

  gl.PushMatrix()
  gl.Translate(ux, uy, uz)
  if scale then
    gl.Scale(scale, scale, scale)
  end
  gl.UnitShape(uDefID, uTeam, false, true, true)
  gl.PopMatrix()

  gl.Lighting(false)
  gl.DepthTest(false)
  gl.DepthMask(false)
end

local function DoBuildingsClash(buildData1, buildData2)

  local w1, h1 = GetBuildingDimensions(buildData1[1], buildData1[5])
  local w2, h2 = GetBuildingDimensions(buildData2[1], buildData2[5])

  return math.abs(buildData1[2] - buildData2[2]) < w1 + w2 and
          math.abs(buildData1[4] - buildData2[4]) < h1 + h2
end


function widget:DrawScreen()
  if chobbyInterface then return end

  cacheUnitIcons()

  -- refresh buildmenu if active cmd changed
  prevActiveCmd = activeCmd
  activeCmd = select(4, spGetActiveCommand())
  if activeCmd ~= prevActiveCmd then
    doUpdate = true
  end

  WG['buildmenu'].hoverID = nil
  if not preGamestartPlayer and selectedBuilderCount == 0 then
    if WG['guishader'] and dlistGuishader then
      WG['guishader'].RemoveDlist('buildmenu')
    end
  else
    local x,y,b,b2,b3 = Spring.GetMouseState()
    local now = os_clock()
    if doUpdate or (doUpdateClock and now >= doUpdateClock) then
      if doUpdateClock and now >= doUpdateClock then
        doUpdateClock = nil
      end
      lastUpdate = now
      clear()
      RefreshCommands()
      doUpdate = nil
    end

    -- create buildmenu drawlists
    if WG['guishader'] and dlistGuishader then
      WG['guishader'].InsertDlist(dlistGuishader, 'buildmenu')
    end
    if not dlistBuildmenu then
      dlistBuildmenuBg = gl.CreateList( function()
        drawBuildmenuBg()
      end)
      dlistBuildmenu = gl.CreateList( function()
        drawBuildmenu()
      end)
    end

    -- draw buildmenu background
    gl.CallList(dlistBuildmenuBg)

    -- pre process + 'highlight' under the icons
    local hoveredCellID = nil
    if not WG['topbar'] or not WG['topbar'].showingQuit() then
      if IsOnRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
        Spring.SetMouseCursor('cursornormal')

        for cellRectID, cellRect in pairs(cellRects) do
          if IsOnRect(x, y, cellRect[1], cellRect[2], cellRect[3], cellRect[4]) then
            hoveredCellID = cellRectID
            local cellIsSelected = (activeCmd and cmds[cellRectID] and activeCmd == cmds[cellRectID].name)
            local uDefID = cmds[cellRectID].id*-1
            WG['buildmenu'].hoverID = uDefID
            gl.Color(1,1,1,1)
            local alt, ctrl, meta, shift = Spring.GetModKeyState()
            if showTooltip and WG['tooltip'] and not meta then  -- when meta: unitstats does the tooltip
              local text = "\255\215\255\215"..unitHumanName[uDefID].."\n\255\240\240\240"..unitTooltip[uDefID]
              WG['tooltip'].ShowTooltip('buildmenu', text)
            end

            -- highlight --if b and not disableInput then
            glBlending(GL_SRC_ALPHA, GL_ONE)
            RectRound(cellRects[cellRectID][1]+cellPadding, cellRects[cellRectID][2]+cellPadding, cellRects[cellRectID][3]-cellPadding, cellRects[cellRectID][4]-cellPadding, cellSize*0.03, 1,1,1,1,{0,0,0,0.1*ui_opacity}, {0,0,0,0.1*ui_opacity})
            glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
            break
          end
        end
      end
    end

    -- draw buildmenu content
    gl.CallList(dlistBuildmenu)

    -- draw highlight
    if not WG['topbar'] or not WG['topbar'].showingQuit() then
      if IsOnRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
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
          -- gloss
          RectRound(paginatorRects[paginatorHovered][1]+cellPadding, paginatorRects[paginatorHovered][4]-cellPadding-((paginatorRects[paginatorHovered][4]-paginatorRects[paginatorHovered][2])*0.5), paginatorRects[paginatorHovered][3]-cellPadding, paginatorRects[paginatorHovered][4]-cellPadding, cellSize*0.03, 1,1,0,0,{1,1,1,0.045}, {1,1,1,0.15})
          RectRound(paginatorRects[paginatorHovered][1]+cellPadding, paginatorRects[paginatorHovered][2]+cellPadding, paginatorRects[paginatorHovered][3]-cellPadding, paginatorRects[paginatorHovered][2]+cellPadding+((paginatorRects[paginatorHovered][4]-paginatorRects[paginatorHovered][2])*0.18), cellSize*0.03, 0,0,1,1,{1,1,1,0.06}, {1,1,1,0})
        end
        if hoveredCellID then
          local cellRectID = hoveredCellID
          local cellIsSelected = (activeCmd and cmds[cellRectID] and activeCmd == cmds[cellRectID].name)
          local uDefID = cmds[cellRectID].id*-1

          -- highlight
          local cellZoom = hoverCellZoom
          if (b or b2) and cellIsSelected then
            cellZoom = clickSelectedCellZoom
          elseif cellIsSelected then
            cellZoom = selectedCellZoom
          elseif (b or b2) and not disableInput then
            cellZoom = clickCellZoom
          elseif b3 and not disableInput and cmds[cellRectID].params[1] then  -- has queue
            cellZoom = rightclickCellZoom
          end
          drawCell(cellRectID, cellZoom)

          glBlending(GL_SRC_ALPHA, GL_ONE)
          --RectRound(cellRects[cellRectID][1]+cellPadding, cellRects[cellRectID][2]+cellPadding, cellRects[cellRectID][3]-cellPadding, cellRects[cellRectID][4]-cellPadding, cellSize*0.03, 1,1,0,0,{1,1,1,0.07}, {1,1,1,0.07})
          if (b or b2) and not disableInput then
            glColor(0.7,1,0.5,alternativeUnitpics and 1 or 0.4)
          elseif b3 and not disableInput then
            glColor(1,0.6,0.4,alternativeUnitpics and 1 or 0.4)
          else
            glColor(1,1,1,alternativeUnitpics and 0.5 or 0.2)
          end
          glTexture(':lr128,128:unitpics/'..((alternativeUnitpics and hasAlternativeUnitpic[uDefID]) and 'alternative/' or '')..unitBuildPic[uDefID])
          DrawTexRectRound(
                  cellRects[cellRectID][1]+cellPadding+iconPadding,
                  cellRects[cellRectID][2]+cellPadding+iconPadding,
                  cellRects[cellRectID][3]-cellPadding-iconPadding,
                  cellRects[cellRectID][4]-cellPadding-iconPadding,
                  cornerSize, 1,1,1,1,
                  cellZoom
          )
          glTexture(false)

          -- gloss highlight
          RectRound(cellRects[cellRectID][1]+cellPadding, cellRects[cellRectID][4]-cellPadding-(cellInnerSize*0.5), cellRects[cellRectID][3]-cellPadding, cellRects[cellRectID][4]-cellPadding, cellSize*0.03, 1,1,0,0,{1,1,1,0.0}, {1,1,1,alternativeUnitpics and 0.18 or 0.1})
          RectRound(cellRects[cellRectID][1]+cellPadding, cellRects[cellRectID][2]+cellPadding, cellRects[cellRectID][3]-cellPadding, cellRects[cellRectID][2]+cellPadding+(cellInnerSize*0.15), cellSize*0.03, 0,0,1,1,{1,1,1,alternativeUnitpics and 0.11 or 0.08}, {1,1,1,0})
          glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

          -- display price
          if not showPrice then
            RectRound(cellRects[cellRectID][1]+cellPadding+iconPadding, cellRects[cellRectID][2]+cellPadding+iconPadding, cellRects[cellRectID][3]-cellPadding-iconPadding, cellRects[cellRectID][2]+cellPadding+iconPadding+(cellInnerSize*0.415), cellSize*0.03, 0,0,0,0,{0,0,0,0.35}, {0,0,0,0})
            font2:Print("\255\245\245\245"..unitMetalCost[uDefID].."\n\255\255\255\000"..unitEnergyCost[uDefID], cellRects[cellRectID][1]+cellPadding+(cellInnerSize*0.05), cellRects[cellRectID][2]+cellPadding+(priceFontSize*1.4), priceFontSize, "o")
          end
        end
      end
    end
  end
end

function widget:DrawWorld()
  if chobbyInterface then return end

  -- draw pregamestart commander models on start positions
  if Spring.GetGameFrame() == 0 then
    glColor(1, 1, 1, 0.5)
    glDepthTest(false)
    for i = 1, #teamList do
      local teamID = teamList[i]
      local tsx, tsy, tsz = spGetTeamStartPosition(teamID)
      if tsx and tsx > 0 then
        if spGetTeamRulesParam(teamID, 'startUnit') == UnitDefNames.armcom.id then
          --glTexture('unitpics/alternative/armcom.png')
          --glBeginEnd(GL_QUADS, QuadVerts, tsx, spGetGroundHeight(tsx, tsz), tsz, 64)
          DrawUnitDef(UnitDefNames.armcom.id, teamID, tsx, spGetGroundHeight(tsx, tsz), tsz)
        else
          --glTexture('unitpics/alternative/corcom.png')
          --glBeginEnd(GL_QUADS, QuadVerts, tsx, spGetGroundHeight(tsx, tsz), tsz, 64)
          DrawUnitDef(UnitDefNames.corcom.id, teamID, tsx, spGetGroundHeight(tsx, tsz), tsz)
        end
      end
    end
    glColor(1, 1, 1, 1)
    glTexture(false)


    -- draw pregame build queue
    if preGamestartPlayer then
      local buildDistanceColor = {0.3, 1.0, 0.3, 0.6}
      local buildLinesColor = {0.3, 1.0, 0.3, 0.6}
      local borderNormalColor = {0.3, 1.0, 0.3, 0.5}
      local borderClashColor = {0.7, 0.3, 0.3, 1.0}
      local borderValidColor = {0.0, 1.0, 0.0, 1.0}
      local borderInvalidColor = {1.0, 0.0, 0.0, 1.0}
      local buildingQueuedAlpha = 0.5

      gl.LineWidth(1.49)

      -- We need data about currently selected building, for drawing clashes etc
      local selBuildData
      if selBuildQueueDefID then
        local x,y,b = Spring.GetMouseState()
        local _, pos = Spring.TraceScreenRay(x, y, true)
        if pos then
          local bx, by, bz = Spring.Pos2BuildPos(selBuildQueueDefID, pos[1], pos[2], pos[3])
          local buildFacing = Spring.GetBuildFacing()
          selBuildData = {selBuildQueueDefID, bx, by, bz, buildFacing}
        end
      end

      local sx, sy, sz = Spring.GetTeamStartPosition(myTeamID) -- Returns -100, -100, -100 when none chosen
      local startChosen = (sx ~= -100)
      if startChosen and startDefID then
        -- Correction for start positions in the air
        sy = Spring.GetGroundHeight(sx, sz)

        -- Draw the starting unit at start position
        --DrawUnitDef(startDefID, myTeamID, sx, sy, sz)		--(disabled: faction change widget does this now)

        -- Draw start units build radius
        gl.Color(buildDistanceColor)
        gl.DrawGroundCircle(sx, sy, sz, UnitDefs[startDefID].buildDistance, 40)
      end

      -- Check for faction change
      for b = 1, #buildQueue do
        local buildData = buildQueue[b]
        local buildDataId = buildData[1]
        if startDefID == UnitDefNames["armcom"].id then
          if coreToArm[buildDataId] ~= nil then
            buildData[1] = coreToArm[buildDataId]
            buildQueue[b] = buildData
          end
        elseif startDefID == UnitDefNames["corcom"].id then
          if armToCore[buildDataId] ~= nil then
            buildData[1] = armToCore[buildDataId]
            buildQueue[b] = buildData
          end
        end
      end

      -- Draw all the buildings
      local queueLineVerts = startChosen and {{v={sx, sy, sz}}} or {}
      for b = 1, #buildQueue do
        local buildData = buildQueue[b]

        if selBuildData and DoBuildingsClash(selBuildData, buildData) then
          DrawBuilding(buildData, borderClashColor, buildingQueuedAlpha)
        else
          DrawBuilding(buildData, borderNormalColor, buildingQueuedAlpha)
        end

        queueLineVerts[#queueLineVerts + 1] = {v={buildData[2], buildData[3], buildData[4]}}
      end

      -- Draw queue lines
      glColor(buildLinesColor)
      gl.LineStipple("springdefault")
      gl.Shape(GL.LINE_STRIP, queueLineVerts)
      gl.LineStipple(false)

      -- Draw selected building
      if selBuildData then
        if Spring.TestBuildOrder(selBuildQueueDefID, selBuildData[2], selBuildData[3], selBuildData[4], selBuildData[5]) ~= 0 then
          DrawBuilding(selBuildData, borderValidColor, 1.0, true)
        else
          DrawBuilding(selBuildData, borderInvalidColor, 1.0, true)
        end
      end

      -- Reset gl
      glColor(1,1,1,1)
      gl.LineWidth(1.0)
    end
  end
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdOpts, cmdParams, cmdTag)
  if isFactory[unitDefID] and cmdID < 0 then   -- filter away non build cmd's
    if doUpdateClock == nil then
      doUpdateClock = os_clock() + 0.01
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


local function GetUnitCanCompleteQueue(uID)

  local uDefID = Spring.GetUnitDefID(uID)
  if uDefID == startDefID then
    return true
  end

  -- What can this unit build ?
  local uCanBuild = {}
  local uBuilds = UnitDefs[uDefID].buildOptions
  for i = 1, #uBuilds do
    uCanBuild[uBuilds[i]] = true
  end

  -- Can it build everything that was queued ?
  for i = 1, #buildQueue do
    if not uCanBuild[buildQueue[i][1]] then
      return false
    end
  end

  return true
end


function widget:GameFrame(n)

  -- handle the pregame build queue
  preGamestartPlayer = false
  if n <= 90 and #buildQueue > 0 then

    if n < 2 then return end -- Give the unit frames 0 and 1 to spawn

    -- inform gadget how long is our queue
    local t = 0
    for i = 1, #buildQueue do
      t = t + UnitDefs[buildQueue[i][1]].buildTime
    end
    if startDefID then
      local buildTime = t / UnitDefs[startDefID].buildSpeed
      Spring.SendCommands("luarules initialQueueTime " .. buildTime)
    end

    local tasker
    -- Search for our starting unit
    local units = Spring.GetTeamUnits(Spring.GetMyTeamID())
    for u = 1, #units do
      local uID = units[u]
      if GetUnitCanCompleteQueue(uID) then
        tasker = uID
        if Spring.GetUnitRulesParam(uID,"startingOwner") == Spring.GetMyPlayerID() then
          -- we found our com even if cooping, assigning queue to this particular unit
          break
        end
      end
    end
    if tasker then
      for b=1, #buildQueue do
        local buildData = buildQueue[b]
        Spring.GiveOrderToUnit(tasker, -buildData[1], {buildData[2], buildData[3], buildData[4], buildData[5]}, {"shift"})
      end
      buildQueue = {}
    end
  end
end


function SetBuildFacing()
  local wx,wy,_,_ = Spring.GetScreenGeometry()
  local _, pos = Spring.TraceScreenRay(wx/2, wy/2, true)
  if not pos then return end
  local x = pos[1]
  local z = pos[3]

  if math.abs(Game.mapSizeX - 2*x) > math.abs(Game.mapSizeZ - 2*z) then
    if (2*x>Game.mapSizeX) then
      facing=3
    else
      facing=1
    end
  else
    if (2*z>Game.mapSizeZ) then
      facing=2
    else
      facing=0
    end
  end
  Spring.SetBuildFacing(facing)
end

local function setPreGamestartDefID(uDefID)
  selBuildQueueDefID = uDefID
  if isMex[uDefID] then
    if Spring.GetMapDrawMode() ~= "metal" then
      Spring.SendCommands("ShowMetalMap")
    end
  elseif Spring.GetMapDrawMode() == "metal" then
      Spring.SendCommands("ShowStandard")
  end
end


function widget:KeyPress(key,mods,isRepeat)
  -- add buildfacing shortcuts (facing commands are only handled by spring if we have a building selected, which isn't possible pre-game)
  if preGamestartPlayer and selBuildQueueDefID then
    if key == 91 then  -- [
      local facing = Spring.GetBuildFacing()
      facing = facing + 1
      if facing > 3 then
        facing = 0
      end
      Spring.SetBuildFacing(facing)
    end
    if key == 93 then  -- ]
      local facing = Spring.GetBuildFacing()
      facing = facing - 1
      if facing < 0 then
        facing = 3
      end
      Spring.SetBuildFacing(facing)
    end
    if key == 27 then  -- ESC
      setPreGamestartDefID()
    end
  end
end


function widget:MousePress(x, y, button)
  if (WG['topbar'] and WG['topbar'].showingQuit()) then return end

  if IsOnRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
    if selectedBuilderCount > 0 or (preGamestartPlayer and startDefID) then
      local paginatorHovered = false
      if paginatorRects[1] and IsOnRect(x, y, paginatorRects[1][1], paginatorRects[1][2], paginatorRects[1][3], paginatorRects[1][4]) then
        currentPage = currentPage - 1
        if currentPage < 1 then
          currentPage = pages
        end
        doUpdate = true
      end
      if paginatorRects[2] and IsOnRect(x, y, paginatorRects[2][1], paginatorRects[2][2], paginatorRects[2][3], paginatorRects[2][4]) then
        currentPage = currentPage + 1
        if currentPage > pages then
          currentPage = 1
        end
        doUpdate = true
      end
      if not disableInput then
        for cellRectID, cellRect in pairs(cellRects) do
          if cmds[cellRectID].id and unitHumanName[-cmds[cellRectID].id] and IsOnRect(x, y, cellRect[1], cellRect[2], cellRect[3], cellRect[4]) then
            if button ~= 3 then
              Spring.PlaySoundFile(sound_queue_add, 0.75, 'ui')
              if preGamestartPlayer then
                setPreGamestartDefID(cmds[cellRectID].id*-1)
              else
                Spring.SetActiveCommand(Spring.GetCmdDescIndex(cmds[cellRectID].id),1,true,false,Spring.GetModKeyState())
              end
            else
              if cmds[cellRectID].params[1] then  -- has queue
                Spring.PlaySoundFile(sound_queue_rem, 0.75, 'ui')
              end
              if preGamestartPlayer then
                setPreGamestartDefID(cmds[cellRectID].id*-1)
              else
                Spring.SetActiveCommand(Spring.GetCmdDescIndex(cmds[cellRectID].id),3,false,true,Spring.GetModKeyState())
              end
            end
            doUpdateClock = os_clock() + 0.01
            return true
          end
        end
      end
      return true
    end

  elseif preGamestartPlayer then

    if selBuildQueueDefID then
      if button == 1 then

        local mx, my, button = Spring.GetMouseState()
        local _, pos = Spring.TraceScreenRay(mx, my, true)
        if not pos then return end
        local bx, by, bz = Spring.Pos2BuildPos(selBuildQueueDefID, pos[1], pos[2], pos[3])
        local buildFacing = Spring.GetBuildFacing()

        if Spring.TestBuildOrder(selBuildQueueDefID, bx, by, bz, buildFacing) ~= 0 then

          local buildData = {selBuildQueueDefID, bx, by, bz, buildFacing}
          local _, _, meta, shift = Spring.GetModKeyState()
          if meta then
            table.insert(buildQueue, 1, buildData)

          elseif shift then

            local anyClashes = false
            for i = #buildQueue, 1, -1 do
              if DoBuildingsClash(buildData, buildQueue[i]) then
                anyClashes = true
                table.remove(buildQueue, i)
              end
            end

            if not anyClashes then
              buildQueue[#buildQueue + 1] = buildData
            end
          else
            buildQueue = {buildData}
          end

          if not shift then
            setPreGamestartDefID(nil)
          end
        end

        return true

      elseif button == 3 then
        setPreGamestartDefID(nil)
        return true
      end
    end
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
    buildQueue = buildQueue,
    gameID = Game.gameID,
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
  if data.buildQueue and Spring.GetGameFrame() == 0 then
    buildQueue = data.buildQueue
  end
end
