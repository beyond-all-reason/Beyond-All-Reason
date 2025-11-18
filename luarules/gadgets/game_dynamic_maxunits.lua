
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
	The total engine limit is 32000, we will reserve 500 for Gaia.

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
	- Scavenger/Raptor teams always receive exactly scavengerRaptorLimit (3500)
	- Regular teams receive equalized distribution from remaining maxunits, capped at maxunits from modoptions
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
local engineLimit = 32000
local gaiaLimit = 500
local scavengerRaptorLimit = 3500  -- Minimum maxunits for Scavenger/Raptor teams
local equalizationFactor = 0.25  -- How much to equalize (0 = no equalization, 1 = full equalization). 0.25 means go 25% of the way toward equal allyteam totals

local mathFloor = math.floor
local mathMin = math.min

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
	local totalRegularTeams = 0

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
						else
							totalRegularTeams = totalRegularTeams + 1
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

	-- Redistribute: Scav/Raptor teams get fixed scavengerRaptorLimit, regular teams get equalized distribution

	-- First, allocate scavengerRaptorLimit to each Scav/Raptor team
	local scavRaptorAllocation = #scavengerRaptorTeams * scavengerRaptorLimit

	-- Calculate remaining units for regular teams
	local remainingMaxUnits = totalMaxUnits - scavRaptorAllocation

	-- Build map of regular teams by allyteam for equalization (exclude allyteams with only scav/raptor)
	local regularAllyTeamSizes = {}
	local regularAllyTeamTeams = {}
	local numRegularAllyTeams = 0

	for allyID, teams in pairs(allyTeamTeams) do
		local regularTeams = {}
		for _, teamID in ipairs(teams) do
			if not isScavengerOrRaptor(teamID) then
				regularTeams[#regularTeams + 1] = teamID
			end
		end
		if #regularTeams > 0 then
			regularAllyTeamSizes[allyID] = #regularTeams
			regularAllyTeamTeams[allyID] = regularTeams
			numRegularAllyTeams = numRegularAllyTeams + 1
		end
	end

	-- Calculate adjustments for all teams
	local adjustments = {}

	-- Set targets for Scav/Raptor teams (fixed allocation)
	for _, teamID in ipairs(scavengerRaptorTeams) do
		local currentMaxUnits = Spring.GetTeamMaxUnits(teamID)
		adjustments[teamID] = {
			current = currentMaxUnits,
			target = scavengerRaptorLimit,
			isScavRaptor = true
		}
	end

	-- Calculate equalized distribution for regular teams only
	if totalRegularTeams > 0 and numRegularAllyTeams > 0 then
		for allyID, teams in pairs(regularAllyTeamTeams) do
			local allySize = regularAllyTeamSizes[allyID]
			-- Base proportional share per team
			local proportionalPerTeam = remainingMaxUnits / totalRegularTeams
			-- Equalized share: equal total per allyteam, divided by team count
			local equalizedPerTeam = (remainingMaxUnits / numRegularAllyTeams) / allySize
			-- Blend between proportional and equalized
			local adjustedShare = mathFloor(proportionalPerTeam + (equalizedPerTeam - proportionalPerTeam) * equalizationFactor)
			-- Cap at modoption maxunits limit
			adjustedShare = mathMin(adjustedShare, maxunits)

			for _, teamID in ipairs(teams) do
				local currentMaxUnits = Spring.GetTeamMaxUnits(teamID)
				adjustments[teamID] = {
					current = currentMaxUnits,
					target = adjustedShare,
					isScavRaptor = false
				}
			end
		end
	end

	-- Perform transfers: Strategy is to collect ALL maxunits into a pool, then redistribute
	-- This ensures we have a clean slate and can properly allocate according to our targets

	-- Step 1: Collect all maxunits from ALL teams (including Gaia) into a central pool
	-- We'll use a dummy team to hold everything temporarily, then redistribute
	-- Build a sorted list of team IDs to ensure consistent ordering
	local sortedTeamIDs = {}
	for teamID, _ in pairs(adjustments) do
		sortedTeamIDs[#sortedTeamIDs + 1] = teamID
	end
	table.sort(sortedTeamIDs)

	-- First collect from Gaia to get the full pool
	local gaiaInitial = Spring.GetTeamMaxUnits(gaiaTeamID)
	local totalAvailable = gaiaInitial

	-- Then collect from all player teams
	local totalCollected = 0
	for _, teamID in ipairs(sortedTeamIDs) do
		local currentMaxUnits = Spring.GetTeamMaxUnits(teamID)
		if currentMaxUnits > 0 then
			Spring.TransferTeamMaxUnits(teamID, gaiaTeamID, currentMaxUnits)
			totalCollected = totalCollected + currentMaxUnits
		end
	end
	totalAvailable = totalAvailable + totalCollected

	-- Step 2: Distribute from Gaia according to targets (distribute to ALL teams in adjustments)
	for _, teamID in ipairs(sortedTeamIDs) do
		local adj = adjustments[teamID]
		if adj.target > 0 then
			Spring.TransferTeamMaxUnits(gaiaTeamID, teamID, adj.target)
		end
	end

	-- Set Gaia to exactly their defined limit from the total pool
	local gaiaCurrentMax = Spring.GetTeamMaxUnits(gaiaTeamID)
	local gaiaExpected = gaiaLimit

	if gaiaCurrentMax < gaiaExpected then
		-- Gaia needs more, take from regular teams proportionally
		local gaiaNeeds = gaiaExpected - gaiaCurrentMax
		local regularTeams = {}
		for _, teams in pairs(allyTeamTeams) do
			for _, teamID in ipairs(teams) do
				if not isScavengerOrRaptor(teamID) then
					regularTeams[#regularTeams + 1] = teamID
				end
			end
		end
		table.sort(regularTeams)

		if #regularTeams > 0 then
			local perTeam = mathFloor(gaiaNeeds / #regularTeams)
			local remaining = gaiaNeeds

			for _, teamID in ipairs(regularTeams) do
				if remaining > 0 then
					local takeAmount = mathMin(perTeam, remaining, Spring.GetTeamMaxUnits(teamID))
					if takeAmount > 0 then
						Spring.TransferTeamMaxUnits(teamID, gaiaTeamID, takeAmount)
						remaining = remaining - takeAmount
					end
				end
			end

			-- Take any remaining one by one
			if remaining > 0 then
				for _, teamID in ipairs(regularTeams) do
					if remaining <= 0 then
						break
					end
					local currentMax = Spring.GetTeamMaxUnits(teamID)
					if currentMax > 0 then
						Spring.TransferTeamMaxUnits(teamID, gaiaTeamID, 1)
						remaining = remaining - 1
					end
				end
			end
		end
	elseif gaiaCurrentMax > gaiaExpected then
			-- Transfer excess from Gaia fairly to all alive regular (non-scav/raptor) teams
			local gaiaExcess = gaiaCurrentMax - gaiaExpected
			local regularTeams = {}
			for _, teams in pairs(allyTeamTeams) do
				for _, teamID in ipairs(teams) do
					if not isScavengerOrRaptor(teamID) then
						regularTeams[#regularTeams + 1] = teamID
					end
				end
			end
			-- Sort to ensure consistent ordering
			table.sort(regularTeams)

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
