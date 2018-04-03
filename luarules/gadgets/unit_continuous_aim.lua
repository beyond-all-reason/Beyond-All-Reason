function gadget:GetInfo()
  return {
    name      = "Continuous Aim",
    desc      = "Applies lower 'reaimTime for continuous aim'",
    author    = "Doo",
    date      = "April 2018",
    license   = "Whatever works",
    layer     = 0,
    enabled   = false, -- When we will move on 105 :)
  }
end

if (not gadgetHandler:IsSyncedCode()) then return end
function gadget:UnitCreated(unitID)
	for id, table in pairs(UnitDefs[Spring.GetUnitDefID(unitID)].weapons) do
		Spring.SetUnitWeaponState(unitID, id, "reaimTime", 3)
	end
end