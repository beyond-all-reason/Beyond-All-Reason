---
--- Loadout spawning logic used in :GamePreload() and the SpawnLoadout action.
---

local facingToHeading = {
	s = 0, n = 32768, e = 16384, w = 49152,
	south = 0, north = 32768, east = 16384, west = 49152,
	[0] = 0, [1] = 32768, [2] = 16384, [3] = 49152,
}

local function spawnUnitLoadout(unitLoadout, trackUnit)
	for _, unit in ipairs(unitLoadout or {}) do
		local y = Spring.GetGroundHeight(unit.x, unit.z)
		local unitID = Spring.CreateUnit(unit.name, unit.x, y, unit.z, unit.facing or 's', unit.team)
		if unitID then
			if unit.neutral == true or unit.neutral == 'true' then
				Spring.SetUnitNeutral(unitID, true)
			end
			if not table.isNilOrEmpty(unit.orders) then
				for _, order in ipairs(unit.orders) do
					local cmdID  = order[1]
					local params = order[2] or {}
					local opts   = order[3] or {}
					-- TODO: update when orders can be on named units
					Spring.GiveOrderToUnit(unitID, cmdID, params, opts)
				end
			else
				Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, 0)
			end
			if unit.unitName and trackUnit then
				trackUnit(unit.unitName, unitID)
			end
		end
	end
end

local function spawnFeatureLoadout(featureLoadout, trackFeature)
	local gaiaTeamID = Spring.GetGaiaTeamID()
	for _, feature in ipairs(featureLoadout or {}) do
		local heading = feature.facing and (facingToHeading[feature.facing] or 0) or 0
		local y = Spring.GetGroundHeight(feature.x, feature.z)
		local featureID = Spring.CreateFeature(feature.name, feature.x, y, feature.z, heading, gaiaTeamID)
		if featureID then
			if feature.resurrectAs and UnitDefNames[feature.resurrectAs] then
				Spring.SetFeatureResurrect(featureID, feature.resurrectAs)
			end
			if feature.featureName and trackFeature then
				trackFeature(feature.featureName, featureID)
			end
		end
	end
end

return {
	SpawnUnitLoadout = spawnUnitLoadout,
	SpawnFeatureLoadout = spawnFeatureLoadout,
}
