function gadget:GetInfo()
  return {
    name      = "Prevent Unload Hax",
    desc      = "removes unit velocity on unload (and prevents firing units across the map with 'stored' impulse)",
    author    = "Bluestone",
    date      = "12/08/2013",
    license   = "horse has fallen over, again",
    layer     = 0,
    enabled   = true
  }
end

if (not gadgetHandler:IsSyncedCode()) then return end

local COMMANDO = UnitDefNames["commando"].id

local SpSetUnitVelocity = Spring.SetUnitVelocity
local SpGetUnitVelocity = Spring.GetUnitVelocity

function gadget:UnitUnloaded(unitID, unitDefID, teamID, transportID)
	if unitID == nil or unitDefID == nil or transportID == nil then return end

	if (unitDefID == COMMANDO) then		
		local x,y,z = SpGetUnitVelocity(transportID)
		if x > 10 then x = 10 elseif x <- 10 then x = -10 end -- 10 is well above 'normal' airtrans velocity
		if z > 10 then z = 10 elseif z <- 10 then z = -10 end		
		SpSetUnitVelocity(unitID, x, y,z)
	else
		SpSetUnitVelocity(unitID, 0,0,0)	
	end
end



	


