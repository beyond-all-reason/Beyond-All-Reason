local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function secondsToFrames(seconds)
	-- Round to the nearest whole frame:
	return math.floor(seconds * Game.gameSpeed + 0.5)
end

return {
	type = 'TimeElapsed',
	parameters = {
		{ name = 'seconds',  required = true,  type = ParameterTypes.Number },
		{ name = 'interval', required = false, type = ParameterTypes.Number },
	},
	callins = {
		GameFrame = function(trigger, triggerID, context, gameFrame)
			local parameters = trigger.parameters
			-- GameFrame isn't called on frame 0:
			local targetFrame = math.max(1, secondsToFrames(parameters.seconds))

			if gameFrame == targetFrame then
				context.ActivateTrigger(trigger)
			elseif trigger.settings.repeating and parameters.interval and gameFrame > targetFrame then
				local intervalFrames = secondsToFrames(parameters.interval)
				if intervalFrames > 0 and (gameFrame - targetFrame) % intervalFrames == 0 then
					context.ActivateTrigger(trigger)
				end
			end
		end,
	},
}
