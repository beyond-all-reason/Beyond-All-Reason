local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local DAMAGETYPE_FACTORY_CANCEL = Game.envDamageTypes.FactoryCancel

local function matchesUnit(trigger, context, unitID, unitDefID, unitTeam)
	local parameters = trigger.parameters
	if parameters.unitName and not context.DoesUnitHaveName(unitID, parameters.unitName) then
		return false
	end
	if parameters.unitDefName and parameters.unitDefName ~= UnitDefs[unitDefID].name then
		return false
	end
	if parameters.teamID and not Spring.AreTeamsAllied(parameters.teamID, unitTeam) then
		return false
	end
	if not context.isBuildFrameOwner(unitID, parameters.factoryDefName, parameters.factoryName) then
		return false
	end
	return true
end

return {
	type = 'ProductionCanceled',
	parameters = {
		{ name = 'unitName',       required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName',    required = false, type = ParameterTypes.UnitDefName },
		{ name = 'teamID',         required = false, type = ParameterTypes.TeamID },
		{ name = 'factoryName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'factoryDefName', required = false, type = ParameterTypes.UnitDefName },
		requiresOneOf = { 'unitName', 'unitDefName' },
	},
	callins = {
		UnitDestroyed = function(trigger, triggerID, context, unitID, unitDefID, unitTeam,
		                         attackerID, attackerDefID, attackerTeam, weaponDefID)
			if weaponDefID ~= DAMAGETYPE_FACTORY_CANCEL then
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
