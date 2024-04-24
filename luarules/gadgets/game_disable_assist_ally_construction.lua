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
if not Spring.GetModOptions().disable_assist_ally_construction then
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


local function isBuildCapable(unitID)
	return UnitDefs[Spring.GetUnitDefID(unitID)].isBuilder
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)

	-- Disallow guard commands onto ally's labs, and units with build bp or that can reclaim

	if (cmdID == CMD.GUARD) then
		local targetID = cmdParams[1]
		local targetTeam = Spring.GetUnitTeam(targetID)

		if not isBuildCapable(targetID) then
			return true
		end

		if (unitTeam ~= Spring.GetUnitTeam(targetID)) and Spring.AreTeamsAllied(unitTeam, targetTeam) then
			return false
		end
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
