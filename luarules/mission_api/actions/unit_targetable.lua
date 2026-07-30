local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function setTargetable(unitName, targetable)
	local tracking = GG['MissionAPI'].Modules.Tracking
	if tracking.IsUnitNameUntracked(unitName) then return end
	GG['MissionAPI'].untargetableUnitIDs[GG['MissionAPI'].trackedUnitIDs[unitName]] = not targetable and true or nil
end

return {
	{
		type = 'Unit Targetable',
		parameters = {
			{ name = 'unitName', required = true, type = ParameterTypes.UnitName },
			{ name = 'targetable', required = true, type = ParameterTypes.Boolean },
		},
		actionFunction = setTargetable,
	}
}
