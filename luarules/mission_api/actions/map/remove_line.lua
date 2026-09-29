local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function removeLine(lineName)
	local starts = GG['MissionAPI'].lineNames[lineName]
	GG['MissionAPI'].lineNames[lineName] = nil
	if not starts then return end

	for i = 1, #starts do
		local pos = starts[i]
		Spring.MarkerErasePosition(pos.x, pos.y, pos.z, nil, false, nil, true)
	end
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
