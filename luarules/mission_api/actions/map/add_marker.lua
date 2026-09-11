local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function addMarker(position, label, name)
	if name then
		GG['MissionAPI'].markerNames[name] = position
	end
	Spring.MarkerAddPoint(position.x, position.y, position.z, label, false)
end

return {
	{
		type = 'AddMarker',
		parameters = {
			{ name = 'position', required = true, type = ParameterTypes.Position },
			{ name = 'label', required = false, type = ParameterTypes.String },
			{ name = 'name', required = false, type = ParameterTypes.String },
		},
		actionFunction = addMarker,
	}
}
