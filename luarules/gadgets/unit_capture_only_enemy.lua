function gadget:GetInfo()
	return {
		name = "Capture Only Enemy",
		desc = "prevents capturing allied units",
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

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	if cmdID == CMD.CAPTURE and Spring.GetUnitAllyTeam(unitID) == Spring.GetUnitAllyTeam(cmdParams[1]) then
		return false
	end
	return true
end
