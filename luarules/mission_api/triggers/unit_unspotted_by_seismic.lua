local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local SeismicContacts = VFS.Include('luarules/mission_api/seismic_contacts.lua')

-- Seismic sensors have no engine "left range" event. It is a ping/heartbeat.

-- A unit only pings while it happens to be moving at its slow update, so a gap in the series is not
-- a loss of detection: moving in short enough bursts skips pings without ever leaving coverage.
-- Falloff is scored against a sustained ping rate instead. See seismic_contacts.lua.

-- Filters that hold for a unit at any time, so they can be rechecked once its contact falls off.
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

		-- Artificial callin that we raise once every 15 frames in GameFrame,
		-- matching the full interval of the sliding window on seismic pings.
		SeismicInterval = function(trigger, triggerID, context)
			for index = 1, SeismicContacts.UpdateContacts(triggerID, undetected) do
				local unitID = undetected[index]
				-- Dying/crashing/exploding units can still emit pings.
				-- Unit tracking can change in the delay before firing.
				if Spring.GetUnitIsDead(unitID) == false and matchesUnit(trigger, context, unitID, Spring.GetUnitDefID(unitID)) then
					context.ActivateTrigger(trigger)
				end
			end
		end,
	},
}
