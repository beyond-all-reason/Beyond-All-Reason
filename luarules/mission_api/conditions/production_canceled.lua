local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local ConditionKinds = GG['MissionAPI'].Modules.ConditionKinds

local DAMAGETYPE_FACTORY_CANCEL = Game.envDamageTypes.FactoryCancel
local DAMAGETYPE_FACTORY_KILLED = Game.envDamageTypes.FactoryKilled -- Kills current buildee, which might be completed. Oy vey.

local function matchesUnit(trigger, context, unitID, unitDefID, unitTeam)
	local parameters = trigger.parameters
	if not context.IsUnitIncluded(unitID, parameters, unitDefID, unitTeam) then
		return false
	end
	if not context.IsBuildFrameOwner(unitID, parameters.factoryName, parameters.factoryDefName) then
		return false
	end
	return true
end

return {
	type = 'ProductionCanceled',
	kind = ConditionKinds.Event,
	parameters = {
		{ name = 'includeUnit',    required = true,  type = ParameterTypes.UnitFilter },
		{ name = 'excludeUnit',    required = false, type = ParameterTypes.UnitFilters },
		{ name = 'factoryName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'factoryDefName', required = false, type = ParameterTypes.UnitDefName },
	},
	callins = {
		UnitDestroyed = function(trigger, triggerID, context, unitID, unitDefID, unitTeam,
		                         attackerID, attackerDefID, attackerTeam, weaponDefID)
			if weaponDefID ~= DAMAGETYPE_FACTORY_CANCEL and (weaponDefID ~= DAMAGETYPE_FACTORY_KILLED or not Spring.GetUnitIsBeingBuilt(unitID)) then
				return
			end

			if matchesUnit(trigger, context, unitID, unitDefID, unitTeam) then
				context.ActivateTrigger(trigger)
			end
		end,

		-- Units captured while inside a factory are not canceled. Keep this so mission authors do not have to know
		-- about the engine's split decision-making for canceling units when a factory vs its buildee is captured.
		UnitTaken = function(trigger, triggerID, context, unitID, unitDefID, oldTeam, newTeam)
			if not Spring.GetUnitIsBeingBuilt(unitID) or not context.InFactory(unitID) then
				return
			end

			if matchesUnit(trigger, context, unitID, unitDefID, oldTeam) then
				context.ActivateTrigger(trigger)
			end
		end,
	},
}
