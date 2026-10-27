local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local countdowns = GG['MissionAPI'].Modules.Countdowns

local function secondsToFrames(seconds)
	-- Round to the nearest whole frame:
	return math.floor(seconds * Game.gameSpeed + 0.5)
end

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
		GameStart = function(trigger, triggerID, _context)
			countdowns.AddCountdownFrames(getCountdownID(triggerID), secondsToFrames(trigger.parameters.seconds))
		end,
		CountdownEnded = function(trigger, triggerID, context, countdownID)
			if countdownID ~= getCountdownID(triggerID) then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
