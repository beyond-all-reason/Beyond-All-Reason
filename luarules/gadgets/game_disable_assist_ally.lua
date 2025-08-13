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
-- Decide whether to run
----------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return false
end

local disableAssist = Spring.GetModOptions().disable_assist_ally_construction
local disableEconShare = Spring.GetModOptions().disable_economic_sharing
if not disableAssist and not disableEconShare then
	return false
end


----------------------------------------------------------------
--
----------------------------------------------------------------

-- TODO: This gadget could handle edge-cases where a blueprint being assisted is transfered to another team
-- The assisting units will continue because they are on the same command. Need to intercept with UnitGiven
-- and change the assisting units orders so that they can no longer help the blueprint that is not theirs
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitIsBeingBuilt= Spring.GetUnitIsBeingBuilt
local spGetUnitTeam = Spring.GetUnitTeam
local spAreTeamsAllied = Spring.AreTeamsAllied
local spGiveOrderToUnit = Spring.GiveOrderToUnit

local CMD_GUARD = CMD.GUARD
local CMD_REPAIR = CMD.REPAIR
local CMD_MOVE_STATE = CMD.MOVE_STATE

local canAssist = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.canAssist then
		canAssist[unitDefID] = true
	end
end


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
			if(spGetUnitIsBeingBuilt(targetID)) then
				return false
			end
		end
	end

	-- Disallow changing the move_state value of non-factory builders to ROAM (move_state of roam causes builders to auto-assist ally construction)
	if (cmdID == CMD_MOVE_STATE and cmdParams[1] == 2 and canAssist[unitDefID] ) then
		spGiveOrderToUnit(unitID, CMD_MOVE_STATE, 0) -- make toggling still work between Hold and Maneuver
		return false
	end
	return true
end
