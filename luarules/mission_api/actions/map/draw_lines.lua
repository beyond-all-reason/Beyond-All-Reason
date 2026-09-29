local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- The engine erases a line by its first start position, so that's what we store.

local function eraseLine(starts)
	for i = 1, #starts do
		local pos = starts[i]
		Spring.MarkerErasePosition(pos.x, pos.y, pos.z, nil, false, nil, true)
	end
end

local function drawLines(positions, lineName)
	local api = GG['MissionAPI']
	local starts = {}
	for i = 1, #positions - 1 do
		local pos1 = positions[i]
		local pos2 = positions[i + 1]
		Spring.MarkerAddLine(pos1.x, pos1.y, pos1.z, pos2.x, pos2.y, pos2.z, nil, false)
		starts[i] = pos1
	end

	local previous = api.lineNames[lineName]
	if previous then eraseLine(previous) end
	api.lineNames[lineName] = starts
end

return {
	{
		type = 'DrawLines',
		parameters = {
			{ name = 'positions', required = true,  type = ParameterTypes.Positions },
			{ name = 'lineName',  required = true,  type = ParameterTypes.String },
		},
		actionFunction = drawLines,
	}
}
