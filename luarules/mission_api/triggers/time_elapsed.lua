local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local countdowns = GG['MissionAPI'].Modules.Countdowns

local function secondsToFrames(seconds)
	-- Round to the nearest whole frame:
	return math.floor(seconds * Game.gameSpeed + 0.5)
end

-- Each TimeElapsed trigger runs on a hidden countdown, so it can be changed like any countdown.
local function countdownIDOf(triggerID)
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
			-- GameFrame isn't called on frame 0:
			local frames = math.max(1, secondsToFrames(trigger.parameters.seconds))
			countdowns.AddCountdownFrames(countdownIDOf(triggerID), frames)
		end,
		CountdownEnded = function(trigger, triggerID, context, countdownID)
			if countdownID ~= countdownIDOf(triggerID) then
				return
			end
			context.ActivateTrigger(trigger)

			local interval = trigger.parameters.interval
			if trigger.settings.repeating and interval then
				local intervalFrames = secondsToFrames(interval)
				if intervalFrames > 0 then
					countdowns.AddCountdownFrames(countdownID, intervalFrames)
				end
			end
		end,
	},
}
