---
--- Loadout spawning logic used in :GamePreload() and the SpawnLoadout action.
---

local tracking = VFS.Include('luarules/mission_api/tracking.lua')

local gaiaTeamID = Spring.GetGaiaTeamID()

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

local function createFeature(featureDefName, position, facing)
	local heading = Spring.Utilities.FacingToHeading(facing or 0)
	local featureID = Spring.CreateFeature(featureDefName, position.x, position.y, position.z, heading, gaiaTeamID)

	if featureDefName:sub(-5) == '_dead' then
		local unitDefName = featureDefName:sub(1, -6)
		if UnitDefNames[unitDefName] then
			Spring.SetFeatureResurrect(featureID, unitDefName, facing)
		end
	end

	return featureID
end

local function spawnFeatureLoadout(featureLoadout, trackFeature)
	for _, feature in ipairs(featureLoadout or {}) do
		feature.y = Spring.GetGroundHeight(feature.x, feature.z)
		local featureID = createFeature(feature.name, feature, feature.facing)

		if featureID and feature.featureName and trackFeature then
			trackFeature(feature.featureName, featureID)
		end
	end
end

return {
	SpawnUnitLoadout = spawnUnitLoadout,
	SpawnFeatureLoadout = spawnFeatureLoadout,
	CreateFeature = createFeature,
}
