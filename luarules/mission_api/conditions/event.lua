local ConditionKinds = GG['MissionAPI'].Modules.ConditionKinds

-- Raised by whatever names it: an objective's `onCompleted`, for now.
-- Declares no callins and no parameters, so nothing else can fire it.
return {
	type = 'Event',
	kind = ConditionKinds.Event,
	parameters = {},
}
