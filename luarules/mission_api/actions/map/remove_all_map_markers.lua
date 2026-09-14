local function removeAllMapMarkers()
	GG['MissionAPI'].markerNames = {}
	Spring.SendCommands('clearmapmarks')
end

return {
	{
		type = 'RemoveAllMapMarkers',
		parameters = {},
		actionFunction = removeAllMapMarkers,
	}
}
