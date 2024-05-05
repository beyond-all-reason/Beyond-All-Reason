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

local inheritchildrenxp = {} -- stores the value of XP rate to be derived from unitdef
-- inheritxratemultiplier = defined in unitdef customparams of the parent unit. It's a number by which XP gained by children is multiplied and passed to the parent

local childrenwithparents = {} --stores the parent/child relationships format. Each entry stores key of unitID with an array of {unitID, builderID, xpInheritance}
for id, def in pairs(UnitDefs) do
	if def.customParams then
		if def.customParams.inheritxratemultiplier then
			inheritchildrenxp[id] = def.customParams.inheritxratemultiplier or -1
		end
	end
end

if table.count(inheritchildrenxp) <= 0 then -- this enables or disables the gadget
	return false
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if  builderID ~= nil then
		local builderDefID = Spring.GetUnitDefID(builderID)
		if builderID then
			childrenwithparents[unitID] = {unitid=unitID, parentunitid=builderID, parentxpmultiplier=inheritchildrenxp[builderDefID]}
		end
	end
end

function gadget:UnitExperience(unitID, unitDefID, unitTeam, experience, oldExperience)
	if not childrenwithparents[unitID] then
		if Spring.GetUnitRulesParam(unitID, "parent_unit_id") then
		local parentID = Spring.GetUnitRulesParam(unitID, "parent_unit_id") --this establishes parenthood of unit_explosion_spawner.lua unit creations E.G pawn launchers/legion Evocom Dgun. IT CANNOT BE DONE AT UnitCreated or UnitDestroyed!!! Exhibits anomolous behavior if not done at runtime.
		local builderDefID = Spring.GetUnitDefID(parentID)
		childrenwithparents[unitID] = {unitid=unitID, parentunitid=parentID, parentxpmultiplier=inheritchildrenxp[builderDefID]}
		end
	end
	if childrenwithparents[unitID] then
		local parentUnitID = childrenwithparents[unitID].parentunitid
		local parentOldXP = Spring.GetUnitExperience(parentUnitID)
		local parentMultiplier = childrenwithparents[unitID].parentxpmultiplier
		local xp

		if parentMultiplier then
			xp = parentOldXP + ((experience - oldExperience) * parentMultiplier)
			Spring.SetUnitExperience(parentUnitID, xp)
		end
	end
end
function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
		childrenwithparents[unitID] = nil --removes children from list when destroyed
end
