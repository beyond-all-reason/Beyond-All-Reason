function widget:GetInfo()
  return {
    name = "SelectCommander",
    desc = "Press ctrl+c to select the commander",
    author = "Teifion",
    date = "26/10/2020",
    license = "GNU GPL, v2 or later",
    layer = 0,
    enabled = true
  }
end

function widget:Update()
  local t = Spring.GetGameSeconds()
  if (select(3,Spring.GetPlayerInfo(Spring.GetMyPlayerID(),false)) or t > 10) then
    widgetHandler:RemoveWidget(self)
    return
  end
  if (t > 0) then
    local unitArray = Spring.GetTeamUnits(Spring.GetMyTeamID())
    for key, unit in pairs(unitArray) do
      if (unitDef.customParams.iscommander == true) do
        Spring.SelectUnitArray{unitArray[key]}
        return
      end
    end
  end
end
