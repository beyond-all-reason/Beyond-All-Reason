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


local spGetUnitTeam = Spring.GetUnitTeam
local spAreTeamsAllied = Spring.AreTeamsAllied
local spGetUnitDefID =  Spring.GetUnitDefID
local spAreTeamsAllied = Spring.AreTeamsAllied
local spIsCheatingEnabled = Spring.IsCheatingEnabled
local spGetTeamUnitCount = Spring.GetTeamUnitCount

local gameMaxUnits = math.min(Spring.GetModOptions().maxunits, math.floor(32000 / #Spring.GetTeamList()))

local sharingTax = Spring.GetModOptions().tax_resource_sharing_amount
local sharingFullyDisabled = Spring.GetModOptions().tax_resource_sharing_amount == 1

----------------------------------------------------------------
-- Callins
----------------------------------------------------------------

function gadget:AllowResourceTransfer(senderId, receiverId, resourceType, amount)

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

	if sharingFullyDisabled then -- if tax is 100%, don't eat the sender's money and just block the transfer
		return false   
	end

	local rCurrent, rStorage, _, _, _, rShare = Spring.GetTeamResources(receiverId, resourceName)

	-- rShare is their share slider setting from between 0 and 1. 
	-- To avoid taxed resources immediately being shared, only allow sending up to their share slider
	local maxCanReceive = rStorage * rShare - rCurrent

	local taxedAmount = math.min((1-sharingTax)*amount, maxCanReceive)
	local totalAmount = taxedAmount / (1-sharingTax)
	local transferTax = totalAmount * sharingTax

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

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
	
	-- Disallow reclaiming allied units for metal
	if (cmdID == CMD.RECLAIM and #cmdParams >= 1) then
		local targetID = cmdParams[1]
		local targetTeam
		if(targetID >= Game.maxUnits) then
			return true
		end
		targetTeam = spGetUnitTeam(targetID)
		if not unitTeam or not targetTeam then -- be permissive in case of undefined teams
			return true
		elseif unitTeam ~= targetTeam and spAreTeamsAllied(unitTeam, targetTeam) then
			return false
		end
	-- Also block guarding allied units that can reclaim
	elseif (cmdID == CMD.GUARD) then
		local targetID = cmdParams[1]
		local targetTeam = spGetUnitTeam(targetID)
		local targetUnitDef = UnitDefs[spGetUnitDefID(targetID)]
		if not unitTeam or not targetTeam then 
			return true
		elseif (unitTeam ~= targetTeam) and spAreTeamsAllied(unitTeam, targetTeam) then
			-- Labs are considered able to reclaim. In practice you will always use this modoption with "disable_assist_ally_construction", so disallowing guard labs here is fine
			if targetUnitDef.canReclaim then
				return false
			end
		end
	end
	return true
end


function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD.RECLAIM)
	gadgetHandler:RegisterAllowCommand(CMD.GUARD)
end

	