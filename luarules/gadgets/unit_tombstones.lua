
local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name		= "Tombstones",
		desc		= "Adds a tombstone next to commander wreck",
		author		= "Floris",
		date		= "December 2021",
		license     = "GNU GPL, v2 or later",
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
		if string.sub(def.name, 1, 6) == 'corcom' and FeatureDefNames.corstone then
			isCommander[defID] = FeatureDefNames.corstone.id
		elseif string.sub(def.name, 1, 6) == 'armcom' and FeatureDefNames.armstone then
			isCommander[defID] = FeatureDefNames.armstone.id
		elseif string.sub(def.name, 1, 6) == 'legcom' and FeatureDefNames.legstone then
			isCommander[defID] = FeatureDefNames.legstone.id
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
	if isCommander[unitDefID] then
		local px,py,pz = Spring.GetUnitPosition(unitID)
		pz = pz - 40
		if not Spring.GetUnitRulesParam(unitID, "unit_evolved") then
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
end
