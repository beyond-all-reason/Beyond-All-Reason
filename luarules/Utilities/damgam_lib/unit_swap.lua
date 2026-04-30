local function SwapUnit(unitID, newUnitName)
	-- Collect info about unit
	local unitDefID = SpringShared.GetUnitDefID(unitID)
	local unitTeam = SpringShared.GetUnitTeam(unitID)
	local unitHealth, unitMaxHealth, unitParalyze, unitCapture, unitBuildProgress = SpringShared.GetUnitHealth(unitID)
	local unitExperience = SpringShared.GetUnitExperience(unitID)
	local unitPosX, unitPosY, unitPosZ = SpringShared.GetUnitPosition(unitID)
	local unitDirectionX, unitDirectionY, unitDirectionZ = SpringShared.GetUnitDirection(unitID)
	local unitVelocityX, unitVelocityY, unitVelocityZ = SpringShared.GetUnitVelocity(unitID)
	local unitResurrected = SpringShared.GetUnitRulesParam(unitID, "resurrected")

	-- Spawn new unit, and if successful, despawn old one.
	local newUnitID = SpringSynced.CreateUnit(newUnitName, unitPosX, unitPosY, unitPosZ, 0, unitTeam)
	if newUnitID then
		SpringSynced.DestroyUnit(unitID, false, true)
		GG.ScavengersSpawnEffectUnitID(newUnitID)

		-- Apply stats of old unit to new one
		SpringSynced.SetUnitExperience(newUnitID, unitExperience)
		local newUnitMaxHealth = select(2, SpringShared.GetUnitHealth(newUnitID))
		local newUnitHealth = (unitHealth / unitMaxHealth) * newUnitMaxHealth
		SpringSynced.SetUnitHealth(newUnitID, newUnitHealth, unitCapture, unitParalyze, unitBuildProgress)
		SpringSynced.SetUnitDirection(newUnitID, unitDirectionX, unitDirectionY, unitDirectionZ)
		SpringSynced.SetUnitVelocity(newUnitID, unitVelocityX, unitVelocityY, unitVelocityZ)
		if unitResurrected then
			SpringSynced.SetUnitRulesParam(newUnitID, "resurrected", 1, { inlos = true })
		end
	end
end

return {
	SwapUnit = SwapUnit,
}
