local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local ConditionKinds = GG['MissionAPI'].Modules.ConditionKinds
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
	if not context.IsUnitIncluded(unitID, parameters, unitDefID) then
		return false
	end
	return true
end

return {
	type = 'UnitUndetected',
	kind = ConditionKinds.Event,
	parameters = {
		{ name = 'includeUnit',        required = true,  type = ParameterTypes.UnitFilter },
		{ name = 'excludeUnit',        required = false, type = ParameterTypes.UnitFilters },
		{ name = 'sensorAllianceName', required = false, type = ParameterTypes.AllianceName },
		{ name = 'sensorTypes',        required = false, type = ParameterTypes.SensorTypes },
	},
	callins = {
		-- Artificial callin raised once a frame, for units whose sensor state was touched.
		DetectionUpdate = DetectionLevels.NewDetectionUpdate(FIRES_ON_UNDETECTED, matchesUnit),

		UnitDestroyed = function(trigger, triggerID, context, unitID)
			DetectionLevels.Clear(triggerID, unitID)
		end,
	},
}
