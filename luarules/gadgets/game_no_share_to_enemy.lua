function gadget:GetInfo()
  return {
    name      = "game_no_share_to_enemy",
    desc      = "Disallows sharing to enemies",
    author    = "TheFatController",
    date      = "19 Jan 2008",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (not gadgetHandler:IsSyncedCode()) then
  return
end

local AreTeamsAllied = Spring.AreTeamsAllied
local SendMessageToTeam = Spring.SendMessageToTeam
local IsCheatingEnabled = Spring.IsCheatingEnabled

function gadget:AllowResourceTransfer(oldTeam, newTeam, type, amount)
  if AreTeamsAllied(newTeam, oldTeam) or (IsCheatingEnabled()) then
    return true
  end
  SendMessageToTeam(oldTeam, "Resource sharing to enemies has been disabled.")
  return false
end

function gadget:AllowUnitTransfer(unitID, unitDefID, oldTeam, newTeam, capture)
  if AreTeamsAllied(newTeam, oldTeam) or (capture) or (IsCheatingEnabled()) then
    return true
  end
  SendMessageToTeam(oldTeam, "Unit sharing to enemies has been disabled.")
  return false
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------