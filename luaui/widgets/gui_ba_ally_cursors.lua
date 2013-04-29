--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "BA_AllyCursors",
    desc      = "Shows the mouse pos of allied players",
    author    = "jK,TheFatController",
    date      = "Apr,2009",
    license   = "GNU GPL, v2 or later",
    layer     = 50,
    enabled   = true,
	handler   = true
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- configs

local sendPacketEvery = 0.8
local numMousePos     = 2 --//num mouse pos in 1 packet

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- locals

local pairs = pairs

local GetMouseState   = Spring.GetMouseState
local TraceScreenRay  = Spring.TraceScreenRay
local SendLuaUIMsg    = Spring.SendLuaUIMsg
local GetGameFrame    = Spring.GetGameFrame
local GetGroundHeight = Spring.GetGroundHeight
local GetPlayerInfo   = Spring.GetPlayerInfo
local GetTeamColor    = Spring.GetTeamColor
local IsSphereInView  = Spring.IsSphereInView
local GetSpectatingState = Spring.GetSpectatingState
local GetMyPlayerID      = Spring.GetMyPlayerID
local GetMyTeamID 	 	 = Spring.GetMyTeamID
local GetPlayerRoster 	 = Spring.GetPlayerRoster

local glTexCoord      = gl.TexCoord
local glVertex        = gl.Vertex
local glPolygonOffset = gl.PolygonOffset
local glDepthTest     = gl.DepthTest
local glTexture       = gl.Texture
local glColor         = gl.Color
local glBeginEnd      = gl.BeginEnd

local floor = math.floor
local tanh  = math.tanh
local GL_QUADS = GL.QUADS

local clock = os.clock

local spec = false

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function CubicInterpolate2(x0,x1,mix)
  local mix2 = mix*mix;
  local mix3 = mix2*mix;

  return x0*(2*mix3-3*mix2+1) + x1*(3*mix2-2*mix3);
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local alliedCursorsPos = {}

local newPos = {}
function widget:RecvLuaMsg(msg, playerID)
  if (msg:sub(1,1)=="£")
  then
    if (playerID==GetMyPlayerID()) or select(3,GetPlayerInfo(playerID)) then return true end
    local xz = msg:sub(3)

    local l = xz:len()*0.25
    if (l==numMousePos) then
      for i=0,numMousePos-1 do
        local x = VFS.UnpackU16(xz:sub(i*4+1,i*4+2))
        local z = VFS.UnpackU16(xz:sub(i*4+3,i*4+4))
        newPos[i*2+1]   = x
        newPos[i*2+2] = z
      end

      if (alliedCursorsPos[playerID]) then
        local acp = alliedCursorsPos[playerID]

        acp[(numMousePos)*2+1]   = acp[1]
        acp[(numMousePos)*2+2]   = acp[2]

        for i=0,numMousePos-1 do
          acp[i*2+1] = newPos[i*2+1]
          acp[i*2+2] = newPos[i*2+2]
        end

        acp[(numMousePos+1)*2+1] = clock()
        acp[(numMousePos+1)*2+2] = (msg:sub(2,2)=="1")
      else
        local acp = {}
        alliedCursorsPos[playerID] = acp

        for i=0,numMousePos-1 do
          acp[i*2+1] = newPos[i*2+1]
          acp[i*2+2] = newPos[i*2+2]
        end

        acp[(numMousePos)*2+1]   = newPos[(numMousePos-2)*2+1]
        acp[(numMousePos)*2+2]   = newPos[(numMousePos-2)*2+2]

        acp[(numMousePos+1)*2+1] = clock()
        acp[(numMousePos+1)*2+2] = (msg:sub(2,2)=="1")
        _,_,_,acp[(numMousePos+1)*2+3] = GetPlayerInfo(playerID)
      end
    end
    return true
  end
end

--------------------------------------------------------------------------------

local updateTimer = 0
local poshistory = {}

local saveEach = sendPacketEvery/numMousePos
local updateTick = saveEach

local lastx,lastz = 0,0
local n = 0
local lastclick = 0

function widget:Initialize()
  for i, widget in ipairs(widgetHandler.widgets) do
    if (widget:GetInfo().name == 'AllyCursors') then
      widgetHandler:RemoveWidget(widget)
    end
  end
end

function widget:Update(t)
  if spec then return end
  updateTimer = updateTimer + t

  if (updateTimer>updateTick) then
    local mx,my = GetMouseState()
    local _,pos = TraceScreenRay(mx,my,true)

    if (pos~=nil) then
      poshistory[n*2]   = VFS.PackU16(floor(pos[1]))
      poshistory[n*2+1] = VFS.PackU16(floor(pos[3]))
      if n == numMousePos then
        lastx,lastz = pos[1],pos[3]
      end
      n = n + 1
    end
    
    updateTick = (updateTimer + saveEach)
  end
    
  if (n>numMousePos) then
    n = 0
    updateTimer = 0
    updateTick = saveEach
    
    local posStr = "0"
  
    for i=numMousePos,1,-1 do
      local xStr = poshistory[i*2]
      local zStr = poshistory[i*2+1]
      if (xStr and zStr) then posStr = posStr .. xStr .. zStr end
    end
    SendLuaUIMsg("£" .. posStr,"allies")
   
  end
  
  if (GetSpectatingState()) then
    spec = true
    return
  end
end

local QSIZE = 12

local function DrawGroundquad(wx,gy,wz)
  -- get ground heights
  local gy_tl,gy_tr = GetGroundHeight(wx-QSIZE,wz-QSIZE),GetGroundHeight(wx+QSIZE,wz-QSIZE)
  local gy_bl,gy_br = GetGroundHeight(wx-QSIZE,wz+QSIZE),GetGroundHeight(wx+QSIZE,wz+QSIZE)
  local gy_t,gy_b = GetGroundHeight(wx,wz-QSIZE),GetGroundHeight(wx,wz+QSIZE)
  local gy_l,gy_r = GetGroundHeight(wx-QSIZE,wz),GetGroundHeight(wx+QSIZE,wz)

  --topleft
  glTexCoord(0,0)
  glVertex(wx-QSIZE,gy_bl,wz-QSIZE)
  glTexCoord(0,0.5)
  glVertex(wx-QSIZE,gy_l,wz)
  glTexCoord(0.5,0.5)
  glVertex(wx,gy,wz)
  glTexCoord(0.5,0)
  glVertex(wx,gy_t,wz-QSIZE)

  --topright
  glTexCoord(0.5,0)
  glVertex(wx,gy_t,wz-QSIZE)
  glTexCoord(0.5,0.5)
  glVertex(wx,gy,wz)
  glTexCoord(1,0.5)
  glVertex(wx+QSIZE,gy_r,wz)
  glTexCoord(1,0)
  glVertex(wx+QSIZE,gy_tr,wz-QSIZE)

  --bottomright
  glTexCoord(0.5,0.5)
  glVertex(wx,gy,wz)
  glTexCoord(0.5,1)
  glVertex(wx,gy_b,wz+QSIZE)
  glTexCoord(1,1)
  glVertex(wx+QSIZE,gy_br,wz+QSIZE)
  glTexCoord(1,0.5)
  glVertex(wx+QSIZE,gy_r,wz)

  --bottomleft
  glTexCoord(0.5,0)
  glVertex(wx-QSIZE,gy_l,wz)
  glTexCoord(1,0)
  glVertex(wx-QSIZE,gy_bl,wz+QSIZE)
  glTexCoord(1,0.5)
  glVertex(wx,gy_b,wz+QSIZE)
  glTexCoord(0.5,0.5)
  glVertex(wx,gy,wz)
end


local teamColors = {}
local function SetTeamColor(teamID,a)
  local color = teamColors[teamID]
  if (color) then
    color[4]=a
    glColor(color)
    return
  end
  local r, g, b = Spring.GetTeamColor(teamID)
  if (r and g and b) then
    color = { r, g, b }
    teamColors[teamID] = color
    glColor(color)
    return
  end
end

function widget:MousePress(x,y,button)
  if spec then return false end
  if (button ~= 2) then
    local mx,my = GetMouseState()
    local _,pos = TraceScreenRay(mx,my,true)

    if (pos~=nil) then
      if (math.abs(pos[1] - lastx) > 300) or (math.abs(pos[3] - lastz) > 300) then
        poshistory[0] = VFS.PackU16(floor(pos[1]))
        poshistory[1] = VFS.PackU16(floor(pos[3]))
        poshistory[2] = VFS.PackU16(floor(pos[1]))
        poshistory[3] = VFS.PackU16(floor(pos[3]))
        poshistory[4] = VFS.PackU16(floor(pos[1]))
        poshistory[5] = VFS.PackU16(floor(pos[3]))
        lastx,lastz = pos[1],pos[3]
        updateTick = saveEach
        updateTimer = 0
        n = 0
        local posStr = "0"
        for i=numMousePos,1,-1 do
          local xStr = poshistory[i*2]
          local zStr = poshistory[i*2+1]
          if (xStr and zStr) then posStr = posStr .. xStr .. zStr end
        end
        SendLuaUIMsg("£" .. posStr,"allies") 
      end     
    end
  end
  return false
end

function widget:DrawWorldPreUnit()
  glDepthTest(true)
  glTexture('LuaUI/Images/AlliedCursors.png')
  glPolygonOffset(-7,-10)
  local time = clock()
  local isally = {}
  local fullView = false
  if spec then 
	_,NOTfullView,_ = GetSpectatingState()
	fullView = not NOTfullView --HOTFIX FOR 94.0/1: Spring returns the second argument of GetSpectatingState with true/false swapped. http://springrts.com/mantis/view.php?id=3753.
	if fullView then 
	    local specTeamID=GetMyTeamID()
	    local roster = GetPlayerRoster()
		local specAllyTeamID = -1
		for _,playerTable in ipairs(roster) do
			if playerTable[3] == specTeamID then
				specAllyTeamID = playerTable[4]
				break
			end
		end
	    for _,playerTable in ipairs(roster) do
	  	  	local playerID = playerTable[2]
			local teamID = playerTable[3]
			local allyTeamID = playerTable[4]
			if playerID and allyTeamID then isally[playerID] = (allyTeamID == specAllyTeamID) end
	    end
	end
  end
  for playerID,data in pairs(alliedCursorsPos) do
	if (not fullView) or isally[playerID] then 
		local teamID = data[#data]
		for n=0,5 do
		  local wx,wz = data[1],data[2]
		  local lastUpdatedDiff = time-data[#data-2] + n*0.025

		  if (lastUpdatedDiff<sendPacketEvery) then
			local scale  = (1-(lastUpdatedDiff/sendPacketEvery))*numMousePos
			local iscale = math.min(floor(scale),numMousePos-1)
			local fscale = scale-iscale

			wx = CubicInterpolate2(data[iscale*2+1],data[(iscale+1)*2+1],fscale)
			wz = CubicInterpolate2(data[iscale*2+2],data[(iscale+1)*2+2],fscale)
		  end

		  local gy = GetGroundHeight(wx,wz)
		  if (IsSphereInView(wx,gy,wz,QSIZE)) then
			SetTeamColor(teamID,n*0.1)
			glBeginEnd(GL_QUADS,DrawGroundquad,wx,gy,wz)
		  end
		end
	end
  end

  glPolygonOffset(false)
  glTexture(false)
  glDepthTest(false)
end            

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
