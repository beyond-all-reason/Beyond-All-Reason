local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = 'Disable Assist Ally Construction',
		desc    = 'Disable assisting allied units (e.g. labs and units/buildings under construction) when modoption is enabled',
		author  = 'Rimilel',
		date    = 'April 2024',
		license = 'GNU GPL, v2 or later',
		layer   = 0,
		enabled = Spring.GetModOptions().disable_assist_ally_construction,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local function isComplete(u)
	local _,_,_,_,buildProgress = Spring.GetUnitHealth(u)
	if buildProgress and buildProgress>=1 then
		return true
	else
		return false
	end
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_GUARD)
	gadgetHandler:RegisterAllowCommand(CMD_REPAIR)
	gadgetHandler:RegisterAllowCommand(CMD_INSERT)
end

local CMD_GUARD = CMD.GUARD
local CMD_REPAIR = CMD.REPAIR
local CMD_INSERT = CMD.INSERT
local params = { 0, 0, 0 }
local EMPTY = {} -- stupid

local function resolveCommand(cmdID, cmdParams)
	local p = params
	p[1], p[2], p[3] = cmdParams[4], cmdParams[5], cmdParams[6]
	cmdID, cmdParams = cmdParams[1], p

	if cmdID ~= CMD_GUARD and cmdID ~= CMD_REPAIR then
		return 0, EMPTY
	else
		return cmdID, cmdParams
	end
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
	if cmdID == CMD_INSERT then
		cmdID, cmdParams = resolveCommand(cmdID, cmdParams)
	end

	-- Disallow guard commands onto labs, units that have buildOptions or can assist
	if cmdID == CMD.GUARD then
		local targetID = cmdParams[1]
		local targetTeam = Spring.GetUnitTeam(targetID)
		local targetUnitDef = UnitDefs[Spring.GetUnitDefID(targetID)]

		if targetTeam and unitTeam ~= Spring.GetUnitTeam(targetID) and Spring.AreTeamsAllied(unitTeam, targetTeam) then
			if #targetUnitDef.buildOptions > 0 or targetUnitDef.canAssist then
				return false
			end
		end
		return true
	end

	-- Also disallow assisting building (caused by a repair command) units under construction
	-- Area repair doesn't cause assisting, so it's fine that we can't properly filter it
	if cmdID == CMD.REPAIR and #cmdParams == 1 then
		local targetID = cmdParams[1]
		local targetTeam = Spring.GetUnitTeam(targetID)

		if targetTeam and unitTeam ~= Spring.GetUnitTeam(targetID) and Spring.AreTeamsAllied(unitTeam, targetTeam) then
			if not isComplete(targetID) then
				return false
			end
		end
		return true
	end

	return true
end
