local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local SeismicContacts = VFS.Include('luarules/mission_api/seismic_contacts.lua')

-- Seismic sensors have no engine "left range" event. It is a ping/heartbeat.

-- A unit only pings while it happens to be moving at its slow update, so a gap in the series is not
-- a loss of detection: moving in short enough bursts skips pings without ever leaving coverage.
-- Falloff is scored against a sustained ping rate instead. See seismic_contacts.lua.

-- This exists as a built-in because actions cannot see the unit that fired a trigger.
-- A `Custom` action passed the triggering target data (unitID, unitDefID, unitTeam)
-- could replace it with a plain recipe: a UnitSpottedBySeismic and a per-unit timer.

-- Filters that hold for a unit at any time, so they can be rechecked once its contact falls off.
-- spottingAllyTeamID is not among them: only a ping says which allyTeam heard it.
local function matchesUnit(trigger, context, unitID, unitDefID)
	if trigger.parameters.unitName and not context.DoesUnitHaveName(unitID, trigger.parameters.unitName) then
		return false
	end
	if trigger.parameters.unitDefName and trigger.parameters.unitDefName ~= UnitDefs[unitDefID].name then
		return false
	end
	if trigger.parameters.owningTeamID and trigger.parameters.owningTeamID ~= Spring.GetUnitTeam(unitID) then
		return false
	end
	return true
end

-- Reused each interval to collect the contacts that fell off.
local undetected = {}

return {
	type = 'UnitUnspottedBySeismic',
	parameters = {
		{ name = 'unitName',           required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName',        required = false, type = ParameterTypes.UnitDefName },
		{ name = 'owningTeamID',       required = false, type = ParameterTypes.TeamID },
		{ name = 'spottingAllyTeamID', required = false, type = ParameterTypes.AllyTeamID },
		requiresOneOf = { 'unitName', 'unitDefName' },
	},
	callins = {
		UnitSeismicPing = function(trigger, triggerID, context, x, y, z, strength, seismicAllyTeamID, unitID, unitDefID)
			if not matchesUnit(trigger, context, unitID, unitDefID) then
				return
			end
			if trigger.parameters.spottingAllyTeamID and trigger.parameters.spottingAllyTeamID ~= seismicAllyTeamID then
				return
			end
			SeismicContacts.RecordPing(triggerID, unitID)
		end,

		GameFrame = function(trigger, triggerID, context, frameNumber)
			if not SeismicContacts.IsIntervalEnd(frameNumber) then
				return
			end
			for index = 1, SeismicContacts.UpdateScores(triggerID, undetected) do
				local unitID = undetected[index]
				-- Dying/crashing/exploding units can still emit pings.
				-- Unit tracking can change in the delay before firing.
				if Spring.GetUnitIsDead(unitID) == false and matchesUnit(trigger, context, unitID, Spring.GetUnitDefID(unitID)) then
					context.ActivateTrigger(trigger)
				end
			end
		end,

		UnitDestroyed = function(trigger, triggerID, context, unitID)
			SeismicContacts.Forget(triggerID, unitID)
		end,
	},
}
