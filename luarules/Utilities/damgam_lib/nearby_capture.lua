-- To be done
local GaiaTeamID = Spring.GetGaiaTeamID()
local GaiaAllyTeamID = select(6, Spring.GetTeamInfo(GaiaTeamID))

local function NearbyCapture(unitID, difficulty, range)
	difficulty = difficulty or 1
	range = range or 256

	local unitAllyTeam = Spring.GetUnitAllyTeam(unitID)

	local x, y, z = Spring.GetUnitPosition(unitID)
	local nearbyUnits = Spring.GetUnitsInCylinder(x, z, range)

	local captureDamage = 0
	for i = 1, #nearbyUnits do
		local attackerID = nearbyUnits[i]
		if attackerID ~= unitID then
			if not Spring.GetUnitIsBeingBuilt(unitID) then
				local attackerAllyTeamID = Spring.GetUnitAllyTeam(attackerID)
				local attackerDefID = Spring.GetUnitDefID(attackerID)
				local attackerMetalCost = UnitDefs[attackerDefID].metalCost
				local capturePower = ((attackerMetalCost / 1000) * 0.01) / difficulty
				if attackerAllyTeamID == unitAllyTeam then
					captureDamage = captureDamage - capturePower
				elseif attackerAllyTeamID ~= GaiaAllyTeamID then
					captureDamage = captureDamage + capturePower
				end
			end
		end
	end

	if captureDamage ~= 0 then
		local captureProgress = select(4, Spring.GetUnitHealth(unitID))
		local newProgress = captureProgress + captureDamage
		if newProgress < 0 then
			Spring.SetUnitHealth(unitID, { capture = 0 })
			SendToUnsynced("unitCaptureFrame", unitID, 0)
			GG.addUnitToCaptureDecay(unitID)
		elseif newProgress >= 1 then
			local nearestAttacker = Spring.GetUnitNearestEnemy(unitID, range * 2, false)
			if nearestAttacker then
				local attackerTeamID = Spring.GetUnitTeam(nearestAttacker)
				Spring.TransferUnit(unitID, attackerTeamID, false)
				Spring.SetUnitHealth(unitID, { capture = 0.75 })
				SendToUnsynced("unitCaptureFrame", unitID, 0.75)
				GG.addUnitToCaptureDecay(unitID)
			end
		else
			Spring.SetUnitHealth(unitID, { capture = newProgress })
			SendToUnsynced("unitCaptureFrame", unitID, newProgress)
			GG.addUnitToCaptureDecay(unitID)
		end
	end
end

return {
	NearbyCapture = NearbyCapture,
}
