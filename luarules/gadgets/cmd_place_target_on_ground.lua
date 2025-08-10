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
local CMD_UNIT_SET_TARGET = GameCMD.UNIT_SET_TARGET
local CMD_UNIT_SET_TARGET_NO_GROUND = GameCMD.UNIT_SET_TARGET_NO_GROUND
local CMD_UNIT_SET_TARGET_RECTANGLE = GameCMD.UNIT_SET_TARGET_RECTANGLE 
local CMDTYPE_ICON_MAP = CMDTYPE.ICON_MAP
local cmdDesc

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
	if place_target_on_ground[unitDefID] then
		if (cmdID == CMD_ATTACK) and (#cmdParams == 1) then -- deny the command if it is an attack command, and just targeting a unitID and not a set of 3 coordinates
			return false
		end
	end
	return true
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
    if place_target_on_ground[unitDefID] then
        local cmdIdx = spFindUnitCmdDesc(unitID, CMD_ATTACK)
        if cmdIdx then
            cmdDesc = spGetUnitCmdDescs(unitID, cmdIdx, cmdIdx)[1]
            if cmdDesc then
                cmdDesc.type = CMDTYPE_ICON_MAP -- Forces attack commands to accept (x,y,z) spatial coordinates, and not allow unitIDs as valid parameters.
				-- HOWEVER, this does not seem to propogate to default right click commands.
				-- so the above AllowCommand function checks for any attacks just targeting a unitID and denies them.  
                spEditUnitCmdDesc(unitID, cmdIdx, cmdDesc)
            end
        end

		cmdIdx = spFindUnitCmdDesc(unitID, CMD_UNIT_SET_TARGET)
        if cmdIdx then
            cmdDesc = spGetUnitCmdDescs(unitID, cmdIdx, cmdIdx)[1]
            if cmdDesc then
                cmdDesc.type = CMDTYPE_ICON_MAP
                spEditUnitCmdDesc(unitID, cmdIdx, cmdDesc)
            end
        end

		cmdIdx = spFindUnitCmdDesc(unitID, CMD_UNIT_SET_TARGET_NO_GROUND)
        if cmdIdx then
            cmdDesc = spGetUnitCmdDescs(unitID, cmdIdx, cmdIdx)[1]
            if cmdDesc then
                cmdDesc.type = CMDTYPE_ICON_MAP
                spEditUnitCmdDesc(unitID, cmdIdx, cmdDesc)
            end
        end

		cmdIdx = spFindUnitCmdDesc(unitID, CMD_UNIT_SET_TARGET_RECTANGLE)
        if cmdIdx then
            cmdDesc = spGetUnitCmdDescs(unitID, cmdIdx, cmdIdx)[1]
            if cmdDesc then
                cmdDesc.type = CMDTYPE_ICON_MAP
                spEditUnitCmdDesc(unitID, cmdIdx, cmdDesc)
            end
        end
    end
end
