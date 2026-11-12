local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Hour 12 is the map's own lighting. With a dayLength the clock keeps running once the hour is reached.
local function setMapTimeOfDay(hour, transitionDuration, dayLength)
	GG.MapLighting.SetTimeOfDay(hour, transitionDuration, dayLength)
end

return {
	{
		type = 'SetMapTimeOfDay',
		parameters = {
			{ name = 'hour',               required = true,  type = ParameterTypes.TimeOfDay },
			{ name = 'transitionDuration', required = false, type = ParameterTypes.Quantity }, -- seconds, default 0
			{ name = 'dayLength',          required = false, type = ParameterTypes.Quantity }, -- seconds per 24 hours, default stopped
		},
		actionFunction = setMapTimeOfDay,
	}
}
