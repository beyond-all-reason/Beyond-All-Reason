function gadget:GetInfo()
    return {
        name = "Transport To Command",
        desc = "Adds ferry command",
        author = "You",
        date = "2026",
        license = "GPL",
        layer = 0,
        enabled = true
    }
end

-- 🔴 THIS LINE SPLITS SYNCED VS UNSYNCED
if not gadgetHandler:IsSyncedCode() then
    return
end

-- 🔽 EVERYTHING BELOW IS SYNCED

local CMD_TRANSPORT_TO = 19990

local cmdDesc = {
    id = CMD_TRANSPORT_TO,
    type = CMDTYPE.ICON_MAP,
    name = "Ferry",
    cursor = "Attack",
    action = "ferry",
}

function gadget:UnitCreated(unitID, unitDefID, team)
    if Spring.GetUnitIsTransportable(unitID) then
        Spring.InsertUnitCmdDesc(unitID, cmdDesc)
    end
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
    if cmdID == CMD_TRANSPORT_TO then
        Spring.Echo("Ferry command received", unitID)
        return false
    end
    return true
end