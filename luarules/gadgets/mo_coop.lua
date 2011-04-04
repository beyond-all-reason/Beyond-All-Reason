--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "MultiCom",
    desc      = "One Commander for each playerID per team",
    author    = "TheFatController",
    date      = "APR 20, 2009",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if gadgetHandler:IsSyncedCode() then

local enabled = tonumber(Spring.GetModOptions().mo_coop) or 0

if (enabled == 0) then 
  return false
end

local COMMANDER = {
  [UnitDefNames["corcom"].id] = true,
  [UnitDefNames["armcom"].id] = true,
}
local comStrings = {
  [1] = "corcom",
  [2] = "armcom",
}
local CMD_SELFD = CMD.SELFD
local CMD_INSERT = CMD.INSERT
local GetGameFrame = Spring.GetGameFrame
local GetUnitSelfDTime = Spring.GetUnitSelfDTime

local startPoints = {}
local allowSelfD = {}
local preStart = true

local excludeTeams = {}

for _, teamID in ipairs(Spring.GetTeamList()) do
  local playerCount = 0
  for _, playerID in ipairs(Spring.GetPlayerList(teamID)) do
    if not select(3,Spring.GetPlayerInfo(playerID)) then
      playerCount = playerCount + 1
    end
  end
  if (playerCount < 2) then excludeTeams[teamID] = true end
end

for _, teamID in ipairs(Spring.GetTeamList()) do
  if not excludeTeams[teamID] then
    for _, playerID in ipairs(Spring.GetPlayerList(teamID)) do
      if not select(3,Spring.GetPlayerInfo(playerID)) then
        startPoints[playerID] = {teamID = teamID, commander = comStrings[math.random(2)]}
      end
    end
  end
end

function gadget:GameStart()
  preStart = false
  SendToUnsynced("gamestart")
  for playerID, defs in pairs(startPoints) do
    local nudge = false
    if not defs.x then
      defs.x, defs.y, defs.z = Spring.GetTeamStartPosition(defs.teamID)
      nudge = true  
    end
    local commanderID = Spring.CreateUnit(defs.commander, defs.x, defs.y, defs.z, 1, defs.teamID)
    if nudge then
      Spring.GiveOrderToUnit(commanderID,CMD.MOVE,{defs.x+(math.random(200)-100), defs.y, defs.z+(math.random(200)-100)}, {""})
    end
  end
end

function gadget:GameFrame(n)
  if (n == 15) then
    for _, teamID in ipairs(Spring.GetTeamList()) do
      local mMax = select(2,Spring.GetTeamResources(teamID, "metal"))
      Spring.SetTeamResource(teamID, "m", mMax)
      local eMax = select(2,Spring.GetTeamResources(teamID, "energy"))
      Spring.SetTeamResource(teamID, "e", eMax)
    end
    gadgetHandler:RemoveCallIn("UnitCreated")
    gadgetHandler:RemoveCallIn("GameFrame")
  end
end

function gadget:RecvLuaMsg(msg, id)
  if preStart and startPoints[id] then
    if (msg:find("coop_startpoint",1,true)) then
      local x,z,name,playerID = string.match(msg, ",([^,]+),([^,]+),([^,]+),([^,]+)")
      playerID = (playerID * 1)
      x = (x * 1)
      z = (z * 1)
      if (id == playerID) then
        local allyID = select(5,Spring.GetPlayerInfo(playerID))
        local xn, zn, xp, zp = Spring.GetAllyTeamStartBox(allyID)
        if x < xn then x = xn elseif x > xp then x = xp end
        if z < zn then z = zn elseif z > zp then z = zp end
        SendToUnsynced("startpoint",x,z,name,playerID,startPoints[playerID].commander)
        startPoints[playerID].x = x
        startPoints[playerID].y = Spring.GetGroundHeight(x,z)
        startPoints[playerID].z = z
      end
    elseif (msg:find("coop_factionchange",1,true)) then
      local playerID = string.match(msg, ",([^,]+)")
      if id == (playerID * 1) then
        if startPoints[id].commander == "armcom" then
          startPoints[id].commander = "corcom"
        else
          startPoints[id].commander = "armcom"
        end
        SendToUnsynced("factionchange",id,startPoints[id].commander)
      end 
    end 
  elseif (msg:find("coop_selfd",1,true)) then
    local playerID,teamID,unitCount = string.match(msg, ",([^,]+),([^,]+),([^,]+)")
    playerID = (playerID * 1)
    teamID = (teamID * 1)
    if (playerID == id) then
      SendToUnsynced("selfdnotify",playerID,teamID,(unitCount * 1))
      allowSelfD[teamID] = Spring.GetGameFrame()
    end
  end
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, synced)
  if synced or excludeTeams[teamID] then return true end
  if (cmdID == CMD_SELFD) then
    if ((GetGameFrame() - (allowSelfD[teamID] or 0)) <= 30) or (GetUnitSelfDTime(unitID) > 0) then
      return true
    else
      return false
    end
  elseif (cmdID == CMD_INSERT) and (CMD_SELFD == cmdParams[2]) then
    return false
  end
  return true
end


-----
else
-----

local enabled = tonumber(Spring.GetModOptions().mo_coop) or 0

if (enabled == 0) then 
  return false
end

local isspec = false
local checkSelfD = false
local preStart = true
local coneList = 0
local xformList = 0
local startPoints = {}
local selfDunits = {}
local teamColorStrs = {}
local teamColors = {}
local excludeTeams = {}
local validStartPoint = {}
local CMD_SELFD = CMD.SELFD
local gaiaTeamID = Spring.GetGaiaTeamID()
local myPlayerID = Spring.GetMyPlayerID()
local myTeamID = Spring.GetMyTeamID()
local msx = Game.mapSizeX
local msz = Game.mapSizeZ

local GetUnitPosition = Spring.GetUnitPosition
local GetUnitSelfDTime = Spring.GetUnitSelfDTime
local GetUnitRadius = Spring.GetUnitRadius
local GetSelectedUnits = Spring.GetSelectedUnits
local AreTeamsAllied = Spring.AreTeamsAllied
local DrawGroundCircle = gl.DrawGroundCircle

for _, teamID in ipairs(Spring.GetTeamList()) do
  local playerCount = 0
  for _, playerID in ipairs(Spring.GetPlayerList(teamID)) do
    if not select(3,Spring.GetPlayerInfo(playerID)) then
      playerCount = playerCount + 1
    end
  end
  if (playerCount < 2) then excludeTeams[teamID] = true end
end

local function GetTeamColorStr(teamID)
  local colorSet = teamColorStrs[teamID]
  if (colorSet) then
    return colorSet[1], colorSet[2]
  end

  local outlineChar = ''
  local r,g,b = Spring.GetTeamColor(teamID)
  if (r and g and b) then
    local function ColorChar(x)
      local c = math.floor(x * 255)
      c = ((c <= 1) and 1) or ((c >= 255) and 255) or c
      return string.char(c)
    end
    local colorStr
    colorStr = '\255'
    colorStr = colorStr .. ColorChar(r)
    colorStr = colorStr .. ColorChar(g)
    colorStr = colorStr .. ColorChar(b)
    local i = (r * 0.299) + (g * 0.587) + (b * 0.114)
    outlineChar = ((i > 0.25) and 'o') or 'O'
    teamColorStrs[teamID] = { colorStr, outlineChar }
    return colorStr, outlineChar
  end
end

local function GetTeamColor(teamID)
  local color = teamColors[teamID]
  if (color) then
    return color
  end
  local r,g,b = Spring.GetTeamColor(teamID)
  
  color = { r, g, b }
  teamColors[teamID] = color
  return color
end

function gadget:CommandNotify(id, params, options)
  if (id == CMD_SELFD) then
    local units = GetSelectedUnits()
    local count = 0
    for _,unitID in ipairs(units) do
      if GetUnitSelfDTime(unitID) == 0 then
        count = count + 1
      end
    end
    if (count > 0) then
      Spring.SendLuaRulesMsg("coop_selfd," .. myPlayerID .. "," .. myTeamID .. "," .. count);
    end
  end
  return false
end

function GameStart()
  preStart = false
  gadgetHandler:RemoveCallIn("DrawWorld")
  gadgetHandler:RemoveCallIn("MapDrawCmd")
  gadgetHandler:RemoveCallIn("MousePress")
  gadgetHandler:RemoveSyncAction("startpoint")
  gadgetHandler:RemoveSyncAction("gamestart")
  gadgetHandler:RemoveSyncAction("factionchange")
  gl.DeleteList(coneList)
  gl.DeleteList(xformList)
  xformList = 0
  coneList = 0
end

function SelfDNotify(_,playerID,teamID,count)
  if (teamID == Spring.GetMyTeamID()) then
    Spring.Echo(select(1,Spring.GetPlayerInfo(playerID)) .. " has issued a self destruct command to " .. count .. " units!")
    checkSelfD = true
  end
end

function gadget:Update(n)
  if checkSelfD then
    local teamUnits = Spring.GetTeamUnits(myTeamID)
	for _,unitID in ipairs(teamUnits) do
	  if (GetUnitSelfDTime(unitID) > 0) then
	    selfDunits[unitID] = GetUnitRadius(unitID)
	  end
    end
    checkSelfD = false
  end
end

function gadget:Initialize()
  if Spring.GetSpectatingState() or (Game.startPosType ~= 2) then
    gadgetHandler:RemoveCallIn("MapDrawCmd")
    gadgetHandler:RemoveCallIn("Update")
    gadgetHandler:RemoveCallIn("DrawWorldPreUnit")
    gadgetHandler:RemoveCallIn("MousePress")
    isspec = true
  end
  gaiaTeamID = Spring.GetGaiaTeamID()
  myPlayerID = Spring.GetMyPlayerID()
  myTeamID = Spring.GetMyTeamID()
  if excludeTeams[myTeamID] then
    gadgetHandler:RemoveCallIn("CommandNotify")
    gadgetHandler:RemoveCallIn("MousePress")
    gadgetHandler:RemoveCallIn("MapDrawCmd")
  end
  gadgetHandler:AddSyncAction("startpoint", StartPoint)
  gadgetHandler:AddSyncAction("gamestart", GameStart)
  gadgetHandler:AddSyncAction("selfdnotify", SelfDNotify)
  gadgetHandler:AddSyncAction("factionchange", FactionChange)
  coneList = gl.CreateList(function()
    local h = 80
    local r = 20
    local divs = 32
    gl.BeginEnd(GL.TRIANGLE_FAN, function()
      gl.Vertex( 0, h,  0)
      for i = 0, divs do
        local a = i * ((math.pi * 2) / divs)
        local cosval = math.cos(a)
        local sinval = math.sin(a)
        gl.Vertex(r * sinval, 0, r * cosval)
      end
    end)
  end)
  for _, teamID in ipairs(Spring.GetTeamList()) do
    for _, playerID in ipairs(Spring.GetPlayerList(teamID)) do
      startPoints[playerID] = {teamID = teamID}
      validStartPoint[playerID] = "11"
    end
  end
  xformList = gl.CreateList(function()
    gl.LoadIdentity()
    gl.Translate(0, 1, 0)
    gl.Scale(1 / msx, -1 / msz, 1)
  end)
end

function StartPoint(_,x,z,name,playerID,faction)
  if (startPoints[playerID].teamID == myTeamID) or isspec or AreTeamsAllied(startPoints[playerID].teamID,myTeamID) then
    startPoints[playerID].x = x
    startPoints[playerID].y = Spring.GetGroundHeight(x,z)
    startPoints[playerID].z = z
    startPoints[playerID].name = name
    if faction == "armcom" then
      startPoints[playerID].faction = "(ARM) "
    else
      startPoints[playerID].faction = "(CORE) "
    end
  end
end

function FactionChange(_,playerID, faction)
  if faction == "armcom" then
    startPoints[playerID].faction = "(ARM) "
  else
    startPoints[playerID].faction = "(CORE) "
  end
end

function gadget:MousePress(x,y,button)
  if preStart and (button == 3) then
    Spring.SendLuaRulesMsg("coop_factionchange," .. myPlayerID)
  end
  return false
end

function gadget:MapDrawCmd(playerID, cmdType, px, py, pz, label)
  if not preStart then return end
  if (cmdType == "erase") and (playerID == myPlayerID) and (validStartPoint[playerID] == ("" .. px .. pz)) then
    validStartPoint[playerID] = true
  end
  if (cmdType == "point") and (playerID == myPlayerID) and (label:find("Start",1,true)) and (validStartPoint[playerID] == true) then
    Spring.SendLuaRulesMsg("coop_startpoint," .. px .. "," .. pz .. "," .. select(1,Spring.GetPlayerInfo(playerID)) .. "," .. playerID);
    Spring.MarkerErasePosition(px+1,py,pz+1)
    validStartPoint[playerID] = ("" .. math.floor(px) .. math.floor(pz))
  end
end

function gadget:DrawWorldPreUnit()
  if preStart then return end
  gl.DepthTest(true)
  gl.Color(0.5+(math.random()/2),0,0)
  gl.LineWidth(4)
  for unitID,radius in pairs(selfDunits) do
    if Spring.ValidUnitID(unitID) and (GetUnitSelfDTime(unitID) > 0) then
      local x,y,z = GetUnitPosition(unitID)
      DrawGroundCircle(x,y,z,radius,20)
    else
      selfDunits[unitID] = nil
    end
  end
  gl.LineWidth(1)
  gl.DepthTest(false)
end

function gadget:DrawWorld()
  if not preStart then return end
  for playerID, defs in pairs(startPoints) do
    if defs.x then
      local colorStr, outlineStr = GetTeamColorStr(defs.teamID)
      local color = GetTeamColor(defs.teamID)
      local r, g, b = color[1], color[2], color[3]
      gl.PushMatrix()
        gl.DepthTest(true)
        gl.Translate(startPoints[playerID].x, startPoints[playerID].y, startPoints[playerID].z)
        gl.Color(r,g,b,1)
        gl.CallList(coneList)
        gl.Translate(0,90,0)
        gl.Billboard()
        gl.Text(colorStr..startPoints[playerID].faction..startPoints[playerID].name,0,0,25,outlineStr .. "c")
        gl.DepthTest(false)
      gl.PopMatrix()
    end
  end
  myTeamID = Spring.GetMyTeamID()
  if not excludeTeams[myTeamID] then
    for teamID in pairs(excludeTeams) do
      if AreTeamsAllied(teamID, myTeamID) then
        local x, y, z = Spring.GetTeamStartPosition(teamID)
        if (x ~= nil and x > 0 and z > 0 and y > -500) then
          local name = Spring.GetPlayerInfo(select(2,Spring.GetTeamInfo(teamID)))
          local colorStr, outlineStr = GetTeamColorStr(teamID)
          local color = GetTeamColor(teamID)
          local r, g, b = color[1], color[2], color[3]
          gl.PushMatrix()
            gl.DepthTest(true)
            gl.Translate(x, y, z)
            gl.Color(r,g,b,1)
            gl.CallList(coneList)
            gl.Translate(0,90,0)
            gl.Billboard()
            gl.Text(colorStr..name,0,0,25,outlineStr .. "c")
            gl.DepthTest(false)
          gl.PopMatrix()  
        end
      end  
    end
  end
end

function gadget:DrawInMiniMap(sx, sz)
  gl.PushMatrix()
  gl.CallList(xformList)
  for playerID, defs in pairs(startPoints) do
    if defs.x then
      local color = GetTeamColor(defs.teamID)
      local r, g, b = color[1], color[2], color[3]
      gl.PointSize(7)
      if (defs.faction == "(ARM) ") then
         gl.Color(0, 0.5, 0.5+(math.random()/2), 1)
      else
         gl.Color(0.5+(math.random()/2), 0, 0, 1)
      end
      gl.BeginEnd(GL.POINTS, function() gl.Vertex(defs.x, defs.z) end)
      gl.PointSize(5)
      gl.Color(r, g, b, 1)
      gl.BeginEnd(GL.POINTS, function() gl.Vertex(defs.x, defs.z) end)
    end
  end
  myTeamID = Spring.GetMyTeamID()
  if not excludeTeams[myTeamID] then
    for teamID in pairs(excludeTeams) do
      if AreTeamsAllied(teamID, myTeamID) then
        local x, y, z = Spring.GetTeamStartPosition(teamID)
        if (x ~= nil and x > 0 and z > 0 and y > -500) then
          local color = GetTeamColor(teamID)
          local r, g, b = color[1], color[2], color[3]
          gl.PointSize(7)
          gl.Color(1, 1, 1, 1)
          gl.BeginEnd(GL.POINTS, function() gl.Vertex(x, z) end)
          gl.PointSize(5)
          gl.Color(r, g, b, 1)
          gl.BeginEnd(GL.POINTS, function() gl.Vertex(x, z) end)
        end 
      end
    end
  end
  gl.PointSize(1.0)
  gl.PopMatrix()
end

end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------