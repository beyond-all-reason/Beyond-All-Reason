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
local metalTaxThreshold = Spring.GetModOptions().player_metal_send_threshold or 0 -- Use standardized key

local Tax = VFS.Include('common/luaUtilities/resource_share_tax.lua')

-- Table to store cumulative metal sent per sender team
local cumulativeMetalSent = {}

----------------------------------------------------------------
-- Initialization
----------------------------------------------------------------

function gadget:Initialize()
	-- Initialize cumulative tracking for all potential senders
	local teamList = Spring.GetTeamList()
	for _, senderID in ipairs(teamList) do
		cumulativeMetalSent[senderID] = 0
		-- Expose baseline values for UI
		Spring.SetTeamRulesParam(senderID, "metal_share_cumulative_sent", 0)
		Spring.SetTeamRulesParam(senderID, "metal_share_threshold", metalTaxThreshold)
		Spring.SetTeamRulesParam(senderID, "resource_share_tax_rate", sharingTax)
	end
end

----------------------------------------------------------------
-- Callins
----------------------------------------------------------------

function gadget:AllowResourceTransfer(senderTeamId, receiverTeamId, resourceType, amount)
	-- Spring uses 'm' and 'e' instead of the full names that we need, so we need to convert the resourceType
	-- We also check for 'metal' or 'energy' incase Spring decides to use those in a later version
	local resourceName -- This variable will hold the standardized name
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

	-- Prevent negative maxShare
	maxShare = math.max(0, maxShare)

	local transferAmount = math.min(amount, maxShare)

	local currentCumulative = cumulativeMetalSent[senderTeamId] or 0
	local breakdown = Tax.computeTransfer(resourceName, transferAmount, sharingTax, metalTaxThreshold, currentCumulative)
	local actualSentAmount = breakdown.actualSent
	local actualReceivedAmount = breakdown.actualReceived

	-- Ensure we don't send more than originally intended due to tax calculation edge cases / maxShare limit
	actualSentAmount = math.min(actualSentAmount, amount) 
	actualReceivedAmount = math.min(actualReceivedAmount, transferAmount)

	-- Perform the transfer
	Spring.SetTeamResource(receiverTeamId, resourceName, rCur + actualReceivedAmount)
	local sCur, _, _, _, _, _ = Spring.GetTeamResources(senderTeamId, resourceName)
	Spring.SetTeamResource(senderTeamId, resourceName, sCur - actualSentAmount)

	-- Update cumulative total *after* successful transfer (only for metal)
	if resourceName == 'metal' and metalTaxThreshold > 0 then
		local updatedCumulative = breakdown.newCumulative or (currentCumulative + actualSentAmount)
		cumulativeMetalSent[senderTeamId] = updatedCumulative
		Spring.SetTeamRulesParam(senderTeamId, "metal_share_cumulative_sent", updatedCumulative)
	end

	-- Keep threshold and tax rate exposed (in case of dynamic joins)
	Spring.SetTeamRulesParam(senderTeamId, "metal_share_threshold", metalTaxThreshold)
	Spring.SetTeamRulesParam(senderTeamId, "resource_share_tax_rate", sharingTax)

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