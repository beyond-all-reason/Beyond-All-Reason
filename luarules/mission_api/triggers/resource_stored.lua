local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Return value index as on https://recoilengine.org/docs/lua-api/#Spring.GetTeamResources
local CURRENT_RESOURCE_LEVEL_INDEX = 1

return {
	type = 'ResourceStored',
	parameters = {
		{ name = 'teamName', required = true,  type = ParameterTypes.TeamName },
		{ name = 'metal',    required = false, type = ParameterTypes.Number },
		{ name = 'energy'  , required = false, type = ParameterTypes.Number },
		requiresOneOf = { 'metal', 'energy' },
	},
	callins = {
		GameFrame = function(trigger, triggerID, context)
			local teamId = GG['MissionAPI'].Teams[trigger.parameters.teamName]
			if trigger.parameters.metal and select(CURRENT_RESOURCE_LEVEL_INDEX, Spring.GetTeamResources(teamId, "metal")) < trigger.parameters.metal then
				return
			end
			if trigger.parameters.energy and select(CURRENT_RESOURCE_LEVEL_INDEX, Spring.GetTeamResources(teamId, "energy")) < trigger.parameters.energy then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
