local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local ConditionKinds = GG['MissionAPI'].Modules.ConditionKinds

-- Fires when a position comes into the vision of an alliance, such as a wreck or a cache.
-- The engine has no call-in for a position entering line of sight, so the position is polled.
-- Repeating triggers fire again each time the position comes back into sight after leaving it.

-- Half a second is soon enough for a line of dialogue, at one LOS read per trigger.
local CHECK_INTERVAL_FRAMES = math.floor(0.5 * Game.gameSpeed)

local function onActivationAttempted(trigger, triggerID, context, argument, activated)
	if activated then
		context.RevealedLocations[triggerID] = true
	end
end

return {
	type = 'LocationRevealed',
	kind = ConditionKinds.Event,
	parameters = {
		{ name = 'position',           required = true, type = ParameterTypes.Position },
		{ name = 'sensorAllianceName', required = true, type = ParameterTypes.AllianceName },
	},
	callins = {
		GameFrame = function(trigger, triggerID, context, frameNumber)
			if frameNumber % CHECK_INTERVAL_FRAMES ~= 0 then
				return
			end
			local parameters = trigger.parameters
			local position = parameters.position
			if not Spring.IsPosInLos(position.x, position.y, position.z, parameters.sensorAllianceName) then
				context.RevealedLocations[triggerID] = nil
			elseif not context.RevealedLocations[triggerID] then
				context.ActivateTrigger(trigger, onActivationAttempted, triggerID)
			end
		end,
	},
}
