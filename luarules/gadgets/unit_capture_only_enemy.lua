local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Capture Only Enemy",
		desc = "prevents capturing allied units unless owned by AI",
		author = "Floris",
		date = "March 2023",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local CMD_CAPTURE = CMD.CAPTURE

local allowAll = Spring.Utilities.Gametype.isSinglePlayer()
	or (Spring.Utilities.Gametype.isFFA() and not Spring.Utilities.Gametype.isTeams())
	or Spring.Utilities.Gametype.isSandbox()

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	-- accepts: CMD.CAPTURE
	local nParams = #cmdParams

	if nParams == 1 or nParams == 5 then
		-- Command is targeting a single unit.
		local targetUnitID = cmdParams[1]
		local targetTeamID = targetUnitID and Spring.GetUnitTeam(targetUnitID)
		if targetTeamID then
			local _, _, isDead, hasSkirmishAI, _, allyTeam = Spring.GetTeamInfo(targetTeamID, false)
			return isDead or hasSkirmishAI or Spring.GetUnitAllyTeam(unitID) ~= allyTeam
		end
	elseif nParams == 4 then
		-- Command is targeting an area.
		if allowAll or not cmdOptions.ctrl then
			return true
		else
			cmdOptions.ctrl = false
			Spring.GiveOrderToUnit(unitID, cmdID, cmdParams, cmdOptions)
			return false
		end
	end
	return true
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_CAPTURE)
end
