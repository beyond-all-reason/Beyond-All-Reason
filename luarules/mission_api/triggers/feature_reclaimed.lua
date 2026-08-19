local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

return {
	type = 'FeatureReclaimed',
	parameters = {
		{ name = 'featureName',    required = false, type = ParameterTypes.FeatureName },
		{ name = 'featureDefName', required = false, type = ParameterTypes.FeatureDefName },
		{ name = 'teamName',       required = false, type = ParameterTypes.TeamName },
		{ name = 'area',           required = false, type = ParameterTypes.Area },
		requiresOneOf = { 'featureName', 'featureDefName', 'teamName', 'area' },
	},
	callins = {
		FeatureDestroyed = function(trigger, triggerID, context, featureID, featureDefID, attackerAllyTeamID, reclaimerTeamID, reclaimLeft)
			-- Feature was fully reclaimed:
			if not (reclaimerTeamID and reclaimLeft <= 0) then
				return
			end

			if trigger.parameters.featureName and not context.DoesFeatureHaveName(featureID, trigger.parameters.featureName) then
				return
			end
			if trigger.parameters.featureDefName and trigger.parameters.featureDefName ~= FeatureDefs[featureDefID].name then
				return
			end
			if trigger.parameters.teamName and reclaimerTeamID ~= GG['MissionAPI'].Teams[trigger.parameters.teamName] then
				return
			end
			if trigger.parameters.area and not context.IsFeatureInArea(featureID, trigger.parameters.area) then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
