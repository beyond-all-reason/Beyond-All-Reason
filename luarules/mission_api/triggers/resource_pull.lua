local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Return value index as on https://recoilengine.org/docs/lua-api/#Spring.GetTeamResources
local RESOURCE_PULL_INDEX = 3

return {
	type = 'ResourcePull',
	parameters = {
		{ name = 'teamName', required = true,  type = ParameterTypes.TeamName },
		{ name = 'metal',    required = false, type = ParameterTypes.Number },
		{ name = 'energy',   required = false, type = ParameterTypes.Number },
		requiresOneOf = { 'metal', 'energy' },
	},
	callins = {
		GameFrame = function(trigger, triggerID, context, frameNumber)
			-- Pull is evaluated once per second (matches income accounting).
			if frameNumber % Game.gameSpeed ~= 0 then
				return
			end

			local teamID = GG['MissionAPI'].Teams[trigger.parameters.teamName]
			if trigger.parameters.metal and select(RESOURCE_PULL_INDEX, Spring.GetTeamResources(teamID, "metal")) < trigger.parameters.metal then
				return
			end
			if trigger.parameters.energy and select(RESOURCE_PULL_INDEX, Spring.GetTeamResources(teamID, "energy")) < trigger.parameters.energy then
				return
			end

			context.ActivateTrigger(trigger)
		end,
	},
}
