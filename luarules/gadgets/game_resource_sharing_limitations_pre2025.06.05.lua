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

if sharing_tax == 0 and disable_manual_resource_sharing == false and disable_overflow == false then
	return false
end

-- localized functions
local SpSetTeamShareLevel = Spring.SetTeamShareLevel
local SpShareTeamResource = Spring.ShareTeamResource
local SpUseTeamResource = Spring.UseTeamResource
local SpAddTeamResource = Spring.AddTeamResource


-- localized lists
local teamList = Spring.GetTeamList()
local allyTeamList = Spring.GetAllyTeamList()
local allyteamTeamList = {}


local ForcedRequests = {}
local lastRecv = {}
local lastSent = {}
local lastExcess = {}
local teamOverflowedLastFrame = {}
local allyTeamOverflowedLastFrame = {}

for _, teamID in pairs(teamList) do
	teamOverflowedLastFrame[teamID] = {metal = 0, energy = 0} -- set to 0 for gamestart
	lastRecv[teamID] = {metal = 0, energy = 0}
	lastSent[teamID] = {metal = 0, energy = 0}
	lastExcess[teamID] = {metal = 0, energy = 0}
	if disable_overflow or sharing_tax > 0 then -- force to 1.0 when mod option is enabled
		SpSetTeamShareLevel(teamID, "metal", 1.0)
		SpSetTeamShareLevel(teamID, "energy", 1.0)
	end
end

for _, allyTeam in pairs(allyTeamList) do
	allyteamTeamList[allyTeam] = Spring.GetTeamList(allyTeam) -- register our allyteamTeamLists
	allyTeamOverflowedLastFrame[allyTeam] = {metal = 0, energy = 0} -- set to 0 for game start
end

function GetAvailableStorage(teamID, resType)
	local current, storage = Spring.GetTeamResources(teamID, resType)
	return math.max(0, storage - current)
end

function GG.ForcedResourceSharing(senderTeamId, receiverTeamId, resourceType, amount) -- set this as a global function in case we need some ways to override current limitations
	local hash = Hash(senderTeamId, receiverTeamId, resourceType, amount) -- we hash, then register, then send a new ShareRequest with the proper value, which will be validated by our allowResourceTransfer process
	if resourceType == "m" then
		resourceType = "metal"
	elseif resourceType == "e" then
		resourceType = "energy"
	end
	ForcedRequests[hash] = true
	SpShareTeamResource(senderTeamId, receiverTeamId, resourceType, amount)
	lastSent[senderTeamId][resourceType] = lastSent[senderTeamId][resourceType] + amount
	lastRecv[receiverTeamId][resourceType] = lastRecv[receiverTeamId][resourceType] + amount
end

function Hash(senderTeamId, receiverTeamId, resourceType, amount)
	local frame = Spring.GetGameFrame()
	local str = frame .. senderTeamId .. receiverTeamId .. resourceType .. amount
	return str
end

function gadget:AllowResourceTransfer(senderTeamId, receiverTeamId, resourceType, amount) 

	-- other sharing restrictions have to happen before this one
	-- so this is never actually called if anything else has been preventing the share from happening.
	-- By the time a "sharing process" have reached this, this means the share is legal, so sending a new request from here with the same params should no be an issue.
	-- So it just means we need a higher layer than other restrictions

	local hash = Hash(senderTeamId, receiverTeamId, resourceType, amount)
	if ForcedRequests[hash] == true then
		ForcedRequests[hash] = nil
		return true
	end
	if disable_manual_resource_sharing then
		return false
	end
	SpUseTeamResource(senderTeamId, resourceType, sharing_tax * amount) -- we apply the tax here and not within ForcedResourceSharing because ForcedResourceSharing is supposed to be a method that bypasses AllowResourceTransfer process
	GG.ForcedResourceSharing(senderTeamId, receiverTeamId, resourceType, (1 - sharing_tax) * amount)
	return false
end

if (sharing_tax > 0 or disable_overflow) then -- only enable this part if we need to manage overflow


	function KillOverflow(teamID, resType, amount) -- cancel the overflow from last slowUpdate
		if amount > 0 then
			local curr = Spring.GetTeamResources(teamID, resType)
			Spring.SetTeamResource(teamID, string.sub(resType, 1, 1), curr - amount)
		end
	end

	function Leak(allyTeam, metal, energy)
		if metal == 0 then metal = nil end
		if energy == 0 then energy = nil end

		local preTaxValue = {metal = metal, energy = energy}
		local totalAvailableAllyTeamStorages = {metal = 0, energy = 0}
		local availableTeamStorage = {}

		for _, teamID in pairs(allyteamTeamList[allyTeam]) do -- 1st iteration's goal is to assess the available storage
			availableTeamStorage[teamID] = {}
			for resType, excess in pairs(preTaxValue) do -- this only runs if excess ~= nil so we're not processing null excess
				local availableStorage = GetAvailableStorage(teamID, resType)
				if teamOverflowedLastFrame[teamID][resType] > 0 and availableStorage > 0 then -- this can happen because we do not process excess in real time, we have to do it because otherwise we might tax the same "resource" twice
					local shareBack = math.min(teamOverflowedLastFrame[teamID][resType], availableStorage)
					SpAddTeamResource(teamID, resType, shareBack)
					availableStorage = availableStorage - shareBack
					teamOverflowedLastFrame[teamID][resType] = teamOverflowedLastFrame[teamID][resType] - shareBack
					allyTeamOverflowedLastFrame[allyTeam][resType] = allyTeamOverflowedLastFrame[allyTeam][resType] - shareBack
					preTaxValue[resType] = preTaxValue[resType] - shareBack
				end
				availableTeamStorage[teamID][resType] = availableStorage
				totalAvailableAllyTeamStorages[resType] = totalAvailableAllyTeamStorages[resType] + availableStorage
			end
		end

		if preTaxValue.metal == 0 then preTaxValue.metal = nil end -- if our shareBack process left 0 excess, we again filter out null excesses to avoid needless processing
		if preTaxValue.energy == 0 then preTaxValue.energy = nil end

		for resType, excess in pairs(preTaxValue) do -- 2nd iteration: either available storage is null and we just reset counters, or is non null and we add resources then reset counters
			if totalAvailableAllyTeamStorages[resType] <= 0 then
				for _, teamID in pairs(allyteamTeamList[allyTeam]) do
					teamOverflowedLastFrame[teamID][resType] = 0 -- just reset counter
				end
			else	
				local postTaxValue = excess * (1 - sharing_tax)
				local percent = math.min(1, postTaxValue / totalAvailableAllyTeamStorages[resType])
				local SharedAmount = 0
				for _, teamID in pairs(allyteamTeamList[allyTeam]) do
					local aftTaxAmount = percent * availableTeamStorage[teamID][resType]
					local preTaxAmount = aftTaxAmount / (1 - sharing_tax)
					SpAddTeamResource(teamID, resType, aftTaxAmount)
					teamOverflowedLastFrame[teamID][resType] = 0
				end
			end
			allyTeamOverflowedLastFrame[allyTeam][resType] = 0
		end
	end

	function gadget:GameFramePost(f)
		if f % 30 == 0 then
			for _, teamID in pairs(teamList) do
				local _, _, _, _, _, allyTeam = Spring.GetTeamInfo(teamID)
				local _, _, curExcessedM, curRecvM, curSentM = Spring.GetTeamResourceStats(teamID, "m")
				local _, _, curExcessedE, curRecvE, curSentE = Spring.GetTeamResourceStats(teamID, "e")
				local diffRecvM, diffRecvE, diffExcessM, diffExcessE, diffSentM, diffSentE = curRecvM - lastRecv[teamID].metal, curRecvE - lastRecv[teamID].energy, curExcessedM - lastExcess[teamID].metal, curExcessedE - lastExcess[teamID].energy, curSentM - lastSent[teamID].metal, curSentE - lastSent[teamID].energy
				KillOverflow(teamID, "metal", diffRecvM)
				KillOverflow(teamID, "energy", diffRecvE)
				local overFlowedE, overFlowedM = diffExcessE + diffSentE, diffExcessM + diffSentM
				allyTeamOverflowedLastFrame[allyTeam].energy, allyTeamOverflowedLastFrame[allyTeam].metal  = allyTeamOverflowedLastFrame[allyTeam].energy + overFlowedE, allyTeamOverflowedLastFrame[allyTeam].metal + overFlowedM
				teamOverflowedLastFrame[teamID].energy, teamOverflowedLastFrame[teamID].metal  = overFlowedE, overFlowedM
				lastRecv[teamID].metal,lastRecv[teamID].energy, lastExcess[teamID].metal,lastExcess[teamID].energy, lastSent[teamID].metal, lastSent[teamID].energy = curRecvM, curRecvE,curExcessedM, curExcessedE, curSentM, curSentE
			end
			if not disable_overflow then -- reapply overflow only if not disabled
				for _, allyTeam in pairs(allyTeamList) do
					Leak(allyTeam, allyTeamOverflowedLastFrame[allyTeam].metal, allyTeamOverflowedLastFrame[allyTeam].energy)
				end
			end
		end
	end

	function gadget:AllowResourceLevel()
		return false
	end
end