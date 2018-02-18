function gadget:GetInfo()
	return {
		name	= "Only Target Emp-able units",
		desc	= "Prevents paralyzer units attacking anything other than empable units",
		author	= "Floris",
		date	= "February 2018",
		license	= "GNU GPL, v2 or later",
		layer	= 0,
		enabled	= true,
	}
end

local empUnits = {}
for udid, unitDef in pairs(UnitDefs) do
	for wid, weapon in ipairs(unitDef.weapons) do
		if WeaponDefs[weapon.weaponDef].paralyzer then
			empUnits[udid] = true
		end
	end
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
	if cmdID == CMD.ATTACK
	and empUnits[unitDefID]
	and cmdParams[2] == nil
	and type(cmdParams[1]) == 'number'
	and UnitDefs[Spring.GetUnitDefID(cmdParams[1])] ~= nil
	and UnitDefs[Spring.GetUnitDefID(cmdParams[1])].customParams.paralyzemultiplier == '0' then
		return false
	else
		return true
	end
end