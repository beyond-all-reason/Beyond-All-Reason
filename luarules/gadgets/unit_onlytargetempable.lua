local gadget = gadget ---@type Gadget

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
local unEmpableUnits = {}
for udid, unitDef in pairs(UnitDefs) do
	local weapons = unitDef.weapons
	for i=1, #weapons do
		if WeaponDefs[weapons[i].weaponDef].paralyzer then
			empUnits[udid] = true 
		else
			empUnits[udid] = false
			break
		end
	end
	if not unitDef.modCategories.empable then
		unEmpableUnits[udid] = true
	end
end

function gadget:Initialize()
    gadgetHandler:RegisterAllowCommand(CMD.ATTACK)
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	-- accepts: CMD.ATTACK
	if empUnits[unitDefID]
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
