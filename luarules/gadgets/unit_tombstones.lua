
function gadget:GetInfo()
	return {
		name		= "Tombstones",
		desc		= "Adds a tombstone next to commander wreck",
		author		= "Floris",
		date		= "December 2021",
		license		= "",
		layer		= 0,
		enabled		= true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local isCommander = {}
for defID, def in ipairs(UnitDefs) do
	if def.customParams.iscommander ~= nil and not string.find(def.name, "scav") then
		isCommander[defID] = def.name == 'armcom' and FeatureDefNames.armstone.id or FeatureDefNames.corstone.id
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
	if isCommander[unitDefID] then
		local px,py,pz = Spring.GetUnitPosition(unitID)
		pz = pz - 40
		local tombstoneID = Spring.CreateFeature(isCommander[unitDefID], px, Spring.GetGroundHeight(px,pz), pz, 0, teamID)
		if tombstoneID then
			local rx,ry,rz = Spring.GetFeatureRotation(tombstoneID)
			rx = rx + 0.18 + (math.random(0, 6) / 50)
			rz = rz - 0.12 + (math.random(0, 12) / 50)
			ry = ry - 0.12 + (math.random(0, 12) / 50)
			Spring.SetFeatureRotation(tombstoneID, rx,ry,rz)
		end
	end
end
