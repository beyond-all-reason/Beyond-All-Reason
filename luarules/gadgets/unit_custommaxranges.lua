--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "Controls Unit's maxrange",
    desc      = "Fixes some aa/ground units not closing in on target when given attack order",
    author    = "Doo",
    date      = "06 dec 2017",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

function gadget:Initialize()
	for ct, unitID in pairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	if UnitDefs[unitDefID].customParams and UnitDefs[unitDefID].customParams.maxrange and tonumber(UnitDefs[unitDefID].customParams.maxrange) then
		Spring.SetUnitMaxRange(unitID, tonumber(UnitDefs[unitDefID].customParams.maxrange))
	end
end