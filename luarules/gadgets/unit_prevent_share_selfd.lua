-- $Id: unit_noselfd.lua 3171 2008-11-06 09:06:29Z det $
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Copyright (C) 2008.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "No Self-D",
    desc      = "Prevents self-destruction when a unit changes hands.",
    author    = "quantum",
    date      = "July 13, 2008",
    license   = "GNU GPL, v2 or later",
    layer     = -10,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (not gadgetHandler:IsSyncedCode()) then
  return false
end

function gadget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
  if (Spring.GetUnitSelfDTime(unitID) > 0) then
    Spring.GiveOrderToUnit(unitID, CMD.SELFD, {}, {})
  end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------