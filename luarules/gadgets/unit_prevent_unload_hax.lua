function gadget:GetInfo()
  return {
    name      = "Prevent Unload Hax",
    desc      = "removes unit velocity on unload (and prevents firing units across the map with 'stored' impulse)",
    author    = "bluestone",
    date      = "12/08/2013",
    license   = "horse has fallen over, again",
    layer     = 0,
    enabled   = true
  }
end

if (not gadgetHandler:IsSyncedCode()) then return end

local COMMANDO = UnitDefNames["commando"].id

local max = math.max
local SpSetUnitVelocity = Spring.SetUnitVelocity
local SpGetUnitVelocity = Spring.GetUnitVelocity

function gadget:UnitUnloaded(unitID, unitDefID, teamID, transportID)
	if unitID == nil then return end
	if unitDefID == nil then return end
	if transportID == nil then return end

	if (unitDefID == COMMANDO) then		
		local x,y,z = SpGetUnitVelocity(transportID)
		SpSetUnitVelocity(unitID, x, y,z)
	else
		SpSetUnitVelocity(unitID, 0,0,0)	
	end
end



	


