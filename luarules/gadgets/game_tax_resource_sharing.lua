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



function gadget:AllowResourceTransfer(senderTeamId, receiverTeamId, resourceType, amount)

	-- Spring uses 'm' and 'e' instead of the full names that we need, so we need to convert the resourceType
	-- We also check for 'metal' or 'energy' incase Spring decides to use those in a later version
	local resourceName
	if (resourceType == 'm') or (resourceType == 'metal') then
		resourceName = 'metal'
	elseif (resourceType == 'e') or (resourceType == 'energy') then
		resourceName = 'energy'
	else
		-- We don't handle whatever this resource is, allow it
		return true
	end

	-- Calculate the maximum amount the receiver can receive
	--Current, Storage, Pull, Income, Expense
	local rCur, rStor, rPull, rInc, rExp, rShare = Spring.GetTeamResources(receiverTeamId, resourceName)

	-- rShare is the share slider setting, don't exceed their share slider max when sharing
	local maxShare = rStor * rShare - rCur

	local taxedAmount = math.min((1-sharingTax)*amount, maxShare)
	local totalAmount = taxedAmount / (1-sharingTax)
	local transferTax = totalAmount * sharingTax

	Spring.SetTeamResource(receiverTeamId, resourceName, rCur+taxedAmount)
	local sCur, _, _, _, _, _ = Spring.GetTeamResources(senderTeamId, resourceName)
	Spring.SetTeamResource(senderTeamId, resourceName, sCur-totalAmount)

	-- Block the original transfer
	return false
end

function gadget:AllowUnitTransfer(unitID, unitDefID, oldTeam, newTeam, capture, reason)
	if oldTeam == newTeam then
		return true
	end
	local unitCount = spGetTeamUnitCount(newTeam)
	if capture or spIsCheatingEnabled() or unitCount < gameMaxUnits then
		return true
	end
	return false
end


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