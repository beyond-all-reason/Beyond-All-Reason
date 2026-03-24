function gadget:GetInfo()
    return {
        name = "Transport To Command",
        desc = "Registers ferry command",
        author = "Isajoefeat",
        date = "2026",
        license = "GPL",
        layer = 0,
        enabled = true
    }
end

if not gadgetHandler:IsSyncedCode() then
    return
end

local CMD_TRANSPORT_TO = 19990

local cmdDesc = {
    id = CMD_TRANSPORT_TO,
    type = CMDTYPE.ICON_MAP,
    name = "Ferry",
    cursor = "Attack",
    action = "ferry",
}

function gadget:UnitCreated(unitID, unitDefID, team)
    local unitDef = UnitDefs[unitDefID]
    -- Add command to units that can be transported
    if unitDef and not unitDef.cantBeTransported then
        Spring.InsertUnitCmdDesc(unitID, cmdDesc)
    end
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
    if cmdID == CMD_TRANSPORT_TO then
        -- Let it pass; widget will handle it
        return true
    end
    return true
end
