--- Anything that moves on treads stays on the ground; the rest is BAR's business.

local Stages = VFS.Include("modules/transport/contract.lua").Load ---@type TransportLoadStages

---@param unitDef table|nil
---@return boolean
local function isTank(unitDef)
	local moveDef = unitDef and unitDef.moveDef
	return moveDef ~= nil and type(moveDef.name) == "string" and moveDef.name:upper():find("TANK", 1, true) ~= nil
end

Policies.Pipeline(Stages).Unless("TanksStayOnTheGround", function(ctx)
	return isTank(ctx.passengerDef)
end)
