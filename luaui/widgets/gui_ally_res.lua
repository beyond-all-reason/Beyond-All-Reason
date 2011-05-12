--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    gui_allu_res.lua
--  brief:   Shows your allies resources and allows quick resource transfer
--  author:  Owen Martindell
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "Ally Resource Bars",
    desc      = "Shows your allies resources and allows quick resource transfer (v1.4)",
    author    = "TheFatController & AF",
    date      = "July 2, 2010",
    license   = "MIT/x11",
    layer     = -9,
    enabled   = false  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local TOOL_TIPS = true

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
local mathMin = math.min
local gl, GL = gl, GL
local sF = string.format

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local displayList
local staticList
local viewSizeX, viewSizeY = 0,0
local BAR_HEIGHT       = 6
local BAR_SPACER       = 3
local BAR_WIDTH        = 120
local BAR_GAP          = 7
local TOTAL_BAR_HEIGHT = (BAR_SPACER + BAR_HEIGHT + BAR_HEIGHT)
local TOP_HEIGHT       = (BAR_GAP + BAR_GAP)
local BAR_OFFSET       = (TOP_HEIGHT + BAR_SPACER)
local START_HEIGHT     = (TOTAL_BAR_HEIGHT + BAR_GAP + TOP_HEIGHT)
local FULL_BAR         = (BAR_WIDTH + BAR_GAP + BAR_GAP + BAR_SPACER)
local w                = (BAR_WIDTH + BAR_OFFSET + BAR_GAP)
local h                = START_HEIGHT
local x1               = - w
local y1               = - h - 31
local mx, my
local sentSomething = false
local enabled       = false
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
local myID

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

function widget:Initialize()
  x1 = math.floor(x1 - viewSizeX)
  y1 = math.floor(y1 - viewSizeY)
  viewSizeX, viewSizeY = gl.GetViewSizes()
  x1 = viewSizeX + x1
  y1 = viewSizeY + y1
  myID = GetMyTeamID()
end

function widget:Shutdown()
  gl.DeleteList(displayList)
end

local function setUpTeam()
  teamList = {}
  teamRes = {}
  teamColors = {}
  myID = GetMyTeamID()
  local getTeams = nil
  local teamCount = 0
  mx, my = 0,0
  if GetSpectatingState() then
   local alist = Spring.GetAllyTeamList()
   for _,allyID in pairs(alist) do
     getTeams = Spring.GetTeamList(allyID)
     if getTeams ~= nil then
       for _,teamID in pairs(getTeams) do
          --local eCur = GetTeamResources(teamID, "energy")
          --if eCur and (not deadTeams[teamID]) then
        if not deadTeams[teamID] then
            teamList[teamID] = true
            teamCount = (teamCount + 1)
          end
        end
     end
   end
  else
   getTeams = Spring.GetTeamList(Spring.GetMyAllyTeamID())
   for _,teamID in pairs(getTeams) do
      local eCur = GetTeamResources(teamID, "energy")
      if eCur and (not deadTeams[teamID]) then
        teamList[teamID] = true
        teamCount = (teamCount + 1)
      end
    end
  end

  for teamID in pairs(teamList) do
    local r,g,b = Spring.GetTeamColor(teamID)
    teamColors[teamID] = {r=r,g=g,b=b}
  end
  if (teamCount > 1) then
    enabled = true
    return true
  else
    enabled = false
    return false
  end
end

local function updateStatics()
  if (staticList) then gl.DeleteList(staticList) end
  staticList = gl.CreateList( function()
    gl.Color(0.2, 0.2, 0.2, 0.8)
    gl.Rect(x1, y1, x1+w,y1+h)
    local height = h - TOP_HEIGHT
    local teamNames = getTeamNames()
    teamIcons = {}
    for teamID in pairs(teamList) do
      if (teamID ~= myID or GetSpectatingState()) then
        gl.Color(teamColors[teamID].r,teamColors[teamID].g,teamColors[teamID].b,1)
        gl.Rect(x1+BAR_GAP,y1+height,x1+TOP_HEIGHT,y1+height-TOTAL_BAR_HEIGHT)
        teamIcons[teamID] =
        {
         name = teamNames[teamID] or "No Player",
         iy1 = y1+height,
         iy2 = y1+height-TOTAL_BAR_HEIGHT,
        }
        height = (height - TOTAL_BAR_HEIGHT - BAR_GAP)
      end
    end
  end)
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
  for teamID in pairs(teamList) do
    if (teamID ~= myID or GetSpectatingState()) then
      eCur, eMax = GetTeamResources(teamID, "energy")
      mCur, mMax = GetTeamResources(teamID, "metal")
      eCur = eCur + (sendEnergy[teamID] or 0)
      mCur = mCur + (sendMetal[teamID] or 0)
      local xoffset = (x1+BAR_OFFSET)
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
    y1 = (y1 + height)
    updateStatics()
  end
  if (displayList) then gl.DeleteList(displayList) end
  displayList = gl.CreateList( function()
    for _,d in pairs(teamRes) do
      if d.eRec then
        gl.Color(0.8, 0, 0, 0.8)
      else
        gl.Color(0.8, 0.8, 0, 0.3)
      end
      gl.Rect(d.ex1,d.ey1,d.ex2,d.ey2)
      gl.Color(1, 1, 0, 1)
      gl.Rect(d.ex1,d.ey1,d.ex2b,d.ey2)
      if d.mRec then
        gl.Color(0.8, 0, 0, 0.8)
      else
        gl.Color(0.8, 0.8, 0.8, 0.3)
      end
      gl.Rect(d.mx1,d.my1,d.mx2,d.my2)
      gl.Color(1, 1, 1, 1)
      gl.Rect(d.mx1,d.my1,d.mx2b,d.my2)
    end
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
  if enabled then
    updateBars()
    if transferTeam then
      transferResources(n)
    end
    if sentSomething and ((n % 16) == 0) then
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
      if (mx ~= x) or (my ~= y) or transferring or ((n % 15) == 0) then
        mx = x
        my = y
        if (x > x1 + BAR_GAP) and (y > y1 + BAR_GAP) and (x < (x1 + FULL_BAR)) and (y < (y1 + h - TOP_HEIGHT)) then
          for teamID,defs in pairs(teamIcons) do
            if (y < defs.iy1) and (y >= defs.iy2) then
              local _, _, _, eInc, _, _, _, eRec = GetTeamResources(teamID, "energy")
              local _, _, _, mInc, _, _, _, mRec = GetTeamResources(teamID, "metal")   
              eRec = eRec + (trnsEnergy[teamID] or 0)
              mRec = mRec + (trnsMetal[teamID] or 0)     
              labelText[1] =
              {
                label=defs.name,
                x=x1-BAR_SPACER,
                y=defs.iy2-1,
                size=TOTAL_BAR_HEIGHT,
                config="orn",
              }
              labelText[2] =
              {
                label="(E: +"..sF("%.1f",eInc+eRec) ..", M: +"..sF("%.2f",mInc+mRec)..")",
                x=x1-BAR_SPACER,
                y=defs.iy2-TOTAL_BAR_HEIGHT,
                size=TOTAL_BAR_HEIGHT/1.25,
                config="orn",
              }
              return
            end
          end
          if (labelText) then labelText = {} end
        elseif (labelText) then labelText = {} end
      end
    end
  elseif (#Spring.GetTeamList(Spring.GetMyAllyTeamID()) > 1) then
    setUpTeam()
    updateStatics()
    updateBars()
  end
end

function widget:GameStart()
  enabled = true
  setUpTeam()
  updateStatics()
end

function widget:DrawScreen()
  if enabled and (not IsGUIHidden()) then
    gl.PushMatrix()
      gl.CallList(staticList)
      gl.CallList(displayList)
      if (labelText[1]) then
        gl.Color(1, 1, 1, 0.8)
        gl.Text(labelText[1].label,labelText[1].x,labelText[1].y,labelText[1].size,labelText[1].config)
        gl.Color(0.8, 0.8, 0.8, 0.8)
        gl.Text(labelText[2].label,labelText[2].x,labelText[2].y,labelText[2].size,labelText[2].config)
      end
    gl.PopMatrix()
  end
end

function widget:MouseMove(x, y, dx, dy, button)
  if (enabled) then
    if moving then
      x1 = x1 + dx
      y1 = y1 + dy
      updateBars()
      updateStatics()
    elseif transferring then
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

function widget:MousePress(x, y, button)
  if (enabled) and ((x > x1) and (y > y1) and (x < (x1 + w)) and (y < (y1 + h))) then
    if y > (y1 + h - TOP_HEIGHT) then
      capture = true
      moving  = true
      return capture
    end
    if GetSpectatingState() or IsReplay() then
      if (x > (x1+BAR_OFFSET)) and (x < (x1+BAR_OFFSET+BAR_WIDTH)) then
        for teamID,defs in pairs(teamRes) do
          if (y < defs.ey1) and (y >= defs.ey2) then
          local tid = teamID
         Spring.SendCommands('specteam '..tid)
            --transferTeam = teamID
            --transferType = "energy"
            --transferring = true
            return true
          elseif (y < defs.my1) and (y >= defs.my2) then
            local tid = teamID
         Spring.SendCommands('specteam '..tid)
         --transferTeam = teamID
            --transferType = "metal"
            --transferring = true
            return true
          end
        end
      end
     --return false
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
  capture = nil
  moving  = nil
  transferring = false
  transferTeam = nil
  return capture
end

function widget:ViewResize(vsx, vsy)
  x1 = math.floor(x1 - viewSizeX)
  y1 = math.floor(y1 - viewSizeY)
  viewSizeX, viewSizeY = vsx, vsy
  x1 = viewSizeX + x1
  y1 = viewSizeY + y1
  updateBars()
  updateStatics()
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------