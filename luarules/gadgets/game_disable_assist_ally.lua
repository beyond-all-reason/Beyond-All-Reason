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

local allowAssist = not Spring.GetModOptions().disable_assist_ally_construction and not Spring.GetModOptions().disable_economic_sharing
if allowAssist then
	return false
end

Spring.Echo("Restrictions on assisting allies with BP are enabled")

local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitIsBuilding = Spring.GetUnitIsBuilding
local spGetUnitTeam = Spring.GetUnitTeam
local spAreTeamsAllied = Spring.AreTeamsAllied

local CMD_GUARD = CMD.GUARD
local CMD_REPAIR = CMD.REPAIR


function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)

	-- Disallow guard commands onto labs, units that have buildOptions or can assist
	if (cmdID == CMD_GUARD) then
		local targetID = cmdParams[1]
		local targetTeam = spGetUnitTeam(targetID)
		local targetUnitDef = UnitDefs[spGetUnitDefID(targetID)]

		if (unitTeam ~= targetTeam) and spAreTeamsAllied(unitTeam, targetTeam) then
			if #targetUnitDef.buildOptions > 0 or targetUnitDef.canAssist then
				return false
			end
		end
		return true
	end

	-- Also disallow assisting building (caused by a repair command) units under construction
	-- Area repair doesn't cause assisting, so it's fine that we can't properly filter it
	if (cmdID == CMD_REPAIR and #cmdParams == 1) then
		local targetID = cmdParams[1]
		local targetTeam = spGetUnitTeam(targetID)

		if (unitTeam ~= targetTeam) and spAreTeamsAllied(unitTeam, targetTeam) then
			if(spGetUnitIsBuilding(targetID)) then
				return false
			end
		end
	end

	return true
end
