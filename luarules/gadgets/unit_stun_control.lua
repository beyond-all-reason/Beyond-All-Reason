-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "Stun Control",
    desc      = "Disables on/off for Stunned Units",
    author    = "Nixtux",
    date      = "Apr 13, 2014",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
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


function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, synced)
  if (cmdID == CMD_ONOFF) and Spring.GetUnitIsStunned(unitID) then
    return false
    else
      return true
      end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------