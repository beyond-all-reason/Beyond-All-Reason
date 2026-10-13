local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Shakes the view by up to `magnitude` elmos for `duration` seconds: ramping up over
-- `rampUp` seconds, fading out over the last `falloff` seconds, jittering at `frequency` Hz
-- and tilting by up to `rotationMagnitude` degrees. Shakes that overlap add up.
local function shakeCamera(magnitude, duration, rampUp, falloff, frequency, rotationMagnitude, teamID)
	GG['MissionAPI'].Modules.ClientActions.Send('shake', {
		magnitude = magnitude,
		duration = duration,
		rampUp = rampUp,
		falloff = falloff,
		frequency = frequency,
		rotationMagnitude = rotationMagnitude,
	}, teamID)
end

return {
	{
		type = 'ShakeCamera',
		parameters = {
			{ name = 'magnitude',         required = true,  type = ParameterTypes.Quantity }, -- elmos
			{ name = 'duration',          required = false, type = ParameterTypes.Quantity }, -- seconds
			{ name = 'rampUp',            required = false, type = ParameterTypes.Quantity }, -- seconds
			{ name = 'falloff',           required = false, type = ParameterTypes.Quantity }, -- seconds
			{ name = 'frequency',         required = false, type = ParameterTypes.Quantity }, -- Hz
			{ name = 'rotationMagnitude', required = false, type = ParameterTypes.Quantity }, -- degrees
			{ name = 'teamID',            required = false, type = ParameterTypes.TeamID }, -- only this team's players; everyone when left out
		},
		actionFunction = shakeCamera,
	}
}
