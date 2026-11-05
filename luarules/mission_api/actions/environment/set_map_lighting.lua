local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Changes only the values given, through GG.MapLighting (api_map_lighting.lua); the rest stay as they are.
local function setMapLighting(brightness, tint, sunAzimuth, sunElevation, groundAmbientColor, groundDiffuseColor,
	groundSpecularColor, unitAmbientColor, unitDiffuseColor, unitSpecularColor, groundShadowDensity, unitShadowDensity,
	transitionDuration)
	GG.MapLighting.SetLighting({
		brightness = brightness,
		tint = tint,
		sunAzimuth = sunAzimuth,
		sunElevation = sunElevation,
		groundAmbientColor = groundAmbientColor,
		groundDiffuseColor = groundDiffuseColor,
		groundSpecularColor = groundSpecularColor,
		unitAmbientColor = unitAmbientColor,
		unitDiffuseColor = unitDiffuseColor,
		unitSpecularColor = unitSpecularColor,
		groundShadowDensity = groundShadowDensity,
		unitShadowDensity = unitShadowDensity,
	}, transitionDuration)
end

return {
	{
		type = 'SetMapLighting',
		parameters = {
			{ name = 'brightness',          required = false, type = ParameterTypes.Quantity },
			{ name = 'tint',                required = false, type = ParameterTypes.Color },
			{ name = 'sunAzimuth',          required = false, type = ParameterTypes.CompassAngle },
			{ name = 'sunElevation',        required = false, type = ParameterTypes.Elevation },
			{ name = 'groundAmbientColor',  required = false, type = ParameterTypes.Color },
			{ name = 'groundDiffuseColor',  required = false, type = ParameterTypes.Color },
			{ name = 'groundSpecularColor', required = false, type = ParameterTypes.Color },
			{ name = 'unitAmbientColor',    required = false, type = ParameterTypes.Color },
			{ name = 'unitDiffuseColor',    required = false, type = ParameterTypes.Color },
			{ name = 'unitSpecularColor',   required = false, type = ParameterTypes.Color },
			{ name = 'groundShadowDensity', required = false, type = ParameterTypes.Fraction },
			{ name = 'unitShadowDensity',   required = false, type = ParameterTypes.Fraction },
			{ name = 'transitionDuration',  required = false, type = ParameterTypes.Quantity },
			requiresOneOf = {
				'brightness', 'tint', 'sunAzimuth', 'sunElevation',
				'groundAmbientColor', 'groundDiffuseColor', 'groundSpecularColor',
				'unitAmbientColor', 'unitDiffuseColor', 'unitSpecularColor',
				'groundShadowDensity', 'unitShadowDensity',
			},
		},
		actionFunction = setMapLighting,
	}
}
