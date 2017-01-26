--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "Prevent Strange Orders",
    desc      = "There's no reason to need to insert a remove command (if even possible)",
    author    = "TheFatController",
    date      = "Aug 31, 2009",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (not gadgetHandler:IsSyncedCode()) then
  return false
end

local CMD_INSERT = CMD.INSERT
local CMD_REMOVE = CMD.REMOVE

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, synced)
  if (cmdID == CMD_INSERT) then
	if (CMD_REMOVE == cmdParams[2]) or (CMD_INSERT == cmdParams[2]) then
      return false
    end
  end
  return true
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------