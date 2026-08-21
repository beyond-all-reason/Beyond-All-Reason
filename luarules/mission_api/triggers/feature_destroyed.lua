local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

return {
	type = 'FeatureDestroyed',
	parameters = {
		{ name = 'featureName',    required = false, type = ParameterTypes.FeatureName },
		{ name = 'featureDefName', required = false, type = ParameterTypes.FeatureDefName },
		{ name = 'allyTeamName',   required = false, type = ParameterTypes.AllyTeamName },
		{ name = 'area',           required = false, type = ParameterTypes.Area },
		requiresOneOf = { 'featureName', 'featureDefName', 'allyTeamName', 'area' },
	},
	callins = {
		FeatureDestroyed = function(trigger, triggerID, context, featureID, featureDefID, attackerAllyTeamID, reclaimerTeamID, reclaimLeft)
			-- Skip when the feature was fully reclaimed (handled by FeatureReclaimed):
			if reclaimerTeamID and reclaimLeft <= 0 then
				return
			end

			if trigger.parameters.featureName and not context.DoesFeatureHaveName(featureID, trigger.parameters.featureName) then
				return
			end
			if trigger.parameters.featureDefName and trigger.parameters.featureDefName ~= FeatureDefs[featureDefID].name then
				return
			end
			if trigger.parameters.allyTeamName and attackerAllyTeamID ~= GG['MissionAPI'].AllyTeams[trigger.parameters.allyTeamName] then
				return
			end
			if trigger.parameters.area and not context.IsFeatureInArea(featureID, trigger.parameters.area) then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
