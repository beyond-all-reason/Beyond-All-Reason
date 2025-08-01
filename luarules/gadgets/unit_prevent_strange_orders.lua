local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Prevent Strange Orders",
		desc = "There's no reason to need to insert a remove command (if even possible)",
		author = "TheFatController",
		date = "Aug 31, 2009",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD.INSERT)
	gadgetHandler:RegisterAllowCommand(CMD.REMOVE)
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua, fromInsert)
	-- accepts: CMD.REMOVE, CMD.INSERT
	return fromInsert == nil
end
