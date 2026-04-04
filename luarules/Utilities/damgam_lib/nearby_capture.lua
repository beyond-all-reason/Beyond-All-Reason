-- To be done
local GaiaTeamID = SpringShared.GetGaiaTeamID()
local GaiaAllyTeamID = select(6, SpringShared.GetTeamInfo(GaiaTeamID))

local function NearbyCapture(unitID, difficulty, range)
	difficulty = difficulty or 1
	range = range or 256

	local unitAllyTeam = SpringShared.GetUnitAllyTeam(unitID)

	local x, y, z = SpringShared.GetUnitPosition(unitID)
	local nearbyUnits = SpringShared.GetUnitsInCylinder(x, z, range)

	local captureDamage = 0
	for i = 1, #nearbyUnits do
		local attackerID = nearbyUnits[i]
		if attackerID ~= unitID then
			if not SpringShared.GetUnitIsBeingBuilt(unitID) then
				local attackerAllyTeamID = SpringShared.GetUnitAllyTeam(attackerID)
				local attackerDefID = SpringShared.GetUnitDefID(attackerID)
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
		local captureProgress = select(4, SpringShared.GetUnitHealth(unitID))
		local newProgress = captureProgress + captureDamage
		if newProgress < 0 then
			SpringSynced.SetUnitHealth(unitID, { capture = 0 })
			SendToUnsynced("unitCaptureFrame", unitID, 0)
			GG.addUnitToCaptureDecay(unitID)
		elseif newProgress >= 1 then
			local nearestAttacker = SpringShared.GetUnitNearestEnemy(unitID, range * 2, false)
			if nearestAttacker then
				local attackerTeamID = SpringShared.GetUnitTeam(nearestAttacker)
				SpringSynced.TransferUnit(unitID, attackerTeamID, false)
				SpringSynced.SetUnitHealth(unitID, { capture = 0.75 })
				SendToUnsynced("unitCaptureFrame", unitID, 0.75)
				GG.addUnitToCaptureDecay(unitID)
			end
		else
			SpringSynced.SetUnitHealth(unitID, { capture = newProgress })
			SendToUnsynced("unitCaptureFrame", unitID, newProgress)
			GG.addUnitToCaptureDecay(unitID)
		end
	end
end

return {
	NearbyCapture = NearbyCapture,
}
