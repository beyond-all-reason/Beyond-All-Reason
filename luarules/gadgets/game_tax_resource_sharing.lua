local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = 'Tax Resource Sharing',
		desc    = 'Tax Resource Sharing when modoption enabled. Modified from "Prevent Excessive Share" by Niobium', -- taxing overflow needs to be handled by the engine 
		author  = 'Rimilel',
		date    = 'April 2024',
		license = 'GNU GPL, v2 or later',
		layer   = 1, -- Needs to occur before "Prevent Excessive Share" since their restriction on AllowResourceTransfer is not compatible
		enabled = true
	}
end

----------------------------------------------------------------
-- Synced only
----------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return false
end
if Spring.GetModOptions().tax_resource_sharing_amount == 0 then
	return false
end

local spIsCheatingEnabled = Spring.IsCheatingEnabled
local spGetTeamUnitCount = Spring.GetTeamUnitCount

local gameMaxUnits = math.min(Spring.GetModOptions().maxunits, math.floor(32000 / #Spring.GetTeamList()))

local sharingTax = Spring.GetModOptions().tax_resource_sharing_amount

----------------------------------------------------------------
-- Callins
----------------------------------------------------------------



-- Deprecated: centralized in TeamTransfer resource validators/processors

function gadget:Initialize()
    -- Tax is now handled directly in teammates.lua TeamAutoShare and NetResourceTransfer
    -- This gadget only validates that tax is enabled and provides reclaim restrictions
    Spring.Log("TaxResourceSharing", LOG.INFO, "Resource sharing tax enabled at " .. (sharingTax * 100) .. "%")
end

-- Keep the old function as fallback for compatibility
-- AllowUnitTransfer removed - validation now handled by centralized BARTransfer validator system


function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
	-- Disallow reclaiming allied units for metal
	if (cmdID == CMD.RECLAIM and #cmdParams >= 1) then
		local targetID = cmdParams[1]
		local targetTeam
		if(targetID >= Game.maxUnits) then
			return true
		end
		targetTeam = Spring.GetUnitTeam(targetID)
		if unitTeam ~= targetTeam and Spring.AreTeamsAllied(unitTeam, targetTeam) then
			return false
		end
	-- Also block guarding allied units that can reclaim
	elseif (cmdID == CMD.GUARD) then
		local targetID = cmdParams[1]
		local targetTeam = Spring.GetUnitTeam(targetID)
		local targetUnitDef = UnitDefs[Spring.GetUnitDefID(targetID)]

		if (unitTeam ~= Spring.GetUnitTeam(targetID)) and Spring.AreTeamsAllied(unitTeam, targetTeam) then
			-- Labs are considered able to reclaim. In practice you will always use this modoption with "disable_assist_ally_construction", so disallowing guard labs here is fine
			if targetUnitDef.canReclaim then
				return false
			end
		end
	end
	return true
end