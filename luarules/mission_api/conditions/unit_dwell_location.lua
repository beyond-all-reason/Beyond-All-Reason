local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local ConditionKinds = GG['MissionAPI'].Modules.ConditionKinds

local function onActivationAttempted(trigger, triggerID, context, unitID, activated)
	local dwellingUnits = context.DwellingUnitsInAreas[triggerID]
	-- Prevents a second activation for the same unit, unless it left the area before this one went through.
	if activated and dwellingUnits and dwellingUnits[unitID] then
		dwellingUnits[unitID] = -1
	end
end

return {
	type = 'UnitDwellLocation',
	kind = ConditionKinds.Event,
	parameters = {
		-- Rectangle: { x1 = 0, z1 = 0, x2 = 123, z2 = 123 } with x1 < x2 and z1 < z2
		-- Circle: { x = 0, z = 0, radius = 123 }
		{ name = 'area',        required = true,  type = ParameterTypes.Area },
		{ name = 'duration',    required = true,  type = ParameterTypes.Number },
		{ name = 'unitName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName', required = false, type = ParameterTypes.UnitDefName },
		{ name = 'teamName',    required = false, type = ParameterTypes.TeamName },
		requiresOneOf = { 'unitName', 'unitDefName', 'teamName' },
	},
	callins = {
		-- Dwell time starts the frame after entering, so a duration of 0 fires on the first frame.
		GameFrame = function(trigger, triggerID, context, frameNumber)
			local dwellingUnits = context.DwellingUnitsInAreas[triggerID]
			if not dwellingUnits then
				return
			end

			local parameters = trigger.parameters
			for unitID, enteredFrame in pairs(dwellingUnits) do
				if enteredFrame >= 0 and frameNumber > enteredFrame and frameNumber - enteredFrame >= parameters.duration
					and (not parameters.unitName or context.DoesUnitHaveName(unitID, parameters.unitName)) then
					context.ActivateTrigger(trigger, onActivationAttempted, triggerID, unitID)
				end
			end
		end,
		UnitsEnteredArea = function(trigger, triggerID, context, unitIDs)
			local parameters = trigger.parameters
			local dwellingUnits = table.ensureTable(context.DwellingUnitsInAreas, triggerID)
			local frameNumber = Spring.GetGameFrame()
			for i = 1, #unitIDs do
				local unitID = unitIDs[i]
				if context.DoesUnitMatch(unitID, parameters.unitName, parameters.unitDefName) then
					dwellingUnits[unitID] = frameNumber
				end
			end
		end,
		UnitsLeftArea = function(trigger, triggerID, context, unitIDs)
			local dwellingUnits = context.DwellingUnitsInAreas[triggerID]
			if not dwellingUnits then return end

			for i = 1, #unitIDs do
				dwellingUnits[unitIDs[i]] = nil
			end
		end,
	},
}
