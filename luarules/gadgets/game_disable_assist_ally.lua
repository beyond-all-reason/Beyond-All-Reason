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

local function isComplete(u)
	local _,_,_,_,buildProgress=Spring.GetUnitHealth(u)
	if buildProgress and buildProgress>=1 then
		return true
	else
		return false
	end
end


function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)

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
