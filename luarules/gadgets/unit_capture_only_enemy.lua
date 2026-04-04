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

local spGetUnitTeam = SpringShared.GetUnitTeam
local spGetTeamInfo = SpringShared.GetTeamInfo
local spGetUnitAllyTeam = SpringShared.GetUnitAllyTeam

local reissueOrder = Game.Commands.ReissueOrder

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, fromSynced, fromLua, fromInsert)
	-- accepts: CMD.CAPTURE
	local nParams = #cmdParams

	if nParams == 1 or nParams == 5 then
		-- Command is targeting a single unit.
		local targetUnitID = cmdParams[1]
		local targetTeamID = targetUnitID and spGetUnitTeam(targetUnitID)
		if targetTeamID then
			local _, _, isDead, hasSkirmishAI, _, allyTeam = spGetTeamInfo(targetTeamID, false)
			return isDead or hasSkirmishAI or spGetUnitAllyTeam(unitID) ~= allyTeam
		end
	elseif nParams == 4 then
		-- Command is targeting an area.
		if cmdOptions.ctrl then
			cmdOptions.ctrl = false
			reissueOrder(unitID, cmdID, cmdParams, cmdOptions, cmdTag, fromInsert)
			return false
		end
	end
	return true
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD.CAPTURE)
end
