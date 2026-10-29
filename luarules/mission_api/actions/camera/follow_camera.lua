local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Follows a unit (the middle of the group when several share the name) or watches a position.
local function followCamera(unitName, position, distance, pitch, yaw, fov, duration, transitionDuration, easing, smoothing, onEnd, restoreSlot, restoreDuration, restoreEasing, releaseDuration, releaseEasing)
	SendToUnsynced('MissionCameraFollow', {
		target = GG['MissionAPI'].Modules.Camera.BuildTarget(unitName, position),
		distance = distance,
		pitch = pitch,
		yaw = yaw,
		fov = fov,
		duration = duration,
		transitionDuration = transitionDuration,
		easing = easing,
		smoothing = smoothing,
		onEnd = onEnd,
		restoreSlot = restoreSlot,
		restoreDuration = restoreDuration,
		restoreEasing = restoreEasing,
		releaseDuration = releaseDuration,
		releaseEasing = releaseEasing,
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
			{ name = 'fov',                required = false, type = ParameterTypes.Number },       -- degrees, vertical
			{ name = 'duration',           required = false, type = ParameterTypes.Quantity },     -- seconds, 0 = until the next camera action
			{ name = 'transitionDuration', required = false, type = ParameterTypes.Quantity },     -- seconds to blend in from the current view
			{ name = 'easing',             required = false, type = ParameterTypes.CameraEasing }, -- of that blend
			{ name = 'smoothing',          required = false, type = ParameterTypes.Quantity },     -- seconds for the lag behind the target to halve, 0 = none
			{ name = 'onEnd',              required = false, type = ParameterTypes.CameraSequenceEnd },
			{ name = 'restoreSlot',        required = false, type = ParameterTypes.String },       -- SaveCamera slot for onEnd = 'restore'
			{ name = 'restoreDuration',    required = false, type = ParameterTypes.Quantity },     -- seconds
			{ name = 'restoreEasing',      required = false, type = ParameterTypes.CameraEasing },
			{ name = 'releaseDuration',    required = false, type = ParameterTypes.Quantity },     -- seconds to ease roll and fov back for onEnd = 'release'
			{ name = 'releaseEasing',      required = false, type = ParameterTypes.CameraEasing },
			requiresOneOf = { 'unitName', 'position' },
		},
		actionFunction = followCamera,
	}
}
