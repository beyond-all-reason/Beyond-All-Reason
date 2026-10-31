local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

return {
	type = 'FeatureCreated',
	parameters = {
		{ name = 'featureDefName', required = false, type = ParameterTypes.FeatureDefName },
		{ name = 'area',           required = false, type = ParameterTypes.Area },
		requiresOneOf = { 'featureDefName', 'area' },
	},
	callins = {
		FeatureCreated = function(trigger, triggerID, context, featureID, featureDefID)
			if trigger.parameters.featureDefName and trigger.parameters.featureDefName ~= FeatureDefs[featureDefID].name then
				return
			end
			if trigger.parameters.area and not context.IsFeatureInArea(featureID, trigger.parameters.area) then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
