--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


function widget:GetInfo()
  return {
    name      = "Select n Center!",
    desc      = "Selects and centers the Commander at the start of the game.",
    author    = "quantum and Evil4Zerggin and zwzsg",
    date      = "19 April 2008",
    license   = "GNU GPL, v2 or later",
    layer     = 5,
    enabled   = true  --  loaded by default?
  }
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


function widget:Update()
  local t = Spring.GetGameSeconds()
  _, _, spectator = Spring.GetPlayerInfo(Spring.GetMyTeamID())
  if (spectator or t > 10) then
    widgetHandler:RemoveWidget()
    return
  end
  if (t > 0) then
    local x, y, z = Spring.GetTeamStartPosition(Spring.GetMyTeamID())
    local unitArray = Spring.GetTeamUnits(Spring.GetMyTeamID())
    if (unitArray and #unitArray==1) then
      Spring.SelectUnitArray{unitArray[1]}
      x, y, z = Spring.GetUnitPosition(unitArray[1])
    end
    if x and y and z then
      Spring.SetCameraTarget(x, y, z)
    end
    widgetHandler:RemoveWidget()
  end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
