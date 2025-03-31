-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "Stun Control",
		desc      = "Disables on/off for Stunned Units",
		author    = "Nixtux",
		date      = "Apr 13, 2014",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

if (not gadgetHandler:IsSyncedCode()) then
	return false
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

local CMD_ONOFF = CMD.ONOFF

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_ONOFF)
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	-- accepts: CMD.ONOFF
	if Spring.GetUnitIsStunned(unitID) then
		return false
	else
		return true
	end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
