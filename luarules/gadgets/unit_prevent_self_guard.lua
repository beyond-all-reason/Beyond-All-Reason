function gadget:GetInfo()
    return {
        name      = "Prevent Self Guard",
        desc      = "Prevents all units from issuing guard commands on themselves",
        author    = "Trunks",
        date      = "2025",
        enabled   = true,
        layer     = 0,
		license = "GNU GPL, v2 or later",
    }
end

if not gadgetHandler:IsSyncedCode() then
    return
end

function gadget:Initialize()
    gadgetHandler:RegisterAllowCommand(CMD.GUARD)
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams)
    local targetID = cmdParams[1]

    -- Block self-guard for ALL units
    if targetID == unitID then
        return false
    end

    return true
end
