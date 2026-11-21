local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

return {
	type = 'UnitResurrected',
	parameters = {
		{ name = 'filter',      required = false, type = ParameterTypes.UnitFilter },
		{ name = 'exclude',     required = false, type = ParameterTypes.UnitFilters },
		{ name = 'featureName', required = false, type = ParameterTypes.FeatureName },
		requiresOneOf = { 'featureName', 'filter' },
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
			if not context.DoesUnitMatchCondition(unitID, trigger.parameters, unitDefID, unitTeam) then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
