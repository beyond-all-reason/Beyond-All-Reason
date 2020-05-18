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

local ui_opacity = tonumber(Spring.GetConfigFloat("ui_opacity",0.66) or 0.66)
local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale",1) or 1)
local glossMult = 1 + (2-(ui_opacity*2))	-- increase gloss/highlight so when ui is transparant, you can still make out its boundaries and make it less flat

local backgroundRect = {0,0,0,0}
local currentTooltip = ''

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
local unitMaxWeaponRange = {}
local unitHealth = {}
local unitBuildOptions = {}
local unitWeapons = {}
local unitDPS = {}
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
  unitHealth[unitDefID] = unitDef.health
  unitBuildTime[unitDefID] = unitDef.buildTime
  unitBuildPic[unitDefID] = unitDef.buildpicname
  if VFS.FileExists('unitpics/alternative/'..unitDef.name..'.png') then
    hasAlternativeUnitpic[unitDefID] = true
  end
  if unitDef.buildSpeed > 0 and unitDef.buildOptions[1] then
    isBuilder[unitDefID] = true
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
local spGetSelectedUnitsCount = Spring.GetSelectedUnitsCount
local SelectedUnitsCount = Spring.GetSelectedUnitsCount()
local selectedUnits = Spring.GetSelectedUnits()
local spTraceScreenRay = Spring.TraceScreenRay
local spGetMouseState = Spring.GetMouseState

local isSpec = Spring.GetSpectatingState()

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


function widget:Initialize()
  if Script.LuaRules('GetIconTypes') then
    iconTypesMap = Script.LuaRules.GetIconTypes()
  end
  Spring.SetDrawSelectionInfo(false) --disables springs default display of selected units count
  Spring.SendCommands("tooltip 0")
  widget:ViewResize()
--  widget:SelectionChanged()
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
    end
    if ui_opacity ~= Spring.GetConfigFloat("ui_opacity",0.66) then
      ui_opacity = Spring.GetConfigFloat("ui_opacity",0.66)
      glossMult = 1 + (2-(ui_opacity*2))
      doUpdate = true
    end
  end

  sec = sec + dt
  if sec > 0.06 then
    sec = 0
    -- reset
    currentTooltip = ''
    showUnitDefID = nil
    showUnitID = nil
    if WG['buildmenu'] and (WG['buildmenu'].hoverID or WG['buildmenu'].selectedID) then
      showUnitDefID = WG['buildmenu'].hoverID or WG['buildmenu'].selectedID
      doUpdate = true
    else
      local newTooltip = spGetCurrentTooltip()
      if newTooltip ~= currentTooltip then
        currentTooltip = newTooltip
        if SelectedUnitsCount > 0 then
          currentTooltip = "Selected units: "..SelectedUnitsCount.."\n" .. currentTooltip
        end
        doUpdate = true
      end
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

function drawInfo()
  padding = bgBorder*vsy
  RectRound(backgroundRect[1],backgroundRect[2],backgroundRect[3],backgroundRect[4], padding*1.7, 1,1,1,1,{0.05,0.05,0.05,ui_opacity}, {0,0,0,ui_opacity})
  RectRound(backgroundRect[1], backgroundRect[2]+padding, backgroundRect[3]-padding, backgroundRect[4]-padding, padding, 0,1,1,0,{0.3,0.3,0.3,ui_opacity*0.2}, {1,1,1,ui_opacity*0.2})
  -- gloss
  glBlending(GL_SRC_ALPHA, GL_ONE)
  RectRound(backgroundRect[1],backgroundRect[4]-((backgroundRect[4]-backgroundRect[2])*0.16),backgroundRect[3]-padding,backgroundRect[4]-padding, padding, 0,1,0,0, {1,1,1,0.01*glossMult}, {1,1,1,0.055*glossMult})
  RectRound(backgroundRect[1],backgroundRect[2],backgroundRect[3]-padding,backgroundRect[2]+((backgroundRect[4]-backgroundRect[2])*0.15), padding, 0,0,0,0, {1,1,1,0.02*glossMult}, {1,1,1,0})
  glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

  RectRound(backgroundRect[1],backgroundRect[4]-((backgroundRect[4]-backgroundRect[2])*0.4),backgroundRect[3]-padding,backgroundRect[4]-padding, padding, 0,1,0,0, {1,1,1,0}, {1,1,1,0.1})
  --RectRound(backgroundRect[1],backgroundRect[2],backgroundRect[3]-padding,backgroundRect[4]-((backgroundRect[4]-backgroundRect[2])*0.75), padding, 0,0,0,0, {1,1,1,0.08}, {1,1,1,0})

  local fontSize = (height*vsy * 0.11) * (1-((1-ui_scale)*0.5))
  local contentPadding = (height*vsy * 0.075) * (1-((1-ui_scale)*0.5))
  local contentWidth = backgroundRect[3]-backgroundRect[1]-contentPadding-contentPadding

  local mx, my = spGetMouseState()
  local hoverType, hoverData = spTraceScreenRay(mx, my)

  -- determine what mode to display
  displayMode = 'text'
  displayUnitID = nil
  displayUnitDefID = nil
  if WG['buildmenu'] and (WG['buildmenu'].hoverID or WG['buildmenu'].selectedID) then
    displayMode = 'unitdef'
    displayUnitDefID = WG['buildmenu'].hoverID or WG['buildmenu'].selectedID
  elseif SelectedUnitsCount > 0 then
    displayMode = 'selection'
    displayUnitDefID = Spring.GetUnitDefID(selectedUnits[1])
  elseif hoverType and hoverType == 'unit' then
    displayMode = 'unit'
    displayUnitID = hoverData
    displayUnitDefID = Spring.GetUnitDefID(displayUnitID)
  end

  if displayMode ~= 'text' and displayUnitDefID then
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

    if unitIconType[displayUnitDefID] and iconTypesMap[unitIconType[displayUnitDefID]] then
      local radarIconSize = iconSize * 0.3
      local radarIconMargin = radarIconSize * 0.3
      glColor(1,1,1,0.88)
      glTexture(':lr64,64:'..iconTypesMap[unitIconType[displayUnitDefID]])
      glTexRect(backgroundRect[3]-radarIconMargin-radarIconSize, backgroundRect[4]-radarIconMargin-radarIconSize, backgroundRect[3]-radarIconMargin, backgroundRect[4]-radarIconMargin)
      glTexture(false)
      glColor(1,1,1,1)
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
    local height = (backgroundRect[4]-backgroundRect[2]-padding) * 0.45
    unitCustomInfoArea = {backgroundRect[3]-width-padding, backgroundRect[2]+padding, backgroundRect[3]-padding, backgroundRect[2]+height+padding}
    RectRound(unitCustomInfoArea[1], unitCustomInfoArea[2], unitCustomInfoArea[3], unitCustomInfoArea[4], padding, 1,0,0,0,{1,1,1,0.04}, {1,1,1,0.12})

    -- draw unit buildoption icons
    if displayMode == 'unitdef' and unitBuildOptions[displayUnitDefID] then
      local rows = 2
      local colls = math.ceil(#unitBuildOptions[displayUnitDefID] / rows)
      local cellsize = math.min(width/colls, height/rows)
      if cellsize < height/3 then
        rows = 3
        colls = math.ceil(#unitBuildOptions[displayUnitDefID] / rows)
        cellsize = math.min(width/colls, height/rows)
      end
      -- draw grid (bottom right to top left)
      glColor(0.88,0.88,0.88,1)
      local cellID = #unitBuildOptions[displayUnitDefID]
      local cellPadding = cellsize * 0.033
      local cellRect = {}
      for row=1, rows do
        for coll=1, colls do
          if unitBuildOptions[displayUnitDefID][cellID] then
            local uDefID = unitBuildOptions[displayUnitDefID][cellID]
            cellRect[cellID] = {unitCustomInfoArea[3]-(coll*cellsize), unitCustomInfoArea[2]+((row-1)*cellsize), unitCustomInfoArea[3]-((coll-1)*cellsize), unitCustomInfoArea[2]+((row)*cellsize)}
            glTexture(":lr64,64:unitpics/"..((alternativeUnitpics and hasAlternativeUnitpic[uDefID]) and 'alternative/' or '')..unitBuildPic[uDefID])
            --glTexRect(cellRect[cellID][1]+cellPadding, cellRect[cellID][2]+cellPadding, cellRect[cellID][3]-cellPadding, cellRect[cellID][4]-cellPadding)
            DrawRect(cellRect[cellID][1]+cellPadding, cellRect[cellID][2]+cellPadding, cellRect[cellID][3]-cellPadding, cellRect[cellID][4]-cellPadding,0.06)
          end
          cellID = cellID - 1
          if cellID <= 0 then break end
        end
        if cellID <= 0 then break end
      end
      glTexture(false)
      glColor(1,1,1,1)
    else

      local contentPaddingLeft = unitCustomInfoArea[1] + (contentPadding)
      local labelColor = '\255\166\166\166'
      local valueColor = '\255\245\245\245'
      -- dps
      if unitDPS[displayUnitDefID] then
        font2:Begin()
        font2:Print(labelColor..'dps '..valueColor..unitDPS[displayUnitDefID], backgroundRect[1]+contentPaddingLeft, backgroundRect[4]-contentPadding-iconSize-(fontSize*0.6), fontSize, "o")
        font2:End()
      end
      -- energy
      --font2:Print(energyColor..unitEnergyCost[displayUnitDefID], backgroundRect[1]+contentPaddingLeft, backgroundRect[4]-contentPadding-iconSize-(fontSize*1.85), fontSize, "o")
      -- health
      --font2:Print(healthColor..unitHealth[displayUnitDefID], backgroundRect[1]+contentPaddingLeft, backgroundRect[4]-contentPadding-iconSize-(fontSize*3.1), fontSize, "o")

    end

  else

    -- plain text tooltip
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


-- load all icons to prevent briefly showing white unit icons
function cacheUnitIcons()
  if not cached then
    cached = true
    gl.Color(1,1,1,0.001)
    for id, unit in pairs(UnitDefs) do
      if hasAlternativeUnitpic[id] then
        gl.Texture(':lr128,128:unitpics/alternative/'..unitBuildPic[id])
      else
        gl.Texture(':lr128,128:unitpics/'..unitBuildPic[id])
      end
      gl.TexRect(-1,-1,0,0)
      gl.Texture(':lr64,64:unitpics/'..unitBuildPic[id])
      gl.TexRect(-1,-1,0,0)
      gl.Texture(false)
    end
    gl.Color(1,1,1,1)
  end
end


function widget:DrawScreen()
  if chobbyInterface then return end

  local x,y,b = Spring.GetMouseState()

  if (displayUnitID or displayUnitDefID) and  IsOnRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
    Spring.SetMouseCursor('cursornormal')

    RectRound(backgroundRect[1],backgroundRect[2],backgroundRect[3]-padding,backgroundRect[4]-padding, padding, 0,1,0,0, {1,1,1,b and 0.4 or 0.25}, {1,1,1,b and 0.12 or 0.06})
    RectRound(backgroundRect[1],backgroundRect[4]-((backgroundRect[4]-backgroundRect[2])*0.25),backgroundRect[3]-padding,backgroundRect[4]-padding, padding, 0,1,0,0, {1,1,1,0}, {1,1,1,b and 0.3 or 0.15})
    RectRound(backgroundRect[1],backgroundRect[4]-((backgroundRect[4]-backgroundRect[2])*0.16),backgroundRect[3]-padding,backgroundRect[4]-padding, padding, 0,1,0,0, {1,1,1,b and 0.2 or 0.1}, {1,1,1,b and 0.4 or 0.2})

    -- add tooltip
    if WG['tooltip'] then
      if unitCustomInfoArea and IsOnRect(x, y, unitCustomInfoArea[1], unitCustomInfoArea[2], unitCustomInfoArea[3], unitCustomInfoArea[4]) then

        glBlending(GL_SRC_ALPHA, GL_ONE)
        RectRound(unitCustomInfoArea[1], unitCustomInfoArea[2], unitCustomInfoArea[3], unitCustomInfoArea[4], padding, 1,0,0,0,{1,1,1,b and 0.2 or 0.13}, {1,1,1,b and 0.3 or 0.2})
        glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

        WG['tooltip'].ShowTooltip('info', 'Additional unit info goes here...')
      end
    end
  end

  if doUpdate then
    cacheUnitIcons()
    clear()
    doUpdate = nil
  end

  if not dlistInfo then
    dlistInfo = gl.CreateList( function()
      drawInfo()
    end)
  end
  gl.CallList(dlistInfo)
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
    doUpdate = true
  end
end

function widget:MousePress(x, y, button)
  if IsOnRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
    return true
  end
end
