local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = 'Disable Assist Ally Construction',
		desc    = 'Disable assisting allied units (e.g. labs and units/buildings under construction) when modoption is enabled',
		author  = 'Rimilel',
		date    = 'April 2024',
		license = 'GNU GPL, v2 or later',
		layer   = 0,
		enabled = true
	}
end

----------------------------------------------------------------
-- Synced only
----------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return false
end

local allowAssist = not Spring.GetModOptions().disable_assist_ally_construction

if allowAssist then
	return false
end

local CMD_INSERT = CMD.INSERT

local function isComplete(u)
	local _,_,_,_,buildProgress=Spring.GetUnitHealth(u)
	if buildProgress and buildProgress>=1 then
		return true
	else
		return false
	end
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD.GUARD)
	gadgetHandler:RegisterAllowCommand(CMD.REPAIR)
end

local params = {}

local function fromInsert(cmdParams)
	local p = params
	p[1], p[2], p[3], p[4], p[5] = cmdParams[4], cmdParams[5], cmdParams[6], cmdParams[7], cmdParams[8]
	return cmdParams[2], p
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
	if cmdID == CMD_INSERT then
		cmdID, cmdParams = fromInsert(cmdParams)
	end

	-- Disallow guard commands onto labs, units that have buildOptions or can assist

	if (cmdID == CMD.GUARD) then
		local targetID = cmdParams[1]
		local targetTeam = Spring.GetUnitTeam(targetID)
		local targetUnitDef = UnitDefs[Spring.GetUnitDefID(targetID)]
		
		if (unitTeam ~= Spring.GetUnitTeam(targetID)) and Spring.AreTeamsAllied(unitTeam, targetTeam) then
			if #targetUnitDef.buildOptions > 0 or targetUnitDef.canAssist then
				return false
			end
		end
		return true
	end

	-- Also disallow assisting building (caused by a repair command) units under construction 
	-- Area repair doesn't cause assisting, so it's fine that we can't properly filter it

	if (cmdID == CMD.REPAIR and #cmdParams == 1) then
		local targetID = cmdParams[1]
		local targetTeam = Spring.GetUnitTeam(targetID)

		if (unitTeam ~= Spring.GetUnitTeam(targetID)) and Spring.AreTeamsAllied(unitTeam, targetTeam) then
			if(not isComplete(targetID)) then
				return false
			end
		end
		return true
	end



	return true
end
