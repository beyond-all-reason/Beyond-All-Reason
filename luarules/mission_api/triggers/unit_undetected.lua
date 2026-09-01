local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local DetectionLevels = GG['MissionAPI'].Modules.DetectionLevels

-- Fires when a matching unit's detection level falls from the sensor set watched by the trigger.
-- Sensors progress from least to most accurate: unseen -> seismic ping -> in radar -> in vision.

-- Seismic has no engine "left range" event, and radar and vision both report leaving one sensor
-- while another still holds the unit, so the fall is taken against the full "level" rather than
-- against any single callin. Dropping out of vision and into radar is not a detection loss for
-- a trigger that watches both sensor types but stays in the bit set. See detection_levels.lua.

-- Death is not a loss of detection. A killed unit drops from sensor tracking without reporting.

local FIRES_ON_UNDETECTED = false

local function matchesUnit(parameters, context, unitID, unitDefID)
	if parameters.unitName and not context.DoesUnitHaveName(unitID, parameters.unitName) then
		return false
	end
	if parameters.unitDefName and parameters.unitDefName ~= UnitDefs[unitDefID].name then
		return false
	end
	if parameters.owningTeamName and GG['MissionAPI'].Teams[parameters.owningTeamName] ~= Spring.GetUnitTeam(unitID) then
		return false
	end
	return true
end

return {
	type = 'UnitUndetected',
	parameters = {
		{ name = 'unitName',           required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName',        required = false, type = ParameterTypes.UnitDefName },
		{ name = 'owningTeamName',     required = false, type = ParameterTypes.TeamName },
		{ name = 'sensorAllyTeamName', required = false, type = ParameterTypes.AllyTeamName },
		{ name = 'sensorTypes',        required = false, type = ParameterTypes.SensorTypes },
		requiresOneOf = { 'unitName', 'unitDefName' },
	},
	callins = {
		-- Artificial callin raised once a frame, for units whose sensor state was touched.
		DetectionUpdate = DetectionLevels.NewDetectionUpdate(FIRES_ON_UNDETECTED, matchesUnit),

		UnitDestroyed = function(trigger, triggerID, context, unitID)
			DetectionLevels.Clear(triggerID, unitID)
		end,
	},
}
