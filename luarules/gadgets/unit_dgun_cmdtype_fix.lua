local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = 'DGun CmdType Fix',
		desc      = 'Fixed DGun CmdType so it can target units',
		author    = 'Niobium',
		date      = 'April 2011',
		license   = 'GNU GPL, v2 or later',
		layer     = 0,
		enabled   = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local canDGun = {}
for uDefID, uDef in pairs(UnitDefs) do
	if uDef.canManualFire then
		canDGun[uDefID] = true
	end
end

local spFindUnitCmdDesc = Spring.FindUnitCmdDesc
local spGetUnitCmdDescs = Spring.GetUnitCmdDescs
local spEditUnitCmdDesc = Spring.EditUnitCmdDesc

local CMD_DGUN = CMD.MANUALFIRE
local CMDTYPE_ICON_UNIT_OR_MAP = CMDTYPE.ICON_UNIT_OR_MAP

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
    if canDGun[unitDefID] then
        local cmdIdx = spFindUnitCmdDesc(unitID, CMD_DGUN)
        if cmdIdx then
            local cmdDesc = spGetUnitCmdDescs(unitID, cmdIdx, cmdIdx)[1]
            if cmdDesc then
                cmdDesc.type = CMDTYPE_ICON_UNIT_OR_MAP
                spEditUnitCmdDesc(unitID, cmdIdx, cmdDesc)
            end
        end
    end
end
