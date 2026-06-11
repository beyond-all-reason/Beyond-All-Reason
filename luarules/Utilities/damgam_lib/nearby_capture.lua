-- To be done
local GaiaTeamID = Engine.Shared.GetGaiaTeamID()
local GaiaAllyTeamID = select(6, Engine.Shared.GetTeamInfo(GaiaTeamID))

local function NearbyCapture(unitID, difficulty, range)
	difficulty = difficulty or 1
	range = range or 256

	local unitAllyTeam = Engine.Shared.GetUnitAllyTeam(unitID)

	local x, y, z = Engine.Shared.GetUnitPosition(unitID)
	local nearbyUnits = Engine.Shared.GetUnitsInCylinder(x, z, range)

	local captureDamage = 0
	for i = 1, #nearbyUnits do
		local attackerID = nearbyUnits[i]
		if attackerID ~= unitID then
			if not Engine.Shared.GetUnitIsBeingBuilt(unitID) then
				local attackerAllyTeamID = Engine.Shared.GetUnitAllyTeam(attackerID)
				local attackerDefID = Engine.Shared.GetUnitDefID(attackerID)
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
		local captureProgress = select(4, Engine.Shared.GetUnitHealth(unitID))
		local newProgress = captureProgress + captureDamage
		if newProgress < 0 then
			Engine.Synced.SetUnitHealth(unitID, { capture = 0 })
			SendToUnsynced("unitCaptureFrame", unitID, 0)
			GG.addUnitToCaptureDecay(unitID)
		elseif newProgress >= 1 then
			local nearestAttacker = Engine.Shared.GetUnitNearestEnemy(unitID, range * 2, false)
			if nearestAttacker then
				local attackerTeamID = Engine.Shared.GetUnitTeam(nearestAttacker)
				Engine.Synced.TransferUnit(unitID, attackerTeamID, false)
				Engine.Synced.SetUnitHealth(unitID, { capture = 0.75 })
				SendToUnsynced("unitCaptureFrame", unitID, 0.75)
				GG.addUnitToCaptureDecay(unitID)
			end
		else
			Engine.Synced.SetUnitHealth(unitID, { capture = newProgress })
			SendToUnsynced("unitCaptureFrame", unitID, newProgress)
			GG.addUnitToCaptureDecay(unitID)
		end
	end
end

return {
	NearbyCapture = NearbyCapture,
}
