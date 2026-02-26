local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name	= "Only Target Emp-able units",
		desc    = "Prevents paralyzer units attacking anything other than empable units",
		author  = "Floris",
		date    = "February 2018",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true,
	}
end

local empUnits = {}
local unEmpableUnits = {}
for udid = 1, #UnitDefs do
	local unitDef = UnitDefs[udid]
	local weapons = unitDef.weapons
	empUnits[udid] = false
	for i = 1, #weapons do
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

-- accepts: CMD.ATTACK only
function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	if not empUnits[unitDefID] then
		return true 
	end

	local isTargetingGround = cmdParams[2] ~= nil
	if isTargetingGround then
		return true 
	end

	local targetUnitId = cmdParams[1]
	if type(targetUnitId) ~= 'number' then
		return true
	 end
	
	local targetUnitDefId = Spring.GetUnitDefID(targetUnitId)
	if not targetUnitDefId or UnitDefs[targetUnitDefId] == nil then
		return true
	 end

	if unEmpableUnits[targetUnitDefId] then
		return false
	end

	local _,_,_,_, y = Spring.GetUnitPosition(targetUnitId, true)
	local isAboveSurface = (y ~= nil) and (y >= 0)
	return isAboveSurface
end