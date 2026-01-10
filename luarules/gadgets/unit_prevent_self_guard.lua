function gadget:GetInfo()
    return {
        name      = "Prevent Self Guard",
        desc      = "Prevents units from issuing guard commands on themselves",
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

local isFactory = {} -- Factory order queue goes to built units, not themselves.
for unitDefID, unitDef in ipairs(UnitDefs) do
	isFactory[unitDefID] = unitDef.isFactory
end

function gadget:Initialize()
    gadgetHandler:RegisterAllowCommand(CMD.GUARD)
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams)
	return cmdParams[1] ~= unitID or isFactory[unitDefID]
end
