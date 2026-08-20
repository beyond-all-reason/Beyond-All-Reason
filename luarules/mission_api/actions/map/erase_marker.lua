local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function eraseMarker(name)
	local position = GG['MissionAPI'].markerNames[name]
	GG['MissionAPI'].markerNames[name] = nil
	if not position then return end

	Spring.MarkerErasePosition(position.x, position.y, position.z, nil, false, nil, true)
end

return {
	{
		type = 'EraseMarker',
		parameters = {
			{ name = 'name', required = true, type = ParameterTypes.String },
		},
		actionFunction = eraseMarker,
	}
}
