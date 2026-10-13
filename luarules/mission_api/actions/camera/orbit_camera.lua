local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Circles a unit, the centroid of several units (unitName and unitNames add up), or a position
-- (which wins over any units named): `degrees` of turn (signed;
-- default a full turn) over `duration` seconds, from `distance` elmos away, pitched down by
-- `pitch` degrees. startYaw is the compass bearing the orbit starts on; left out, the orbit
-- starts from the bearing the camera already has toward the target. The sweep starts at once
-- (eased in and out unless `easing` says otherwise) and the current view blends into it over
-- `transitionDuration` seconds.
local function orbitCamera(
	unitName,
	unitNames,
	position,
	distance,
	pitch,
	startYaw,
	degrees,
	duration,
	transitionDuration,
	easing,
	onEnd,
	teamID
)
	local clientActions = GG['MissionAPI'].Modules.ClientActions
	clientActions.Send('orbit', {
		target = clientActions.BuildTarget(unitName, unitNames, position),
		distance = distance,
		pitch = pitch,
		startYaw = startYaw,
		degrees = degrees,
		duration = duration,
		transitionDuration = transitionDuration,
		easing = easing,
		onEnd = onEnd,
	}, teamID)
end

return {
	{
		type = 'OrbitCamera',
		parameters = {
			{ name = 'unitName',           required = false, type = ParameterTypes.UnitName },
			{ name = 'unitNames',          required = false, type = ParameterTypes.UnitNames },
			{ name = 'position',           required = false, type = ParameterTypes.Position },
			{ name = 'distance',           required = false, type = ParameterTypes.Quantity }, -- elmos
			{ name = 'pitch',              required = false, type = ParameterTypes.Number },   -- degrees
			{ name = 'startYaw',           required = false, type = ParameterTypes.Number },   -- degrees
			{ name = 'degrees',            required = false, type = ParameterTypes.Number },   -- degrees of turn, signed
			{ name = 'duration',           required = false, type = ParameterTypes.Quantity }, -- seconds
			{ name = 'transitionDuration', required = false, type = ParameterTypes.Quantity }, -- seconds
			{ name = 'easing',             required = false, type = ParameterTypes.Easing },
			{ name = 'onEnd',              required = false, type = ParameterTypes.CameraSequenceEnd },
			{ name = 'teamID',             required = false, type = ParameterTypes.TeamID }, -- only this team's players; everyone when left out
			requiresOneOf = { 'unitName', 'unitNames', 'position' },
		},
		actionFunction = orbitCamera,
	}
}
