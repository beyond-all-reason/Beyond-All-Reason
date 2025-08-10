local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = 'Tax Resource Sharing',
		desc    = 'Tax Resource Sharing by variable amounts', -- taxing overflow needs to be handled by the engine
		author  = 'Rimilel',
		date    = 'April 2024',
		license = 'GNU GPL, v2 or later',
		layer   = 1, -- Needs to occur before "Prevent Excessive Share" since their restriction on AllowResourceTransfer is not compatible
		enabled = true
	}
end

----------------------------------------------------------------
-- Decide whether to activate
----------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return false
end

local sharingDisabled = Spring.GetModOptions().disable_economic_sharing
local taxEnabled = Spring.GetModOptions().tax_resource_sharing_amount > 0
local taxAmount = Spring.GetModOptions().tax_resource_sharing_amount
if taxAmount >= 1 then
	taxEnabled = false
	sharingDisabled = true
end

if not taxEnabled and not sharingDisabled then
	return false
end


----------------------------------------------------------------
-- Callins
----------------------------------------------------------------

function gadget:Initialize()
	local teams = Spring.GetTeamList()
	for _, teamID in ipairs(teams) do
		Spring.SetTeamShareLevel(teamID, 'metal', 0)
		Spring.SetTeamShareLevel(teamID, 'energy', 0)
	end
end

function gadget:AllowResourceTransfer(senderId, receiverId, resourceType, amount)
	if sharingDisabled then -- no transfers allowed, don't bother taxing
		return false
	end

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


	local rCurrent, rStorage, _, _, _, rShare = Spring.GetTeamResources(receiverId, resourceName)

	-- rShare is their share slider setting from between 0 and 1.
	-- To avoid taxed resources immediately being shared, only allow sending up to their share slider
	local maxCanReceive = rStorage * rShare - rCurrent

	local taxedAmount = math.min((1-taxAmount)*amount, maxCanReceive)
	local totalAmount = taxedAmount / (1-taxAmount)
	local transferTax = totalAmount * taxAmount

	local sCurrent, _, _, _, _, _ = Spring.GetTeamResources(senderId, resourceName)

	Spring.SetTeamResource(receiverId, resourceName, rCurrent+taxedAmount)
	Spring.SetTeamResource(senderId, resourceName, sCurrent-totalAmount)


	-- Display a console message about the transfer
	local senderName = Spring.GetPlayerInfo(senderId, false)

	local _, _, _, isAiTeam = Spring.GetTeamInfo(receiverId)
	local receiverName
	if isAiTeam then
		_, receiverName = Spring.GetAIInfo(receiverId, false)
	else
		receiverName = Spring.GetPlayerInfo(receiverId, false)
	end

	Spring.Echo(senderName.." sent "..math.round(taxedAmount).." "..resourceName.." to "..receiverName.." (-"..math.round(transferTax).." "..resourceName.." taxed)")

	-- Block the original transfer
	return false
end
