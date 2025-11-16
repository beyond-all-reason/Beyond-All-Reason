
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
	- equalizationFactor: how much to equalize allyteams (0.0 to 1.0, default 0.25)
	  * 0.0 = pure proportional distribution (each team gets equal share)
	  * 1.0 = full equalization (each allyteam gets equal combined total)
	  * 0.25 = go 25% of the way toward equal allyteam totals (recommended)

	On Initialize:
	- Excludes Gaia from all calculations
	- Calculates target maxunits for each team based on equalization factor
	- Smaller allyteams receive more maxunits per team to compensate for team count imbalance
	- Fairly distributes available donor pool across all recipient teams
	- Respects the per-team maxunits limit from modoptions

	When a Team Dies:
	- First redistributes maxunits to alive teammates
	- If no teammates alive, redistributes to all alive enemy teams
	- Always respects the per-team maxunits limit
	- Gaia never receives or donates maxunits on team death
]]--

local maxunits = tonumber(Spring.GetModOptions().maxunits) or 2000
local engineLimit = 32768
local gaiaLimit = 500
local equalizationFactor = 0.25  -- How much to equalize (0 = no equalization, 1 = full equalization). 0.25 means go 25% of the way toward equal allyteam totals

local mathFloor = math.floor
local mathMin = math.min

function gadget:Initialize()
	if Spring.GetGameFrame() > 0 then
		return
	end

	-- Ensure Gaia team always get their maxunits
	local gaiaTeamID = Spring.GetGaiaTeamID()
	local gaiaAllyTeamID = select(6, Spring.GetTeamInfo(gaiaTeamID, false))
	local totalMaxUnits = engineLimit - gaiaLimit

	-- Get all allyteams and their teams (excluding Gaia)
	local allyTeamList = Spring.GetAllyTeamList()
	local allyTeamSizes = {}
	local allyTeamTeams = {}
	local totalTeams = 0

	for _, allyID in ipairs(allyTeamList) do
		if allyID ~= gaiaAllyTeamID then
			local teams = Spring.GetTeamList(allyID)
			local aliveTeams = {}
			for _, teamID in ipairs(teams) do
				if teamID ~= gaiaTeamID then
					local _, _, isDead = Spring.GetTeamInfo(teamID, false)
					if not isDead then
						aliveTeams[#aliveTeams + 1] = teamID
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
	local adjustments = {}
	for allyID, teams in pairs(allyTeamTeams) do
		local allySize = allyTeamSizes[allyID]

		-- Calculate target: go 25% of the way from proportional share toward equal allyteam share
		-- This gives smaller teams a boost without over-penalizing larger teams
		local proportionalPerTeam = totalMaxUnits / totalTeams  -- what they'd get with equal per-team distribution
		local equalizedPerTeam = (totalMaxUnits / numAllyTeams) / allySize  -- what they'd need for equal allyteam totals

		-- Apply equalization factor
		local adjustedShare = mathFloor(proportionalPerTeam + (equalizedPerTeam - proportionalPerTeam) * equalizationFactor)

		-- Respect per-team limit
		adjustedShare = mathMin(adjustedShare, maxunits)

		for _, teamID in ipairs(teams) do
			local currentMaxUnits = Spring.GetTeamMaxUnits(teamID)
			adjustments[teamID] = {
				current = currentMaxUnits,
				target = adjustedShare
			}
		end
	end

	-- Second pass: perform transfers
	-- Teams that need more will take from teams that have excess
	local donors = {}
	local recipients = {}
	local totalDonorPool = 0
	local totalRecipientNeed = 0

	for teamID, adj in pairs(adjustments) do
		if adj.target > adj.current then
			local need = adj.target - adj.current
			recipients[#recipients + 1] = { teamID = teamID, need = need }
			totalRecipientNeed = totalRecipientNeed + need
		elseif adj.target < adj.current then
			local excess = adj.current - adj.target
			donors[#donors + 1] = { teamID = teamID, excess = excess }
			totalDonorPool = totalDonorPool + excess
		end
	end

	-- Calculate fair share per recipient based on available donor pool
	local availablePerRecipient = mathFloor(totalDonorPool / #recipients)

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
	end

	-- Set Gaia to exactly their defined limit
	local gaiaCurrentMax = Spring.GetTeamMaxUnits(gaiaTeamID)
	if gaiaCurrentMax ~= gaiaLimit then
		if gaiaCurrentMax > gaiaLimit then
			-- Transfer excess from Gaia to first alive team
			for _, teams in pairs(allyTeamTeams) do
				if #teams > 0 then
					Spring.TransferTeamMaxUnits(gaiaTeamID, teams[1], gaiaCurrentMax - gaiaLimit)
					break
				end
			end
		else
			-- Transfer to Gaia from first alive team with excess
			local needed = gaiaLimit - gaiaCurrentMax
			for _, teams in pairs(allyTeamTeams) do
				for _, teamID in ipairs(teams) do
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
		if teams[i] ~= teamID and teams[i] ~= gaiaTeamID and not select(2, Spring.GetTeamInfo(teams[i], false)) then	-- not dead and not gaia
			aliveTeams = aliveTeams + 1
		end
	end

	if aliveTeams > 0 then
		for i = 1, #teams do
			if teams[i] ~= teamID and teams[i] ~= gaiaTeamID and not select(2, Spring.GetTeamInfo(teams[i], false)) then	-- not dead and not gaia
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
			if teams[i] ~= teamID and teams[i] ~= gaiaTeamID and not select(2, Spring.GetTeamInfo(teams[i], false)) then	-- not dead and not gaia
				aliveTeams = aliveTeams + 1
			end
		end

		if aliveTeams > 0 then
			for i = 1, #teams do
				if teams[i] ~= teamID and teams[i] ~= gaiaTeamID and not select(2, Spring.GetTeamInfo(teams[i], false)) then	-- not dead and not gaia
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
