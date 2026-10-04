-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
if (not gadgetHandler:IsSyncedCode()) then
    return
end
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
  return {
    name      = "Allow Builder Hold Fire",
    desc      = "Sets whether a builder can fire while doing anything nanolathe related.",
    author    = "Google Frog",
    date      = "22 June 2014",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true
  }
end



function gadget:AllowBuilderHoldFire(unitID, unitDefID, action)
	--Spring.Echo("gadget:AllowBuilderHoldFire(unitID, unitDefID, action)", unitID, unitDefID, action)
	return false -- false means that a unit can build and shoot at the same time
end
