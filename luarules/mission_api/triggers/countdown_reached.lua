local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- timeRemaining is deliberately a Number, not a Quantity: a Quantity parameter
-- would turn this into a statistics trigger (see mission-api-instructions.md).
return {
	type = 'CountdownReached',
	parameters = {
		{ name = 'countdownID', required = true, type = ParameterTypes.CountdownID },
		{ name = 'timeRemaining', required = true, type = ParameterTypes.Number },
	},
	callins = {
		CountdownTick = function(trigger, triggerID, context, countdownID, timeRemaining)
			if trigger.parameters.countdownID ~= countdownID then
				return
			end
			if trigger.parameters.timeRemaining ~= timeRemaining then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
