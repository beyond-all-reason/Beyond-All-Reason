local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local ConditionKinds = GG['MissionAPI'].Modules.ConditionKinds

return {
	type = 'CountdownFinished',
	kind = ConditionKinds.Event,
	parameters = {
		{ name = 'countdownID', required = true, type = ParameterTypes.CountdownID },
	},
	callins = {
		CountdownEnded = function(trigger, triggerID, context, countdownID)
			if trigger.parameters.countdownID ~= countdownID then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
