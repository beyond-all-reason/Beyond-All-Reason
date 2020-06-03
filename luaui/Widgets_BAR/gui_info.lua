function widget:GetInfo()
  return {
    name      = "Info",
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

local width = 0
local height = 0
local bgBorderOrg = 0.0035
local bgBorder = bgBorderOrg
local bgMargin = 0.005
local alternativeUnitpics = false

local zoomMult = 1.5
local defaultCellZoom = 0 * zoomMult
local rightclickCellZoom = 0.065 * zoomMult
local clickCellZoom = 0.065 * zoomMult
local hoverCellZoom = 0.03 * zoomMult

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local fontfile = "fonts/" .. Spring.GetConfigString("bar_font", "Poppins-Regular.otf")
local vsx,vsy = Spring.GetViewGeometry()
local fontfileScale = (0.5 + (vsx*vsy / 5700000))
local fontfileSize = 36
local fontfileOutlineSize = 7
local fontfileOutlineStrength = 1.1
local font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)
local fontfile2 = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
local font2 = gl.LoadFont(fontfile2, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)
local loadedFontSize = fontfileSize*fontfileScale

local barGlowCenterTexture = ":l:LuaUI/Images/barglow-center.png"
local barGlowEdgeTexture   = ":l:LuaUI/Images/barglow-edge.png"

local hoverType, hoverData = '', ''
local sound_button = 'LuaUI/Sounds/buildbar_add.wav'
local sound_button2 = 'LuaUI/Sounds/buildbar_rem.wav'

local ui_opacity = tonumber(Spring.GetConfigFloat("ui_opacity",0.66) or 0.66)
local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale",1) or 1)
local glossMult = 1 + (2-(ui_opacity*2))	-- increase gloss/highlight so when ui is transparant, you can still make out its boundaries and make it less flat

local backgroundRect = {0,0,0,0}
local currentTooltip = ''
local lastUpdateClock = 0

local hpcolormap = { {1, 0.0, 0.0, 1},  {0.8, 0.60, 0.0, 1}, {0.0, 0.75, 0.0, 1} }

function lines(str)
  local t = {}
  local function helper(line) t[#t+1] = line return "" end
  helper((str:gsub("(.-)\r?\n", helper)))
  return t
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

function round(value, numDecimalPlaces)
  if value then
    return string.format("%0."..numDecimalPlaces.."f", math.round(value, numDecimalPlaces))
  else
    return 0
  end
end

local hasAlternativeUnitpic = {}
local unitBuildPic = {}
local unitEnergyCost = {}
local unitMetalCost = {}
local unitBuildTime = {}
local unitGroup = {}
local isBuilder = {}
local unitHumanName = {}
local unitDescriptionLong = {}
local unitTooltip = {}
local unitIconType = {}
local isMex = {}
local isTransport = {}
local unitMaxWeaponRange = {}
local unitHealth = {}
local unitBuildOptions = {}
local unitBuildSpeed = {}
local unitWeapons = {}
local unitDPS = {}
local unitCanStockpile = {}
local unitLosRadius = {}
local unitAirLosRadius = {}
local unitRadarRadius = {}
local unitSonarRadius = {}
local unitJammerRadius = {}
local unitSonarJamRadius = {}
local unitSeismicRadius = {}
local unitArmorType = {}
for unitDefID, unitDef in pairs(UnitDefs) do
  unitHumanName[unitDefID] = unitDef.humanName
  if unitDef.maxWeaponRange > 16 then
    unitMaxWeaponRange[unitDefID] = unitDef.maxWeaponRange
  end
  if unitDef.customParams.description_long then
    unitDescriptionLong[unitDefID] = wrap(unitDef.customParams.description_long, 58)
  end
  if unitDef.isTransport then
    isTransport[unitDefID] = {unitDef.transportMass, unitDef.transportSize, unitDef.transportCapacity}
  end

  unitArmorType[unitDefID] = Game.armorTypes[unitDef.armorType or 0] or '???'

  if unitDef.losRadius > 0 then
    unitLosRadius[unitDefID] = unitDef.losRadius
  end
  if unitDef.airLosRadius > 0 then
    unitAirLosRadius[unitDefID] = unitDef.airLosRadius
  end
  if unitDef.radarRadius > 0 then
    unitRadarRadius[unitDefID] = unitDef.radarRadius
  end
  if unitDef.sonarRadius > 0 then
    unitSonarRadius[unitDefID] = unitDef.sonarRadius
  end
  if unitDef.jammerRadius > 0 then
    unitJammerRadius[unitDefID] = unitDef.jammerRadius
  end
  if unitDef.sonarJamRadius > 0 then
    unitSonarJamRadius[unitDefID] = unitDef.sonarJamRadius
  end
  if unitDef.seismicRadius > 0 then
    unitSeismicRadius[unitDefID] = unitDef.seismicRadius
  end

  unitTooltip[unitDefID] = unitDef.tooltip
  unitIconType[unitDefID] = unitDef.iconType
  unitEnergyCost[unitDefID] = unitDef.energyCost
  unitMetalCost[unitDefID] = unitDef.metalCost
  unitHealth[unitDefID] = unitDef.health
  unitBuildTime[unitDefID] = unitDef.buildTime
  unitBuildPic[unitDefID] = unitDef.buildpicname
  if unitDef.canStockpile then
    unitCanStockpile[unitDefID] = true
  end
  if VFS.FileExists('unitpics/alternative/'..string.gsub(unitDef.buildpicname, '(.*/)', '')) then
    hasAlternativeUnitpic[unitDefID] = true
  end
  if unitDef.buildSpeed > 0 then
    unitBuildSpeed[unitDefID] = unitDef.buildSpeed
  end
  if unitDef.buildOptions[1] then
    unitBuildOptions[unitDefID] = unitDef.buildOptions
  end
  if unitDef.extractsMetal > 0 then
    isMex[unitDefID] = true
  end

  for i=1, #unitDef.weapons do
    if not unitWeapons[unitDefID] then
      unitWeapons[unitDefID] = {}
      unitDPS[unitDefID] = 0
    end
    unitWeapons[unitDefID][i] = unitDef.weapons[i].weaponDef
    local weaponDef = WeaponDefs[unitDef.weapons[i].weaponDef]
    if weaponDef.damages then
      local defaultDPS = weaponDef.damages[0] * weaponDef.salvoSize / weaponDef.reload
      unitDPS[unitDefID] = math.floor(defaultDPS)
    end
  end
end
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local spGetCurrentTooltip = Spring.GetCurrentTooltip
local spGetSelectedUnitsCounts = Spring.GetSelectedUnitsCounts
local spGetSelectedUnitsSorted = Spring.GetSelectedUnitsSorted
local spGetSelectedUnitsCount = Spring.GetSelectedUnitsCount
local SelectedUnitsCount = Spring.GetSelectedUnitsCount()
local selectedUnits = Spring.GetSelectedUnits()
local spGetUnitDefID = Spring.GetUnitDefID
local spTraceScreenRay = Spring.TraceScreenRay
local spGetMouseState = Spring.GetMouseState
local spGetModKeyState = Spring.GetModKeyState
local spSelectUnitArray = Spring.SelectUnitArray
local spGetTeamUnitsSorted = Spring.GetTeamUnitsSorted
local spSelectUnitMap = Spring.SelectUnitMap
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitResources = Spring.GetUnitResources
local spGetUnitMaxRange = Spring.GetUnitMaxRange
local spGetUnitExperience = Spring.GetUnitExperience
local spGetUnitMetalExtraction = Spring.GetUnitMetalExtraction
local spGetUnitStates = Spring.GetUnitStates
local spGetUnitStockpile = Spring.GetUnitStockpile

local os_clock = os.clock

local isSpec = Spring.GetSpectatingState()
local myTeamID = Spring.GetMyTeamID()

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

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------



-- load all icons to prevent briefly showing white unit icons (will happen due to the custom texture filtering options)
local function cacheUnitIcons()
  for id, unit in pairs(UnitDefs) do
    if hasAlternativeUnitpic[id] then
      gl.Texture(':lr128,128:unitpics/alternative/'..unitBuildPic[id])
    else
      gl.Texture(':lr128,128:unitpics/'..unitBuildPic[id])
    end
    gl.TexRect(-1,-1,0,0)
    if alternativeUnitpics and hasAlternativeUnitpic[id] then
      gl.Texture(':lr64,64:unitpics/alternative/'..unitBuildPic[id])
    else
      gl.Texture(':lr64,64:unitpics/'..unitBuildPic[id])
    end
    gl.TexRect(-1,-1,0,0)
    if alternativeUnitpics and hasAlternativeUnitpic[id] then
      gl.Texture(':lr128,128:unitpics/alternative/'..unitBuildPic[id])
    else
      gl.Texture(':lr128,128:unitpics/'..unitBuildPic[id])
    end
    if iconTypesMap[unitIconType[id]] then
      gl.TexRect(-1,-1,0,0)
      gl.Texture(':lr64,64:'..iconTypesMap[unitIconType[id]])
      gl.TexRect(-1,-1,0,0)
    end
    gl.Texture(false)
  end
end

local function refreshUnitIconCache()
  if dlistCache then
    dlistCache = gl.DeleteList(dlistCache)
  end
  dlistCache = gl.CreateList( function()
    cacheUnitIcons()
  end)
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
      WG['guishader'].InsertDlist(dlistGuishader, 'info')
    end
  elseif dlistGuishader then
    dlistGuishader = gl.DeleteList(dlistGuishader)
  end
end

function widget:PlayerChanged(playerID)
  isSpec = Spring.GetSpectatingState()
  myTeamID = Spring.GetMyTeamID()
end

function widget:ViewResize()
  vsx,vsy = Spring.GetViewGeometry()

  width = 0.23
  height = 0.14
  width = width / (vsx/vsy) * 1.78		-- make smaller for ultrawide screens
  width = width * ui_scale

  backgroundRect = {0, 0, width*vsx, height*vsy}

  doUpdate = true
  clear()

  checkGuishader(true)

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

function GetColor(colormap,slider)
  local coln = #colormap
  if (slider>=1) then
    local col = colormap[coln]
    return col[1],col[2],col[3],col[4]
  end
  if (slider<0) then slider=0 elseif(slider>1) then slider=1 end
  local posn  = 1+(coln-1) * slider
  local iposn = math.floor(posn)
  local aa    = posn - iposn
  local ia    = 1-aa

  local col1,col2 = colormap[iposn],colormap[iposn+1]

  return col1[1]*ia + col2[1]*aa, col1[2]*ia + col2[2]*aa,
  col1[3]*ia + col2[3]*aa, col1[4]*ia + col2[4]*aa
end

function widget:Initialize()
  WG['info'] = {}
  WG['info'].getPosition = function()
    return width,height
  end
  WG['info'].getAlternativeIcons = function()
    return alternativeUnitpics
  end
  WG['info'].setAlternativeIcons = function(value)
    alternativeUnitpics = value
    doUpdate = true
    refreshUnitIconCache()
  end
  iconTypesMap = {}
  if Script.LuaRules('GetIconTypes') then
    iconTypesMap = Script.LuaRules.GetIconTypes()
  end
  Spring.SetDrawSelectionInfo(false) --disables springs default display of selected units count
  Spring.SendCommands("tooltip 0")
  widget:ViewResize()

  bfcolormap = {}
  for hp=0,100 do
    bfcolormap[hp] = {GetColor(hpcolormap,hp*0.01)}
  end

  refreshUnitIconCache()
end

function clear()
  dlistInfo = gl.DeleteList(dlistInfo)
end

function widget:Shutdown()
  Spring.SetDrawSelectionInfo(true) --disables springs default display of selected units count
  Spring.SendCommands("tooltip 1")
  clear()
  if WG['guishader'] and dlistGuishader then
    WG['guishader'].DeleteDlist('info')
    dlistGuishader = nil
  end
end

local uiOpacitySec = 0
local sec = 0
function widget:Update(dt)
  uiOpacitySec = uiOpacitySec + dt
  if uiOpacitySec > 0.5 then
    uiOpacitySec = 0
    checkGuishader()
    if ui_scale ~= Spring.GetConfigFloat("ui_scale",1) then
      ui_scale = Spring.GetConfigFloat("ui_scale",1)
      widget:ViewResize()
      refreshUnitIconCache()
    end
    if ui_opacity ~= Spring.GetConfigFloat("ui_opacity",0.66) then
      ui_opacity = Spring.GetConfigFloat("ui_opacity",0.66)
      glossMult = 1 + (2-(ui_opacity*2))
      doUpdate = true
    end
  end

  sec = sec + dt
  if sec > 0.05 then
    sec = 0
    checkChanges()
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
  gl.Texture(false)
  gl.BeginEnd(GL.QUADS, DrawRectRound, px,py,sx,sy,cs, tl,tr,br,bl, c1,c2)
end

function IsOnRect(x, y, BLcornerX, BLcornerY,TRcornerX,TRcornerY)
  return x >= BLcornerX and x <= TRcornerX and y >= BLcornerY and y <= TRcornerY
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

local function DrawTexRectRound(px,py,sx,sy,cs, tl,tr,br,bl, offset)
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
function TexRectRound(px,py,sx,sy,cs, tl,tr,br,bl, zoom)
  gl.BeginEnd(GL.QUADS, DrawTexRectRound, px,py,sx,sy,cs, tl,tr,br,bl, zoom)
end


local function drawSelectionCell(cellID, uDefID, usedZoom)
  if not usedZoom then
    usedZoom = defaultCellZoom
  end

  glColor(1,1,1,1)
  glTexture(texSetting.."unitpics/"..((alternativeUnitpics and hasAlternativeUnitpic[uDefID]) and 'alternative/' or '')..unitBuildPic[uDefID])
  --glTexRect(cellRect[cellID][1]+cellPadding, cellRect[cellID][2]+cellPadding, cellRect[cellID][3]-cellPadding, cellRect[cellID][4]-cellPadding)
  --DrawRect(cellRect[cellID][1]+cellPadding, cellRect[cellID][2]+cellPadding, cellRect[cellID][3]-cellPadding, cellRect[cellID][4]-cellPadding,0.06)
  TexRectRound(cellRect[cellID][1]+cellPadding, cellRect[cellID][2]+cellPadding, cellRect[cellID][3]-cellPadding, cellRect[cellID][4]-cellPadding, cornerSize, 1,1,1,1, usedZoom)
  glTexture(false)
  -- darkening bottom
  RectRound(cellRect[cellID][1]+cellPadding, cellRect[cellID][2]+cellPadding, cellRect[cellID][3]-cellPadding, cellRect[cellID][4]-cellPadding, cornerSize, 0,0,1,1, {0,0,0,0.15}, {0,0,0,0})
  -- gloss
  glBlending(GL_SRC_ALPHA, GL_ONE)
  RectRound(cellRect[cellID][1]+cellPadding, cellRect[cellID][4]-cellPadding-((cellRect[cellID][4]-cellRect[cellID][2])*0.77), cellRect[cellID][3]-cellPadding, cellRect[cellID][4]-cellPadding, cornerSize, 1,1,0,0, {1,1,1,0}, {1,1,1,0.1})
  RectRound(cellRect[cellID][1]+cellPadding, cellRect[cellID][4]-cellPadding-((cellRect[cellID][4]-cellRect[cellID][2])*0.14), cellRect[cellID][3]-cellPadding, cellRect[cellID][4]-cellPadding, cornerSize, 1,1,0,0, {1,1,1,0}, {1,1,1,0.1})
  RectRound(cellRect[cellID][1]+cellPadding, cellRect[cellID][2]+cellPadding, cellRect[cellID][3]-cellPadding, cellRect[cellID][2]+cellPadding+((cellRect[cellID][4]-cellRect[cellID][2])*0.14), cornerSize, 0,0,1,1, {1,1,1,0.08}, {1,1,1,0})
  glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
  -- unitcount
  if selUnitsCounts[uDefID] > 1 then
    local fontSize = math.min(gridHeight*0.19, cellsize*0.6) * (1-((1+string.len(selUnitsCounts[uDefID]))*0.066))
    font2:Begin()
    font2:Print(selUnitsCounts[uDefID], cellRect[cellID][3]-cellPadding-(fontSize*0.09), cellRect[cellID][2]+(fontSize*0.3), fontSize, "ro")
    font2:End()
  end
end

local function drawInfo()
  padding = 0.0033*vsy * ui_scale
  RectRound(backgroundRect[1],backgroundRect[2],backgroundRect[3],backgroundRect[4], padding*1.7, 1,(WG['buildpower'] and 0 or 1),1,1,{0.05,0.05,0.05,ui_opacity}, {0,0,0,ui_opacity})
  RectRound(backgroundRect[1], backgroundRect[2]+padding, backgroundRect[3]-padding, backgroundRect[4]-padding, padding, 0,(WG['buildpower'] and 0 or 1),1,0,{0.3,0.3,0.3,ui_opacity*0.1}, {1,1,1,ui_opacity*0.1})

  --colorize
  --glBlending(GL.DST_COLOR, GL.DST_COLOR)
  --RectRound(backgroundRect[1],backgroundRect[2],backgroundRect[3],backgroundRect[4], padding*1.7, 1,1,1,1,{0.5,0.5,0.5,1}, {0.5,0.5,0.5,1})
  --glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

  -- gloss
  glBlending(GL_SRC_ALPHA, GL_ONE)
  RectRound(backgroundRect[1],backgroundRect[4]-((backgroundRect[4]-backgroundRect[2])*0.16),backgroundRect[3]-padding,backgroundRect[4]-padding, padding, 0,(WG['buildpower'] and 0 or 1),0,0, {1,1,1,0.01*glossMult}, {1,1,1,0.055*glossMult})
  RectRound(backgroundRect[1],backgroundRect[2],backgroundRect[3]-padding,backgroundRect[2]+((backgroundRect[4]-backgroundRect[2])*0.15), padding, 0,0,0,0, {1,1,1,0.02*glossMult}, {1,1,1,0})
  glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

  RectRound(backgroundRect[1],backgroundRect[4]-((backgroundRect[4]-backgroundRect[2])*0.4),backgroundRect[3]-padding,backgroundRect[4]-padding, padding, 0,(WG['buildpower'] and 0 or 1),0,0, {1,1,1,0}, {1,1,1,0.1})
  --RectRound(backgroundRect[1],backgroundRect[2],backgroundRect[3]-padding,backgroundRect[4]-((backgroundRect[4]-backgroundRect[2])*0.75), padding, 0,0,0,0, {1,1,1,0.08}, {1,1,1,0})

  local fontSize = (height*vsy * 0.11) * (1-((1-ui_scale)*0.5))
  contentPadding = (height*vsy * 0.075) * (1-((1-ui_scale)*0.5))
  contentWidth = backgroundRect[3]-backgroundRect[1]-contentPadding-contentPadding


  if displayMode == 'selection' then

    selUnitsCounts = spGetSelectedUnitsCounts()
    selUnitsSorted = spGetSelectedUnitsSorted()
    selUnitTypes = 0
    selectionCells = {}
    for uDefID,v in pairs(selUnitsSorted) do
      if type(v) == 'table' then
        selUnitTypes = selUnitTypes + 1
        selectionCells[selUnitTypes] = uDefID
      end
    end

    -- selected units grid area
    gridWidth = backgroundRect[3]-backgroundRect[1]
    gridHeight = (backgroundRect[4]-backgroundRect[2])-padding-padding
    customInfoArea = {backgroundRect[3]-gridWidth-padding, backgroundRect[2], backgroundRect[3]-padding, backgroundRect[2]+gridHeight}

    -- selected units grid area

    -- draw selected unit icons
    local rows = 2
    local maxRows = 15  -- just to be sure
    local colls = math.ceil(selUnitTypes / rows)
    cellsize = math.min(gridWidth/colls, gridHeight/rows)
    while cellsize < gridHeight/(rows+1) do
      rows = rows + 1
      colls = math.ceil(selUnitTypes / rows)
      cellsize = math.min(gridWidth/colls, gridHeight/rows)
      if rows > maxRows then
        break
      end
    end
    -- draw grid (bottom right to top left)
    cellPadding = cellsize * 0.03
    cellRect = {}
    texOffset = (0.03*rows) * zoomMult
    texSetting = cellsize > 38 and ':lr128,128:' or ':lr64,64:'
    cornerSize = cellPadding*0.9
    if texOffset > 0.25 then texOffset = 0.25 end
    local cellID = selUnitTypes
    for row=1, rows do
      for coll=1, colls do
        if selectionCells[cellID] then
          local uDefID = selectionCells[cellID]
          cellRect[cellID] = {customInfoArea[3]-cellPadding-(coll*cellsize), customInfoArea[2]+cellPadding+((row-1)*cellsize), customInfoArea[3]-cellPadding-((coll-1)*cellsize), customInfoArea[2]+cellPadding+((row)*cellsize)}
          drawSelectionCell(cellID, selectionCells[cellID], texOffset)
        end
        cellID = cellID - 1
        if cellID <= 0 then break end
      end
      if cellID <= 0 then break end
    end
    glTexture(false)
    glColor(1,1,1,1)


  elseif displayMode ~= 'text' and displayUnitDefID then
    local iconSize = fontSize*5
    local iconPadding = 0
    local alternative = ''
    if hasAlternativeUnitpic[displayUnitDefID] then
      alternative = 'alternative/'
      iconPadding = padding
    end

    glColor(1,1,1,1)
    if unitBuildPic[displayUnitDefID] then
      glTexture(":lr128,128:unitpics/"..alternative..unitBuildPic[displayUnitDefID])
      glTexRect(backgroundRect[1]+iconPadding, backgroundRect[4]-iconPadding-iconSize-padding, backgroundRect[1]+iconPadding+iconSize, backgroundRect[4]-iconPadding-padding)
      glTexture(false)
    end
    iconSize = iconSize + iconPadding

    local radarIconSize = iconSize * 0.3
    local radarIconMargin = radarIconSize * 0.3
    local showingRadarIcon = false
    if unitIconType[displayUnitDefID] and iconTypesMap[unitIconType[displayUnitDefID]] then
      glColor(1,1,1,0.88)
      glTexture(':lr64,64:'..iconTypesMap[unitIconType[displayUnitDefID]])
      glTexRect(backgroundRect[3]-radarIconMargin-radarIconSize, backgroundRect[4]-radarIconMargin-radarIconSize, backgroundRect[3]-radarIconMargin, backgroundRect[4]-radarIconMargin)
      glTexture(false)
      glColor(1,1,1,1)
      showingRadarIcon = true
    end

    -- unitID
    if displayUnitID then
      local radarIconSpace = showingRadarIcon and (radarIconMargin+radarIconSize) or 0
      font:Begin()
      font:Print('\255\200\200\200#'..displayUnitID, backgroundRect[3]-radarIconMargin-radarIconSpace, backgroundRect[4]+(fontSize*0.6)-radarIconSpace, fontSize*0.8, "ro")
      font:End()
    end


    local unitNameColor = '\255\205\255\205'
    if SelectedUnitsCount > 0 then
      if not displayMode == 'unitdef' or (WG['buildmenu'] and (WG['buildmenu'].selectedID and (not WG['buildmenu'].hoverID or (WG['buildmenu'].selectedID == WG['buildmenu'].hoverID)))) then
        unitNameColor = '\255\125\255\125'
      end
    end
    local descriptionColor = '\255\240\240\240'
    local metalColor = '\255\245\245\245'
    local energyColor = '\255\255\255\000'
    local healthColor = '\255\100\255\100'

    local text, numLines = font:WrapText(unitTooltip[displayUnitDefID], (contentWidth-iconSize)*(loadedFontSize/fontSize))
    -- unit tooltip
    font:Begin()
    font:Print(descriptionColor..text, backgroundRect[1]+contentPadding+iconSize, backgroundRect[4]-contentPadding-(fontSize*2.4), fontSize, "o")
    font:End()
    -- unit name
    font2:Begin()
    font2:Print(unitNameColor..unitHumanName[displayUnitDefID], backgroundRect[1]+iconSize+iconPadding, backgroundRect[4]-contentPadding-(fontSize), fontSize*1.15, "o")

    local contentPaddingLeft = contentPadding * 0.75
    local texPosY = backgroundRect[4]-iconSize-(contentPadding * 0.64)
    local texSize = fontSize * 1.15
    glColor(1,1,1,1)
    glTexture(":l:LuaUI/Images/info_metal.png")
    glTexRect(backgroundRect[1]+contentPaddingLeft, texPosY-texSize, backgroundRect[1]+contentPaddingLeft+texSize, texPosY)
    glTexture(":l:LuaUI/Images/info_energy.png")
    glTexRect(backgroundRect[1]+contentPaddingLeft, texPosY-texSize-(fontSize*1.23), backgroundRect[1]+contentPaddingLeft+texSize, texPosY-(fontSize*1.23))
    glTexture(":l:LuaUI/Images/info_health.png")
    glTexRect(backgroundRect[1]+contentPaddingLeft, texPosY-texSize-(fontSize*2.46), backgroundRect[1]+contentPaddingLeft+texSize, texPosY-(fontSize*2.46))
    glTexture(false)

    -- metal
    local contentPaddingLeft = contentPaddingLeft + texSize + (contentPadding * 0.5)
    font2:Print(metalColor..unitMetalCost[displayUnitDefID], backgroundRect[1]+contentPaddingLeft, backgroundRect[4]-contentPadding-iconSize-(fontSize*0.6), fontSize, "o")
    -- energy
    font2:Print(energyColor..unitEnergyCost[displayUnitDefID], backgroundRect[1]+contentPaddingLeft, backgroundRect[4]-contentPadding-iconSize-(fontSize*1.85), fontSize, "o")
    -- health
    font2:Print(healthColor..unitHealth[displayUnitDefID], backgroundRect[1]+contentPaddingLeft, backgroundRect[4]-contentPadding-iconSize-(fontSize*3.1), fontSize, "o")

    font2:End()

    -- custom unit info background
    local width = contentWidth * 0.8
    local height = (backgroundRect[4]-backgroundRect[2]) * 0.475
    customInfoArea = {backgroundRect[3]-width-padding, backgroundRect[2], backgroundRect[3]-padding, backgroundRect[2]+height}
    RectRound(customInfoArea[1], customInfoArea[2], customInfoArea[3], customInfoArea[4], padding, 1,0,0,0,{1,1,1,0.04}, {1,1,1,0.12})

    -- draw unit buildoption icons
    if displayMode == 'unitdef' and unitBuildOptions[displayUnitDefID] then
      local gridHeight = height*0.98
      local rows = 2
      local colls = math.ceil(#unitBuildOptions[displayUnitDefID] / rows)
      local cellsize = math.min(width/colls, gridHeight/rows)
      if cellsize < gridHeight/3 then
        rows = 3
        colls = math.ceil(#unitBuildOptions[displayUnitDefID] / rows)
        cellsize = math.min(width/colls, gridHeight/rows)
      end
      -- draw grid (bottom right to top left)
      local cellID = #unitBuildOptions[displayUnitDefID]
      cellPadding = cellsize * 0.03
      cellRect = {}
      for row=1, rows do
        for coll=1, colls do
          if unitBuildOptions[displayUnitDefID][cellID] then
            local uDefID = unitBuildOptions[displayUnitDefID][cellID]
            cellRect[cellID] = {customInfoArea[3]-cellPadding-(coll*cellsize), customInfoArea[2]+cellPadding+((row-1)*cellsize), customInfoArea[3]-cellPadding-((coll-1)*cellsize), customInfoArea[2]+cellPadding+((row)*cellsize)}
            glColor(0.9,0.9,0.9,1)
            glTexture(":lr64,64:unitpics/"..((alternativeUnitpics and hasAlternativeUnitpic[uDefID]) and 'alternative/' or '')..unitBuildPic[uDefID])
            --glTexRect(cellRect[cellID][1]+cellPadding, cellRect[cellID][2]+cellPadding, cellRect[cellID][3]-cellPadding, cellRect[cellID][4]-cellPadding)
            --DrawRect(cellRect[cellID][1]+cellPadding, cellRect[cellID][2]+cellPadding, cellRect[cellID][3]-cellPadding, cellRect[cellID][4]-cellPadding,0.06)
            TexRectRound(cellRect[cellID][1]+cellPadding, cellRect[cellID][2]+cellPadding, cellRect[cellID][3]-cellPadding, cellRect[cellID][4]-cellPadding, cellPadding*1.3, 1,1,1,1, 0.11)
            glTexture(false)
            -- darkening bottom
            RectRound(cellRect[cellID][1]+cellPadding, cellRect[cellID][2]+cellPadding, cellRect[cellID][3]-cellPadding, cellRect[cellID][4]-cellPadding, cellPadding*1.3, 0,0,1,1, {0,0,0,0.15}, {0,0,0,0})
            -- gloss
            glBlending(GL_SRC_ALPHA, GL_ONE)
            RectRound(cellRect[cellID][1]+cellPadding, cellRect[cellID][4]-cellPadding-((cellRect[cellID][4]-cellRect[cellID][2])*0.77), cellRect[cellID][3]-cellPadding, cellRect[cellID][4]-cellPadding, cellPadding*1.3, 1,1,0,0, {1,1,1,0}, {1,1,1,0.1})
            RectRound(cellRect[cellID][1]+cellPadding, cellRect[cellID][4]-cellPadding-((cellRect[cellID][4]-cellRect[cellID][2])*0.14), cellRect[cellID][3]-cellPadding, cellRect[cellID][4]-cellPadding, cellPadding*1.3, 1,1,0,0, {1,1,1,0}, {1,1,1,0.1})
            RectRound(cellRect[cellID][1]+cellPadding, cellRect[cellID][2]+cellPadding, cellRect[cellID][3]-cellPadding, cellRect[cellID][2]+cellPadding+((cellRect[cellID][4]-cellRect[cellID][2])*0.14), cellPadding*1.3, 0,0,1,1, {1,1,1,0.08}, {1,1,1,0})
            glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
          end
          cellID = cellID - 1
          if cellID <= 0 then break end
        end
        if cellID <= 0 then break end
      end
      glTexture(false)
      glColor(1,1,1,1)


    else  -- unit/unitdef info (without buildoptions)
      contentPadding = contentPadding * 0.95
      local contentPaddingLeft = customInfoArea[1] + contentPadding
      local labelColor = '\255\205\205\205'
      local valueColor = '\255\255\255\255'
      local valuePlusColor = '\255\180\255\180'
      local valueMinColor = '\255\255\180\180'

      -- unit specific info
      if displayMode == 'unit' then
        -- get lots of unit info from functions: https://springrts.com/wiki/Lua_SyncedRead
        local metalMake, metalUse, energyMake, energyUse = spGetUnitResources(displayUnitID)
        local maxRange = spGetUnitMaxRange(displayUnitID)
        local exp = spGetUnitExperience(displayUnitID)
        local metalExtraction, stockpile, dps
        if isMex[displayUnitDefID] then
          metalExtraction = spGetUnitMetalExtraction(displayUnitID)
        end
        local unitStates = spGetUnitStates(displayUnitID)
        if unitCanStockpile[displayUnitDefID] then
          stockpile = spGetUnitStockpile(displayUnitID)
        end
        if unitDPS[displayUnitDefID] then
          dps = unitDPS[displayUnitDefID]
        end

        -- determine what to show in what order
        local text = ''
        local separator = ''
        local infoFontsize = fontSize * 0.92

        local function addTextInfo(label, value)
          text = text.. labelColor..separator..label .. (label~='' and ' ' or '') .. valueColor..(value and value or '')
          separator = ',   '
        end

        -- add text
        addTextInfo('', labelColor..'m +'..valuePlusColor..round(metalMake, 1)..labelColor..' -'..valueMinColor..round(metalUse, 1)..labelColor..',   e +'..valuePlusColor..round(energyMake, 0)..labelColor..' -'..valueMinColor..round(energyUse, 0))
        if unitWeapons[displayUnitDefID] then
          addTextInfo('weapons', #unitWeapons[displayUnitDefID])
          if maxRange then
            addTextInfo('max-range', maxRange)
          end
          if dps then
            addTextInfo('dps', dps)
          end
        end
        --if metalExtraction then
        --  addTextInfo('metal extraction', round(metalExtraction, 2))
        --end
        if unitBuildSpeed[displayUnitDefID] then
          addTextInfo('builspeed', unitBuildSpeed[displayUnitDefID])
        end
        if unitBuildOptions[displayUnitDefID] then
          addTextInfo('buildoptions', #unitBuildOptions[displayUnitDefID])
        end
        if exp and exp > 0.009 then
          addTextInfo('xp', round(exp, 2))
        end

        if unitLosRadius[displayUnitDefID] then
          addTextInfo('los', round(unitLosRadius[displayUnitDefID],0))
        end
        if unitAirLosRadius[displayUnitDefID] then
          addTextInfo('airlos', round(unitAirLosRadius[displayUnitDefID],0))
        end
        if unitRadarRadius[displayUnitDefID] then
          addTextInfo('radar', round(unitRadarRadius[displayUnitDefID],0))
        end
        if unitSonarRadius[displayUnitDefID] then
          addTextInfo('sonar', round(unitSonarRadius[displayUnitDefID],0))
        end
        if unitJammerRadius[displayUnitDefID] then
          addTextInfo('jammer', round(unitJammerRadius[displayUnitDefID],0))
        end
        if unitSonarJamRadius[displayUnitDefID] then
          addTextInfo('sonarjam', round(unitSonarJamRadius[displayUnitDefID],0))
        end
        if unitSeismicRadius[displayUnitDefID] then
          addTextInfo('seismic', unitSeismicRadius[displayUnitDefID])
        end

        if unitArmorType[displayUnitDefID] then
          addTextInfo('armor', unitArmorType[displayUnitDefID])
        end

        addTextInfo('height', round(Spring.GetUnitHeight(displayUnitID),0))
        addTextInfo('radius', round(Spring.GetUnitRadius(displayUnitID),0))
        addTextInfo('mass', round(Spring.GetUnitMass(displayUnitID),0))

        -- wordwrap text
        unitInfoText = text   -- canbe used to show full text on mouse hover
        text, numLines = font:WrapText(text,((backgroundRect[3]-padding-padding)-(backgroundRect[1]+contentPaddingLeft))*(loadedFontSize/infoFontsize))

        -- prune number of lines
        local lines = lines(text)
        text = ''
        for i,line in pairs(lines) do
          text = text .. line
          -- only 4 fully fit, but showing 5, so the top part of text shows and indicates there is more to see somehow
          if i == 5 then
            break
          end
          text = text .. '\n'
        end

        -- unit info
        font:Begin()
        font:Print(text, customInfoArea[1]+contentPadding, customInfoArea[4]-contentPadding-(infoFontsize*0.42), infoFontsize, "o")
        font:End()

        -- display health value/bar
        local health,maxHealth,_,_,buildProgress = spGetUnitHealth(displayUnitID)
        if health then
          local healthBarWidth = (backgroundRect[3]-backgroundRect[1]) * 0.15
          local healthBarHeight = healthBarWidth * 0.1
          local healthBarMargin = healthBarHeight * 0.7
          local healthBarPadding = healthBarHeight * 0.15
          local healthValueWidth = (healthBarWidth-healthBarPadding) * (health/maxHealth)
          local color = bfcolormap[math.min(math.max(math.floor((health/maxHealth)*100), 0), 100)]

          -- bar background
          RectRound(
                  customInfoArea[3]-healthBarMargin-healthBarWidth,
                  customInfoArea[4]+healthBarMargin,
                  customInfoArea[3]-healthBarMargin,
                  customInfoArea[4]+healthBarMargin+healthBarHeight,
                  healthBarHeight*0.15, 1,1,1,1, {0.15,0.15,0.15,0.3}, {0.75,0.75,0.75,0.4}
          )
          -- bar value
          RectRound(
                  customInfoArea[3]-healthBarMargin-healthBarWidth+healthBarPadding,
                  customInfoArea[4]+healthBarMargin+healthBarPadding,
                  customInfoArea[3]-healthBarMargin-healthBarWidth+healthValueWidth,
                  customInfoArea[4]+healthBarMargin+healthBarHeight-(healthBarPadding*0.66),
                  healthBarHeight*0.11, 1,1,1,1, {color[1]-0.1, color[2]-0.1, color[3]-0.1, color[4]}, {color[1]+0.25, color[2]+0.25, color[3]+0.25, color[4]}
          )
          -- bar text value
          font:Begin()
          font:Print(math.floor(health), customInfoArea[3]+healthBarPadding-healthBarMargin-(healthBarWidth*0.5), customInfoArea[4]+healthBarMargin+healthBarHeight+healthBarHeight-(infoFontsize*0.17), infoFontsize*0.88, "oc")
          font:End()
        end
      end
    end

  else

    -- display default plaintext engine tooltip
    local text, numLines = font:WrapText(currentTooltip, contentWidth*(loadedFontSize/fontSize))
    font:Begin()
    font:Print(text, backgroundRect[1]+contentPadding, backgroundRect[4]-contentPadding-(fontSize*0.8), fontSize, "o")
    font:End()
  end
end


function widget:RecvLuaMsg(msg, playerID)
  if msg:sub(1,18) == 'LobbyOverlayActive' then
    chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
  end
end

local function LeftMouseButton(unitDefID, unitTable)
  local alt, ctrl, meta, shift = spGetModKeyState()
  local acted = false
  if not ctrl then
    -- select units of icon type
    if alt or meta then
      acted = true
      spSelectUnitArray({ unitTable[1] })  -- only 1
    else
      acted = true
      spSelectUnitArray(unitTable)
    end
  else
    -- select all units of the icon type
    local sorted = spGetTeamUnitsSorted(myTeamID)
    local units = sorted[unitDefID]
    if units then
      acted = true
      spSelectUnitArray(units, shift)
    end
  end
  if acted then
    Spring.PlaySoundFile(sound_button, 0.5, 'ui')
  end
end

local function MiddleMouseButton(unitDefID, unitTable)
  local alt, ctrl, meta, shift = spGetModKeyState()
  -- center the view
  if ctrl then
    -- center the view on the entire selection
    Spring.SendCommands({"viewselection"})
  else
    -- center the view on this type on unit
    spSelectUnitArray(unitTable)
    Spring.SendCommands({"viewselection"})
    spSelectUnitArray(selectedUnits)
  end
  Spring.PlaySoundFile(sound_button, 0.5, 'ui')
end

local function RightMouseButton(unitDefID, unitTable)
  local alt, ctrl, meta, shift = spGetModKeyState()
  -- remove selected units of icon type
  local map = {}
  for i=1,#selectedUnits do
    map[selectedUnits[i]] = true
  end
  for _,uid in ipairs(unitTable) do
    map[uid] = nil
    if ctrl then break end -- only remove 1 unit
  end
  spSelectUnitMap(map)
  Spring.PlaySoundFile(sound_button2, 0.5, 'ui')
end

function widget:MouseRelease(x, y, button)

  if displayMode and displayMode == 'selection' and customInfoArea and IsOnRect(x, y, customInfoArea[1], customInfoArea[2], customInfoArea[3], customInfoArea[4]) then
    if selectionCells and selectionCells[1] and cellRect then
      for cellID,unitDefID in pairs(selectionCells) do
        if cellRect[cellID] and IsOnRect(x, y, cellRect[cellID][1], cellRect[cellID][2], cellRect[cellID][3], cellRect[cellID][4]) then
           -- apply selection
          --if b then
          --  local alt, ctrl, meta, shift = spGetModKeyState()
          --  -- select all units of the icon type
          --  local sorted = spGetTeamUnitsSorted(myTeamID)
          --  local units = sorted[unitDefID]
          --  local acted = false
          --  if units then
          --    acted = true
          --    spSelectUnitArray(units, shift)
          --  end
          --  if acted then
          --    Spring.PlaySoundFile(sound_button, 0.75, 'ui')
          --  end
          --end


          local unitTable = nil
          local index = 0
          for udid,uTable in pairs(selUnitsSorted) do
            if udid == unitDefID then
              unitTable = uTable
              break
            end
            index = index + 1
          end
          if unitTable == nil then
            return -1
          end

          if button == 1 then
            LeftMouseButton(unitDefID, unitTable)
          elseif button == 2 then
            MiddleMouseButton(unitDefID, unitTable)
          elseif button == 3 then
            RightMouseButton(unitDefID, unitTable)
          end
          return -1
        end
      end
    end
  end

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

function widget:DrawScreen()
  if chobbyInterface then return end

  local x,y,b,b2,b3 = spGetMouseState()

  if doUpdate or (doUpdateClock and os_clock() >= doUpdateClock) then
    doUpdateClock = nil
    clear()
    doUpdate = nil
    lastUpdateClock = os_clock()
  end

  if not dlistInfo then
    dlistInfo = gl.CreateList( function()
      drawInfo()
    end)
  end
  gl.CallList(dlistInfo)

  if displayMode ~= 'text' and  IsOnRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
    Spring.SetMouseCursor('cursornormal')

    --RectRound(backgroundRect[1],backgroundRect[2],backgroundRect[3]-padding,backgroundRect[4]-padding, padding, 0,1,0,0, {1,1,1,b and 0.4 or 0.25}, {1,1,1,b and 0.12 or 0.06})
    --RectRound(backgroundRect[1],backgroundRect[4]-((backgroundRect[4]-backgroundRect[2])*0.25),backgroundRect[3]-padding,backgroundRect[4]-padding, padding, 0,1,0,0, {1,1,1,0}, {1,1,1,b and 0.3 or 0.15})
    --RectRound(backgroundRect[1],backgroundRect[4]-((backgroundRect[4]-backgroundRect[2])*0.16),backgroundRect[3]-padding,backgroundRect[4]-padding, padding, 0,1,0,0, {1,1,1,b and 0.2 or 0.1}, {1,1,1,b and 0.4 or 0.2})

    if customInfoArea and IsOnRect(x, y, customInfoArea[1], customInfoArea[2], customInfoArea[3], customInfoArea[4]) then
      local tooltipTitleColor = '\255\205\255\205'
      local tooltipTextColor = '\255\255\255\255'
      local tooltipLabelTextColor = '\255\200\200\200'
      local tooltipDarkTextColor = '\255\133\133\133'
      local tooltipValueColor = '\255\255\245\175'

      -- selection grid
      if displayMode == 'selection' and selectionCells and selectionCells[1] and cellRect then
        local cellHovered
        for cellID,unitDefID in pairs(selectionCells) do
          if cellRect[cellID] and IsOnRect(x, y, cellRect[cellID][1], cellRect[cellID][2], cellRect[cellID][3], cellRect[cellID][4]) then

            local cellZoom = hoverCellZoom
            local color = {1,1,1}
            if b then
              cellZoom = clickCellZoom
              color = {0.36,0.8,0.3}
            elseif b2 then
              cellZoom = clickCellZoom
              color = {1,0.66,0.1}
            elseif b3 then
              cellZoom = rightclickCellZoom
              color = {1,0.1,0.1}
            end
            cellZoom = cellZoom + math.min(0.33 * cellZoom * ((gridHeight/cellsize)-2), 0.15) -- add extra zoom when small icons
            drawSelectionCell(cellID, selectionCells[cellID], texOffset+cellZoom)
            -- highlight
            glBlending(GL_SRC_ALPHA, GL_ONE)
            if b or b2 or b3 then
              RectRound(cellRect[cellID][1]+cellPadding, cellRect[cellID][2]+cellPadding, cellRect[cellID][3]-cellPadding, cellRect[cellID][4]-cellPadding, cellPadding*0.9, 1,1,1,1,{color[1],color[2],color[3],(b or b2 or b3) and 0.4 or 0.2}, {color[1],color[2],color[3],(b or b2 or b3) and 0.07 or 0.04})
            end
            -- gloss
            RectRound(cellRect[cellID][1]+cellPadding, cellRect[cellID][4]-cellPadding-((cellRect[cellID][4]-cellRect[cellID][2])*0.66), cellRect[cellID][3]-cellPadding, cellRect[cellID][4]-cellPadding, cellPadding*0.9, 1,1,0,0,{color[1],color[2],color[3],0}, {color[1],color[2],color[3],(b or b2 or b3) and 0.18 or 0.13})
            RectRound(cellRect[cellID][1]+cellPadding, cellRect[cellID][2]+cellPadding, cellRect[cellID][3]-cellPadding, cellRect[cellID][2]+cellPadding+((cellRect[cellID][4]-cellRect[cellID][2])*0.18), cellPadding*0.9, 0,0,1,1,{color[1],color[2],color[3],(b or b2 or b3) and 0.15 or 0.1}, {color[1],color[2],color[3],0})
            glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
            -- bottom darkening
            RectRound(cellRect[cellID][1]+cellPadding, cellRect[cellID][2]+cellPadding, cellRect[cellID][3]-cellPadding, cellRect[cellID][2]+cellPadding+((cellRect[cellID][4]-cellRect[cellID][2])*0.33), cellPadding*0.9, 0,0,1,1,{0,0,0,(b or b2 or b3) and 0.25 or 0.18}, {0,0,0,0})
            cellHovered = cellID
            break
          end
        end

        if WG['tooltip'] then
          local statsIndent = '  '
          local stats = ''
          local cells = cellHovered and {[cellHovered]=selectionCells[cellHovered]} or selectionCells
          -- description
          if cellHovered then
            local text, numLines = font:WrapText(unitTooltip[selectionCells[cellHovered]], (backgroundRect[3]-backgroundRect[1])*(loadedFontSize/16))
            stats = stats..statsIndent..tooltipTextColor..text ..'\n\n'
          end
          -- metal cost
          local totalValue = 0
          for _,unitDefID in pairs(cells) do
            if unitMetalCost[unitDefID] then
              totalValue = totalValue + (unitMetalCost[unitDefID]*selUnitsCounts[unitDefID])
            end
          end
          if totalValue > 0 then
            stats = stats..statsIndent..tooltipLabelTextColor.."metalcost: "..tooltipValueColor..totalValue.."   "
          end
          -- energy cost
          totalValue = 0
          for _,unitDefID in pairs(cells) do
            if unitEnergyCost[unitDefID] then
              totalValue = totalValue + (unitEnergyCost[unitDefID]*selUnitsCounts[unitDefID])
            end
          end
          if totalValue > 0 then
            stats = stats..tooltipLabelTextColor.."energycost: "..tooltipValueColor..totalValue.."   "
          end
          -- health
          totalValue = 0
          local totalHealth = 0
          for _,unitID in pairs(cellHovered and selUnitsSorted[selectionCells[cellHovered]] or selectedUnits) do
            local health,maxHealth,_,_,buildProgress = spGetUnitHealth(unitID)
            if health and maxHealth then
              totalValue = totalValue + maxHealth
              totalHealth = totalHealth + health
            end
          end
          totalHealth = math.floor(totalHealth)
          totalValue = math.floor(totalValue)
          if totalValue > 0 then
            local percentage = math.floor((totalHealth/totalValue)*100)
            stats = stats..'\n'..statsIndent..tooltipLabelTextColor.."health: "..tooltipValueColor..percentage.."%"..tooltipDarkTextColor.."  ( "..tooltipLabelTextColor..totalHealth..tooltipDarkTextColor..' of '..tooltipLabelTextColor..totalValue..tooltipDarkTextColor.." )"
          end
          -- DPS
          totalValue = 0
          for _,unitDefID in pairs(cells) do
            if unitDPS[unitDefID] then
              totalValue = totalValue + (unitDPS[unitDefID]*selUnitsCounts[unitDefID])
            end
          end
          if totalValue > 0 then
            stats = stats..'\n'..statsIndent..tooltipLabelTextColor.."DPS: "..tooltipValueColor..totalValue.."   "
          end
          if stats ~= '' then
            stats = '\n'..stats
            if not cellHovered then
              stats = '\n'..stats
            end
          end

          local text
          if cellHovered then
            text = tooltipTitleColor..unitHumanName[selectionCells[cellHovered]]..tooltipLabelTextColor..(selUnitsCounts[selectionCells[cellHovered]] > 1 and ' x '..tooltipTextColor..selUnitsCounts[selectionCells[cellHovered]] or '')..stats
          else
            text = tooltipTitleColor.."Selected units: "..tooltipTextColor..#selectedUnits..stats.."\n "..(stats == '' and '' or '\n')..tooltipTextColor.."Left click"..tooltipLabelTextColor..": Select\n "..tooltipTextColor.."   + CTRL"..tooltipLabelTextColor..": Select units of this type on map\n "..tooltipTextColor.."   + ALT"..tooltipLabelTextColor..": Select 1 single unit of this unit type\n "..tooltipTextColor.."Right click"..tooltipLabelTextColor..": Remove\n "..tooltipTextColor.."    + CTRL"..tooltipLabelTextColor..": Remove only 1 unit from that unit type\n "..tooltipTextColor.."Middle click"..tooltipLabelTextColor..": Move to center location\n "..tooltipTextColor.."    + CTRL"..tooltipLabelTextColor..": Move to center off whole selection"
          end
          WG['tooltip'].ShowTooltip('info', text)
        end

      else
        --glBlending(GL_SRC_ALPHA, GL_ONE)
        --RectRound(customInfoArea[1], customInfoArea[2], customInfoArea[3], customInfoArea[4], padding, 1,0,0,0,{1,1,1,b and 0.2 or 0.13}, {1,1,1,b and 0.3 or 0.2})
        --glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
        --if WG['tooltip'] then
        --WG['tooltip'].ShowTooltip('info', 'Additional unit info goes here...')
        --end
      end
    end
  end
end

function checkChanges()
  local x,y,b,b2,b3 = spGetMouseState()
  lastType = hoverType
  lastHoverData = hoverData
  hoverType, hoverData = spTraceScreenRay(x, y)
  if hoverType == 'unit' then
    if lastHoverData ~= hoverData then
      lastHoverDataClock = os_clock()
    end
  else
    lastHoverDataClock = os_clock()
  end
  prevDisplayMode = displayMode
  prevDisplayUnitDefID = displayUnitDefID
  prevDisplayUnitID = displayUnitID

  -- determine what mode to display
  displayMode = 'text'
  displayUnitID = nil
  displayUnitDefID = nil
  if WG['buildmenu'] and (WG['buildmenu'].hoverID or WG['buildmenu'].selectedID) then
    displayMode = 'unitdef'
    displayUnitDefID = WG['buildmenu'].hoverID or WG['buildmenu'].selectedID
  elseif not IsOnRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) and hoverType and hoverType == 'unit' and os_clock()-lastHoverDataClock > 0.1 then -- add small hover delay against eplilepsy
    displayMode = 'unit'
    displayUnitID = hoverData
    displayUnitDefID = spGetUnitDefID(displayUnitID)
    if lastUpdateClock+0.6 < os_clock() then -- unit stats could have changed meanwhile
      doUpdate = true
    end
  elseif SelectedUnitsCount == 1 then
    displayMode = 'unit'
    displayUnitID = selectedUnits[1]
    displayUnitDefID = spGetUnitDefID(selectedUnits[1])
    if lastUpdateClock+0.6 < os_clock() then -- unit stats could have changed meanwhile
      doUpdate = true
    end
  elseif SelectedUnitsCount > 1 then
    displayMode = 'selection'
  else -- text
    local newTooltip = spGetCurrentTooltip()
    if newTooltip ~= currentTooltip then
      currentTooltip = newTooltip
      doUpdate = true
    end
  end

  -- display changed
  if prevDisplayMode ~= displayMode or prevDisplayUnitDefID ~= displayUnitDefID or prevDisplayUnitID ~= displayUnitID then
    doUpdate = true
  end
end


function widget:SelectionChanged(sel)
  if SelectedUnitsCount ~= 0 and spGetSelectedUnitsCount() == 0 then
    doUpdate = true
    SelectedUnitsCount = 0
    selectedUnits = {}
  end
  if spGetSelectedUnitsCount() > 0 then
    SelectedUnitsCount = spGetSelectedUnitsCount()
    selectedUnits = sel
    if not doUpdateClock then
      doUpdateClock = os_clock() + 0.05  -- delay to save some performance
    end
  end
end

function widget:MousePress(x, y, button)
  if IsOnRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
    return true
  end
end


function widget:GetConfigData() --save config
  return {
    alternativeUnitpics = alternativeUnitpics,
  }
end

function widget:SetConfigData(data) --load config
  if data.alternativeUnitpics ~= nil then
    alternativeUnitpics = data.alternativeUnitpics
  end
end