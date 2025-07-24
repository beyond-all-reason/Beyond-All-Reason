local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = 'Place Target On Ground',
		desc      = 'Make some units, like nukes, target ground instead of units',
		author    = 'Itanthias',
		date      = 'August 2023',
		license   = 'GNU GPL, v2 or later',
		layer     = 12,
		enabled   = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local place_target_on_ground = {}
for uDefID, uDef in pairs(UnitDefs) do
	local weapons = uDef.weapons
	for i=1, #weapons do
		local wDef = WeaponDefs[weapons[i].weaponDef]
		if wDef.customParams then
			if wDef.customParams.place_target_on_ground then
				place_target_on_ground[uDefID] = true
			end
		end
	end
end

local spFindUnitCmdDesc = Spring.FindUnitCmdDesc
local spGetUnitCmdDescs = Spring.GetUnitCmdDescs
local spEditUnitCmdDesc = Spring.EditUnitCmdDesc

local CMD_ATTACK = CMD.ATTACK
local CMDTYPE_ICON_MAP = CMDTYPE.ICON_MAP

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
    if place_target_on_ground[unitDefID] then
        local cmdIdx = spFindUnitCmdDesc(unitID, CMD_ATTACK)
        if cmdIdx then
            local cmdDesc = spGetUnitCmdDescs(unitID, cmdIdx, cmdIdx)[1]
            if cmdDesc then
                cmdDesc.type = CMDTYPE_ICON_MAP
                spEditUnitCmdDesc(unitID, cmdIdx, cmdDesc)
            end
        end
    end
end