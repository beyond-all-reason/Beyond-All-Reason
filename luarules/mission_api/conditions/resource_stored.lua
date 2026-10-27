local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Return value index as on https://recoilengine.org/docs/lua-api/#Spring.GetTeamResources
local CURRENT_RESOURCE_LEVEL_INDEX = 1

return {
	type = 'ResourceStored',
	kind = 'metric',
	parameters = {
		{ name = 'teamID',   required = true, type = ParameterTypes.TeamID },
		{ name = 'resource', required = true, type = ParameterTypes.Resource },
	},
	callins = {
		GameFrame = function(trigger, triggerID, context)
			local stored = select(CURRENT_RESOURCE_LEVEL_INDEX,
				Spring.GetTeamResources(trigger.parameters.teamID, trigger.parameters.resource))
			context.EvaluateMetric(trigger, stored or 0)
		end,
	},
}
