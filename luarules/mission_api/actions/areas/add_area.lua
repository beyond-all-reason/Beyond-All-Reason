local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function addArea(areaName, area)
	GG['MissionAPI'].Modules.Areas.AddArea(areaName, area)
end

return {
	{
		type = 'AddArea',
		parameters = {
			{ name = 'areaName', required = true, type = ParameterTypes.AreaName },
			{ name = 'area',     required = true, type = ParameterTypes.Area },
		},
		actionFunction = addArea,
	}
}
