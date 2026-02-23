local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Prevent Range Hax",
		desc = "Prevent Range Hax",
		author = "TheFatController",
		date = "Jul 24, 2007",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local spGetGroundHeight = Spring.GetGroundHeight
local reissueOrder = Game.Commands.ReissueOrder
local CMD_ATTACK = CMD.ATTACK

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_ATTACK)
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua, fromInsert)
	if fromSynced then
		return true
	elseif cmdID == CMD_ATTACK and cmdParams[3] then
		local y = spGetGroundHeight(cmdParams[1], cmdParams[3])
		if cmdParams[2] > y then
			cmdParams[2] = y
			reissueOrder(unitID, CMD_ATTACK, cmdParams, cmdOptions, cmdTag, fromInsert)
			return false
		end
	end
	return true
end
