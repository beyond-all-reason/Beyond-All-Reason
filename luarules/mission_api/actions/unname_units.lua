local Types = GG['MissionAPI'].Modules.ParameterTypes.Types

local function unnameUnits(unitName)
	local tracking = GG['MissionAPI'].Modules.Tracking
	tracking.UntrackUnitName(unitName)
end

return {
	name = 'UnnameUnits',
	parameters = {
		{ name = 'unitName', required = true, type = Types.UnitName },
	},
	execute = unnameUnits,
}
