local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Return value index as on https://recoilengine.org/docs/lua-api/#Spring.GetTeamResources
local RESOURCE_PULL_INDEX = 3

return {
	type = 'ResourcePull',
	kind = 'metric',
	parameters = {
		{ name = 'teamName', required = true, type = ParameterTypes.TeamName },
		{ name = 'resource', required = true, type = ParameterTypes.Resource },
	},
	callins = {
		GameFrame = function(trigger, triggerID, context, frameNumber)
			-- Pull is evaluated once per second (matches income accounting).
			if frameNumber % Game.gameSpeed ~= 0 then
				return
			end
			local pull = select(RESOURCE_PULL_INDEX,
				Spring.GetTeamResources(trigger.parameters.teamName, trigger.parameters.resource))
			context.EvaluateMetric(trigger, pull or 0)
		end,
	},
}
