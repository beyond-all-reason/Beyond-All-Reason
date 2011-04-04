--[[ 
Changelog:
3.1.1 [2009-11-21] by Simon Logic
! do not take active AIs
3.1 [2007-03-31] by Evil4Zerggin
* oigininal version
]]

local versionNumber = "v3.1.1"

function widget:GetInfo()
  return {
    name      = "Take Reminder",
    desc      = versionNumber .. " Reminds you to .take if a player is gone",
    author    = "Evil4Zerggin",
    date      = "21 Nov 2009",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

------------------------------------------------
-- modified by:
------------------------------------------------
--  jK: only get mouse owner in MousePress() if there are teams to take
--      and some smaller speed ups
------------------------------------------------

------------------------------------------------
--config
------------------------------------------------
local autoTake = false

------------------------------------------------
--local variables
------------------------------------------------
local updatePeriod = 1.5
local lastUpdate
local vsx, vsy, posx, posy
local count
local myAllyTeamID
local myTeamID
local colorBool
local trueColor = "\255\255\255\1"
local falseColor = "\255\127\127\1"
local buttonX = 240
local buttonY = 36

------------------------------------------------
--speedups
------------------------------------------------
local GetTeamList = Spring.GetTeamList
local GetMyAllyTeamID  = Spring.GetMyAllyTeamID
local GetTeamUnitCount = Spring.GetTeamUnitCount
local GetPlayerList  = Spring.GetPlayerList
local GetPlayerInfo  = Spring.GetPlayerInfo
local GetGameSeconds = Spring.GetGameSeconds
local GetSpectatingState = Spring.GetSpectatingState
local GetUnitPosition = Spring.GetUnitPosition
local GetVisibleUnits = Spring.GetVisibleUnits
local GetUnitTeam = Spring.GetUnitTeam
local AreTeamsAllied = Spring.AreTeamsAllied
local GetMyTeamID = Spring.GetMyTeamID
local GetAIInfo = Spring.GetAIInfo
local glBillboard         = gl.Billboard
local glPushMatrix        = gl.PushMatrix
local glPopMatrix         = gl.PopMatrix
local glText = gl.Text
local glTranslate         = gl.Translate
local glColor = gl.Color

------------------------------------------------
--helper functions
------------------------------------------------
function GetTeamIsTakeable(team)
  local _, _, _, _, shortName = GetAIInfo(team)
  if (shortName ~= nil and shortName ~= "NullAI" and sortName ~= "NullJavaAI") then
    -- do not take active AIs
    return false
  end
   
  local players = GetPlayerList(true)
  for _, player in ipairs(players) do
    local _, _, _, playerTeam = GetPlayerInfo(player)
	if (playerTeam == team) then
	  -- do not take itself
      return false
    end
  end

  return true
end

function UpdateUnitsToTake()
  local teamList = GetTeamList(myAllyTeamID)
  count = 0
  for _, team in ipairs(teamList) do
    local unitsOwned = GetTeamUnitCount(team)
    if (unitsOwned > 0 and GetTeamIsTakeable(team)) then
      count = count + unitsOwned
    end
  end
end

function IsOnButton(x, y)
  return x >= posx - buttonX and x <= posx + buttonX
                             and y >= posy
                             and y <= posy + buttonY
end

function Take()
  Spring.SendCommands{"take"}
  return
end
------------------------------------------------
--call-ins
------------------------------------------------
function widget:Initialize()
  if GetSpectatingState() or Spring.IsReplay() then
    widgetHandler:RemoveWidget()
    return true
  end
  colorBool = false
  lastUpdate = 0
  vsx, vsy = widgetHandler:GetViewSizes()
  posx = vsx * 0.75
  posy = vsy * 0.75
  count = 0
  myTeamID = GetMyTeamID()
end

function widget:ViewResize(viewSizeX, viewSizeY)
  vsx = viewSizeX
  vsy = viewSizeY
  posx = vsx * 0.75
  posy = vsy * 0.75
end

function widget:DrawScreen()
  if (count > 0) then
    gl.Color(  1.0, 1.0, 0 )
    gl.Shape(GL.LINE_LOOP, {{ v = { posx + buttonX, posy} }, 
                            { v = { posx + buttonX, posy + buttonY } }, 
                            { v = { posx - buttonX, posy + buttonY } }, 
                            { v = { posx - buttonX, posy} }  })
    local colorStr
    if (colorBool) then
      colorStr = trueColor
    else
      colorStr = falseColor
    end
    gl.Text(colorStr .. "Click here to take " .. count .. " unit(s)!", posx, posy, 24, "oc")
  end
end

function widget:Update()
  local now = GetGameSeconds()
  if (now < lastUpdate + updatePeriod) then
    return
  end
  
  if GetSpectatingState() then
    Spring.Echo("<Take Reminder> Spectator mode. Widget removed.")
    widgetHandler:RemoveWidget()
    return
  end
  
  lastUpdate = now
  myAllyTeamID = GetMyAllyTeamID()
  colorBool = not colorBool
  UpdateUnitsToTake()
  if (count > 0 and autoTake) then
    Take()
  end
end

function widget:MousePress(x, y, button)
  return (count > 0)and(IsOnButton(x, y))
end

function widget:MouseRelease(x, y, button)
  if (count > 0 and IsOnButton(x, y)) then
    UpdateUnitsToTake()
    if (count > 0) then
      Take()
    end
    return -1
  end
  return false
end

function widget:DrawWorld()
  myTeamID = GetMyTeamID()
  if colorBool then
    local visibleUnits = GetVisibleUnits(ALL_UNITS,nil,true)
    for i=1,#visibleUnits do 
      local currUnit = visibleUnits[i]
      local currTeam = GetUnitTeam(currUnit)
      if (GetTeamIsTakeable(currTeam) and AreTeamsAllied(myTeamID, currTeam)) then
        glPushMatrix()
        local ux, uy, uz = GetUnitPosition(currUnit)
        glTranslate(ux, uy, uz)
        glBillboard()
        glText("\255\255\255\1T", 0, -24, 48, "c")
        glPopMatrix()
        glColor(1,1,1,1)
      end
    end
  end
end

