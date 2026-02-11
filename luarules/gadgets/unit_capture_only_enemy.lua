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
	local nParams = #cmdParams

	if nParams == 1 or nParams == 5 then
		-- Command is targeting a single unit.
		local targetTeamID = Spring.GetUnitTeam(cmdParams[1])
		if targetTeamID then
			local isDead = select(4, Spring.GetTeamInfo(targetTeamID))
			if Spring.GetUnitAllyTeam(unitID) == Spring.GetUnitAllyTeam(cmdParams[1]) and not isDead and not Spring.GetTeamLuaAI(targetTeamID) then
				return false
			end
		end
	elseif nParams == 4 then
		-- Command is targeting an area.
	end
	return true
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_CAPTURE)
end
