--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "Select n Center!",
    desc      = "Selects and centers Commander at start of the game",
    author    = "quantum, Evil4Zerggin, TheFatController",
    date      = "12 Feb 2009",
    license   = "GNU GPL, v2 or later",
    layer     = 5,
    enabled   = true
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local myTeamID = Spring.GetMyTeamID()

if select(3,Spring.GetPlayerInfo(myTeamID)) then
  return false
end

local enabled = tonumber(Spring.GetModOptions().mo_coop) or 0

if (enabled == 1) then
  local playerCount = 0
  for _, playerID in ipairs(Spring.GetPlayerList(myTeamID)) do
    if not select(3,Spring.GetPlayerInfo(playerID)) then
      playerCount = playerCount + 1
    end
  end
  if (playerCount > 1) then
    return false
  end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
  if (unitTeam ~= myTeamID) or (not UnitDefs[unitDefID].isCommander) then return end
  Spring.SelectUnitArray({unitID})
  local x,y,z = Spring.GetUnitPosition(unitID)
  Spring.SetCameraTarget(x,800,z)
  widgetHandler:RemoveWidget()
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------