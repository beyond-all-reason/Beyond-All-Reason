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

local CMD_ATTACK = CMD.ATTACK
local CMD_MOVE = CMD.MOVE

local spGetSelectedUnitsCounts = Spring.GetSelectedUnitsCounts
local spGetUnitDefID = Spring.GetUnitDefID
local spIsUnitAllied = Spring.IsUnitAllied

local empUnits = {}
local attackUnits = {}
local unEmpableUnits = {}
for udid = 1, #UnitDefs do
	local unitDef = UnitDefs[udid]
	local weapons = unitDef.weapons
	empUnits[udid] = false
	if #weapons > 0 then
		empUnits[udid] = true
	end
	for i = 1, #weapons do
		local weaponDef = WeaponDefs[weapons[i].weaponDef]
		if weaponDef and not weaponDef.isShield then
			attackUnits[udid] = true
		end
		if not (weaponDef and weaponDef.paralyzer) then
			empUnits[udid] = false
		end
	end
	if not unitDef.modCategories.empable then
		unEmpableUnits[udid] = true
	end
end

if gadgetHandler:IsSyncedCode() then
	function gadget:Initialize()
		gadgetHandler:RegisterAllowCommand(CMD_ATTACK)
	end

	function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
		-- accepts: CMD.ATTACK
		if empUnits[unitDefID]
			and cmdParams[2] == nil
			and type(cmdParams[1]) == 'number'
			and UnitDefs[Spring.GetUnitDefID(cmdParams[1])] ~= nil then
			if unEmpableUnits[Spring.GetUnitDefID(cmdParams[1])] then --	and UnitDefs[Spring.GetUnitDefID(cmdParams[1])].customParams.paralyzemultiplier == '0' then
				return false
			else
				local _,_,_,_, y = Spring.GetUnitPosition(cmdParams[1], true)
				local _, scaleY, _, _, offY = Spring.GetUnitCollisionVolumeData(cmdParams[1])
				y = y + offY + (scaleY * 0.5)
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
else
	local function CanSelectionAttackTarget(targetDefID)
		local targetIsEmpImmune = unEmpableUnits[targetDefID]
		for unitDefID in pairs(spGetSelectedUnitsCounts()) do
			if attackUnits[unitDefID] and (not targetIsEmpImmune or not empUnits[unitDefID]) then
				return true
			end
		end

		return false
	end

	function gadget:DefaultCommand(type, id, cmd)
		if type ~= "unit" or cmd ~= CMD_ATTACK or not id or spIsUnitAllied(id) then
			return
		end

		local targetDefID = spGetUnitDefID(id)
		if targetDefID and unEmpableUnits[targetDefID] and not CanSelectionAttackTarget(targetDefID) then
			return CMD_MOVE
		end
	end
end
