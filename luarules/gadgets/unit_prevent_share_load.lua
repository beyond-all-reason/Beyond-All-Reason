local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "No Share Load",
		desc      = "Prevents picking up units when a unit changes hands",
		author    = "Floris",
		date      = "May 2024",
		license   = "GNU GPL, v2 or later",
		layer     = -99999,
		enabled   = true
	}
end


if not gadgetHandler:IsSyncedCode() then
	return
end

function gadget:AllowUnitTransfer(unitID, unitDefID, oldTeam, newTeam, capture)
  Spring.GiveOrderToUnit(unitID, CMD.REMOVE, { CMD.LOAD_UNITS }, { "alt" })
  return true
end
