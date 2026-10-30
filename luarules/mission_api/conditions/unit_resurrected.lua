local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

return {
	type = 'UnitResurrected',
	parameters = {
		{ name = 'unitDefName', required = false, type = ParameterTypes.UnitDefName },
		{ name = 'teamID',      required = false, type = ParameterTypes.TeamID },
		{ name = 'featureName', required = false, type = ParameterTypes.FeatureName },
		requiresOneOf = { 'featureName', 'unitDefName' },
	},
	callins = {
		UnitCreated = function(trigger, triggerID, context, unitID, unitDefID, unitTeam, builderID)
			if not builderID then
				return
			end

			local cmdID, featureID = Spring.GetUnitWorkerTask(builderID)
			if cmdID ~= CMD.RESURRECT then
				return
			end
			if not Engine.FeatureSupport.noOffsetForFeatureID then
				featureID = featureID - Game.maxUnits
			end

			if trigger.parameters.featureName and not context.DoesFeatureHaveName(featureID, trigger.parameters.featureName) then
				return
			end
			if trigger.parameters.unitDefName and trigger.parameters.unitDefName ~= UnitDefs[unitDefID].name then
				return
			end
			if trigger.parameters.teamID and unitTeam ~= trigger.parameters.teamID then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
