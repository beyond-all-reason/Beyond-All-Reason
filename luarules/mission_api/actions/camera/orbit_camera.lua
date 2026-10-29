local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Circles a unit (the middle of the group when several share the name) or a position.
local function orbitCamera(unitName, position, distance, pitch, startYaw, degrees, fov, duration, transitionDuration, easing, onEnd, restoreSlot, restoreDuration, restoreEasing, releaseDuration, releaseEasing)
	SendToUnsynced('MissionCameraOrbit', {
		target = GG['MissionAPI'].Modules.Camera.BuildTarget(unitName, position),
		distance = distance,
		pitch = pitch,
		startYaw = startYaw,
		degrees = degrees,
		fov = fov,
		duration = duration,
		transitionDuration = transitionDuration,
		easing = easing,
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
		type = 'OrbitCamera',
		parameters = {
			{ name = 'unitName',           required = false, type = ParameterTypes.UnitName },
			{ name = 'position',           required = false, type = ParameterTypes.Position },
			{ name = 'distance',           required = false, type = ParameterTypes.Quantity },     -- elmos
			{ name = 'pitch',              required = false, type = ParameterTypes.Number },       -- degrees, 0 = level, 90 = straight down
			{ name = 'startYaw',           required = false, type = ParameterTypes.Number },       -- degrees, compass bearing; default: where the camera already is
			{ name = 'degrees',            required = false, type = ParameterTypes.Number },       -- how far to turn, negative turns the other way
			{ name = 'fov',                required = false, type = ParameterTypes.Number },       -- degrees, vertical
			{ name = 'duration',           required = false, type = ParameterTypes.Quantity },     -- seconds
			{ name = 'transitionDuration', required = false, type = ParameterTypes.Quantity },     -- seconds to blend in from the current view
			{ name = 'easing',             required = false, type = ParameterTypes.CameraEasing }, -- of the turn
			{ name = 'onEnd',              required = false, type = ParameterTypes.CameraSequenceEnd },
			{ name = 'restoreSlot',        required = false, type = ParameterTypes.String },       -- SaveCamera slot for onEnd = 'restore'
			{ name = 'restoreDuration',    required = false, type = ParameterTypes.Quantity },     -- seconds
			{ name = 'restoreEasing',      required = false, type = ParameterTypes.CameraEasing },
			{ name = 'releaseDuration',    required = false, type = ParameterTypes.Quantity },     -- seconds to ease roll and fov back for onEnd = 'release'
			{ name = 'releaseEasing',      required = false, type = ParameterTypes.CameraEasing },
			requiresOneOf = { 'unitName', 'position' },
		},
		actionFunction = orbitCamera,
	}
}
