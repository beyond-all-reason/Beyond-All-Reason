local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- On a map with a procedural sky the skybox stays after ResetMapLighting.
local function setMapSkybox(texture, rotation)
	GG.MapLighting.SetSkybox(texture, rotation)
end

return {
	{
		type = 'SetMapSkybox',
		parameters = {
			{ name = 'texture',  required = true,  type = ParameterTypes.SkyboxFile },
			{ name = 'rotation', required = false, type = ParameterTypes.Number }, -- degrees about the vertical axis
		},
		actionFunction = setMapSkybox,
	}
}
