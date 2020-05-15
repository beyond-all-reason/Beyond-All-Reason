function widget:GetInfo()
  return {
    name      = "Factionpicker",
    desc      = "",
    author    = "Floris",
    date      = "May 2020",
    license   = "GNU GPL, v2 or later",
    layer     = -1,
    enabled   = true
  }
end


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
local factions = {
  {UnitDefNames.corcom.id, 'CORE', 'unitpics/alternative/corcom.png' },
  {UnitDefNames.armcom.id, 'ARM', 'unitpics/alternative/armcom.png'},
}
local altPosition = false
local playSounds = true
local posY = 0.75
local posX = 0
local width = 0
local height = 0
local bgBorderOrg = 0.003
local bgBorder = bgBorderOrg
local bgMargin = 0.005

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local factionRect = {}
for i, faction in pairs(factions) do
  factionRect[i] = {}
end

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

local sound_button = 'LuaUI/Sounds/buildbar_waypoint.wav'

local ui_opacity = tonumber(Spring.GetConfigFloat("ui_opacity",0.66) or 0.66)
local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale",1) or 1)

local backgroundRect = {}
local lastUpdate = os.clock()-1

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local os_clock = os.clock

local GL_QUADS = GL.QUADS
local GL_TRIANGLE_FAN = GL.TRIANGLE_FAN
local glBeginEnd = gl.BeginEnd
local glTexture = gl.Texture
local glTexRect = gl.TexRect
local glColor = gl.Color
local glRect = gl.Rect
local glVertex = gl.Vertex
local glDepthTest = gl.DepthTest
local glBlending = gl.Blending
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_ONE = GL.ONE

local mCos = math.cos
local mSin = math.sin
local math_min = math.min

local isSpec = Spring.GetSpectatingState()

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
      WG['guishader'].InsertDlist(dlistGuishader, 'factionpicker')
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

  if altPosition then
    posY = height
    posX = width + 0.003
  else
    posY = 0.75
    posX = 0
  end

  backgroundRect = {posX*vsx, (posY-height)*vsy, (posX+width)*vsx, posY*vsy}
  activeRect = {(posX*vsx)+(bgMargin*vsy), ((posY-height)+bgMargin)*vsy, ((posX+width)*vsx)-(bgMargin*vsy), (posY-bgMargin)*vsy}

  dlistFactionpicker = gl.DeleteList(dlistFactionpicker)

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
  if isSpec or Spring.GetGameFrame() > 0 then
    widgetHandler:RemoveWidget(self)
    return
  end

  if WG['minimap'] then
    altPosition = WG['minimap'].getEnlarged()
  end

  widget:ViewResize()
end

function widget:Shutdown()
  if WG['guishader'] and dlistGuishader then
    WG['guishader'].DeleteDlist('factionpicker')
    dlistGuishader = nil
  end
  dlistFactionpicker = gl.DeleteList(dlistFactionpicker)
  gl.DeleteFont(font)
  gl.DeleteFont(font2)
end


function widget:GameFrame(n)
    widgetHandler:RemoveWidget(self)
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
      doUpdate = true
    end
    if ui_opacity ~= Spring.GetConfigFloat("ui_opacity",0.66) then
      ui_opacity = Spring.GetConfigFloat("ui_opacity",0.66)
      doUpdate = true
    end
    if WG['minimap'] and altPosition ~= WG['minimap'].getEnlarged() then
      altPosition = WG['minimap'].getEnlarged()
      widget:ViewResize()
      doUpdate = true
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

function drawFactionpicker()
  -- background
  local padding = bgBorder*vsy
  RectRound(backgroundRect[1],backgroundRect[2],backgroundRect[3],backgroundRect[4], padding*1.7, 1,1,1,1,{0.05,0.05,0.05,ui_opacity}, {0,0,0,ui_opacity})
  RectRound(backgroundRect[1]+(altPosition and padding or 0), backgroundRect[2]+padding, backgroundRect[3]-padding, backgroundRect[4]-padding, padding, (altPosition and 1 or 0),1,1,0,{0.3,0.3,0.3,ui_opacity*0.2}, {1,1,1,ui_opacity*0.2})

  armcomRect = backgroundRect
  corcomRect = backgroundRect

  padding = (bgBorder*vsy) * 0.35

  font2:Begin()

  padding = (bgBorder*vsy) * 0.4
  local fontSize = (height*vsy * 0.125) * (1-((1-ui_scale)*0.5))
  local contentPadding = (height*vsy * 0.075) * (1-((1-ui_scale)*0.5))
  local contentWidth = backgroundRect[3]-backgroundRect[1]-contentPadding-contentPadding
  local contentHeight = backgroundRect[4]-backgroundRect[2]-contentPadding-contentPadding
  font2:Print("Pick your faction", backgroundRect[1]+contentPadding, backgroundRect[4]-contentPadding-(fontSize*0.8), fontSize, "o")

  local maxCellHeight = contentHeight-(fontSize*1.1)
  local maxCellWidth = contentWidth/#factions
  local cellSize = math.min(maxCellHeight, maxCellWidth)

  local rectMargin = padding * 0.8
  for i, faction in pairs(factions) do
    factionRect[i] = {
      backgroundRect[3]-(altPosition and padding or 0)-(cellSize*i),
      backgroundRect[2]+padding,
      backgroundRect[3]-padding-(cellSize*(i-1)),
      backgroundRect[2]+padding+cellSize
    }
    -- background
    local color1, color2
    if WG['guishader'] then
      color1 = {0.6,0.6,0.6,0.6}
      color2 = {0.8,0.8,0.8,0.6}
    else
      color1 = {0.33,0.33,0.33,0.95}
      color2 = {0.55,0.55,0.55,0.95}
    end
    RectRound(factionRect[i][1]+rectMargin, factionRect[i][2]+rectMargin, factionRect[i][3]-rectMargin, factionRect[i][4]-rectMargin, rectMargin, 1,1,1,1, color1, color2)
    -- gloss
    RectRound(factionRect[i][1]+rectMargin, factionRect[i][4]-((factionRect[i][4]-factionRect[i][2])*0.5), factionRect[i][3]-rectMargin, factionRect[i][4]-rectMargin, rectMargin, 1,1,0,0, {1,1,1,0.06}, {1,1,1,0.3})
    RectRound(factionRect[i][1]+rectMargin, factionRect[i][2]-rectMargin, factionRect[i][3]-rectMargin, factionRect[i][2]+((factionRect[i][4]-factionRect[i][2])*0.22), rectMargin, 0,0,1,1, {1,1,1,0.22}, {1,1,1,0})

    -- startunit icon
    glColor(1,1,1,1)
    glTexture(factions[i][3])
    glTexRect(factionRect[i][1]+rectMargin, factionRect[i][2]+rectMargin, factionRect[i][3]-rectMargin, factionRect[i][4]-rectMargin)
    glTexture(false)

    -- faction name
    font2:Print(factions[i][2], factionRect[i][1]+((factionRect[i][3]-factionRect[i][1])*0.5), factionRect[i][2]+((factionRect[i][4]-factionRect[i][2])*0.22)-(fontSize*0.5), fontSize*0.92, "co")

  end
  font2:End()
end

function widget:RecvLuaMsg(msg, playerID)
  if msg:sub(1,18) == 'LobbyOverlayActive' then
    chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
  end
end


function widget:DrawScreen()
  if chobbyInterface then return end

  local x,y,b = Spring.GetMouseState()
  if not WG['topbar'] or not WG['topbar'].showingQuit() then
    if IsOnRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
      Spring.SetMouseCursor('cursornormal')
    end
  end

  if doUpdate then
    lastUpdate = os_clock()
  end

  if dlistGuishader and WG['guishader'] then
    WG['guishader'].InsertDlist(dlistGuishader, 'factionpicker')
  end
  if doUpdate then
    dlistFactionpicker = gl.DeleteList(dlistFactionpicker)
  end
  if not dlistFactionpicker then
    dlistFactionpicker = gl.CreateList( function()
      drawFactionpicker()
    end)
  end
  gl.CallList(dlistFactionpicker)

  -- highlight
  local rectMargin = 0
  if IsOnRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
    for i, faction in pairs(factions) do
      if IsOnRect(x, y, factionRect[i][1], factionRect[i][2], factionRect[i][3], factionRect[i][4]) then
        glBlending(GL_SRC_ALPHA, GL_ONE)
        RectRound(factionRect[i][1]+rectMargin, factionRect[i][2]+rectMargin, factionRect[i][3]-rectMargin, factionRect[i][4]-rectMargin, bgBorder*vsy, 1,1,1,1,{0.3,0.3,0.3,(b and 0.5 or 0.25)}, {1,1,1,(b and 0.3 or 0.15)})
        glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
        break
      end
    end
  end

  doUpdate = nil
end


function widget:MousePress(x, y, button)
  if IsOnRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then

    for i, faction in pairs(factions) do
      if IsOnRect(x, y, factionRect[i][1], factionRect[i][2], factionRect[i][3], factionRect[i][4]) then
        if playSounds then
          Spring.PlaySoundFile(sound_button, 0.6, 'ui')
        end
        if WG["buildmenu"] then
          WG["buildmenu"].factionChange(factions[i][1])
        end
        -- tell initial spawn
        Spring.SendLuaRulesMsg('\138' .. tostring(factions[i][1]))
        break
      end
    end
    return true
  end
end