function gadget:GetInfo()
    return {
        name = "Transport To Command",
        desc = "Adds ferry command",
        author = "IsaJoeFeat",
        date = "2026",
        license = "GPL",
        layer = 0,
        enabled = true
    }
end

--  SYNCED ONLY
if not gadgetHandler:IsSyncedCode() then
    return
end

local CMD_TRANSPORT_TO = 19990
local CMD_MOVE = CMD.MOVE
local CMD_STOP = CMD.STOP
local CMD_LOAD_UNITS = CMD.LOAD_UNITS
local CMD_UNLOAD_UNITS = CMD.UNLOAD_UNITS

local jobs = {}
local reserved = {}

--  Command Description (FIXED)
local cmdDesc = {
    id = CMD_TRANSPORT_TO,
    type = CMDTYPE.ICON_MAP,
    name = "Ferry",
    action = "ferry",
    tooltip = "Transport this unit to a location",
    cursor = "Attack",
    params = {}, --  REQUIRED for ICON_MAP
}

--  Debug: confirm gadget loaded
Spring.Echo("Transport gadget loaded")

--  Add command to ALL units (no filter for now)
function gadget:UnitCreated(unitID, unitDefID, team)
    Spring.Echo("UnitCreated fired", unitID)

    -- Insert command (forced position for reliability)
    Spring.InsertUnitCmdDesc(unitID, 500, cmdDesc)

    Spring.Echo("Inserted ferry command into unit", unitID)
end

--  Intercept command (Phase 2 ready)
function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
    if cmdID == CMD_TRANSPORT_TO then
        Spring.Echo("Ferry command received", unitID)

	jobs[unitID] = {
		target = {cmdParams[1], cmdParams[2], cmdParams[3},
		state = "walking"
		transportID = nil
	}

	Spring.GiveOrderToUnit(unitID, CMD_MOVE, cmdParams, {})      

        return false
    end
    return true
end