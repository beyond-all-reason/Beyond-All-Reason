local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Points the camera at a unit, the centroid of several units (unitName and unitNames add up),
-- or a position (which wins over any units named), and follows it
-- from `distance` elmos away, pitched down by `pitch` degrees (0 level, 90 straight down) on
-- compass bearing `yaw`. A duration of 0 (the default) follows until another camera action;
-- otherwise the shot ends after `duration` seconds as `onEnd` says. The shot starts at once and
-- the current view blends into it over `transitionDuration` seconds, shaped by `easing`.
-- `smoothing` is something else: how far the camera trails a moving target. Its gap to the
-- target halves every `smoothing` seconds, so 0 pins the camera rigidly to the target and larger
-- values make it float after the unit.
local function followCamera(
	unitName,
	unitNames,
	position,
	distance,
	pitch,
	yaw,
	duration,
	transitionDuration,
	easing,
	smoothing,
	onEnd,
	teamID
)
	local clientActions = GG['MissionAPI'].Modules.ClientActions
	clientActions.Send('follow', {
		target = clientActions.BuildTarget(unitName, unitNames, position),
		distance = distance,
		pitch = pitch,
		yaw = yaw,
		duration = duration,
		transitionDuration = transitionDuration,
		easing = easing,
		smoothing = smoothing,
		onEnd = onEnd,
	}, teamID)
end

return {
	{
		type = 'FollowCamera',
		parameters = {
			{ name = 'unitName',           required = false, type = ParameterTypes.UnitName },
			{ name = 'unitNames',          required = false, type = ParameterTypes.UnitNames },
			{ name = 'position',           required = false, type = ParameterTypes.Position },
			{ name = 'distance',           required = false, type = ParameterTypes.Quantity }, -- elmos
			{ name = 'pitch',              required = false, type = ParameterTypes.Number },   -- degrees
			{ name = 'yaw',                required = false, type = ParameterTypes.Number },   -- degrees
			{ name = 'duration',           required = false, type = ParameterTypes.Quantity }, -- seconds, 0 = until stopped
			{ name = 'transitionDuration', required = false, type = ParameterTypes.Quantity }, -- seconds
			{ name = 'easing',             required = false, type = ParameterTypes.Easing },   -- of the lead-in blend
			{ name = 'smoothing',          required = false, type = ParameterTypes.Quantity }, -- seconds, 0 = rigid
			{ name = 'onEnd',              required = false, type = ParameterTypes.CameraSequenceEnd },
			{ name = 'teamID',             required = false, type = ParameterTypes.TeamID }, -- only this team's players; everyone when left out
			requiresOneOf = { 'unitName', 'unitNames', 'position' },
		},
		actionFunction = followCamera,
	}
}
