local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local countdowns = GG['MissionAPI'].Modules.Countdowns

local function getCountdownID(triggerID)
	return '__timeElapsed_' .. triggerID
end

return {
	type = 'TimeElapsed',
	parameters = {
		{ name = 'seconds',  required = true,  type = ParameterTypes.Number },
		{ name = 'interval', required = false, type = ParameterTypes.Number },
	},
	callins = {
		GameStart = function(trigger, triggerID, context)
			local seconds = trigger.parameters.seconds
			if seconds <= 0 then
				context.ActivateTrigger(trigger)
				return
			end
			countdowns.AddCountdown(getCountdownID(triggerID), seconds, false)
		end,
		CountdownEnded = function(trigger, triggerID, context, countdownID)
			if countdownID ~= getCountdownID(triggerID) then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
