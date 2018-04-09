--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    gui_ally_res.lua
--  brief:   Shows your allies resources and allows quick resource transfer
--  author:  Owen Martindell
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "Ally Resource Bars (old)",
    desc      = "Shows your allies resources and allows quick resource transfer",
    author    = "Floris (org by: TheFatController)",
    date      = "25 april 2015",
    license   = "MIT/x11",
    layer     = -9, 
    enabled   = false  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local TOOL_TIPS = true
local showSelf	= true

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local GetTeamResources = Spring.GetTeamResources
local GetMyTeamID = Spring.GetMyTeamID
local GetMouseState = Spring.GetMouseState
local GetSpectatingState = Spring.GetSpectatingState
local IsReplay = Spring.IsReplay
local IsGUIHidden = Spring.IsGUIHidden
local ShareResources = Spring.ShareResources
local GetGameFrame = Spring.GetGameFrame
local GetTeamList = Spring.GetTeamList
local GetMyAllyTeamID = Spring.GetMyAllyTeamID
local mathMin = math.min
local gl, GL = gl, GL
local sF = string.format
local GetPlayerInfo = Spring.GetPlayerInfo

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local imageDirectory		= ":n:LuaUI/Images/allyres/"
local teamPic				= imageDirectory.."team.png"
local teamHighlightPic		= imageDirectory.."highlight.png"
local barBg					= imageDirectory.."barbg.png"
local bar					= imageDirectory.."bar.png"
local bgcorner				= "LuaUI/Images/bgcorner.png"
local bgcornerSize			= 8

local bordercolor = {1,1,1,0.022}
local displayList
local staticList
local vsx, vsy = 0,0
local xPercentage      = 85
local yPercentage      = 85
local sizeMultiplier   = 1

local customScale = 1

-- nevermind these vars now, they are defined in widget:ViewResize
local BAR_HEIGHT       = 4		-- dont edit
local BAR_SPACER       = 3		-- dont edit
local BAR_WIDTH        = 64		-- dont edit
local BAR_GAP          = 12		-- dont edit
local BAR_MARGIN       = 4		-- dont edit
local TOTAL_BAR_HEIGHT = (BAR_SPACER + BAR_HEIGHT + BAR_HEIGHT)
local TOP_HEIGHT       = (BAR_GAP)
local BAR_OFFSET       = (TOP_HEIGHT + BAR_SPACER + BAR_GAP)
local START_HEIGHT     = (TOTAL_BAR_HEIGHT + BAR_GAP + TOP_HEIGHT)
local FULL_BAR         = (BAR_WIDTH + BAR_GAP + BAR_GAP + BAR_SPACER)
local w                = (BAR_WIDTH + BAR_OFFSET + BAR_GAP)
local h                = START_HEIGHT


local selfXoffset = -3
local x1,y1
local mx, my
local sentSomething = false
local enabled       = false
local doUpdate      = false
local transferring  = false
local transferTeam
local transferType
local teamList   = {}
local teamRes    = {}
local teamColors = {}
local teamIcons  = {}
local deadTeams  = {}
local sendEnergy = {}
local sendMetal  = {}
local trnsEnergy = {}
local trnsMetal  = {}
local labelText  = {}
local sentEnergy = 0
local sentMetal  = 0
local gameFrame  = 0
local lastFrame  = -1
local prevHeight = nil
local myID
local posLoaded = false

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function getTeamNames()
  local teamNames = {}
  local playerList = Spring.GetPlayerList()
  for _,playerID in ipairs(playerList) do
    local name,_,spec,teamID = Spring.GetPlayerInfo(playerID)
    if not spec then
      if name and teamID then
        teamNames[teamID] = name
      end
    end
  end
  return teamNames
end

local function updateGuishader()
  if (WG['guishader_api'] ~= nil) then
	if not enabled then
		WG['guishader_api'].RemoveRect('allyres')
	else
		WG['guishader_api'].InsertRect(
			x1-(BAR_MARGIN/1.75)+(bgcornerSize*0.2),
			y1-BAR_MARGIN+(bgcornerSize*0.2),
			x1+w+(BAR_MARGIN/1.75)-(bgcornerSize*0.2),
			y1+h+BAR_MARGIN-(bgcornerSize*0.2),
			'allyres'
		)
	end
  end
end

function widget:Initialize()
  vsx, vsy = gl.GetViewSizes()
  if not posLoaded then
    percentage2Coords()
  end
  myID = GetMyTeamID()
end

function widget:Shutdown()
    if (displayList) then gl.DeleteList(displayList) end
    if (staticList) then gl.DeleteList(staticList) end
    enabled = false
    updateGuishader()
end

local function setUpTeam()
  teamList = {}
  teamRes = {}
  teamColors = {}
  myID = GetMyTeamID()
  local getTeams = GetTeamList(GetMyAllyTeamID())
  mx, my = 0,0
  local teamCount = 0
  for _,teamID in ipairs(getTeams) do
    if teamID ~= myID or showSelf then
      local eCur = GetTeamResources(teamID, "energy")
      if eCur and (not deadTeams[teamID]) then
        teamCount = teamCount + 1
        teamList[teamCount] = teamID
      end
    end
  end
  for key,teamID in ipairs(teamList) do
    local r,g,b = Spring.GetTeamColor(teamID)
    teamColors[teamID] = {r=r,g=g,b=b}
  end
  if (teamCount > 1 and showSelf) or (showSelf == false and teamCount > 0) then
    enabled = true
  else
    enabled = false
  end
  return enabled
end

function RectRound(px,py,sx,sy,cs)
	
	local px,py,sx,sy,cs = math.floor(px),math.floor(py),math.floor(sx),math.floor(sy),math.floor(cs)
	
	gl.Rect(px+cs, py, sx-cs, sy)
	gl.Rect(sx-cs, py+cs, sx, sy-cs)
	gl.Rect(px+cs, py+cs, px, sy-cs)
	
	if py <= 0 or px <= 0 then gl.Texture(false) else gl.Texture(bgcorner) end
	gl.TexRect(px, py+cs, px+cs, py)		-- top left
	
	if py <= 0 or sx >= vsx then gl.Texture(false) else gl.Texture(bgcorner) end
	gl.TexRect(sx, py+cs, sx-cs, py)		-- top right
	
	if sy >= vsy or px <= 0 then gl.Texture(false) else gl.Texture(bgcorner) end
	gl.TexRect(px, sy-cs, px+cs, sy)		-- bottom left
	
	if sy >= vsy or sx >= vsx then gl.Texture(false) else gl.Texture(bgcorner) end
	gl.TexRect(sx, sy-cs, sx-cs, sy)		-- bottom right
	
	gl.Texture(false)
end

local function updateStatics()
  if (staticList) then gl.DeleteList(staticList) end
  staticList = gl.CreateList( function()
	gl.PushMatrix()
    gl.Color(0.0, 0.0, 0.0, 0.6)
    RectRound(x1-(BAR_MARGIN/1.75), y1-BAR_MARGIN, x1+w+(BAR_MARGIN/1.75), y1+h+BAR_MARGIN, bgcornerSize)
    
    local padding = bgcornerSize*0.5
    gl.Color(bordercolor)
    RectRound(x1-(BAR_MARGIN/1.75)+padding, y1-BAR_MARGIN+padding, x1+w+(BAR_MARGIN/1.75)-padding, y1+h+BAR_MARGIN-padding, padding)
    
    local height = h - TOP_HEIGHT
    local teamNames = getTeamNames()
    teamIcons = {}
	for key,teamID in ipairs(teamList) do
	  if (teamID ~= myID or showSelf) then
		local _,active = GetPlayerInfo(teamID) 
		local xOffset = 0
		local opacityMultiplier = 1
		if showSelf then
			if (teamID == myID ) then 
				xOffset = xOffset + selfXoffset
			else
				xOffset = xOffset - selfXoffset
			end
		end
		local extraSize = 0
		if not active and gameFrame > 0 then
			extraSize = -3
		end
		gl.Color(teamColors[teamID].r,teamColors[teamID].g,teamColors[teamID].b,1*opacityMultiplier)
		gl.Texture(teamPic)
		gl.TexRect(x1+BAR_GAP+xOffset-extraSize, y1+height+extraSize, x1+TOP_HEIGHT+BAR_GAP+xOffset+extraSize, y1+height-TOTAL_BAR_HEIGHT-extraSize)
		gl.Texture(false)
		gl.Color(1,1,1,0.4*opacityMultiplier)
		gl.Texture(teamHighlightPic)
		gl.TexRect(x1+BAR_GAP+xOffset-extraSize, y1+height+extraSize, x1+TOP_HEIGHT+BAR_GAP+xOffset+extraSize, y1+height-TOTAL_BAR_HEIGHT-extraSize)
		gl.Texture(false)
		
		
		teamIcons[teamID] = 
		{
		 name = teamNames[teamID] or "No Player",
		 iy1 = y1+height+(BAR_GAP/2),
		 iy2 = y1+height-(BAR_GAP/2)-TOTAL_BAR_HEIGHT,
		}
		height = (height - TOTAL_BAR_HEIGHT - BAR_GAP)
	  end
	end
    gl.PopMatrix()
  end)
  updateGuishader()
end


local function updateBars()
  if (myID ~= GetMyTeamID()) then
    if setUpTeam() then
      updateStatics()
      updateBars()
    end
    return false 
  end
  local eCur, eMax, mCur, mMax
  local height = h - TOP_HEIGHT
  for key,teamID in ipairs(teamList) do
    if (teamID ~= myID or showSelf) then
      eCur, eMax = GetTeamResources(teamID, "energy")
      mCur, mMax = GetTeamResources(teamID, "metal")
      eCur = eCur + (sendEnergy[teamID] or 0)
      mCur = mCur + (sendMetal[teamID] or 0)
      
		
      local xoffset = (x1+BAR_OFFSET)
	  local opacityMultiplier = 1
      if showSelf then
		if (teamID == myID ) then 
			xoffset = xoffset + selfXoffset
		else
			xoffset = xoffset - selfXoffset
		end
	  end
      teamRes[teamID] = 
      {
        ex1  = xoffset,       
        ey1  = y1+height,
        ex2  = xoffset+BAR_WIDTH,
        ex2b = xoffset+(BAR_WIDTH * (eCur / eMax)),
        ey2  = y1+height-BAR_HEIGHT,
        mx1  = xoffset,
        my1  = y1+height-BAR_HEIGHT-BAR_SPACER,
        mx2  = xoffset+BAR_WIDTH,
        mx2b = xoffset+(BAR_WIDTH * (mCur / mMax)),
        my2  = y1+height-TOTAL_BAR_HEIGHT,
        om   = opacityMultiplier,
      }
      if (teamID == transferTeam) then
        if (transferType == "energy") then
          teamRes[teamID].eRec = true
        else
          teamRes[teamID].mRec = true
        end
      end
      height = (height - TOTAL_BAR_HEIGHT - BAR_GAP)
    end
  end
  if (height ~= 0) then
    h = (h - height)
    if prevHeight then
      --y1 = y1 - (h-prevHeight)
      prevHeight = nil
    else
      --y1 = (y1 + height)
    end
    updateStatics()
  end
  if (displayList) then gl.DeleteList(displayList) end
  displayList = gl.CreateList( function()
	gl.PushMatrix()
    for _,d in pairs(teamRes) do
      if d.eRec then
        gl.Color(0.8, 0, 0, 0.8*d.om)
      else
        gl.Color(0.8, 0.8, 0, 0.13*d.om)
      end
		--gl.Rect(d.ex1,d.ey1,d.ex2,d.ey2)
		gl.Texture(barBg)
		gl.TexRect(d.ex1,d.ey1,d.ex2,d.ey2)
		gl.Texture(false)
        gl.Color(1, 1, 0, 1*d.om)
      --gl.Rect(d.ex1,d.ey1,d.ex2b,d.ey2) 
		gl.Texture(bar)
		gl.TexRect(d.ex1,d.ey1,d.ex2b,d.ey2)
		gl.Texture(false)
      if d.mRec then
        gl.Color(0.8, 0, 0, 0.8*d.om)
      else
        gl.Color(0.8, 0.8, 0.8, 0.13*d.om)
      end
      --gl.Rect(d.mx1,d.my1,d.mx2,d.my2)
		gl.Texture(barBg)
		gl.TexRect(d.mx1,d.my1,d.mx2,d.my2)
		gl.Texture(false)
      gl.Color(1, 1, 1, 1*d.om)
      --gl.Rect(d.mx1,d.my1,d.mx2b,d.my2)
		gl.Texture(bar)
		gl.TexRect(d.mx1,d.my1,d.mx2b,d.my2)
		gl.Texture(false)
    end
    gl.PopMatrix()
  end)
end

function widget:TeamDied(teamID)
  deadTeams[teamID] = true
  if setUpTeam() then
    updateStatics()
    updateBars()
  end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
  if deadTeams[unitTeam] then
    deadTeams[unitTeam] = nil
    if setUpTeam() then
      updateStatics()
      updateBars()
    end
  end
end

local function transferResources(n)
  local sCur, sMax = GetTeamResources(transferTeam, transferType)
  local lCur, _, _, lInc, _, _, _, lRec = GetTeamResources(myID, transferType)
  if (transferType == "metal") then 
    lCur = (lCur - sentMetal)
    sCur = sCur + (sendMetal[transferTeam] or 0)
  else
    lCur = (lCur - sentEnergy)
    sCur = sCur + (sendEnergy[transferTeam] or 0)
  end
  local send = mathMin(mathMin((sMax-sCur),((lInc+lRec)*0.2)),lCur)
  if (send > 0) then
    if (transferType == "energy") then
      if sendEnergy[transferTeam] then
        sendEnergy[transferTeam] = (sendEnergy[transferTeam] + send)
      else
        sendEnergy[transferTeam] = send
        sentSomething = true
      end
      sentEnergy = (sentEnergy + send)
      trnsEnergy[transferTeam] = (send * 30)
    else
      if sendMetal[transferTeam] then
        sendMetal[transferTeam] = (sendMetal[transferTeam] + send)
      else
        sendMetal[transferTeam] = send
        sentSomething = true
      end
      sentMetal = (sentMetal + send)
      trnsMetal[transferTeam] = (send * 30)
    end
  end
end

function widget:GameFrame(n)
	gameFrame = n
    if n == 1 then
        enabled = true
        setUpTeam()
        updateStatics()
    end
end

function widget:Update()
	
  if (gameFrame ~= lastFrame or doUpdate) then
    if enabled then
	  lastFrame = gameFrame
	  updateBars()
	  if transferTeam then
	    transferResources(gameFrame)
	  end
	  if sentSomething and ((gameFrame % 16) == 0) then
	    for teamID,send in pairs(sendEnergy) do
		  ShareResources(teamID,"energy",send)
	    end
	    for teamID,send in pairs(sendMetal) do
	      ShareResources(teamID,"metal",send)
	    end
	    sendEnergy = {}
	    sendMetal = {}
	    trnsEnergy = {}
	    trnsMetal = {}
	    sentEnergy = 0
	    sentMetal = 0
	    sentSomething = false
	  end
	  if TOOL_TIPS then
	    local x, y = GetMouseState()
	    if (mx ~= x) or (my ~= y) or transferring or ((gameFrame % 15) == 0) then
		  mx = x
		  my = y
		  if (x > x1 + BAR_GAP) and (y > y1 + (BAR_GAP/2)) and (x < (x1 + FULL_BAR)) and (y < (y1 + h - TOP_HEIGHT) + (BAR_GAP/2)) then
		    for teamID,defs in pairs(teamIcons) do
			  if (y < defs.iy1) and (y >= defs.iy2) then
			    local eCur, _, _, eInc, _, _, _, eRec = GetTeamResources(teamID, "energy")
			    local mCur, _, _, mInc, _, _, _, mRec = GetTeamResources(teamID, "metal")
			    eRec = eRec + (trnsEnergy[teamID] or 0)
			    mRec = mRec + (trnsMetal[teamID] or 0)      
			    labelText[1] = 
			    {
				  label="\255\255\255\255"..defs.name,
				  x=x1-BAR_GAP-BAR_MARGIN,
				  y=defs.iy1-BAR_SPACER,
				  size=TOTAL_BAR_HEIGHT*1.55,
				  config="orn",
			    }
			    labelText[2] = 
			    {
				  label="\255\255\255\000E  + "..math.floor(sF("%.1f",eInc+eRec)).."\n\255\255\255\000      "..math.floor(sF("%.2f",eCur)).."\n\255\210\210\210M  + "..math.floor(sF("%.2f",mInc+mRec)).."\n\255\210\210\210     "..math.floor(sF("%.2f",mCur)),
				  x=x1-BAR_GAP-BAR_MARGIN, 
				  y=defs.iy1-BAR_SPACER-(TOTAL_BAR_HEIGHT*1.5),
				  size=TOTAL_BAR_HEIGHT*1.4, 
				  config="orn",
			    }
			    return
			  end
		    end
		    if (labelText) then labelText = {} end
		  elseif (labelText) then labelText = {} end
	    end
	  end
    elseif (#GetTeamList(GetMyAllyTeamID()) > 1) then
	  setUpTeam()
	  updateStatics()
	  updateBars()
    end
  end
  doUpdate = false
end


function widget:DrawScreen()
  if enabled and (not IsGUIHidden()) then
      gl.CallList(staticList)
      gl.CallList(displayList)
      if (labelText[1]) then
        gl.PushMatrix()
        gl.Color(1, 1, 1, 0.8)
        gl.Text(labelText[1].label,labelText[1].x,labelText[1].y,labelText[1].size,labelText[1].config)
        gl.Color(0.8, 0.8, 0.8, 0.8)
        gl.Text(labelText[2].label,labelText[2].x,labelText[2].y,labelText[2].size,labelText[2].config)
        gl.PopMatrix()
      end
  else
	updateGuishader()
  end
end


function widget:TweakMouseMove(x, y, dx, dy, button)
	if (enabled) then
		x1 = x1 + dx
		y1 = y1 + dy

		coords2Percentage()
		updateGuishader()
		updateBars()
		updateStatics()
	end
end

function widget:MouseMove(x, y, dx, dy, button)
  if (enabled and button == 1) then
    if transferring then
      transferTeam = nil
      if (x > (x1+BAR_OFFSET)) and (x < (x1+BAR_OFFSET+BAR_WIDTH)) then
        if (transferType == "energy") then
          for teamID,defs in pairs(teamRes) do
            if (y < defs.ey1) and (y > defs.ey2) then
              transferTeam = teamID
              return
            end
          end
        else
          for teamID,defs in pairs(teamRes) do
            if (y < defs.my1) and (y > defs.my2) then
              transferTeam = teamID
              return
            end
          end
        end
      end      
    end
  end
end

function widget:TweakMousePress(x, y, button)

  if Spring.IsGUIHidden() then return end
  
  if (enabled and (button == 2 or button == 3)) 
	  and (x > x1+BAR_GAP-BAR_MARGIN-(bgcornerSize*0.75))
	  and (y > y1+BAR_GAP-BAR_MARGIN-(bgcornerSize*0.75)) 
	  and (x < x1+(w-BAR_GAP+BAR_MARGIN+(bgcornerSize*0.75))) 
	  and (y < y1+(h-BAR_GAP+BAR_MARGIN+(bgcornerSize*0.75))) 
  then
      return true
  end
end

function widget:MousePress(x, y, button)

  if Spring.IsGUIHidden() then return end
  
  if (enabled and button == 1) 
	  and (x > x1+BAR_GAP-BAR_MARGIN-(bgcornerSize*0.75))
	  and (y > y1+BAR_GAP-BAR_MARGIN-(bgcornerSize*0.75)) 
	  and (x < x1+(w-BAR_GAP+BAR_MARGIN+(bgcornerSize*0.75))) 
	  and (y < y1+(h-BAR_GAP+BAR_MARGIN+(bgcornerSize*0.75))) 
  then
    if GetSpectatingState() or IsReplay() then
      return false
    end
    if (x > (x1+BAR_OFFSET)) and (x < (x1+BAR_OFFSET+BAR_WIDTH)) then
      for teamID,defs in pairs(teamRes) do
        if (y < defs.ey1) and (y >= defs.ey2) then
          transferTeam = teamID
          transferType = "energy"
          transferring = true
          return true
        elseif (y < defs.my1) and (y >= defs.my2) then
          transferTeam = teamID
          transferType = "metal"
          transferring = true
          return true
        end
      end
    end
  end
  return false
end

function widget:MouseRelease(x, y, button)
  transferring = false
  transferTeam = nil
end

function percentage2Coords()
    x1 = (vsx * xPercentage) / 100
    y1 = (vsy * yPercentage) / 100
    correctPosition()
end 

function coords2Percentage()
	xPercentage = (((x1 - vsx) / vsx) * 100) + 100
	yPercentage = (((y1 - vsy) / vsy) * 100) + 100
	correctPosition()
end

function correctPosition()
	if (x1 < 0) then x1 = 0 elseif ((x1+w) > vsx) then x1 = (vsx-w) end
	if (y1 < 0) then y1 = 0 elseif ((y1+h) > vsy) then y1 = (vsy-h) end
	xPercentage = (((x1 - vsx) / vsx) * 100) + 100
	yPercentage = (((y1 - vsy) / vsy) * 100) + 100
end


function widget:IsAbove(mx, my)
	local xPos = x1+BAR_GAP-BAR_MARGIN-(bgcornerSize*0.75)
	local yPos = y1+BAR_GAP-BAR_MARGIN-(bgcornerSize*0.75)
	local x2Pos = x1+(w-BAR_GAP+BAR_MARGIN+(bgcornerSize*0.75))
	local y2Pos = y1+(h-BAR_GAP+BAR_MARGIN+(bgcornerSize*0.75))
	return mx > xPos and my > yPos and mx < x2Pos and my < y2Pos
end

function widget:GetTooltip(mx, my)
	if widget:IsAbove(mx,my) then
		return string.format("In CTRL+F11 mode: Hold \255\255\255\1middle mouse button\255\255\255\255 to drag this display.\n\n"..
			"The current selected player is extruded to the left. (YOU)")
	end
end


function processScaling()
  vsx,vsy = Spring.GetViewGeometry()
  if customScale == nil then
	customScale = 1
  end
  sizeMultiplier   = 2.6 + (vsx*vsy / 2330000) * customScale
  
  selfXoffset	   = -math.floor(sizeMultiplier)
  
  BAR_HEIGHT       = math.floor(1*sizeMultiplier)
  BAR_SPACER       = math.floor(1*sizeMultiplier)
  BAR_WIDTH        = math.floor(14*sizeMultiplier)
  BAR_GAP          = math.floor(3*sizeMultiplier)
  BAR_MARGIN       = 0 --math.floor(1*sizeMultiplier)
  bgcornerSize     = math.floor(2*sizeMultiplier)
  
  TOTAL_BAR_HEIGHT = (BAR_SPACER + BAR_HEIGHT + BAR_HEIGHT)
  TOP_HEIGHT       = (BAR_GAP)
  BAR_OFFSET       = (TOP_HEIGHT + BAR_SPACER + BAR_GAP)
  START_HEIGHT     = (TOTAL_BAR_HEIGHT + BAR_GAP + TOP_HEIGHT)
  FULL_BAR         = (BAR_WIDTH + BAR_GAP + BAR_GAP + BAR_SPACER)
  w                = (BAR_WIDTH + BAR_OFFSET + BAR_GAP)
  h                = START_HEIGHT
  
  updateBars()  -- to calculate height
  
  percentage2Coords()
  
  doUpdate = true
  
  setUpTeam()
  updateBars()
  updateStatics()
  updateGuishader()
end

function widget:ViewResize(viewSizeX, viewSizeY)
  vsx, vsy = viewSizeX, viewSizeY
  processScaling()
end


function widget:TextCommand(command)
    if (string.find(command, "allyresbars_sizeup") == 1  and  string.len(command) == 18) then 
		customScale = customScale + 0.2
		processScaling()
	end
    if (string.find(command, "allyresbars_sizedown") == 1  and  string.len(command) == 20) then 
		customScale = customScale - 0.2
		if customScale < 0.5 then 
			customScale = 0.5
		end
		processScaling()
	end
end

function widget:GetConfigData() --save config
  return {xPercentage=xPercentage, yPercentage=yPercentage, h=h, customScale=customScale}
end

function widget:SetConfigData(data) --load config
  if (data.xPercentage) and (data.yPercentage) and (data.h) then
    xPercentage = data.xPercentage
    yPercentage = data.yPercentage
    customScale = data.customScale  
    vsx, vsy = gl.GetViewSizes()
    percentage2Coords()
    prevHeight = data.h
    posLoaded = true
  end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
