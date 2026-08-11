local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local DetectionLevels = VFS.Include('luarules/mission_api/detection_levels.lua')

-- Fires when a matching unit's detection level rises into the sensor set watched by the trigger.
-- Sensors progress from least to most accurate: unseen -> seismic ping -> in radar -> in vision.

-- Sensors escalate, and one sensor update can raise several call-ins for the same unit, so the
-- rise is taken against a latch rather than against any single call-in. A unit already inside
-- sensors cannot rise into them again (whatever the engine reports). See detection_levels.lua.

-- Sensors also deescalate; the latch is cleared upon a unit falling out from the sensor set.

local bit_and = math.bit_and

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
		DetectionUpdate = function(trigger, triggerID, context, dirtyUnits)
			local parameters = trigger.parameters
			local sensorAllyTeam = parameters.sensorAllyTeam
			local levelMask = DetectionLevels.LevelMaskOf(triggerID, parameters.sensorTypes)

			for unitID in pairs(dirtyUnits) do
				local levelBit = DetectionLevels.LevelBitOf(unitID, sensorAllyTeam)
				local isDetected = bit_and(levelBit, levelMask) ~= 0
				if DetectionLevels.UpdateLatch(triggerID, unitID, isDetected) and isDetected then
					-- Dying units remain detectable, and unit tracking can change between updates.
					if Spring.GetUnitIsDead(unitID) == false and matchesUnit(trigger, context, unitID, Spring.GetUnitDefID(unitID)) then
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
