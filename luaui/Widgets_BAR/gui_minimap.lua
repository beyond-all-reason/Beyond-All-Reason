function widget:GetInfo()
  return {
    name      = "Minimap",
    desc      = "",
    author    = "Floris",
    date      = "April 2020",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true,
  }
end


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local vsx,vsy = Spring.GetViewGeometry()

local enlarged = false

local maxWidth = 0.275 * (vsx/vsy)  -- NOTE: changes in widget:ViewResize()
local maxHeight = 0.243  -- NOTE: changes in widget:ViewResize()
maxWidth = math.min(maxHeight*(Game.mapX/Game.mapY), maxWidth)

local bgBorderOrg = 0.0025
local bgBorder = bgBorderOrg
local bgMargin = 0.005

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local ui_opacity = tonumber(Spring.GetConfigFloat("ui_opacity",0.66) or 0.66)
local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale",1) or 1)

local backgroundRect = {0,0,0,0}
local currentTooltip = ''

local spGetMiniMapGeometry = Spring.GetMiniMapGeometry
local spGetCameraState = Spring.GetCameraState

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local function checkGuishader(force)
  if WG['guishader'] then
    if force and dlistGuishader then
      dlistGuishader = gl.DeleteList(dlistGuishader)
    end
    if not dlistGuishader then
      dlistGuishader = gl.CreateList( function()
        local padding = bgBorder*vsy
        RectRound(backgroundRect[1],backgroundRect[2]-padding,backgroundRect[3]+padding,backgroundRect[4], (bgBorder*vsy)*2)
      end)
      WG['guishader'].InsertDlist(dlistGuishader, 'minimap')
    end
  elseif dlistGuishader then
    dlistGuishader = gl.DeleteList(dlistGuishader)
  end
end

function widget:ViewResize()
  vsx,vsy = Spring.GetViewGeometry()
  if enlarged then
    maxWidth = 0.275 * (vsx/vsy)
    maxHeight = 0.3865
  else
    maxWidth = 0.275 * (vsx/vsy)
    maxHeight = 0.243
  end
  maxWidth = math.min(maxHeight*(Game.mapX/Game.mapY), maxWidth)

  Spring.SendCommands(string.format("minimap geometry %i %i %i %i",  0, 0, maxWidth*vsy, maxHeight*vsy))

  backgroundRect = {0, vsy-(maxHeight*vsy), maxWidth*vsy, vsy}

  checkGuishader(true)

  clear()
end

function widget:Initialize()
  oldMinimapGeometry = spGetMiniMapGeometry()
  gl.SlaveMiniMap(true)

  widget:ViewResize()

  WG['minimap'] = {}
    WG['minimap'].getEnlarged = function()
        return enlarged
    end
    WG['minimap'].setEnlarged = function(value)
        enlarged = value
        widget:ViewResize()
    end
end

function widget:GameStart()
    widget:ViewResize()
end

function clear()
  dlistMinimap = gl.DeleteList(dlistMinimap)
end

function widget:Shutdown()
  clear()
  if WG['guishader'] and dlistGuishader then
    WG['guishader'].DeleteDlist('minimap')
    dlistGuishader = nil
  end

  gl.SlaveMiniMap(false)
  Spring.SendCommands("minimap geometry "..oldMinimapGeometry)
end

local uiOpacitySec = 0
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
      clear()
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

function drawMinimap()
  local padding = bgBorder*vsy
  RectRound(backgroundRect[1],backgroundRect[2]-padding,backgroundRect[3]+padding,backgroundRect[4], padding*1.7, 0,0,1,0,{0.05,0.05,0.05,ui_opacity}, {0,0,0,ui_opacity})
  --RectRound(backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4], padding*1, 0,1,1,0,{0.3,0.3,0.3,ui_opacity*0.2}, {1,1,1,ui_opacity*0.2})
end


function widget:DrawScreen()
  --local x,y,b = Spring.GetMouseState()
  --if IsOnRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
  --  Spring.SetMouseCursor('cursornormal')
  --end

  local st = spGetCameraState()
  if st.name == "ov" then -- overview camera
    if dlistGuishader and WG['guishader'] then
      WG['guishader'].RemoveDlist('minimap')
    end
  else
    if dlistGuishader and WG['guishader'] then
      WG['guishader'].InsertDlist(dlistGuishader, 'minimap')
    end
    if not dlistMinimap then
      dlistMinimap = gl.CreateList( function()
        drawMinimap()
      end)
    end
    gl.CallList(dlistMinimap)
  end

  --gl.ResetState()
  --gl.ResetMatrices()
  gl.DrawMiniMap()
  --gl.ResetState()
  --gl.ResetMatrices()
end


function widget:GetConfigData() --save config
    return {
        enlarged = enlarged
    }
end

function widget:SetConfigData(data) --load config
    if data.enlarged ~= nil then
        enlarged = data.enlarged
    end
end

