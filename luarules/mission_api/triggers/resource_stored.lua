local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Return value index as on https://recoilengine.org/docs/lua-api/#Spring.GetTeamResources
local CURRENT_RESOURCE_LEVEL_INDEX = 1

return {
	type = 'ResourceStored',
	parameters = {
		{ name = 'teamID', required = true,  type = ParameterTypes.TeamID },
		{ name = 'metal',  required = false, type = ParameterTypes.Number },
		{ name = 'energy', required = false, type = ParameterTypes.Number },
		requiresOneOf = { 'metal', 'energy' },
	},
	callins = {
		GameFrame = function(trigger, triggerID, context)
			if trigger.parameters.metal and select(CURRENT_RESOURCE_LEVEL_INDEX, Spring.GetTeamResources(trigger.parameters.teamID, "metal")) < trigger.parameters.metal then
				return
			end
			if trigger.parameters.energy and select(CURRENT_RESOURCE_LEVEL_INDEX, Spring.GetTeamResources(trigger.parameters.teamID, "energy")) < trigger.parameters.energy then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
