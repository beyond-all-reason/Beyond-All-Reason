local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function removeArea(areaName)
	GG['MissionAPI'].Modules.Areas.RemoveArea(areaName)
end

return {
	{
		type = 'RemoveArea',
		parameters = {
			{ name = 'areaName', required = true, type = ParameterTypes.AreaName },
		},
		actionFunction = removeArea,
	}
}
