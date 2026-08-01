local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Seismic sensors have no engine "left range" event. It is a ping/heartbeat.

-- Zero/negative timeouts are not validation errors, same as in TimeElapsed.
-- Instead, they indicate to fire on the first lapse in the series of pings.
-- For that, we use the engine's automatic update interval, on `SlowUpdate`.

-- This exists as a built-in because actions cannot see the unit that fired a trigger.
-- A `Custom` action passed the triggering target data (unitID, unitDefID, unitTeam)
-- could replace it with a plain recipe: a UnitSpottedBySeismic and a per-unit timer.

local SEISMIC_INTERVAL_FRAMES = 15
local DEFAULT_TIMEOUT_SECONDS = 1.0

local function match(trigger, context, unitID, unitDefID, seismicAllyTeamID)
	if trigger.parameters.unitName and not context.DoesUnitHaveName(unitID, trigger.parameters.unitName) then
		return false
	end
	if trigger.parameters.unitDefName and trigger.parameters.unitDefName ~= UnitDefs[unitDefID].name then
		return false
	end
	if trigger.parameters.owningTeamID and trigger.parameters.owningTeamID ~= Spring.GetUnitTeam(unitID) then
		return false
	end
	if trigger.parameters.spottingAllyTeamID and trigger.parameters.spottingAllyTeamID ~= seismicAllyTeamID then
		return false
	end
	return true
end

local function getTimeoutInterval(trigger)
	local timeout = trigger.parameters.timeout or DEFAULT_TIMEOUT_SECONDS
	return math.max(math.floor(timeout * Game.gameSpeed / SEISMIC_INTERVAL_FRAMES + 0.5), 1)
end

local function addSeismicContact(context, triggerID, unitID, unitDefID, seismicAllyTeamID)
	table.ensureTable(context.SeismicContacts, triggerID)[unitID] = {
		interval = math.floor(Spring.GetGameFrame() / SEISMIC_INTERVAL_FRAMES),
		unitDefID = unitDefID,
		seismicAllyTeamID = seismicAllyTeamID,
	}
end

return {
	type = 'UnitUnspottedBySeismic',
	parameters = {
		{ name = 'unitName',           required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName',        required = false, type = ParameterTypes.UnitDefName },
		{ name = 'owningTeamID',       required = false, type = ParameterTypes.TeamID },
		{ name = 'spottingAllyTeamID', required = false, type = ParameterTypes.AllyTeamID },
		{ name = 'timeout',            required = false, type = ParameterTypes.Number },
		requiresOneOf = { 'unitName', 'unitDefName' },
	},
	callins = {
		UnitSeismicPing = function(trigger, triggerID, context, x, y, z, strength, seismicAllyTeamID, unitID, unitDefID)
			if not match(trigger, context, unitID, unitDefID, seismicAllyTeamID) then
				return
			end
			addSeismicContact(context, triggerID, unitID, unitDefID, seismicAllyTeamID)
		end,

		GameFrame = function(trigger, triggerID, context, frameNumber)
			if frameNumber % SEISMIC_INTERVAL_FRAMES ~= 0 then
				return
			end

			local contacts = context.SeismicContacts[triggerID]
			if not contacts then
				return
			end

			local currentInterval = frameNumber / SEISMIC_INTERVAL_FRAMES
			local timeoutInterval = getTimeoutInterval(trigger)
			for unitID, contact in pairs(contacts) do
				if currentInterval - contact.interval >= timeoutInterval then
					contacts[unitID] = nil
					-- Dying/crashing/exploding units can still emit pings.
					-- Unit tracking can change in the delay before firing.
					if Spring.GetUnitIsDead(unitID) == false and match(trigger, context, unitID, contact.unitDefID, contact.seismicAllyTeamID) then
						context.ActivateTrigger(trigger)
					end
				end
			end
		end,

		UnitDestroyed = function(trigger, triggerID, context, unitID)
			local contacts = context.SeismicContacts[triggerID]
			if contacts then
				contacts[unitID] = nil
			end
		end,
	},
}
