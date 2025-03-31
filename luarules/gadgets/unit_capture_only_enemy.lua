local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Capture Only Enemy",
		desc = "prevents capturing allied units unless owned by AI",
		author = "Floris",
		date = "March 2023",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local CMD_CAPTURE = CMD.CAPTURE

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	-- accepts: CMD.CAPTURE
	if Spring.GetUnitAllyTeam(unitID) == Spring.GetUnitAllyTeam(cmdParams[1]) and not select(4, Spring.GetTeamInfo(Spring.GetUnitTeam(cmdParams[1]))) and not Spring.GetTeamLuaAI(Spring.GetUnitTeam(cmdParams[1])) then
		return false
	end
	return true
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_CAPTURE)
end
