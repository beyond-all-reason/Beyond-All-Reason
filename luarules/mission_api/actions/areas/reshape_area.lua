local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function reshapeArea(areaName, area, duration, easing)
	GG['MissionAPI'].Modules.Areas.ReshapeArea(areaName, area, duration, easing)
end

return {
	{
		type = 'ReshapeArea',
		parameters = {
			{ name = 'areaName', required = true,  type = ParameterTypes.AreaName },
			{ name = 'area',     required = true,  type = ParameterTypes.Area },
			{ name = 'duration', required = false, type = ParameterTypes.Quantity }, -- default := at once
			{ name = 'easing',   required = false, type = ParameterTypes.Fraction }, -- default := 0.0; 0.0 := edges at a constant speed, 1.0 := covered area at a constant rate
		},
		actionFunction = reshapeArea,
	}
}
