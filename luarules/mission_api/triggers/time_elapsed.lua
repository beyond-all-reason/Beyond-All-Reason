local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

return {
	type = 'TimeElapsed',
	parameters = {
		{ name = 'gameFrame', required = true,  type = ParameterTypes.Number },
		{ name = 'interval',  required = false, type = ParameterTypes.Number },
	},
	callins = {
		GameFrame = function(trigger, triggerID, context, gameframe)
			local targetframe = trigger.parameters.gameFrame
			local interval = trigger.parameters.interval

			if gameframe == targetframe or (trigger.settings.repeating and gameframe > targetframe and (gameframe - targetframe) % interval == 0) then
				context.ActivateTrigger(trigger)
			end
		end,
	},
}
