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

function gadget:Initialize()
    if GG.TeamTransfer then
        GG.TeamTransfer.RegisterValidator("PreventShareLoad", function(unitID, unitDefID, oldTeam, newTeam, reason)
			if not unitID or type(unitID) ~= "number" then
				return true
			end
			
			local success, cmdQueue = pcall(Spring.GetUnitCommands, unitID)
			if not success or not cmdQueue or #cmdQueue == 0 then
				return true
			end
			Spring.GiveOrderToUnit(unitID, CMD.REMOVE, { CMD.LOAD_UNITS }, { "alt" })
			return true
		end)
	end
end
