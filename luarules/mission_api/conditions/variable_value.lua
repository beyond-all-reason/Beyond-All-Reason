local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local ConditionKinds = GG['MissionAPI'].Modules.ConditionKinds

local function evaluate(trigger, context)
	context.EvaluateMetric(trigger, GG['MissionAPI'].Variables[trigger.parameters.key])
end

return {
	type = 'VariableValue',
	kind = ConditionKinds.Metric,
	parameters = {
		{ name = 'key', required = true, type = ParameterTypes.VariableKey },
	},
	callins = {
		VariablesInitialized = function(trigger, triggerID, context)
			evaluate(trigger, context)
		end,
		VariableWritten = function(trigger, triggerID, context, key)
			if trigger.parameters.key == key then
				evaluate(trigger, context)
			end
		end,
	},
}
