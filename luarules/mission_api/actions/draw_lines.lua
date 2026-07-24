local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function drawLines(positions)
	for i = 1, #positions - 1 do
		local pos1 = positions[i]
		local pos2 = positions[i + 1]
		Spring.MarkerAddLine(pos1.x, pos1.y, pos1.z, pos2.x, pos2.y, pos2.z, nil, false)
	end
end

return {
	type = 'DrawLines',
	parameters = {
		{ name = 'positions', required = true, type = ParameterTypes.Positions },
	},
	actionFunction = drawLines,
}
