local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function removeMapMarker(markerName)
	local position = GG['MissionAPI'].markerNames[markerName]
	GG['MissionAPI'].markerNames[markerName] = nil
	if not position then return end

	Spring.MarkerErasePosition(position.x, position.y, position.z, nil, false, nil, true)
end

return {
	{
		type = 'RemoveMapMarker',
		parameters = {
			{ name = 'markerName', required = true, type = ParameterTypes.String },
		},
		actionFunction = removeMapMarker,
	}
}
