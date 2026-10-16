local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Follows a unit (the middle of the group when several share the name) or watches a position.
local function followCamera(unitName, position, distance, pitch, yaw, duration, transitionDuration, easing, smoothing, onEnd)
	SendToUnsynced('MissionCameraFollow', {
		target = GG['MissionAPI'].Modules.Camera.BuildTarget(unitName, position),
		distance = distance,
		pitch = pitch,
		yaw = yaw,
		duration = duration,
		transitionDuration = transitionDuration,
		easing = easing,
		smoothing = smoothing,
		onEnd = onEnd,
	})
end

return {
	{
		type = 'FollowCamera',
		parameters = {
			{ name = 'unitName',           required = false, type = ParameterTypes.UnitName },
			{ name = 'position',           required = false, type = ParameterTypes.Position },
			{ name = 'distance',           required = false, type = ParameterTypes.Quantity },     -- elmos
			{ name = 'pitch',              required = false, type = ParameterTypes.Number },       -- degrees, 0 = level, 90 = straight down
			{ name = 'yaw',                required = false, type = ParameterTypes.Number },       -- degrees, compass bearing
			{ name = 'duration',           required = false, type = ParameterTypes.Quantity },     -- seconds, 0 = until the next camera action
			{ name = 'transitionDuration', required = false, type = ParameterTypes.Quantity },     -- seconds to blend in from the current view
			{ name = 'easing',             required = false, type = ParameterTypes.CameraEasing }, -- of that blend
			{ name = 'smoothing',          required = false, type = ParameterTypes.Quantity },     -- seconds for the lag behind the target to halve, 0 = none
			{ name = 'onEnd',              required = false, type = ParameterTypes.CameraSequenceEnd },
			requiresOneOf = { 'unitName', 'position' },
		},
		actionFunction = followCamera,
	}
}
