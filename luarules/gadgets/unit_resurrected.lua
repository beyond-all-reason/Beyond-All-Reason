function gadget:GetInfo()
   return {
      name      = "resurrected param",
      desc      = "marks resurrected units as resurrected.",
      author    = "Floris",
      date      = "25 oct 2015",
      license   = "GNU GPL, v2 or later",
      layer     = 5,
      enabled   = true
   }
end

if (gadgetHandler:IsSyncedCode()) then
	
	-- detect resurrected units here
	function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
		if builderID  and  UnitDefs[Spring.GetUnitDefID(builderID)].canResurrect then
			
			Spring.SetUnitRulesParam(unitID, "resurrected", 1, {inlos=true})
			
		end
	end
	
end
