local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function unnameUnits(unitName)
	local tracking = GG['MissionAPI'].Modules.Tracking
	tracking.UntrackUnitName(unitName)
end

return {
	{
		type = 'UnnameUnits',
		parameters = {
			{ name = 'unitName', required = true, type = ParameterTypes.UnitName },
		},
		actionFunction = unnameUnits,
	}
}
