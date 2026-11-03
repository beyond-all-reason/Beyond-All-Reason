local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Overlapping shakes add up.
local function shakeCamera(magnitude, duration, rampUp, falloff, frequency, rotationMagnitude)
	SendToUnsynced('MissionCameraShake', {
		magnitude = magnitude,
		duration = duration,
		rampUp = rampUp,
		falloff = falloff,
		frequency = frequency,
		rotationMagnitude = rotationMagnitude,
	})
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
		},
		actionFunction = shakeCamera,
	}
}
