local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local DetectionLevels = VFS.Include('luarules/mission_api/detection_levels.lua')

-- Fires when a matching unit's detection level falls from the sensor set watched by the trigger.
-- Sensors progress from least to most accurate: unseen -> seismic ping -> in radar -> in vision.

-- Seismic has no engine "left range" event, and radar and vision both report leaving one sensor
-- while another still holds the unit, so the fall is taken against the full "level" rather than
-- against any single callin. Dropping out of vision and into radar is not a detection loss for
-- a trigger that watches both sensor types but stays in the bit set. See detection_levels.lua.

-- Death is not a loss of detection. A killed unit drops from sensor tracking without reporting.

local bit_and = math.bit_and

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
	type = 'UnitUndetected',
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
		DetectionUpdate = function(trigger, triggerID, context, dirtyUnits)
			local parameters = trigger.parameters
			local sensorAllyTeam = parameters.sensorAllyTeam
			local levelMask = DetectionLevels.LevelMaskOf(triggerID, parameters.sensorTypes)

			for unitID in pairs(dirtyUnits) do
				local levelBit = DetectionLevels.LevelBitOf(unitID, sensorAllyTeam)
				local isDetected = bit_and(levelBit, levelMask) ~= 0
				if DetectionLevels.UpdateLatch(triggerID, unitID, isDetected) and not isDetected then
					-- Dying units remain detectable, and unit tracking can change between updates.
					if Spring.GetUnitIsDead(unitID) == false and matchesUnit(parameters, context, unitID, Spring.GetUnitDefID(unitID)) then
						context.ActivateTrigger(trigger)
					end
				end
			end
		end,
		UnitDestroyed = function(trigger, triggerID, context, unitID)
			DetectionLevels.Forget(triggerID, unitID)
		end,
	},
}
