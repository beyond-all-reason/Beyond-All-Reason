function widget:GetInfo()
  return {
    name      = "Auto Group Com",
    desc      = "Automagically add Commander to Group",
    author    = "BD, Argh, Troy H. Cheek",
    date      = "July 15, 2009",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
local commanderGroup = 1
--------------------------------------------------------------------------------
local GetTeamUnits 		= Spring.GetTeamUnits
local GetMyTeamID		= Spring.GetMyTeamID
local SetUnitGroup		= Spring.SetUnitGroup
local GetSpectatingState= Spring.GetSpectatingState
local GetUnitDefID 		= Spring.GetUnitDefID

function widget:GameFrame(t)
	if t > 0 then
		local allUnits = GetTeamUnits(GetMyTeamID())
		for _, unitID in pairs(allUnits) do
			local unitDefID = GetUnitDefID(unitID)
			if (unitDefID and UnitDefs[unitDefID].customParams.iscommander) then
				SetUnitGroup( unitID, commanderGroup )
			end
		end
		widgetHandler:RemoveWidget()
	end
end

function widget:Initialize()
	if GetSpectatingState() then
		widgetHandler:RemoveWidget()
		return
	end
end
