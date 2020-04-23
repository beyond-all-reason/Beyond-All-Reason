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

local bgcorner = ":l:LuaUI/Images/bgcorner.png"
local barGlowCenterTexture = ":l:LuaUI/Images/barglow-center.png"
local barGlowEdgeTexture   = ":l:LuaUI/Images/barglow-edge.png"

local ui_opacity = tonumber(Spring.GetConfigFloat("ui_opacity",0.66) or 0.66)
local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale",1) or 1)

local backgroundRect = {0,0,0,0}
local currentTooltip = ''

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local spGetCurrentTooltip = Spring.GetCurrentTooltip

local spGetSelectedUnitsCount = Spring.GetSelectedUnitsCount
local SelectedUnitsCount = spGetSelectedUnitsCount()

local isSpec = Spring.GetSpectatingState()

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local function checkGuishader()
  if WG['guishader'] then
    if not dlistGuishader then
      dlistGuishader = gl.CreateList( function()
        RectRound(backgroundRect[1],backgroundRect[2],backgroundRect[3],backgroundRect[4], (bgBorder*vsy)*2)
      end)
      WG['guishader'].InsertDlist(dlistGuishader, 'info')
    end
  else
    if dlistGuishader then
      dlistGuishader = gl.DeleteList(dlistGuishader)
    end
  end
end

function widget:PlayerChanged(playerID)
  isSpec = Spring.GetSpectatingState()
end

function widget:ViewResize()
  width = 0.23
  height = 0.14
  width = width / (vsx/vsy) * 1.78		-- make smaller for ultrawide screens
  width = width * ui_scale

  backgroundRect = {0, 0, width*vsx, height*vsy}

  checkGuishader()

  doUpdate = true
  clear()

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
  if WG['guishader'] then
    dlistGuishader = WG['guishader'].DeleteDlist('info')
  end
end

local uiOpacitySec = 0
local sec = 0
function widget:Update(dt)
  uiOpacitySec = uiOpacitySec + dt
  if uiOpacitySec > 0.5 then
    uiOpacitySec = 0
    checkGuishader()
    --if ui_scale ~= Spring.GetConfigFloat("ui_scale",1) then
    --  ui_scale = Spring.GetConfigFloat("ui_scale",1)
    --  widget:ViewResize()
    --end
    if ui_opacity ~= Spring.GetConfigFloat("ui_opacity",0.66) then
      ui_opacity = Spring.GetConfigFloat("ui_opacity",0.66)
      doUpdate = true
    end
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

function IsOnRect(x, y, BLcornerX, BLcornerY,TRcornerX,TRcornerY)
  return x >= BLcornerX and x <= TRcornerX and y >= BLcornerY and y <= TRcornerY
end

function drawInfo()
  local padding = bgBorder*vsy
  RectRound(backgroundRect[1],backgroundRect[2],backgroundRect[3],backgroundRect[4], padding*1.7, 1,1,1,1,{0.05,0.05,0.05,ui_opacity}, {0,0,0,ui_opacity})
  RectRound(backgroundRect[1], backgroundRect[2]+padding, backgroundRect[3]-padding, backgroundRect[4]-padding, padding, 0,1,1,0,{0.3,0.3,0.3,ui_opacity*0.2}, {1,1,1,ui_opacity*0.2})

  padding = (bgBorder*vsy) * 0.4
  local fontSize = (height*vsy * 0.11) * (1-((1-ui_scale)*0.5))
  local contentPadding = (height*vsy * 0.075) * (1-((1-ui_scale)*0.5))
  local contentWidth = backgroundRect[3]-backgroundRect[1]-contentPadding-contentPadding
  font:Begin()
  local text, numLines = font:WrapText(currentTooltip, contentWidth*(loadedFontSize/fontSize))
  if SelectedUnitsCount > 0 then
    text = "Selected units: "..SelectedUnitsCount.."\n" .. text
  end
  font:Print(text, backgroundRect[1]+contentPadding, backgroundRect[4]-contentPadding-(fontSize*0.8), fontSize, "o")
  font:End()
end


function widget:DrawScreen()

  local x,y,b = Spring.GetMouseState()

  --if IsOnRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
  --  Spring.SetMouseCursor('cursornormal')
  --end

  if doUpdate then
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
  if SelectedUnitsCount ~= spGetSelectedUnitsCount() then
    doUpdate = true
    SelectedUnitsCount = spGetSelectedUnitsCount()
  end
end