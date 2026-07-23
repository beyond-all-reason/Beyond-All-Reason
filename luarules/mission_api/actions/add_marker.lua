local Types = GG['MissionAPI'].Modules.ParameterTypes.Types

local function addMarker(position, label, name)
	if name then
		GG['MissionAPI'].markerNames[name] = position
	end
	Spring.MarkerAddPoint(position.x, position.y, position.z, label, false)
end

return {
	type = 'AddMarker',
	parameters = {
		{ name = 'position', required = true, type = Types.Position },
		{ name = 'label', required = false, type = Types.String },
		{ name = 'name', required = false, type = Types.String },
	},
	actionFunction = addMarker,
}
