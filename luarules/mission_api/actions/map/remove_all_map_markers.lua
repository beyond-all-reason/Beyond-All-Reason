local function removeAllMapMarkers()
	for _, position in pairs(GG['MissionAPI'].markerNames) do
		Spring.MarkerErasePosition(position.x, position.y, position.z, nil, false, nil, true)
	end
	GG['MissionAPI'].markerNames = {}
end

return {
	{
		type = 'RemoveAllMapMarkers',
		parameters = {},
		actionFunction = removeAllMapMarkers,
	}
}
