local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local ConditionKinds = GG['MissionAPI'].Modules.ConditionKinds

-- Return value index as on https://recoilengine.org/docs/lua-api/#Spring.GetTeamResources
local CURRENT_RESOURCE_LEVEL_INDEX = 1

return {
	type = 'ResourceStored',
	kind = ConditionKinds.Metric,
	parameters = {
		{ name = 'teamName', required = true, type = ParameterTypes.TeamName },
		{ name = 'resource', required = true, type = ParameterTypes.Resource },
	},
	callins = {
		GameFrame = function(trigger, triggerID, context)
			local stored = select(CURRENT_RESOURCE_LEVEL_INDEX,
				Spring.GetTeamResources(trigger.parameters.teamName, trigger.parameters.resource))
			context.EvaluateMetric(trigger, stored or 0)
		end,
	},
}
