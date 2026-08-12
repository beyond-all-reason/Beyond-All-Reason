local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local DetectionLevels = GG['MissionAPI'].Modules.DetectionLevels

-- Fires when a matching unit's detection level rises into the sensor set watched by the trigger.
-- Sensors progress from least to most accurate: unseen -> seismic ping -> in radar -> in vision.

-- Sensors escalate, and one sensor update can raise several call-ins for the same unit, so the
-- rise is taken against a latch rather than against any single call-in. A unit already inside
-- sensors cannot rise into them again (whatever the engine reports). See detection_levels.lua.

-- Sensors also deescalate; the latch is cleared upon a unit falling out from the sensor set.

local FIRES_ON_DETECTED = true

local function matchesUnit(parameters, context, unitID, unitDefID)
	if parameters.unitName and not context.DoesUnitHaveName(unitID, parameters.unitName) then
		return false
	end
	if parameters.unitDefName and parameters.unitDefName ~= UnitDefs[unitDefID].name then
		return false
	end
	if parameters.owningTeamID and parameters.owningTeamID ~= Spring.GetUnitTeam(unitID) then
		return false
	end
	return true
end

return {
	type = 'UnitDetected',
	parameters = {
		{ name = 'unitName',       required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName',    required = false, type = ParameterTypes.UnitDefName },
		{ name = 'owningTeamID',   required = false, type = ParameterTypes.TeamID },
		{ name = 'sensorAllyTeam', required = false, type = ParameterTypes.AllyTeamID },
		{ name = 'sensorTypes',    required = false, type = ParameterTypes.SensorTypes },
		requiresOneOf = { 'unitName', 'unitDefName' },
	},
	callins = {
		-- Artificial callin raised once a frame, for units whose sensor state was touched.
		DetectionUpdate = DetectionLevels.NewDetectionUpdate(FIRES_ON_DETECTED, matchesUnit),

		UnitDestroyed = function(trigger, triggerID, context, unitID)
			DetectionLevels.Clear(triggerID, unitID)
		end,
	},
}
