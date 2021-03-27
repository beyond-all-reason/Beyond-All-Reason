function gadget:GetInfo()
	return {
		name	= "Only Target Emp-able units",
		desc	= "Prevents paralyzer units attacking anything other than empable units",
		author	= "Floris",
		date	= "February 2018",
		layer	= 0,
		enabled	= true,
	}
end

local empUnits = {}
local unEmpableUnits = {}
for udid, unitDef in pairs(UnitDefs) do
	for wid, weapon in ipairs(unitDef.weapons) do
		if WeaponDefs[weapon.weaponDef].paralyzer then
			empUnits[udid] = true
		end
		if not unitDef.modCategories.empable then
			unEmpableUnits[udid] = true
		end
	end
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	if cmdID == CMD.ATTACK
	and empUnits[unitDefID]
	and cmdParams[2] == nil
	and type(cmdParams[1]) == 'number'
	and UnitDefs[Spring.GetUnitDefID(cmdParams[1])] ~= nil then
		if unEmpableUnits[Spring.GetUnitDefID(cmdParams[1])] then		--	and UnitDefs[Spring.GetUnitDefID(cmdParams[1])].customParams.paralyzemultiplier == '0' then
			return false
		else
			local _,_,_,_,y = Spring.GetUnitPosition(cmdParams[1], true)
			if y and y >= 0 then
				return true
			else
				return false
			end
		end
	else
		return true
	end
end