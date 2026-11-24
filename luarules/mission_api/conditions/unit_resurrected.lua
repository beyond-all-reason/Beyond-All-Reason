local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local ConditionKinds = GG['MissionAPI'].Modules.ConditionKinds

return {
	type = 'UnitResurrected',
	kind = ConditionKinds.Event,
	parameters = {
		{ name = 'includeUnit', required = false, type = ParameterTypes.UnitFilter },
		{ name = 'excludeUnit', required = false, type = ParameterTypes.UnitFilters },
		{ name = 'featureName', required = false, type = ParameterTypes.FeatureName },
		requiresOneOf = { 'featureName', 'includeUnit' },
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
			if not context.IsUnitIncluded(unitID, trigger.parameters, unitDefID, unitTeam) then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}
