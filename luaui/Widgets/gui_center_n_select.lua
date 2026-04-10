
local widget = widget ---@type Widget

function widget:GetInfo()
  return {
    name      = "Select n Center!",
    desc      = "Selects and centers the Commander at the start of the game.",
    author    = "quantum and Evil4Zerggin",
    date      = "19 April 2008",
    license   = "GNU GPL, v2 or later",
    layer     = 5,
    enabled   = true
  }
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


local go = true

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


function widget:Update()
  local t = SpringShared.GetGameSeconds()
  local isSpec = select(3, SpringShared.GetPlayerInfo(Spring.GetMyPlayerID(), false))
  if (isSpec or t > 10) then
    widgetHandler:RemoveWidget()
    return
  end
  if (t > 0) then
    local unitArray = SpringShared.GetTeamUnits(Spring.GetMyTeamID())
    if (go and unitArray[1]) then
      local x, y, z = SpringShared.GetUnitPosition(unitArray[1])
      SpringUnsynced.SetCameraTarget(x, y, z)
      SpringUnsynced.SelectUnitArray{unitArray[1]}
      go = false
    end
    if (not go) then
      widgetHandler:RemoveWidget()
    end
  end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
