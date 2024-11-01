if not gadgetHandler:IsSyncedCode() then
	return
end

function gadget:GetInfo()
	return {
		name 	= "Remove Stop",
		desc	= "Removes stop from structures which have no need for the command.",
		author	= "GoogleFrog",
		date	= "3 April 2015",
		license	= "GNU GPL, v2 or later",
		layer	= 0,
		enabled = true,
	}
end

local spRemoveUnitCmdDesc = Spring.RemoveUnitCmdDesc
local spFindUnitCmdDesc   = Spring.FindUnitCmdDesc
local CMD_STOP = CMD.STOP

local removeCommands = {
	--CMD.WAIT,
	CMD.STOP,
	--CMD.REPEAT,
}

local stopRemoveDefs = {}

for unitDefID = 1, #UnitDefs do
	local ud = UnitDefs[unitDefID]
	if ud.customParams.removestop then
		stopRemoveDefs[unitDefID] = true
	end
end

function gadget:AllowCommand_GetWantedCommand()
	return {[CMD_STOP] = true}
end

function gadget:AllowCommand_GetWantedUnitDefID()
	return stopRemoveDefs
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	-- accepts: CMD.STOP
	if stopRemoveDefs[unitDefID] then
		return false
	end
	return true
end

function gadget:UnitCreated(unitID, unitDefID)
	if stopRemoveDefs[unitDefID] then
		for i = 1, #removeCommands do
			local cmdDesc = spFindUnitCmdDesc(unitID, removeCommands[i])
			if cmdDesc then
				spRemoveUnitCmdDesc(unitID, cmdDesc)
			end
		end
	end
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_STOP)
	-- load active units
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		gadget:UnitCreated(unitID, unitDefID)
	end
end
