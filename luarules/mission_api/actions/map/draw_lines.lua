local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function drawLines(positions, lineName)
	GG['MissionAPI'].Modules.MapLines.DrawLine(lineName, positions)
end

return {
	{
		type = 'DrawLines',
		parameters = {
			{ name = 'positions', required = true, type = ParameterTypes.Positions },
			{ name = 'lineName',  required = true, type = ParameterTypes.String },
		},
		actionFunction = drawLines,
	}
}
