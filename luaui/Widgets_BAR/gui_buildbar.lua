-- $Id$

function widget:GetInfo()
  return {
    name      = "BuildBar",
    desc      = "An extended BuildMenu to access the BuildOptions of factories\neverywhere on the map without selecting them before",
    author    = "jK",
    date      = "Jul 11, 2007",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local WhiteStr   = "\255\255\255\255"
local GreyStr    = "\255\210\210\210"
local GreenStr   = "\255\092\255\092"
local BlueStr    = "\255\170\170\255"
local YellowStr  = "\255\255\255\152"
local OrangeStr  = "\255\255\190\128"

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--
--  vars
--

-- saved values
local bar_side         = 1     --left:0,top:2,right:1,bottom:3
local bar_horizontal   = false --(not saved) if sides==top v bottom -> horizontal:=true  else-> horizontal:=false
local bar_offset       = 0     --relative offset side middle (i.e., bar_pos := vsx*0.5+bar_offset)
local bar_align        = 1     --aligns icons to bar_pos: center=0; left/top=+1; right/bottom=-1
local bar_iconSizeBase = 28    --iconSize o_O
local bar_openByClick  = false --needs a click to open the buildmenu or is a hover enough?
local bar_autoclose    = true  --autoclose buildmenu on mouseleave?

-- list and interface vars
local facs = {}
local unfinished_facs = {}
local menuHovered = false --opened a buildlist by hover? (if true-> close the menu on mouseleave)
local openedMenu  = -1
local hoveredFac  = -1
local hoveredBOpt = -1
local pressedFac  = -1
local pressedBOpt = -1
local waypointFac = -1
local waypointMode = 0   -- 0 = off; 1=lazy; 2=greedy (greedy means: you have to left click once before leaving waypoint mode and you can have units selected)

local dlists = {}

-- factory icon rectangle
local facRect  = {-1,-1,-1,-1}

-- build options rectangle
local boptRect = {-1,-1,-1,-1}

-- the following vars make it very easy to use the same code to render the menus, whatever side they are
-- cause we simple take topleft_startcorner and add recursivly *_inext to it to access they next icon pos
local fac_inext  = {0,0}
local bopt_inext = {0,0}

local myTeamID = 0
local inTweak  = 0
local oldUnitpics = false

-- a nice blur shader
local useBlurShader   = false   -- it has a fallback, if the gfx don't support glsl
local blured          = false
local blurFullscreen  = function() return end

local bgcorner		= "LuaUI/Images/bgcorner.png"
local repeatPic		= ":n:LuaUI/Images/repeat.png"

local GL_ONE                   = GL.ONE
local GL_ONE_MINUS_SRC_ALPHA   = GL.ONE_MINUS_SRC_ALPHA
local GL_SRC_ALPHA             = GL.SRC_ALPHA
local glBlending               = gl.Blending

-------------------------------------------------------------------------------
-- SOUNDS
-------------------------------------------------------------------------------

local sound_waypoint  = 'LuaUI/Sounds/buildbar_waypoint.wav'
local sound_click     = 'LuaUI/Sounds/buildbar_click.wav'
local sound_hover     = 'LuaUI/Sounds/buildbar_hover.wav'
local sound_queue_add = 'LuaUI/Sounds/buildbar_add.wav'
local sound_queue_rem = 'LuaUI/Sounds/buildbar_rem.wav'

-------------------------------------------------------------------------------
-- SOME THINGS NEEDED IN DRAWINMINIMAP
-------------------------------------------------------------------------------

local startTimer = Spring.GetTimer()
local msx = Game.mapX * 512
local msz = Game.mapY * 512

local teamColors = {}
local GetTeamColor = Spring.GetTeamColor or function (teamID)
  local color = teamColors[teamID]
  if (color) then return unpack(color) end
  local _,_,_,_,_,_,r,g,b = Spring.GetTeamInfo(teamID)
  teamColors[teamID] = {r,g,b}
  return r,g,b
end

-------------------------------------------------------------------------------
-- SCREENSIZE FUNCTIONS
-------------------------------------------------------------------------------
local iconSizeX  = 70
local iconSizeY  = math.floor(iconSizeX * 0.92)
local iconImgMult= 0.66
local repIcoSize = math.floor(iconSizeY*0.6)   --repeat iconsize
local fontSize   = iconSizeY * 0.31
local borderSize = 1.5
local maxVisibleBuilds = 3
local vsx, vsy   = widgetHandler:GetViewSizes()


local function SetupNewScreenAlignment()
  bar_horizontal = (bar_side>1)
  if bar_side==0 then      -- left
    fac_inext  = {0,-iconSizeY}
    bopt_inext = {iconSizeX,0}
  elseif bar_side==2 then  -- top
    fac_inext  = {iconSizeX,0}
    bopt_inext = {0,-iconSizeY}
  elseif bar_side==1 then  -- right
    fac_inext  = {0,-iconSizeY}
    bopt_inext = {-iconSizeX,0}
  else --bar_side==3       -- bottom
    fac_inext  = {iconSizeX,0}
    bopt_inext = {0,iconSizeY}
  end
end


local function UpdateIconSizes()
  iconSizeX = math.floor(bar_iconSizeBase+((vsx-800)/35))
  iconSizeY = math.floor(iconSizeX * 0.95)
  fontSize  = iconSizeY * 0.31
  repIcoSize = math.floor(iconSizeY*0.4)
end


function widget:ViewResize(viewSizeX, viewSizeY)
  vsx = viewSizeX
  vsy = viewSizeY

  UpdateIconSizes()
  SetupNewScreenAlignment()
end


-------------------------------------------------------------------------------
-- Speed Up
-------------------------------------------------------------------------------
local GetUnitDefID      = Spring.GetUnitDefID
local GetMouseState     = Spring.GetMouseState
local GetUnitHealth     = Spring.GetUnitHealth
local GetUnitStates     = Spring.GetUnitStates
local DrawUnitCommands  = Spring.DrawUnitCommands
local GetSelectedUnits  = Spring.GetSelectedUnits
local GetFullBuildQueue = Spring.GetFullBuildQueue
local GetUnitIsBuilding = Spring.GetUnitIsBuilding
local glText      = gl.Text
local glRect      = gl.Rect
local glShape     = gl.Shape
local glColor     = gl.Color
local glTexture   = gl.Texture
local glTexRect   = gl.TexRect
local glLineWidth = gl.LineWidth
local tan         = math.tan

-------------------------------------------------------------------------------
-- INITIALIZTION FUNCTIONS
-------------------------------------------------------------------------------
function widget:Initialize()
 -- blurFullscreen = ((useBlurShader)and(WG['blur_api'])and(WG['blur_api'].Fullscreen))
 -- if (useBlurShader)and(blurFullscreen==nil) then
 --   Spring.Echo('BuildBar Warning: you deactivated the "blurApi" widget, please reactivate it.')
 -- end
--  blurFullscreen = (blurFullscreen)or(function() return end)

  myTeamID = Spring.GetMyTeamID()

  UpdateFactoryList()
  
  local viewSizeX, viewSizeY = widgetHandler:GetViewSizes()
  self:ViewResize(viewSizeX, viewSizeY)

  if Spring.GetGameFrame() > 0 and Spring.GetSpectatingState() then
	widgetHandler:RemoveWidget(self)
  end

  WG['buildbar'] = {}
  WG['buildbar'].getOldUnitIcons = function()
    return oldUnitpics
  end
  WG['buildbar'].setOldUnitIcons = function(value)
    oldUnitpics = value
  end
end

function widget:Shutdown()
  for i=1, #dlists do
    gl.DeleteList(dlists[i])
  end
  dlists = {}
end

function widget:GetConfigData()
  return {
    side         = bar_side,
    offset       = bar_offset,
    align        = bar_align,
    iconSizeBase = bar_iconSizeBase,
    openByClick  = bar_openByClick,
    autoclose    = bar_autoclose,
    oldUnitpics  = oldUnitpics,
   -- useBlurShader= useBlurShader
  }
end

function widget:SetConfigData(data)
  -- geometric
  bar_side         = data.side         or 2
  bar_offset       = data.offset       or 0
  bar_align        = data.align        or 0
  bar_iconSizeBase = data.iconSizeBase or 28
  bar_openByClick  = data.openByClick  or false
  bar_autoclose    = data.autoclose    or (not bar_openByClick)

  bar_side         = math.min( math.max(bar_side, 0), 3)
  bar_align        = math.min( math.max(bar_align,-1) ,1)
  --SetupNewScreenAlignment()
  if data.oldUnitpics ~= nil then
    oldUnitpics = data.oldUnitpics
  end
  -- shader
  --useBlurShader    = data.useBlurShader or true
end



-------------------------------------------------------------------------------
-- RECTANGLE FUNCTIONS
-------------------------------------------------------------------------------

local function OffsetRect(rect,x_offset,y_offset)
  rect[3], rect[1] = rect[3] + x_offset, rect[1] + x_offset
  rect[2], rect[4] = rect[2] + y_offset, rect[4] + y_offset
end

local function RectWH(left,top,width,height)
  local rect = {left,top}
  rect[3] = rect[1] + width
  rect[4] = rect[2] - height
  return rect
end

local function GetFacIconRect(i)
  local xmin = facRect[1]+ i*fac_inext[1]
  local ymax = facRect[2]+ i*fac_inext[2]
  return xmin,ymax, xmin+iconSizeX,ymax-iconSizeY
end


local function IsInRect(left,top, rect)
  return (left >= rect[1]) and(left <= rect[3])and
         ( top <= rect[2]) and( top >= rect[4])
end



-------------------------------------------------------------------------------
-- DRAW FUNCTIONS
-------------------------------------------------------------------------------
local function DrawRect(rect, color)
  glColor(color)
  --glRect(rect[1],rect[2],rect[3],rect[4])
  RectRound(rect[1],rect[4],rect[3],rect[2],(rect[3]-rect[1])/9)
  glColor(1,1,1,1)
end

function RectRound(px,py,sx,sy,cs)
	
	local px,py,sx,sy,cs = math.floor(px),math.floor(py),math.floor(sx),math.floor(sy),math.floor(cs)
	
	gl.Rect(px+cs, py, sx-cs, sy)
	gl.Rect(sx-cs, py+cs, sx, sy-cs)
	gl.Rect(px+cs, py+cs, px, sy-cs)
	
	gl.Texture(bgcorner)
	
	--if py <= 0 or px <= 0 then gl.Texture(false) else gl.Texture(bgcorner) end
	gl.TexRect(px, py+cs, px+cs, py)		-- top left
	
	--if py <= 0 or sx >= vsx then gl.Texture(false) else gl.Texture(bgcorner) end
	gl.TexRect(sx, py+cs, sx-cs, py)		-- top right
	
	--if sy >= vsy or px <= 0 then gl.Texture(false) else gl.Texture(bgcorner) end
	gl.TexRect(px, sy-cs, px+cs, sy)		-- bottom left
	
	--if sy >= vsy or sx >= vsx then gl.Texture(false) else gl.Texture(bgcorner) end
	gl.TexRect(sx, sy-cs, sx-cs, sy)		-- bottom right
	
	gl.Texture(false)
end

local function DrawLineRect(rect, color, width)
  glColor(color)
  glLineWidth(width or borderSize)
  glShape(GL.LINE_LOOP, {
    { v = { rect[3]+0.5 , rect[2]+0.5 } }, { v = { rect[1]+0.5 , rect[2]+0.5 } },
    { v = { rect[1]+0.5 , rect[4]+0.5 } }, { v = { rect[3]+0.5 , rect[4]+0.5 } },
  })
  glLineWidth(1)
  glColor(1,1,1,1)
end

local function DrawTexRect(rect, texture, color)
  if color ~= nil then
    glColor(color)
  else
    glColor(1,1,1,1)
  end
  glTexture(texture)
  glTexRect(rect[1],rect[4],rect[3],rect[2])
  glColor(1,1,1,1)
  glTexture(false)
end

local function DrawBuildProgress(left,top,right,bottom, progress, color)
  glColor(color)
  local xcen = (left+right)/2
  local ycen = (top+bottom)/2

  local alpha = 360*(progress)
  local alpha_rad = math.rad(alpha)
  local beta_rad  = math.pi/2 - alpha_rad
  local list = {}

  list[#list+1] = {v = { xcen,  ycen }}
  list[#list+1] = {v = { xcen,  top }}

  local x,y
  x = (top-ycen)*tan(alpha_rad) + xcen
  if (alpha<90)and(x<right) then
    list[#list+1] = {v = { x,  top }}
  else
    list[#list+1] = {v = { right,  top }}
    y = (right-xcen)*tan(beta_rad) + ycen
    if (alpha<180)and(y>bottom) then
      list[#list+1] = {v = { right,  y }}
    else
      list[#list+1] = {v = { right,  bottom }}
      x = (top-ycen)*tan(-alpha_rad) + xcen
      if (alpha<270)and(x>left) then
        list[#list+1] = {v = { x,  bottom }}
      else
        list[#list+1] = {v = { left,  bottom }}
        y = (right-xcen)*tan(-beta_rad) + ycen
        if (alpha<350)and(y<top) then
          list[#list+1] = {v = { left,  y }}
        else
          list[#list+1] = {v = { left,  top }}
          x = (top-ycen)*tan(alpha_rad) + xcen
          list[#list+1] = {v = { x,  top }}
        end
      end
    end
  end

  glShape(GL.TRIANGLE_FAN, list)
  
  -- adding additive overlay
  glColor(color[1],color[2],color[3],color[4]/10)
  glBlending(GL_SRC_ALPHA, GL_ONE)
  glShape(GL.TRIANGLE_FAN, list)
  glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
  
  glColor(1,1,1,1)
end


local function DrawButton(rect, unitDefID, options, iconResize, isFac)
  -- options = {pressed,hovered,selected,repeat,hovered_repeat,waypoint,progress,amount,alpha}

  if (#rect<4) then
    Spring.Echo('Incorrect arguments to DrawButton(rect={left,top,right,bottom}, unitDefID, options)')
    return
  end

  -- Progress
  if (options.progress or -1)>-1 then
    DrawBuildProgress(rect[1],rect[2],rect[3],rect[4], options.progress, { 1, 1, 1, 0.4 })
  end

  -- hover or pressed?
  local hoverPadding = 0
  local iconAlpha = (options.alpha or 1)
  if (options.pressed) then
    if options.pressed == 2 then
      DrawRect(rect, { 1, 0.8, 0.8, 0.5 })  -- pressed
    else
      DrawRect(rect, { 1, 1, 1, 0.5 })  -- pressed
    end
    hoverPadding = -iconSizeX/20
    iconAlpha = 1
  elseif (options.hovered) then
    --DrawRect(rect, { 1, 1, 1, 0.45})  -- hover
    hoverPadding = -iconSizeX/15
    iconAlpha = 1
  end

  -- draw icon
  local imgRect = {rect[1]+hoverPadding, rect[2]-hoverPadding, rect[3]-hoverPadding, rect[4]+hoverPadding}
  if iconResize then
    --local yPad = (iconSizeY*(1-iconImgMult)) / 2  -- used with transparant uniticons
    --local xPad = (iconSizeX*(1-iconImgMult)) / 2  -- used with transparant uniticons
    local yPad = (iconSizeY*(1-iconImgMult)) / 3.3
    local xPad = (iconSizeX*(1-iconImgMult)) / 3.3
    imgRect = {imgRect[1]+xPad, imgRect[2]-yPad, imgRect[3]-xPad, imgRect[4]+yPad}
  end

  local tex = '#' .. unitDefID
  if oldUnitpics and UnitDefs[unitDefID] ~= nil and VFS.FileExists('unitpics/'..UnitDefs[unitDefID].name..'.dds') then
    tex = 'unitpics/'..UnitDefs[unitDefID].name..'.dds'
  end

  DrawTexRect(imgRect, tex, {1,1,1,iconAlpha})

  -- loop status?
  if options['repeat'] then
    local color = {1,1,1,0.8}
    if (options.hovered_repeat) then
      color = {1,1,1,0.65}
    end
    DrawTexRect({imgRect[3]-repIcoSize-4,imgRect[2]-4,imgRect[3]-4,imgRect[2]-repIcoSize-4}, repeatPic, color)
  elseif isFac then
    local color = {1,1,1,0.35}
    if (options.hovered_repeat) then
      color = {1,1,1,0.5}
    end
    DrawTexRect({imgRect[3]-repIcoSize-4,imgRect[2]-4,imgRect[3]-4,imgRect[2]-repIcoSize-4}, repeatPic, color)
  end

  -- amount
  if ((options.amount or 0)>0) then
      glText( options.amount ,rect[1]+((rect[3]-rect[1])*0.22),rect[4]-((rect[4]-rect[2])*0.22),fontSize,"o")
  end

  -- draw border
  --[[if (options.waypoint) then
    DrawRect(rect, { 0.5,1.0,0.5,0.45 })
    DrawLineRect(rect, { 0, 0, 0, 1 },borderSize+2)
  elseif (options.selected)and(not options.pressed) then
    DrawRect(rect, { 1, 1, 1, 0.35 })
    DrawLineRect(rect, { 0, 0, 0, 1 },borderSize+2)
  else
    DrawLineRect(rect, { 0, 0, 0, 1 })
  end]]--
end

local sec = 0
function widget:Update(dt)

  if myTeamID~=Spring.GetMyTeamID() then
    myTeamID = Spring.GetMyTeamID()
    UpdateFactoryList()
  end
  inTweak = widgetHandler:InTweakMode()


  local icon,mx,my,lb,mb,rb = -1,-1,-1,false,false,false
  if (not inTweak) then
    mx,my,lb,mb,rb = GetMouseState()
  end

  sec = sec + dt
  local doupdate = false
  if sec > 0.2 then
    doupdate = true
  end
  if factoriesArea ~= nil then
    if IsInRect(mx,my, {factoriesArea[1],factoriesArea[2],factoriesArea[3],factoriesArea[4]}) then
      doupdate = true
      factoriesAreaHovered = true
    elseif factoriesAreaHovered then
      factoriesAreaHovered = nil
      doupdate = true
    end
  end
  if doupdate then
    sec = 0
    SetupDimensions(#facs)
    SetupSubDimensions()
    for i=1, #dlists do
      gl.DeleteList(dlists[i])
    end
    dlists = {}
    factoriesArea = nil

    -- draw factory list
    local fac_rec = RectWH(facRect[1],facRect[2], iconSizeX, iconSizeY)
    for i,facInfo in ipairs(facs) do

      local unitDefID = facInfo.unitDefID
      local options   = {}

      local unitBuildDefID = -1
      local unitBuildID    = -1

      -- determine options -------------------------------------------------------------------
      -- building?
      local iconResize = true
      unitBuildID      = GetUnitIsBuilding(facInfo.unitID)
      if unitBuildID then
        unitBuildDefID = GetUnitDefID(unitBuildID)
        _, _, _, _, options.progress = GetUnitHealth(unitBuildID)
        unitDefID      = unitBuildDefID
        iconResize = true
      elseif (unfinished_facs[facInfo.unitID]) then
        _, _, _, _, options.progress = GetUnitHealth(facInfo.unitID)
        if (options.progress>=1) then
          options.progress = -1
          unfinished_facs[facInfo.unitID] = nil
        end
      end
      -- repeat mode?
      local ustate   = GetUnitStates(facInfo.unitID)
      if ustate ~= nil then
        options['repeat'] = ustate["repeat"]
      else
        options['repeat'] = false
      end
      -- hover or pressed?
      if (i==hoveredFac+1) then
        options.hovered_repeat = IsInRect(mx,my, {fac_rec[3]-repIcoSize,fac_rec[2],fac_rec[3],fac_rec[2]-repIcoSize})
        options.pressed = (lb or mb or rb)or(options.hovered_repeat)
        options.hovered = true
      end
      -- border
      options.waypoint = (waypointMode>1)and(i==waypointFac+1)
      options.selected = (i==openedMenu+1)
      -----------------------------------------------------------------------------------------
      --DrawButton(fac_rec,unitDefID,options, iconResize, true)

      dlists[#dlists+1] = gl.CreateList(DrawButton,fac_rec,unitDefID,options, iconResize, true)
      if factoriesArea == nil then
        factoriesArea = {fac_rec[1],fac_rec[2],fac_rec[3],fac_rec[4]}
      else
        factoriesArea[4] = fac_rec[4]
      end

      -- setup next icon pos
      OffsetRect(fac_rec, fac_inext[1],fac_inext[2])
    end
  end
end

-------------------------------------------------------------------------------
-- DRAWSCREEN
-------------------------------------------------------------------------------

function widget:DrawScreen()

  local icon,mx,my,lb,mb,rb = -1,-1,-1,false,false,false
  if (not inTweak) then
    mx,my,lb,mb,rb = GetMouseState()
  end

  for i=1, #dlists do
    gl.CallList(dlists[i])
  end

  -- draw factory list
  if  (factoriesArea ~= nil and IsInRect(mx,my, {factoriesArea[1],factoriesArea[2],factoriesArea[3],factoriesArea[4]})) or
      (buildoptionsArea ~= nil and IsInRect(mx,my, {buildoptionsArea[1],buildoptionsArea[2],buildoptionsArea[3],buildoptionsArea[4]})) then
    local fac_rec = RectWH(facRect[1],facRect[2], iconSizeX, iconSizeY)
    buildoptionsArea = nil
    for i,facInfo in ipairs(facs) do


      -- draw build list
    if i==openedMenu+1 then
      -- draw buildoptions
      local bopt_rec = RectWH(fac_rec[1]+bopt_inext[1], fac_rec[2]+bopt_inext[2],iconSizeX,iconSizeY)

      local buildList   = facInfo.buildList
      local buildQueue  = GetBuildQueue(facInfo.unitID)
      for j,unitDefID in ipairs(buildList) do
        local unitDefID = unitDefID
        local options   = {}
        -- determine options -------------------------------------------------------------------
         -- building?
          if unitDefID==unitBuildDefID then
            _, _, _, _, options.progress = GetUnitHealth(unitBuildID)
          end
         -- amount
          options.amount = buildQueue[unitDefID]
         -- hover or pressed?
          if (j==hoveredBOpt+1) then
            options.pressed = (lb or mb or rb)
            if lb then
              options.pressed = 1
            elseif rb then
              options.pressed = 2
            elseif mb then
              options.pressed = 3
            end
            options.hovered = true
          end
          options.alpha = 0.85
        -----------------------------------------------------------------------------------------
        DrawButton(bopt_rec,unitDefID,options, true)
        if buildoptionsArea == nil then
          buildoptionsArea = {bopt_rec[1],bopt_rec[2],bopt_rec[3],bopt_rec[4]}
        else
          buildoptionsArea[1] = bopt_rec[1]
        end
        -- setup next icon pos
        OffsetRect(bopt_rec, bopt_inext[1],bopt_inext[2])

        --if j % 3==0 then
        --  xmin_,xmax_ = xmin   + bopt_inext[1],xmin_ + iconSizeX
        --  ymax_,ymin_ = ymax_  - iconSizeY, ymin_ - iconSizeY
        --end
      end
    else
      -- draw buildqueue
      local buildQueue  = Spring.GetFullBuildQueue(facInfo.unitID,maxVisibleBuilds+1)
      if (buildQueue ~= nil) then
        local bopt_rec = RectWH(fac_rec[1]+bopt_inext[1], fac_rec[2]+bopt_inext[2],iconSizeX,iconSizeY)

        local n,j = 1,maxVisibleBuilds
        while (buildQueue[n]) do
          local unitBuildDefID, count = next(buildQueue[n], nil)
          if (n==1) then count=count-1 end -- cause we show the actual in building unit instead of the factory icon

          if (count>0) then

                local yPad = (iconSizeY*(1-iconImgMult)) / 2
                local xPad = (iconSizeX*(1-iconImgMult)) / 2
            DrawTexRect({bopt_rec[1]+xPad,bopt_rec[2]-yPad,bopt_rec[3]-xPad,bopt_rec[4]+yPad},"#"..unitBuildDefID,{1,1,1,0.5})
            if (count>1) then
              glColor(1,1,1,0.66)
              glText( count ,bopt_rec[1]+((bopt_rec[3]-bopt_rec[1])*0.22),bopt_rec[4]-((bopt_rec[4]-bopt_rec[2])*0.22),fontSize,"")
            end

            OffsetRect(bopt_rec, bopt_inext[1],bopt_inext[2])
            j = j-1
            if j==0 then break end
          end
          n = n+1
        end
      end
    end

      -- setup next icon pos
      OffsetRect(fac_rec, fac_inext[1],fac_inext[2])
    end
  else
    buildoptionsArea = nil
  end
  -- draw border around factory list
  --if (#facs>0) then DrawLineRect(facRect, { 0, 0, 0, 1 },borderSize+2) end
end



function widget:DrawWorld()
  
  -- Draw factories command lines
  if waypointMode>1 or openedMenu>=0 then
    local fac
    if waypointMode>1 then
      fac = facs[waypointFac+1]
    else
      fac = facs[openedMenu+1]
    end
    if fac ~= nil then
      DrawUnitCommands(fac.unitID)
    end
  end
end


function widget:DrawInMiniMap(sx,sy)
  
   if (openedMenu>-1) then
     gl.PushMatrix()
       local pt = math.min(sx,sy)

       gl.LoadIdentity()
       gl.Translate(0, 1, 0)
       gl.Scale(1 / msx, -1 / msz, 1)

       local r,g,b = GetTeamColor(myTeamID)
       local alpha = 0.5 + math.abs((Spring.GetGameSeconds() % 0.25)*4 - 0.5)
       local x,_,z = Spring.GetUnitBasePosition(facs[openedMenu+1].unitID)

       if x ~= nil then
         gl.PointSize(pt*0.066)
         gl.Color(0, 0, 0)
         gl.BeginEnd(GL.POINTS, function() gl.Vertex(x, z) end)
         gl.PointSize(pt*0.051)
         gl.Color(r,g,b, alpha)
         gl.BeginEnd(GL.POINTS, function() gl.Vertex(x, z) end)
         gl.PointSize(1)
         gl.Color(1, 1, 1, 1)
       end
     gl.PopMatrix()
   end
end

-------------------------------------------------------------------------------
-- GEOMETRIC FUNCTIONS
-------------------------------------------------------------------------------
local function _clampScreen(mid,half,vsd)
  if     (mid-half<0) then
    return          0, half*2
  elseif (mid+half>vsd) then
    return vsd-half*2, vsd 
  else
    local val = math.floor(mid - half)
    return        val, val+half*2
  end
end

local function _adjustSecondaryAxis(bar_side,vsd,iconSizeD)
  -- bar_side is 0 for left and top, and 1 for right and bottom
  local val = bar_side*(vsd-iconSizeD)
  return val, iconSizeD + val
end

function SetupDimensions(count)
  local length,mid,vsd,iconSizeA,iconSizeB
  if bar_horizontal then -- horizontal (top or bottom bar)
    vsa,iconSizeA,vsb,iconSizeB = vsx,iconSizeX,vsy,iconSizeY
  else                   -- vertical (left or right bar)
    vsa,iconSizeA,vsb,iconSizeB = vsy,iconSizeY,vsx,iconSizeX
  end
  length = math.floor(iconSizeA * count)
  mid    = vsa * 0.5 + bar_offset

  -- setup expanding direction
  mid = mid + bar_align * length * 0.5

  -- clamp screen
  local v1,v2 = _clampScreen(mid,length*0.5,vsa)

  -- adjust SecondaryAxis
  local v3,v4 = _adjustSecondaryAxis(bar_side%2,vsb,iconSizeB)

  -- assign rect
  if bar_horizontal then
    facRect[1],facRect[3],facRect[4],facRect[2] = v1,v2,v3,v4
  else
    facRect[4],facRect[2],facRect[1],facRect[3] = v1,v2,v3,v4
  end
end


function SetupSubDimensions()
  if openedMenu<0 then
    boptRect = {-1,-1,-1,-1}
    return
  end

  local buildListn = #facs[openedMenu+1].buildList
  if bar_horizontal then --please note the factorylist is horizontal not the buildlist!!!

    boptRect[1]  = math.floor(facRect[1] + iconSizeX * openedMenu)
    boptRect[3]  = boptRect[1] + iconSizeX
    if bar_side==2 then --top
      boptRect[2] = vsy - iconSizeY
      boptRect[4] = boptRect[2] - math.floor(iconSizeY * buildListn)
    else --bottom
      boptRect[4] = iconSizeY
      boptRect[2] = iconSizeY + math.floor(iconSizeY * buildListn)
    end

  else

    boptRect[2]  = math.floor(facRect[2] - iconSizeY * openedMenu)
    boptRect[4]  = boptRect[2] - iconSizeY
    if bar_side==0 then --left
      boptRect[1] = iconSizeX
      boptRect[3] = iconSizeX + math.floor(iconSizeX * buildListn)
    else --right
      boptRect[3] = vsx - iconSizeX
      boptRect[1] = boptRect[3] - math.floor(iconSizeX * buildListn)
    end

  end
end


-------------------------------------------------------------------------------
-- UNIT FUNCTIONS
-------------------------------------------------------------------------------
function GetBuildQueue(unitID)
  local result = {}
  local queue = GetFullBuildQueue(unitID)
  if (queue ~= nil) then
    for _,buildPair in ipairs(queue) do
      local udef, count = next(buildPair, nil)
      if result[udef]~=nil then
        result[udef] = result[udef] + count
      else
        result[udef] = count
      end
    end
  end
  return result
end


-------------------------------------------------------------------------------
-- UNIT INITIALIZTION FUNCTIONS
-------------------------------------------------------------------------------
function UpdateFactoryList()
  facs = {}
  local count = 0

  local teamUnits = Spring.GetTeamUnits(myTeamID)
  local totalUnits = #teamUnits

  for num = 1, totalUnits do
    local unitID = teamUnits[num]
    local unitDefID = GetUnitDefID(unitID)
    if UnitDefs[unitDefID].isFactory then
      count = count + 1
      facs[count] = { unitID=unitID, unitDefID=unitDefID, buildList=UnitDefs[unitDefID].buildOptions }
      local _, _, _, _, buildProgress = GetUnitHealth(unitID)
      if (buildProgress)and(buildProgress<1) then
        unfinished_facs[unitID] = true
      end
    end
  end
end



--function widget:UnitFinished(unitID, unitDefID, unitTeam)
function widget:UnitCreated(unitID, unitDefID, unitTeam)
  if (unitTeam ~= myTeamID) then
    return
  end

  if UnitDefs[unitDefID].isFactory and #UnitDefs[unitDefID].buildOptions>0 then
    facs[#facs+1] = { unitID=unitID, unitDefID=unitDefID, buildList=UnitDefs[unitDefID].buildOptions }
  end
  unfinished_facs[unitID] = true
end

function widget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
  widget:UnitCreated(unitID, unitDefID, unitTeam)
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
  if (unitTeam ~= myTeamID) then
    return
  end

  if UnitDefs[unitDefID].isFactory and #UnitDefs[unitDefID].buildOptions>0 then
    for i,facInfo in ipairs(facs) do
      if unitID==facInfo.unitID then
        if (openedMenu+1==i)and(openedMenu > #facs-2) then
          openedMenu = openedMenu-1
          if (openedMenu<0) then
            menuHovered = false
          end
        end
        table.remove(facs,i)
        unfinished_facs[unitID] = nil
        return
      end
    end
  end
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
  widget:UnitDestroyed(unitID, unitDefID, unitTeam)
end


function widget:PlayerChanged()
	if Spring.GetSpectatingState() then
		widgetHandler:RemoveWidget(self)
	end
end


-------------------------------------------------------------------------------
-- MOUSE PRESS FUNCTIONS
-------------------------------------------------------------------------------
function widget:MousePress(x, y, button)
  if (inTweak) then return false end

  pressedFac = hoveredFac
  pressedBOpt= hoveredBOpt

  if (hoveredFac+hoveredBOpt>=-1) then
    if waypointMode>1 then
      Spring.Echo("BuildBar: Exited greedy waypoint mode")
      Spring.PlaySoundFile(sound_waypoint, 0.9, 'ui')
    end
    waypointFac  = -1
    waypointMode = 0
  else
    --todo: close hovered
    if waypointMode>1 then
      -- greedy waypointMode
      return (button~=2) -- we allow middle click scrolling in greedy waypoint mode
    elseif (button==3) and (openedMenu>=0) and (#GetSelectedUnits()==0) then
      -- lazy waypointMode
      waypointMode = 1   -- lazy mode
      waypointFac  = openedMenu
      return true
    end

    if waypointMode>1 then
      Spring.Echo("BuildBar: Exited greedy waypoint mode")
      Spring.PlaySoundFile(sound_waypoint, 0.9, 'ui')
    end
    waypointFac  = -1
    waypointMode = 0

    if button~=2 then
      openedMenu = -1
      menuHovered= false
    end
    return false
  end
  return true
end


function widget:MouseRelease(x, y, button)
  if ( pressedFac == hoveredFac )and
     (pressedBOpt == hoveredBOpt)and
     (waypointMode<1)and
     (not inTweak)
  then
    if (hoveredFac>=0)and(waypointMode<1) then
      MenuHandler(x,y,button)
    else
      BuildHandler(button)
    end
  elseif (waypointMode>0)and(waypointFac>=0) then
    WaypointHandler(x,y,button)
  end
  return -1
end



-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function MenuHandler(x,y,button)
  if button>3 then
    return
  end

  if button==1 then
    local icoRect = {}
    _,icoRect[2],icoRect[3],_ = GetFacIconRect(pressedFac)
      icoRect[1],icoRect[4]   = icoRect[3]-repIcoSize,icoRect[2]-repIcoSize
    if IsInRect(x,y, icoRect) then
      --repeat icon clicked
      local unitID = facs[pressedFac+1].unitID
      local ustate = GetUnitStates(unitID)
      local onoff  = {1}
      if ustate ~= nil and ustate["repeat"] then onoff = {0} end
      Spring.GiveOrderToUnit(unitID, CMD.REPEAT, onoff, { })
      Spring.PlaySoundFile(sound_click, 0.8, 'ui')
    else--if (bar_openByClick) then
      if (not menuHovered)and(openedMenu == pressedFac) then
        openedMenu = -1
        Spring.PlaySoundFile(sound_click, 0.75, 'ui')
      else
        menuHovered= false
        openedMenu = pressedFac
        Spring.PlaySoundFile(sound_click, 0.75, 'ui')
      end
    end
  elseif button==2 then
    local x,y,z = Spring.GetUnitPosition(facs[pressedFac+1].unitID)
    Spring.SetCameraTarget(x,y,z)
  elseif button==3 then
    Spring.Echo("BuildBar: Entered greedy waypoint mode")
    Spring.PlaySoundFile(sound_waypoint, 0.9, 'ui')
    waypointMode = 2 -- greedy mode
    waypointFac  = openedMenu
    openedMenu   = -1
    pressedFac   = -1
    hoveredFac   = -1
   -- blurFullscreen(false)
    blured = false
  end
  return
end


function BuildHandler(button)
  local alt, ctrl, meta, shift = Spring.GetModKeyState()
  local opt = {}
  if alt   then opt[#opt+1]="alt"   end
  if ctrl  then opt[#opt+1]="ctrl"  end
  if meta  then opt[#opt+1]="meta"  end
  if shift then opt[#opt+1]="shift" end

  if button==1 then
    Spring.GiveOrderToUnit(facs[openedMenu+1].unitID, -(facs[openedMenu+1].buildList[pressedBOpt+1]),{},opt)
    Spring.PlaySoundFile(sound_queue_add, 0.75, 'ui')
  elseif button==3 then
    opt[#opt+1]="right"
    Spring.GiveOrderToUnit(facs[openedMenu+1].unitID, -(facs[openedMenu+1].buildList[pressedBOpt+1]),{},opt)
    Spring.PlaySoundFile(sound_queue_rem, 0.75, 'ui')
  end
end


function WaypointHandler(x,y,button)
  if (button==1)or(button>3) then
    Spring.Echo("BuildBar: Exited greedy waypoint mode")
    Spring.PlaySoundFile(sound_waypoint, 0.9, 'ui')
    menuHovered  = false
    waypointFac  = -1
    waypointMode = 0
    openedMenu   = -1
    return
  end

  local alt, ctrl, meta, shift = Spring.GetModKeyState()
  local opt = {"right"}
  if alt   then opt[#opt+1]="alt"   end
  if ctrl  then opt[#opt+1]="ctrl"  end
  if meta  then opt[#opt+1]="meta"  end
  if shift then opt[#opt+1]="shift" end

  local type,param = Spring.TraceScreenRay(x,y)
  if type=='ground' then
    Spring.GiveOrderToUnit(facs[waypointFac+1].unitID, CMD.MOVE,param,opt) 
  elseif type=='unit' then
    Spring.GiveOrderToUnit(facs[waypointFac+1].unitID, CMD.GUARD,{param},opt)     
  else --feature
    type,param = Spring.TraceScreenRay(x,y,true)
    Spring.GiveOrderToUnit(facs[waypointFac+1].unitID, CMD.MOVE,param,opt)
  end

  --if not shift then waypointMode = 0; return true end
end


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function MouseOverIcon(x, y)
  if (x >= facRect[1]) and (x <= facRect[3])and
     (y >= facRect[4]) and (y <= facRect[2])
  then
    local icon
    if bar_horizontal then
      icon = math.floor((x - facRect[1]) / fac_inext[1])
    else
      icon = math.floor((y - facRect[2]) / fac_inext[2])
    end

    if (icon >= #facs) then
      icon = (#facs - 1)
    elseif (icon < 0) then
      icon = 0
    end

    return icon
  end
  return -1
end


function MouseOverSubIcon(x,y)
  if (openedMenu>=0)and
     (x >= boptRect[1]) and (x <= boptRect[3])and
     (y >= boptRect[4]) and (y <= boptRect[2])
  then
    local icon  
    if bar_side==0 then
      icon = math.floor((x - boptRect[1]) / bopt_inext[1])
    elseif bar_side==2 then
      icon = math.floor((y - boptRect[2]) / bopt_inext[2])
    elseif bar_side==1 then
      icon = math.floor((x - boptRect[3]) / bopt_inext[1])
    else --bar_side==3
      icon = math.floor((y - boptRect[4]) / bopt_inext[2])
    end

    if (icon > #facs[openedMenu+1].buildList-1) then
      icon = #facs[openedMenu+1].buildList-1
    elseif (icon < 0) then
      icon = 0
    end

    return icon
  end
  return -1
end



-------------------------------------------------------------------------------
-- HOVER FUNCTIONS
-------------------------------------------------------------------------------
function widget:GetTooltip(x,y)
  if hoveredFac>=0 then
    --local unitID    = facs[hoveredFac+1].unitID
    local unitDef   = UnitDefs[facs[hoveredFac+1].unitDefID]
    return unitDef.humanName .. "\n" ..
           --GreyStr .. "Left mouse: show build options\n" ..
           GreyStr .. "Middle mouse: set camera target\n"
           --GreyStr .. "Right mouse: show build options"
  elseif (hoveredBOpt>=0) then
    if hoveredBOpt>=0 then
      local unitDef = UnitDefs[facs[openedMenu+1].buildList[hoveredBOpt+1]]
      return " " .. unitDef.humanName .. " (" .. unitDef.tooltip .. ")\n" ..
             GreyStr .. "Health " .. GreenStr .. unitDef.health .. "\n" ..
             GreyStr .. "Metal cost " .. OrangeStr .. unitDef.metalCost .. "\n" ..
             GreyStr .. "Energy cost " .. YellowStr .. unitDef.energyCost .. GreyStr .. " Build time "  .. BlueStr .. unitDef.buildTime
    end
  end
  return ""
end




function widget:IsAbove(x,y)
  if (not inTweak) then
    local _,_,lb,mb,rb = GetMouseState()
    if ((lb or mb or rb)and(openedMenu==-1))or(waypointMode==2) then
      return false
    end
  end

  hoveredFac  = MouseOverIcon(x,y)
  hoveredBOpt = MouseOverSubIcon(x,y)

  if hoveredFac>=0 then
    --factory icon
    if (not bar_openByClick)and
       ((openedMenu<0)or(menuHovered))and
       (not inTweak)
    then
      menuHovered= true
      openedMenu = hoveredFac
    end
    if not blured then
      Spring.PlaySoundFile(sound_hover, 0.8, 'ui')
      --blurFullscreen(true)
      blured = true
    end
    return true
  elseif (openedMenu>=0) and IsInRect(x,y, boptRect) then
    --buildoption icon
    if not blured then
      Spring.PlaySoundFile(sound_hover, 0.8, 'ui')
      --blurFullscreen(true)
      blured = true
    end
    return true
  else
    if (bar_autoclose)and(
         (bar_openByClick) or
         (not bar_openByClick)and(menuHovered)
       )
    then
      menuHovered= false
      openedMenu = -1
    end
  end

  if blured then
    Spring.PlaySoundFile(sound_hover, 0.8, 'ui')
    --blurFullscreen(false)
    blured = false
  end
  return false
end


-------------------------------------------------------------------------------
-- TWEAK MODE
-------------------------------------------------------------------------------
local TweakMousePressed = false
local TweakMouseMoved   = false
local TweakPressedPos_X, TweakPressedPos_Y = 0,0
local TweakAbove        = false

function widget:TweakDrawScreen()
  local mx,my,lb,mb,rb = GetMouseState()
  if IsInRect(mx,my, facRect) then
    DrawRect(facRect, { 0, 0, 1, 0.35 })  -- hover
  else
    DrawRect(facRect, { 0, 0, 0, 0.45 })
    DrawRect(facRect, { 0, 0, 1, 0.2 })
    DrawLineRect(facRect, { 0.4, 0.4, 1, 0.5 })
  end

  -- draw alignment line (red)
  local rect = {}
  if bar_horizontal then
    if bar_align==0 then         -- centered line
      rect = {(facRect[1]+facRect[3])/2, facRect[2], (facRect[1]+facRect[3])/2, facRect[4]}
    elseif (bar_align>0) then    -- left line
      rect = {facRect[1], facRect[2], facRect[1], facRect[4]}
    else --if (bar_align<0) then -- right line
      rect = {facRect[3], facRect[2], facRect[3], facRect[4]}
    end
  else
    if bar_align==0 then         -- centered line
      rect = {facRect[1], (facRect[2]+facRect[4])/2, facRect[3], (facRect[2]+facRect[4])/2}
    elseif (bar_align>0) then    -- bottom line
      rect={facRect[1], facRect[4], facRect[3], facRect[4]}
    else --if (bar_align<0) then -- top line
      rect={facRect[1], facRect[2], facRect[3], facRect[2]}
    end
  end
  DrawLineRect(rect, { 1, 0, 0, 0.5 })
end

function widget:TweakIsAbove(x,y)
  TweakAbove = self:IsAbove(x,y)
  return TweakAbove
end

function widget:TweakGetTooltip(x,y)
  return 'Click + Drag:  move\n\n'..
         'Mouse wheel:  in-/decrease iconsize\n' ..
         'Single Middle Click:  change alignment\n'..
         'Single Left\\Right  Click:  raise\\lower\n'
end

function widget:TweakMousePress(x, y, button)
  if (TweakAbove) then
    TweakMousePressed = true
    TweakPressedPos_X, TweakPressedPos_Y = x,y
    return true
  end
  return false
end

function widget:TweakMouseRelease(x, y, button)
  TweakPressedPos_X, TweakPressedPos_Y = 0,0
  if (TweakMousePressed)and(TweakAbove) then
    TweakMousePressed = false
    if not TweakMouseMoved then
      TweakMouseMoved = false
      if (button == 1) then
        widgetHandler:RaiseWidget()
        Spring.Echo("widget raised")
        return true
      elseif (button == 3) then
        widgetHandler:LowerWidget()
        Spring.Echo("widget lowered")
        return true
      elseif (button == 2) then
        bar_align=bar_align+1
        if bar_align>1 then bar_align=-1 end
      end
    else
    end
  end
  TweakMousePressed = false
  TweakMouseMoved   = false
  return false
end

function widget:TweakMouseMove(x, y, dx, dy, button)
  if TweakMousePressed then
    TweakMouseMoved = true
    if bar_horizontal then
      bar_offset = bar_offset + dx

      if math.abs(TweakPressedPos_Y-y)>100 then
        local bar_center = (facRect[1] + facRect[3])/2
        if bar_center>0.5*vsx then
          bar_side=1
        else
          bar_side=0
        end
        TweakPressedPos_X = x
        TweakPressedPos_Y = 0
        bar_offset = y - 0.5*vsy
        SetupNewScreenAlignment()
      end
    else
      bar_offset = bar_offset + dy
      if math.abs(TweakPressedPos_X-x)>100 then
        local bar_center = (facRect[2] + facRect[4])/2
        if bar_center>0.5*vsy then
          bar_side=3
        else
          bar_side=2
        end
        TweakPressedPos_X = 0
        TweakPressedPos_Y = y
        bar_offset = x - 0.5*vsx
        SetupNewScreenAlignment()
      end
    end
  end
end

function widget:TweakMouseWheel(up,value)
  -- you can resize the icons with the mousewheel
  if (hoveredFac+hoveredBOpt>=-1) then
    if up then
      bar_iconSizeBase = math.max(bar_iconSizeBase + 3,40)
    else
      bar_iconSizeBase = math.max(bar_iconSizeBase - 3,40)
    end

    UpdateIconSizes()
    SetupNewScreenAlignment()

    return true
  end
  return false
end
