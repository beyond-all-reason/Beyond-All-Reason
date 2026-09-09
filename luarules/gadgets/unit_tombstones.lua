local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Tombstones",
		desc = "Adds a tombstone next to commander wreck",
		author = "Floris",
		date = "December 2021",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

-- customparams.tombstone names the tombstone featuredef; scav copies inherit the
-- param but never dropped tombstones, so they stay excluded
local isCommander = {}
for defID, def in ipairs(UnitDefs) do
	local tombstone = def.customParams.tombstone
	if tombstone and not def.customParams.isscavenger and FeatureDefNames[tombstone] then
		isCommander[defID] = FeatureDefNames[tombstone].id
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
	if isCommander[unitDefID] then
		if Spring.GetUnitRulesParam(unitID, "remove_decorations") == 1 then
			return
		end
		local px, py, pz = Spring.GetUnitPosition(unitID)
		pz = pz - 40
		if not Spring.GetUnitRulesParam(unitID, "unit_evolved") then
			local tombstoneID =
				Spring.CreateFeature(isCommander[unitDefID], px, Spring.GetGroundHeight(px, pz), pz, 0, teamID)
			if tombstoneID then
				local rx, ry, rz = Spring.GetFeatureRotation(tombstoneID)
				rx = rx + 0.18 + (math.random(0, 6) / 50)
				rz = rz - 0.12 + (math.random(0, 12) / 50)
				ry = ry - 0.12 + (math.random(0, 12) / 50)
				Spring.SetFeatureRotation(tombstoneID, rx, ry, rz)
			end
		end
	end
end
