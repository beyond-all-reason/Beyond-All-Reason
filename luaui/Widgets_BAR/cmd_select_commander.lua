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
  local unitArray = Spring.GetTeamUnits(Spring.GetMyTeamID())
  for i = 1, #unitArray do
    local unit = unitArray[i]
    local unitDefID = Spring.GetUnitDefID(unit)
    local unitDef = UnitDefs[unitDefID]
    if (unitDef.customParams.iscommander == true) do
      Spring.SelectUnitArray{unit}
      return
    end
  end
end
