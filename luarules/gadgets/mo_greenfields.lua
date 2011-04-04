function gadget:GetInfo()
  return {
    name      = "mo_greenfields",
    desc      = "mo_greenfields",
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

local enabled = tonumber(Spring.GetModOptions().mo_greenfields) or 0

if (enabled == 0) then 
  return false
end

local SetUnitMetalExtraction = Spring.SetUnitMetalExtraction

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
 SetUnitMetalExtraction(unitID, 0, 0)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------