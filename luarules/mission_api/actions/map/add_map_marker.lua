local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Drawing is stubbed on the engine's map marks, which pin themselves to the terrain and cannot be
-- styled, so markerType is taken and kept until we draw the marker types ourselves.

local function addMapMarker(markerName, position, markerType, label)
	GG['MissionAPI'].markerNames[markerName] = position
	Spring.MarkerAddPoint(position.x, position.y, position.z, label, false)
end

return {
	{
		type = 'AddMapMarker',
		parameters = {
			{ name = 'markerName', required = true,  type = ParameterTypes.String },
			{ name = 'position',   required = true,  type = ParameterTypes.Position },
			{ name = 'markerType', required = false, type = ParameterTypes.String },
			{ name = 'label',      required = false, type = ParameterTypes.String },
		},
		actionFunction = addMapMarker,
	}
}
