local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

return {
	type = 'UnitResurrected',
	parameters = {
		{ name = 'unitDefName', required = false, type = ParameterTypes.UnitDefName },
		{ name = 'teamName',    required = false, type = ParameterTypes.TeamName },
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
			if trigger.parameters.teamName and unitTeam ~= GG['MissionAPI'].Teams[trigger.parameters.teamName] then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
