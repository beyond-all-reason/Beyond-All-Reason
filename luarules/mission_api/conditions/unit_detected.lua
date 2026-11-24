local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local ConditionKinds = GG['MissionAPI'].Modules.ConditionKinds
local DetectionLevels = GG['MissionAPI'].Modules.DetectionLevels

-- Fires when a matching unit's detection level rises into the sensor set watched by the trigger.
-- Sensors progress from least to most accurate: unseen -> seismic ping -> in radar -> in vision.

-- Sensors escalate, and one sensor update can raise several call-ins for the same unit, so the
-- rise is taken against a latch rather than against any single call-in. A unit already inside
-- sensors cannot rise into them again (whatever the engine reports). See detection_levels.lua.

-- Sensors also deescalate; the latch is cleared upon a unit falling out from the sensor set.

local FIRES_ON_DETECTED = true

local function matchesUnit(parameters, context, unitID, unitDefID)
	if not context.IsUnitIncluded(unitID, parameters, unitDefID) then
		return false
	end
	return true
end

return {
	type = 'UnitDetected',
	kind = ConditionKinds.Event,
	parameters = {
		{ name = 'includeUnit',        required = true,  type = ParameterTypes.UnitFilter },
		{ name = 'excludeUnit',        required = false, type = ParameterTypes.UnitFilters },
		{ name = 'sensorAllianceName', required = false, type = ParameterTypes.AllianceName },
		{ name = 'sensorTypes',        required = false, type = ParameterTypes.SensorTypes },
	},
	callins = {
		-- Artificial callin raised once a frame, for units whose sensor state was touched.
		DetectionUpdate = DetectionLevels.NewDetectionUpdate(FIRES_ON_DETECTED, matchesUnit),

		UnitDestroyed = function(trigger, triggerID, context, unitID)
			DetectionLevels.Clear(triggerID, unitID)
		end,
	},
}
