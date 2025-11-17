
if not Spring.TransferTeamMaxUnits then
	return
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "Dynamic Maxunits",
        desc      = "redistributes unit limit",
        author    = "Floris",
        date      = "May 2024",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = true
    }
end

if not gadgetHandler:IsSyncedCode() then
    return
end

--[[
	Dynamic Maxunits Redistribution

	This gadget takes control of maxunits redistribution using the engine's Spring.TransferTeamMaxUnits API.
	The total engine limit is 32768, with 500 reserved for Gaia.

	Configuration:
	- maxunits: per-team limit from Spring.GetModOptions().maxunits (default 2000)
	- gaiaLimit: reserved maxunits for Gaia team (default 500)
	- scavengerRaptorLimit: minimum maxunits for Scavenger/Raptor teams (default 3000)
	- equalizationFactor: how much to equalize allyteams (0.0 to 1.0, default 0.25)
	  * 0.0 = pure proportional distribution (each team gets equal share)
	  * 1.0 = full equalization (each allyteam gets equal combined total)
	  * 0.25 = go 25% of the way toward equal allyteam totals (recommended)

	On Initialize:
	- Excludes Gaia from all calculations
	- Scavenger/Raptor teams participate in equalization calculations (benefiting from team imbalance)
	- Scavenger/Raptor teams receive the equalized share OR scavengerRaptorLimit (3000), whichever is higher
	- Regular teams receive the equalized share capped at maxunits from modoptions
	- Calculates target maxunits for each team based on equalization factor
	- Smaller allyteams receive more maxunits per team to compensate for team count imbalance
	- Fairly distributes available donor pool across all recipient teams
	- Any leftover units after fair distribution are redistributed to teams still needing more

	When a Team Dies:
	- First redistributes maxunits to alive teammates
	- If no teammates alive, redistributes to all alive enemy teams
	- Always respects the per-team maxunits limit
	- Gaia and Scavenger/Raptor teams never receive or donate maxunits on team death
]]--

local maxunits = tonumber(Spring.GetModOptions().maxunits) or 2000
local engineLimit = 32768
local gaiaLimit = 500
local scavengerRaptorLimit = 3000  -- Minimum maxunits for Scavenger/Raptor teams
local equalizationFactor = 0.25  -- How much to equalize (0 = no equalization, 1 = full equalization). 0.25 means go 25% of the way toward equal allyteam totals

local mathFloor = math.floor
local mathMin = math.min
local mathMax = math.max

-- Check if a team is a Scavenger or Raptor AI team
local function isScavengerOrRaptor(teamID)
	local luaAI = Spring.GetTeamLuaAI(teamID)
	if luaAI then
		return string.find(luaAI, "Scavenger") or string.find(luaAI, "Raptor")
	end
	return false
end

function gadget:Initialize()
	if Spring.GetGameFrame() > 0 then
		return
	end

	-- Ensure Gaia team always get their maxunits
	local gaiaTeamID = Spring.GetGaiaTeamID()
	local gaiaAllyTeamID = select(6, Spring.GetTeamInfo(gaiaTeamID, false))

	local totalMaxUnits = engineLimit - gaiaLimit

	-- Get all allyteams and their teams (excluding Gaia, including Scavenger/Raptor)
	local allyTeamList = Spring.GetAllyTeamList()
	local allyTeamSizes = {}
	local allyTeamTeams = {}
	local scavengerRaptorTeams = {}
	local totalTeams = 0

	for _, allyID in ipairs(allyTeamList) do
		if allyID ~= gaiaAllyTeamID then
			local teams = Spring.GetTeamList(allyID)
			local aliveTeams = {}
			local hasScavRaptor = false
			for _, teamID in ipairs(teams) do
				if teamID ~= gaiaTeamID then
					local _, _, isDead = Spring.GetTeamInfo(teamID, false)
					if not isDead then
						aliveTeams[#aliveTeams + 1] = teamID
						if isScavengerOrRaptor(teamID) then
							scavengerRaptorTeams[#scavengerRaptorTeams + 1] = teamID
							hasScavRaptor = true
						end
					end
				end
			end
			if #aliveTeams > 0 then
				allyTeamSizes[allyID] = #aliveTeams
				allyTeamTeams[allyID] = aliveTeams
				totalTeams = totalTeams + #aliveTeams
			end
		end
	end

	if totalTeams == 0 then
		return
	end

	-- Count non-Gaia allyteams
	local numAllyTeams = 0
	for _ in pairs(allyTeamSizes) do
		numAllyTeams = numAllyTeams + 1
	end

	-- Find max teams per allyteam to determine imbalance
	local maxTeamsPerAlly = 0
	local minTeamsPerAlly = totalTeams
	for _, size in pairs(allyTeamSizes) do
		if size > maxTeamsPerAlly then
			maxTeamsPerAlly = size
		end
		if size < minTeamsPerAlly then
			minTeamsPerAlly = size
		end
	end

	-- Calculate what equal combined maxunits per allyteam would be
	local equalAllyShare = totalMaxUnits / numAllyTeams

	-- Redistribute: smaller allyteams get more per team to approach equal combined totals
	-- First pass: calculate all adjustments
	-- For Scavenger/Raptor teams, we need to first calculate their boosted share, then redistribute the rest
	local scavRaptorAllocation = 0
	local scavRaptorTargets = {}
	
	-- Calculate what Scav/Raptor teams need with equalization
	for allyID, teams in pairs(allyTeamTeams) do
		local allySize = allyTeamSizes[allyID]
		local proportionalPerTeam = totalMaxUnits / totalTeams
		local equalizedPerTeam = (totalMaxUnits / numAllyTeams) / allySize
		local adjustedShare = mathFloor(proportionalPerTeam + (equalizedPerTeam - proportionalPerTeam) * equalizationFactor)
		
		for _, teamID in ipairs(teams) do
			if isScavengerOrRaptor(teamID) then
				local targetShare = mathMax(adjustedShare, scavengerRaptorLimit)
				scavRaptorTargets[teamID] = targetShare
				scavRaptorAllocation = scavRaptorAllocation + targetShare
			end
		end
	end
	
	-- Now calculate for regular teams with the remaining units
	local remainingMaxUnits = totalMaxUnits - scavRaptorAllocation
	local regularTeamCount = totalTeams - #scavengerRaptorTeams
	
	local adjustments = {}
	for allyID, teams in pairs(allyTeamTeams) do
		for _, teamID in ipairs(teams) do
			local currentMaxUnits = Spring.GetTeamMaxUnits(teamID)
			local targetShare
			
			if isScavengerOrRaptor(teamID) then
				targetShare = scavRaptorTargets[teamID]
			else
				-- Regular teams split the remaining units
				if regularTeamCount > 0 then
					targetShare = mathFloor(remainingMaxUnits / regularTeamCount)
					targetShare = mathMin(targetShare, maxunits)
				else
					targetShare = maxunits
				end
			end
			
			adjustments[teamID] = {
				current = currentMaxUnits,
				target = targetShare
			}
		end
	end

	-- Second pass: perform transfers
	-- Teams that need more will take from teams that have excess
	local donors = {}
	local recipients = {}
	local scavRaptorRecipients = {}
	local totalDonorPool = 0
	local totalRecipientNeed = 0
	local totalScavRaptorNeed = 0

	for teamID, adj in pairs(adjustments) do
		if adj.target > adj.current then
			local need = adj.target - adj.current
			if isScavengerOrRaptor(teamID) then
				scavRaptorRecipients[#scavRaptorRecipients + 1] = { teamID = teamID, need = need }
				totalScavRaptorNeed = totalScavRaptorNeed + need
			else
				recipients[#recipients + 1] = { teamID = teamID, need = need }
				totalRecipientNeed = totalRecipientNeed + need
			end
		elseif adj.target < adj.current then
			local excess = adj.current - adj.target
			donors[#donors + 1] = { teamID = teamID, excess = excess }
			totalDonorPool = totalDonorPool + excess
		end
	end

	-- First priority: Distribute to Scavenger/Raptor teams (they get priority)
	for _, scavRaptorRecipient in ipairs(scavRaptorRecipients) do
		local remaining = scavRaptorRecipient.need
		
		-- First try to get from donors (teams with excess)
		for _, donor in ipairs(donors) do
			if remaining > 0 and donor.excess > 0 then
				local transferAmount = mathMin(remaining, donor.excess)
				Spring.TransferTeamMaxUnits(donor.teamID, scavRaptorRecipient.teamID, transferAmount)
				donor.excess = donor.excess - transferAmount
				remaining = remaining - transferAmount
			end
		end
		
		-- If still need more, force regular teams to donate (Scav/Raptor has priority)
		if remaining > 0 then
			-- First try from regular recipients
			for _, recipient in ipairs(recipients) do
				if remaining <= 0 then
					break
				end
				-- Force regular teams to give up units for Scav/Raptor
				local currentMax = Spring.GetTeamMaxUnits(recipient.teamID)
				if currentMax > 0 then
					local canGive = mathMin(remaining, currentMax)
					Spring.TransferTeamMaxUnits(recipient.teamID, scavRaptorRecipient.teamID, canGive)
					remaining = remaining - canGive
					-- Update the recipient's need since they now have less
					recipient.need = recipient.need + canGive
				end
			end
			
			-- If still need more, take from donors too
			if remaining > 0 then
				for _, donor in ipairs(donors) do
					if remaining <= 0 then
						break
					end
					local currentMax = Spring.GetTeamMaxUnits(donor.teamID)
					if currentMax > 0 then
						local canGive = mathMin(remaining, currentMax)
						Spring.TransferTeamMaxUnits(donor.teamID, scavRaptorRecipient.teamID, canGive)
						remaining = remaining - canGive
					end
				end
			end
		end
		
		scavRaptorRecipient.need = remaining
	end

	-- Recalculate donor pool after Scav/Raptor distribution
	totalDonorPool = 0
	for _, donor in ipairs(donors) do
		totalDonorPool = totalDonorPool + donor.excess
	end

	-- Calculate fair share per recipient based on available donor pool (after scav/raptor got theirs)
	local availablePerRecipient = 0
	if #recipients > 0 then
		availablePerRecipient = mathFloor(totalDonorPool / #recipients)
	end

	-- Transfer from donors to recipients, distributing fairly
	for _, recipient in ipairs(recipients) do
		local targetTransfer = mathMin(recipient.need, availablePerRecipient)
		local remaining = targetTransfer

		for _, donor in ipairs(donors) do
			if remaining > 0 and donor.excess > 0 then
				local transferAmount = mathMin(remaining, donor.excess)
				Spring.TransferTeamMaxUnits(donor.teamID, recipient.teamID, transferAmount)
				donor.excess = donor.excess - transferAmount
				remaining = remaining - transferAmount
			end
		end

		-- Update recipient need after receiving their fair share
		recipient.need = recipient.need - (targetTransfer - remaining)
	end

	-- Distribute any leftover units from donors to recipients who still need more
	for _, donor in ipairs(donors) do
		if donor.excess > 0 then
			for _, recipient in ipairs(recipients) do
				if donor.excess <= 0 then
					break
				end
				if recipient.need > 0 then
					local transferAmount = mathMin(donor.excess, recipient.need)
					Spring.TransferTeamMaxUnits(donor.teamID, recipient.teamID, transferAmount)
					donor.excess = donor.excess - transferAmount
					recipient.need = recipient.need - transferAmount
				end
			end
		end
	end

	-- Set Gaia to exactly their defined limit
	local gaiaCurrentMax = Spring.GetTeamMaxUnits(gaiaTeamID)
	if gaiaCurrentMax ~= gaiaLimit then
		if gaiaCurrentMax > gaiaLimit then
			-- Transfer excess from Gaia fairly to all alive regular (non-scav/raptor) teams
			local gaiaExcess = gaiaCurrentMax - gaiaLimit
			local regularTeams = {}
			for _, teams in pairs(allyTeamTeams) do
				for _, teamID in ipairs(teams) do
					if not isScavengerOrRaptor(teamID) then
						regularTeams[#regularTeams + 1] = teamID
					end
				end
			end
			
			if #regularTeams > 0 then
				local perTeam = mathFloor(gaiaExcess / #regularTeams)
				local remaining = gaiaExcess
				
				-- Give each team their fair share
				for _, teamID in ipairs(regularTeams) do
					if remaining > 0 then
						local transferAmount = mathMin(perTeam, remaining)
						Spring.TransferTeamMaxUnits(gaiaTeamID, teamID, transferAmount)
						remaining = remaining - transferAmount
					end
				end
				
				-- Distribute any leftover from rounding
				if remaining > 0 then
					for _, teamID in ipairs(regularTeams) do
						if remaining <= 0 then
							break
						end
						Spring.TransferTeamMaxUnits(gaiaTeamID, teamID, 1)
						remaining = remaining - 1
					end
				end
			end
		else
			-- Transfer to Gaia from alive teams with excess
			local needed = gaiaLimit - gaiaCurrentMax
			for _, teams in pairs(allyTeamTeams) do
				for _, teamID in ipairs(teams) do
					if not isScavengerOrRaptor(teamID) then
						local teamMax = Spring.GetTeamMaxUnits(teamID)
						if teamMax > maxunits then
							local canGive = mathMin(needed, teamMax - maxunits)
							if canGive > 0 then
								Spring.TransferTeamMaxUnits(teamID, gaiaTeamID, canGive)
								needed = needed - canGive
								if needed <= 0 then
									break
								end
							end
						end
					end
				end
				if needed <= 0 then
					break
				end
			end
		end
	end
end

function gadget:TeamDied(teamID)
	local gaiaTeamID = Spring.GetGaiaTeamID()

	-- Don't redistribute if Gaia dies
	if teamID == gaiaTeamID then
		return
	end

	local redistributionAmount = Spring.GetTeamMaxUnits(teamID)

	-- redistribute to teammates (respecting per-team maxunits limit)
	local allyID = select(6, Spring.GetTeamInfo(teamID, false))
	local teams = Spring.GetTeamList(allyID)
	local aliveTeams = 0
	for i = 1, #teams do
		if teams[i] ~= teamID and teams[i] ~= gaiaTeamID and not isScavengerOrRaptor(teams[i]) and not select(2, Spring.GetTeamInfo(teams[i], false)) then	-- not dead, not gaia, not scav/raptor
			aliveTeams = aliveTeams + 1
		end
	end

	if aliveTeams > 0 then
		for i = 1, #teams do
			if teams[i] ~= teamID and teams[i] ~= gaiaTeamID and not isScavengerOrRaptor(teams[i]) and not select(2, Spring.GetTeamInfo(teams[i], false)) then	-- not dead, not gaia, not scav/raptor
				local targetTeamID = teams[i]
				local currentMaxUnits = Spring.GetTeamMaxUnits(targetTeamID)
				local portionSize = mathFloor(redistributionAmount / aliveTeams)

				-- Respect the per-team maxunits limit
				local transferAmount = mathMin(portionSize, maxunits - currentMaxUnits)
				if transferAmount > 0 then
					Spring.TransferTeamMaxUnits(teamID, targetTeamID, transferAmount)
				end
			end
		end
	end

	-- redistribute to enemies if no teammates alive (respecting per-team maxunits limit)
	if aliveTeams == 0 then
		teams = Spring.GetTeamList()
		aliveTeams = 0
		for i = 1, #teams do
			if teams[i] ~= teamID and teams[i] ~= gaiaTeamID and not isScavengerOrRaptor(teams[i]) and not select(2, Spring.GetTeamInfo(teams[i], false)) then	-- not dead, not gaia, not scav/raptor
				aliveTeams = aliveTeams + 1
			end
		end

		if aliveTeams > 0 then
			for i = 1, #teams do
				if teams[i] ~= teamID and teams[i] ~= gaiaTeamID and not isScavengerOrRaptor(teams[i]) and not select(2, Spring.GetTeamInfo(teams[i], false)) then	-- not dead, not gaia, not scav/raptor
					local targetTeamID = teams[i]
					local currentMaxUnits = Spring.GetTeamMaxUnits(targetTeamID)
					local portionSize = mathFloor(redistributionAmount / aliveTeams)

					-- Respect the per-team maxunits limit
					local transferAmount = mathMin(portionSize, maxunits - currentMaxUnits)
					if transferAmount > 0 then
						Spring.TransferTeamMaxUnits(teamID, targetTeamID, transferAmount)
					end
				end
			end
		end
	end
end
