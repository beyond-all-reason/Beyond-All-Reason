local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function setSelectable(unitName, selectable)
	local tracking = GG['MissionAPI'].Modules.Tracking
	if tracking.IsUnitNameUntracked(unitName) then return end

	local noSelect = not selectable
	for unitID in pairs(GG['MissionAPI'].trackedUnitIDs[unitName]) do
		Spring.SetUnitNoSelect(unitID, noSelect)
	end
end

return {
	{
		type = 'UnitSelectable',
		parameters = {
			{ name = 'unitName', required = true, type = ParameterTypes.UnitName },
			{ name = 'selectable', required = true, type = ParameterTypes.Boolean },
		},
		actionFunction = setSelectable,
	}
}
