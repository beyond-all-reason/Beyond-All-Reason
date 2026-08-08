local function clearAllMarkers()
	GG['MissionAPI'].markerNames = {}
	Spring.SendCommands('clearmapmarks')
end

return {
	{
		type = 'ClearAllMarkers',
		parameters = {},
		actionFunction = clearAllMarkers,
	}
}
