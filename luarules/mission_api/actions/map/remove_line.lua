local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function removeLine(lineName)
	GG['MissionAPI'].Modules.MapLines.RemoveLine(lineName)
end

return {
	{
		type = 'RemoveLine',
		parameters = {
			{ name = 'lineName', required = true, type = ParameterTypes.String },
		},
		actionFunction = removeLine,
	}
}
