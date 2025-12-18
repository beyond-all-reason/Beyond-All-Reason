-- localized modoptions
local sharing_tax = Spring.GetModOptions().sharing_tax / 100
local disable_manual_resource_sharing = Spring.GetModOptions().disable_manual_resource_sharing
local disable_overflow = Spring.GetModOptions().disable_overflow

function gadget:GetInfo()
	return {
		name    = 'Resource sharing limitations',
		desc    = 'Handles tax and related limitations',
		author  = 'DoodVanDaag',
		date    = 'Oct 2025',
		license = 'GNU GPL, v2 or later',
		layer   = 1,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

-- localized functions
local SpSetTeamShareLevel = Spring.SetTeamShareLevel
local SpShareTeamResource = Spring.ShareTeamResource

local SilentAdd = function (teamID, resType, amount)
	local current = Spring.GetTeamResources(teamID, resType)
	Spring.SetTeamResource(teamID, resType, current + amount)
end

local SilentUse = function (teamID, resType, amount)
	local current = Spring.GetTeamResources(teamID, resType)
	if current >= amount then
		Spring.SetTeamResource(teamID, resType, current - amount)
		return true
	else
		return false
	end
end



-- localized lists
local teamList = Spring.GetTeamList()
local allyTeamList = Spring.GetAllyTeamList()
local allyteamTeamList = {}


local ForcedRequests = {}
local lastRecv = {}
local lastSent = {}
local lastExcess = {}
local availableTeamOverflow = {}
local totalAvailableAllyTeamOverflow = {}

for _, teamID in pairs(teamList) do
	local _, _, curExcessedM, curRecvM, curSentM = Spring.GetTeamResourceStats(teamID, "m")
	local _, _, curExcessedE, curRecvE, curSentE = Spring.GetTeamResourceStats(teamID, "e")
	availableTeamOverflow[teamID] = {metal = 0, energy = 0} -- set to 0 for gamestart
	lastExcess[teamID] = {metal = curExcessedM, energy = curExcessedE}
	if disable_overflow then -- force to 1.0 when mod option is enabled
		SpSetTeamShareLevel(teamID, "metal", 1.0)
		SpSetTeamShareLevel(teamID, "energy", 1.0)
	end
end

for _, allyTeam in pairs(allyTeamList) do
	allyteamTeamList[allyTeam] = Spring.GetTeamList(allyTeam) -- register our allyteamTeamLists
	totalAvailableAllyTeamOverflow[allyTeam] = {metal = 0, energy = 0} -- set to 0 for game start
end

function GetAvailableUnderShare(teamID, resType)
	local current, storage,_,_,_,share = Spring.GetTeamResources(teamID, resType)
	return (storage*share) - current
end

function GetAvailableStorage(teamID, resType)
	local current, storage,_,_,_,share = Spring.GetTeamResources(teamID, resType)
	return math.max(0,storage - current)
end

function gadget:AllowResourceTransfer(senderTeamId, receiverTeamId, resourceType, amount) 
	if disable_manual_resource_sharing then
		return false
	end
	SilentUse(senderTeamId, resourceType, sharing_tax * amount) -- we apply the tax here and not within ForcedResourceSharing because ForcedResourceSharing is supposed to be a method that bypasses AllowResourceTransfer process
	SpShareTeamResource(senderTeamId, receiverTeamId, resourceType, (1 - sharing_tax) * amount) -- 2025.06.11 should not trigger allowresourcetransfer anymore ++
	return false
end

-- reimplemented overflow here, even without tax; so from now on it should always be on

	function Leak(allyTeam)
	
		local resTypes = {"metal", "energy"}
		local totalAvailableAllyTeamUnderShare = {metal = 0, energy = 0}
		local availableTeamUnderShare = {}

		-- STEP 1; REFUND OWNED EXCESS + ASSESS UNDERSHARE CAPACITIES + FUND OVERSHARE EXCESS

		for _, teamID in pairs(allyteamTeamList[allyTeam]) do
			availableTeamUnderShare[teamID] = {}
			for _, resType in pairs(resTypes) do
			
				local availableUnderShare = GetAvailableUnderShare(teamID, resType)
				
				if availableUnderShare > 0 then -- POSITIVE AVAILABLE UNDERSHARE; START REFUNDING AS MUCH AS POSSIBLE
					local shareBack = math.min(availableTeamOverflow[teamID][resType], availableUnderShare) -- AMOUNT TO SHARE BACK
					SilentAdd(teamID, resType, shareBack) -- SILENTLY add
					
					availableUnderShare = availableUnderShare - shareBack -- REMOVE FROM AVAILABLE STORAGE
					
					availableTeamOverflow[teamID][resType] = availableTeamOverflow[teamID][resType] - shareBack -- REMOVE FROM OWN AVAILABLE RESOURCES
					totalAvailableAllyTeamOverflow[allyTeam][resType] = totalAvailableAllyTeamOverflow[allyTeam][resType] - shareBack -- REMOVE FROM TOTAL ALLYTEAM AVAILABLE RESOURCES
					
					
				elseif availableUnderShare < 0 then -- NEGATIVE AVAILABLE UNDERSHARE; REMOVE RESOURCES TO FUND SHARE POOL
					local funds = math.abs(availableUnderShare) -- AMOUNT TO REMOVE TO REACH %SHARE VALUE
					
					SilentUse(teamID, resType, funds) -- SILENTLY use
					
					availableTeamOverflow[teamID][resType] = availableTeamOverflow[teamID][resType] + funds -- ADD TO OWN AVAILABLE RESOURCES
					totalAvailableAllyTeamOverflow[allyTeam][resType] = totalAvailableAllyTeamOverflow[allyTeam][resType] + funds  -- ADD TO TOTAL ALLYTEAM AVAILABLE RESOURCES
					availableUnderShare = 0 -- NO UNDERSHARE STORAGE AVAILABLE
				end
				
				-- ADD AVAILABLE UNDERSHARE VALUES AFTER 1st CORRECTIONS
				availableTeamUnderShare[teamID][resType] = availableUnderShare
				totalAvailableAllyTeamUnderShare[resType] = totalAvailableAllyTeamUnderShare[resType] + availableUnderShare
			end
		end

		-- STEP 2: FILL EVERYONE IN THE TEAM UP TO THEIR INDIVIDUAL %SHARE CURSOR 
		for _, resType in pairs(resTypes) do
			if totalAvailableAllyTeamOverflow[allyTeam][resType] > 0 then -- WE HAVE RESOURCES OF THIS TYPE TO SHARE // SKIP
				if totalAvailableAllyTeamUnderShare[resType] > 0 then -- WE HAVE ROOM TO RECEIVE MORE RESOURCES OF THIS TYPE
					local costToFill = (totalAvailableAllyTeamUnderShare[resType]) / (1-sharing_tax) -- AMOUNT OF RESOURCES TO SEND IF WE WANT TO FILL EVERYONE			
					local globalPercent = math.min(1,(totalAvailableAllyTeamOverflow[allyTeam][resType]) / costToFill) -- PERCENT OF EVERYONE'S UNDERSHARE STORAGE THAT WE SHOULD BE ABLE TO FILL

					for _, receiverTeamID in pairs (allyteamTeamList[allyTeam]) do
					
						local receivedAmount = globalPercent * availableTeamUnderShare[receiverTeamID][resType] -- AMOUNT THAT WILL BE CREDITED TO RECEIVER TEAM (after tax)
						local sentAmount = receivedAmount / (1-sharing_tax) -- AMOUNT THAT WILL BE REMOVED FROM TEAMS SHARING POOL (before tax)
						local personalPercent = sentAmount / totalAvailableAllyTeamOverflow[allyTeam][resType] -- PARTICIPATION OF EACH TEAM IN THE CURRENT SHARING PROCESS

						for _,senderTeamID in pairs (allyteamTeamList[allyTeam]) do -- WE CYCLE THROUGH SENDERS ASWELL AS WE NEED TO REMOVE FROM THEIR SHARING POOL PROPORTIONALLY
							local SenderUsed = personalPercent * availableTeamOverflow[senderTeamID][resType] -- COMPUTE SENT AMOUNT FROM SENDERTEAM
							availableTeamOverflow[senderTeamID][resType] = availableTeamOverflow[senderTeamID][resType] - SenderUsed -- REMOVE FROM HIS SHARING POOL
						end
						SilentAdd(receiverTeamID, resType, receivedAmount) -- ADD RECEIVED AMOUNT TO RECEIVER TEAM
						totalAvailableAllyTeamOverflow[allyTeam][resType] = totalAvailableAllyTeamOverflow[allyTeam][resType] - receivedAmount -- REMOVE FROM TOTAL ALLYTEAM SHARING POOL
					end
				end
			end
			local availableTeamStorage = {}
			local totalAvailableAllyteamStorage = 0
			if totalAvailableAllyTeamOverflow[allyTeam][resType] > 0 then -- WE STILL HAVE MORE RESOURCES OF THIS TYPE TO SHARE // SKIP
				-- STEP 3: REFUND OWNED SHAREPOOL AND ASSESS AVAILABLE STORAGES	
				for _, teamID in pairs(allyteamTeamList[allyTeam]) do
					local myStorage = GetAvailableStorage(teamID, resType)
					local myExcess = availableTeamOverflow[teamID][resType]
					if myExcess > 0 and myStorage > 0 then -- I STILL HAVE EXCESS TO FUND MYSELF
						local toFund = math.min(myStorage, myExcess) -- VALUE TO FUND MYSELF (= taxless refund)
						SilentAdd(teamID, resType, toFund) -- SILENTLY ADD VALUE
						availableTeamOverflow[teamID][resType] = availableTeamOverflow[teamID][resType] - toFund -- REMOVE FROM OWN AVAILABLE SHARE POOL
						totalAvailableAllyTeamOverflow[allyTeam][resType] = totalAvailableAllyTeamOverflow[allyTeam][resType] - toFund -- REMOVE FROM TOTAL ALLYTEAM AVAILABLE SHARE POOL
						
						local remainingStorage = GetAvailableStorage(teamID, resType) -- REMAINING STORAGE AFTER REFUND
						
						totalAvailableAllyteamStorage = totalAvailableAllyteamStorage + remainingStorage -- ADD TO TOTAL ALLYTEAM AVAILABLE STORAGE
						availableTeamStorage[teamID] = (availableTeamStorage[teamID] or 0) + remainingStorage -- ADD TO OWN AVAILABLE STORAGE
					end
				end
			end
			if totalAvailableAllyTeamOverflow[allyTeam][resType] > 0 then -- WE STILL HAVE MORE RESOURCES OF THIS TYPE TO SHARE // SKIP
				if totalAvailableAllyteamStorage > 0 then -- WE STILL HAVE MORE STORAGES TO FILL
					-- STEP 4: ATTEMPT TO FILL OTHERS' STORAGE WITH WHATEVER EXCESS REMAINS
					local availableAfterTax = totalAvailableAllyTeamOverflow[allyTeam][resType] * (1-sharing_tax) -- AMOUNT OF RESOURCES THAT CAN BE RECEIVED
					local percent = math.min(1,availableAfterTax / (totalAvailableAllyteamStorage)) -- PERCENT OF EVERYONE'S STORAGE THAT WE SHOULD BE ABLE TO FILL
					
					for _,teamID in pairs(allyteamTeamList[allyTeam]) do
						-- WE DONT NEED TO REMOVE FROM SENDERS' SHARE POOL UNTIL WE CAN ADD STATISTICS; WHEN ADDTEAMRESOURCESTATS IS UP WE WILL NEED TO ITERATE THROUGH SENDERS ASWELL
						availableTeamStorage[teamID] = (availableTeamStorage[teamID] or 0)
						SilentAdd(teamID, resType, availableTeamStorage[teamID] * percent) -- SILENTLY ADD TO RECEIVER TEAM
					end
				end
			end
			for _, teamID in pairs(allyteamTeamList[allyTeam]) do
				availableTeamOverflow[teamID][resType] = 0 -- RESET COUNTERS FOR ALL TEAM MEMBERS
			end
			totalAvailableAllyTeamOverflow[allyTeam][resType] = 0 -- RESET ALLYTEAM COUNTER
		end
	end

	function gadget:GameFramePost(f)
		if f % 30 == 0 then
			for _, teamID in pairs(teamList) do
				local _, _, _, _, _, allyTeam = Spring.GetTeamInfo(teamID)
				local _, _, curExcessedM = Spring.GetTeamResourceStats(teamID, "m")
				local _, _, curExcessedE = Spring.GetTeamResourceStats(teamID, "e")
				local diffExcessM, diffExcessE = curExcessedM - lastExcess[teamID].metal, curExcessedE - lastExcess[teamID].energy
				local overFlowedE, overFlowedM = diffExcessE, diffExcessM
				totalAvailableAllyTeamOverflow[allyTeam].energy, totalAvailableAllyTeamOverflow[allyTeam].metal  = totalAvailableAllyTeamOverflow[allyTeam].energy + overFlowedE, totalAvailableAllyTeamOverflow[allyTeam].metal + overFlowedM
				availableTeamOverflow[teamID].energy, availableTeamOverflow[teamID].metal  = overFlowedE, overFlowedM
				lastExcess[teamID].metal,lastExcess[teamID].energy = curExcessedM, curExcessedE
			end
			if not disable_overflow then -- reapply overflow only if not disabled
				for _, allyTeam in pairs(allyTeamList) do
					Leak(allyTeam)
				end
			end
		end
	end

	function gadget:AllowResourceLevel(teamID, resType, level)
		if disable_overflow then
			return false
		end
		return true
	end
