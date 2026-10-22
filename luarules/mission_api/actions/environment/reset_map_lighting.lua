local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Back to the map's own lighting and time of day, and its own skybox if it has one.
local function resetMapLighting(transitionDuration)
	GG.MapLighting.Reset(transitionDuration)
end

return {
	{
		type = 'ResetMapLighting',
		parameters = {
			{ name = 'transitionDuration', required = false, type = ParameterTypes.Quantity }, -- seconds, default 0
		},
		actionFunction = resetMapLighting,
	}
}
