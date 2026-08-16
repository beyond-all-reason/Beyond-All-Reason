local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function setSelectable(unitName, selectable)
	local tracking = GG['MissionAPI'].Modules.Tracking
	if tracking.IsUnitNameUntracked(unitName) then return end
	Spring.SetUnitNoSelect(GG['MissionAPI'].trackedUnitIDs[unitName], not selectable)
end

return {
	{
		type = 'Unit Selectable',
		parameters = {
			{ name = 'unitName', required = true, type = ParameterTypes.UnitName },
			{ name = 'selectable', required = true, type = ParameterTypes.Boolean },
		},
		actionFunction = setSelectable,
	}
}
