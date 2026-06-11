local function SwapUnit(unitID, newUnitName)
	-- Collect info about unit
	local unitDefID = Engine.Shared.GetUnitDefID(unitID)
	local unitTeam = Engine.Shared.GetUnitTeam(unitID)
	local unitHealth, unitMaxHealth, unitParalyze, unitCapture, unitBuildProgress = Engine.Shared.GetUnitHealth(unitID)
	local unitExperience = Engine.Shared.GetUnitExperience(unitID)
	local unitPosX, unitPosY, unitPosZ = Engine.Shared.GetUnitPosition(unitID)
	local unitDirectionX, unitDirectionY, unitDirectionZ = Engine.Shared.GetUnitDirection(unitID)
	local unitVelocityX, unitVelocityY, unitVelocityZ = Engine.Shared.GetUnitVelocity(unitID)
	local unitResurrected = Engine.Shared.GetUnitRulesParam(unitID, "resurrected")

	-- Spawn new unit, and if successful, despawn old one.
	local newUnitID = Engine.Synced.CreateUnit(newUnitName, unitPosX, unitPosY, unitPosZ, 0, unitTeam)
	if newUnitID then
		Engine.Synced.DestroyUnit(unitID, false, true)
		GG.ScavengersSpawnEffectUnitID(newUnitID)

		-- Apply stats of old unit to new one
		Engine.Synced.SetUnitExperience(newUnitID, unitExperience)
		local newUnitMaxHealth = select(2, Engine.Shared.GetUnitHealth(newUnitID))
		local newUnitHealth = (unitHealth / unitMaxHealth) * newUnitMaxHealth
		Engine.Synced.SetUnitHealth(newUnitID, newUnitHealth, unitCapture, unitParalyze, unitBuildProgress)
		Engine.Synced.SetUnitDirection(newUnitID, unitDirectionX, unitDirectionY, unitDirectionZ)
		Engine.Synced.SetUnitVelocity(newUnitID, unitVelocityX, unitVelocityY, unitVelocityZ)
		if unitResurrected then
			Engine.Synced.SetUnitRulesParam(newUnitID, "resurrected", 1, { inlos = true })
		end
	end
end

return {
	SwapUnit = SwapUnit,
}
