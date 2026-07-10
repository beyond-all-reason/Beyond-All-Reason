local function clearAllMarkers()
	GG['MissionAPI'].markerNames = {}
	Spring.SendCommands('clearmapmarks')
end

return {
	name = 'ClearAllMarkers',
	parameters = {},
	execute = clearAllMarkers,
}
