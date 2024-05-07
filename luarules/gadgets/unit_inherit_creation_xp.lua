function gadget:GetInfo()
	return {
		name = "Inherit Creation Units XP",
		desc = "Allows units with added UnitDefs to gain a defined fraction of the XP earned by their creations.",
		author = "SethDGamre and Xehrath",
		date = "May 2024",
		license = "Public domain",
		layer = 0,
		enabled = true
	}
end

-- synced only
if not gadgetHandler:IsSyncedCode() then return false end

local inheritChildrenXP = {} -- stores the value of XP rate to be derived from unitdef
-- inheritxratemultiplier = defined in unitdef customparams of the parent unit. It's a number by which XP gained by children is multiplied and passed to the parent

local childrenWithParents = {} --stores the parent/child relationships format. Each entry stores key of unitID with an array of {unitID, builderID, xpInheritance}
for id, def in pairs(UnitDefs) do
	if def.customParams.inheritxratemultiplier then
		inheritChildrenXP[id] = def.customParams.inheritxratemultiplier or 0
	end
end

if table.count(inheritChildrenXP) <= 0 then -- this enables or disables the gadget
	return false
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if  builderID ~= nil then
		local builderDefID = Spring.GetUnitDefID(builderID)
		if builderID then
			childrenWithParents[unitID] = {unitid=unitID, parentunitid=builderID, parentxpmultiplier=inheritChildrenXP[builderDefID]}
		end
	end
end

function gadget:UnitExperience(unitID, unitDefID, unitTeam, experience, oldExperience)
	if not childrenWithParents[unitID] then
		if Spring.GetUnitRulesParam(unitID, "parent_unit_id") then
		local parentID = Spring.GetUnitRulesParam(unitID, "parent_unit_id") --this establishes parenthood of unit_explosion_spawner.lua unit creations E.G pawn launchers/legion Evocom Dgun. IT CANNOT BE DONE AT UnitCreated or UnitDestroyed!!! Exhibits anomolous behavior if not done at runtime.
		local parentDefID = Spring.GetUnitDefID(parentID)
		childrenWithParents[unitID] = {unitid=unitID, parentunitid=parentID, parentxpmultiplier=inheritChildrenXP[parentDefID]}
		elseif Spring.GetUnitRulesParam(unitID, "carrier_host_unit_id") then
		local parentID = Spring.GetUnitRulesParam(unitID, "carrier_host_unit_id")
		local parentDefID = Spring.GetUnitDefID(parentID)
		childrenWithParents[unitID] = {unitid=unitID, parentunitid=parentID, parentxpmultiplier=inheritChildrenXP[parentDefID]}
		end
	end
	if childrenWithParents[unitID] then
		local parentUnitID = childrenWithParents[unitID].parentunitid
		local parentOldXP = Spring.GetUnitExperience(parentUnitID)
		local parentMultiplier = childrenWithParents[unitID].parentxpmultiplier
		local xp

		if parentMultiplier then
			xp = parentOldXP + ((experience - oldExperience) * parentMultiplier)
			Spring.SetUnitExperience(parentUnitID, xp)
		end
	end
end
function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
		childrenWithParents[unitID] = nil --removes children from list when destroyed
end
