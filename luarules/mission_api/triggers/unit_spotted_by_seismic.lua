local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local SeismicContacts = VFS.Include('luarules/mission_api/seismic_contacts.lua')

-- Fires when a matching enemy unit is picked up by an allyTeam's seismic coverage.
-- This is generally while the unit is moving within that range; there are caveats.

-- Synced gadgets receive seismic pings for all units, even fully visible ones.

return {
	type = 'UnitSpottedBySeismic',
	parameters = {
		{ name = 'unitName',           required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName',        required = false, type = ParameterTypes.UnitDefName },
		{ name = 'owningTeamID',       required = false, type = ParameterTypes.TeamID },
		{ name = 'spottingAllyTeamID', required = false, type = ParameterTypes.AllyTeamID },
		requiresOneOf = { 'unitName', 'unitDefName' },
	},
	callins = {
		UnitSeismicPing = function(trigger, triggerID, context, x, y, z, strength, seismicAllyTeamID, unitID, unitDefID)
			if trigger.parameters.unitName and not context.DoesUnitHaveName(unitID, trigger.parameters.unitName) then
				return
			end
			if trigger.parameters.unitDefName and trigger.parameters.unitDefName ~= UnitDefs[unitDefID].name then
				return
			end
			if trigger.parameters.owningTeamID and trigger.parameters.owningTeamID ~= Spring.GetUnitTeam(unitID) then
				return
			end
			if trigger.parameters.spottingAllyTeamID and trigger.parameters.spottingAllyTeamID ~= seismicAllyTeamID then
				return
			end
			if SeismicContacts.RecordPing(triggerID, unitID) then
				context.ActivateTrigger(trigger)
			end
		end,

		SeismicInterval = function(trigger, triggerID, context)
			-- Falloff only re-arms this trigger. UnitUnspottedBySeismic is what reports it.
			SeismicContacts.UpdateScores(triggerID)
		end,
	},
}
