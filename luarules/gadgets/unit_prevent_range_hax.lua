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

local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetGroundHeight = Spring.GetGroundHeight
local CMD_ATTACK = CMD.ATTACK
local CMD_INSERT = CMD.INSERT

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_INSERT)
	gadgetHandler:RegisterAllowCommand(CMD_ATTACK)
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	if fromSynced then
		return true
	elseif cmdID == CMD_INSERT and CMD_ATTACK == cmdParams[2] and cmdParams[6] then
		local y = spGetGroundHeight(cmdParams[4], cmdParams[6]) --is automatically corrected for below/above waterline and water/nonwater weapons within engine
		if cmdParams[5] > y then
			spGiveOrderToUnit(unitID, CMD_INSERT, { cmdParams[1], cmdParams[2], cmdParams[3], cmdParams[4], y, cmdParams[6] }, cmdOptions.coded)
			return false
		end
	elseif cmdID == CMD_ATTACK and cmdParams[3] then
		local y = spGetGroundHeight(cmdParams[1], cmdParams[3])
		if cmdParams[2] > y then
			spGiveOrderToUnit(unitID, CMD_ATTACK, { cmdParams[1], y, cmdParams[3] }, cmdOptions.coded)
			return false
		end
	end
	return true
end
