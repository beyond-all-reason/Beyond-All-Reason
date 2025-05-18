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


if Spring.GetModOptions().tax_resource_sharing_amount == 0 then
	return false
end

if gadgetHandler:IsSyncedCode() then
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

		if sharingFullyDisabled then
			return false   -- if tax is 100%, don't eat the sender's money and just block the transfer
		end

		-- Calculate the maximum amount the receiver can receive
		--Current, Storage, Pull, Income, Expense
		local rCur, rStor, rPull, rInc, rExp, rShare = Spring.GetTeamResources(receiverId, resourceName)

		-- rShare is the share slider setting, don't exceed their share slider max when sharing
		local maxShare = rStor * rShare - rCur

		local taxedAmount = math.min((1-sharingTax)*amount, maxShare)
		local totalAmount = taxedAmount / (1-sharingTax)
		local transferTax = totalAmount * sharingTax

		Spring.SetTeamResource(receiverId, resourceName, rCur+taxedAmount)
		local sCur, _, _, _, _, _ = Spring.GetTeamResources(senderId, resourceName)
		Spring.SetTeamResource(senderId, resourceName, sCur-totalAmount)
		
		local senderName = Spring.GetPlayerInfo(senderId, false)
		local receiverName = Spring.GetPlayerInfo(receiverId, false)
		
		SendToUnsynced("SentTaxedResources", senderName, receiverName, resourceName, math.round(taxedAmount), math.round(transferTax))
		
		-- Block the original transfer
		return false
	end

	function gadget:AllowUnitTransfer(unitID, unitDefID, oldTeam, newTeam, capture)
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
			if not unitTeam or not targetTeam then -- be permissive in case of undefined teams
				return true
			elseif unitTeam ~= targetTeam and Spring.AreTeamsAllied(unitTeam, targetTeam) then
				return false
			end
		-- Also block guarding allied units that can reclaim
		elseif (cmdID == CMD.GUARD) then
			local targetID = cmdParams[1]
			local targetTeam = Spring.GetUnitTeam(targetID)
			local targetUnitDef = UnitDefs[Spring.GetUnitDefID(targetID)]
			if not unitTeam or not targetTeam then 
				return true
			elseif (unitTeam ~= Spring.GetUnitTeam(targetID)) and Spring.AreTeamsAllied(unitTeam, targetTeam) then
				-- Labs are considered able to reclaim. In practice you will always use this modoption with "disable_assist_ally_construction", so disallowing guard labs here is fine
				if targetUnitDef.canReclaim then
					return false
				end
			end
		end
		return true
	end

else -- UNSYNCED

	local spSendLuaUIMsg        = Spring.SendLuaUIMsg

	local function sendMsg(_, playerID, msg)
		local name,_,spec,_,playerAllyTeamID = Spring.GetPlayerInfo(playerID)
		local mySpec = Spring.GetSpectatingState()
		if not spec and (playerAllyTeamID == Spring.GetMyAllyTeamID() or mySpec) then
			Spring.SendMessageToPlayer(Spring.GetMyPlayerID(), '<'..name..'> Allies: > '..msg)
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("SentTaxedResources", handleSentTaxedResources)
	end
	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("SentTaxedResources")
	end

	function handleSentTaxedResources(_, senderName, receiverName, resourceName, taxedAmount, transferTax)
		spSendLuaUIMsg("tax_resource_sharing:"..senderName..","..(receiverName or "Unknown")..","..resourceName..","..taxedAmount..","..transferTax)
	end
end