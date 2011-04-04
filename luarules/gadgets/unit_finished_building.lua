function gadget:GetInfo()
  return {
    name      = "FinishedBuilding",
    desc      = "Provides information on whether or not a unit is underconstruction",
    author    = "TheFatController",
    date      = "17 Feb 2010",
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

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
  Spring.SetUnitRulesParam(unitID, "under_construction", 1, { public = true })
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
  Spring.SetUnitRulesParam(unitID, "under_construction", 0, { public = true })
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
