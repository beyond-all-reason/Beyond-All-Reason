local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name	= "AllyTeam ranking",
		desc	= "broadcast the allyteam ranking order by total unit value, can be used to order playerlist",
		author	= "Floris",
		date	= "February 2025",
		license   = "GNU GPL, v2 or later",
		layer	= 0,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then
	return
end

if not Spring.Utilities.Gametype.IsFFA() or Spring.Utilities.Gametype.IsSinglePlayer() then
	return
end

local prevRanking = {}
local allyteamCost = {}
local unfinishedUnits = {}
local teamAllyteam = {}
local teamList = Spring.GetTeamList()
local GaiaTeamID = Spring.GetGaiaTeamID()
for i = 1, #teamList do
	local teamID = teamList[i]
	if teamID ~= GaiaTeamID then
		local allyTeamID = select(6, Spring.GetTeamInfo(teamID))
		teamAllyteam[teamID] = allyTeamID
		allyteamCost[allyTeamID] = 0
		unfinishedUnits[allyTeamID] = {}
	end
end

local spGetTeamResources = Spring.GetTeamResources
local spGetTeamList = Spring.GetTeamList
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local mathFloor = math.floor
local tableSort = table.sort

local unitCost = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	unitCost[unitDefID] = mathFloor(unitDef.metalCost + (unitDef.energyCost / 65))
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	local allyTeamID = teamAllyteam[unitTeam]
	if not allyTeamID then return end
	if spGetUnitIsBeingBuilt(unitID) then
		unfinishedUnits[allyTeamID][unitID] = unitDefID
	else
		allyteamCost[allyTeamID] = allyteamCost[allyTeamID] + unitCost[unitDefID]
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	local allyTeamID = teamAllyteam[unitTeam]
	if not allyTeamID then return end
	if unfinishedUnits[allyTeamID][unitID] then
		allyteamCost[allyTeamID] = allyteamCost[allyTeamID] + unitCost[unitDefID]
		unfinishedUnits[allyTeamID][unitID] = nil
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	local allyTeamID = teamAllyteam[unitTeam]
	if not allyTeamID then return end
	if unfinishedUnits[allyTeamID][unitID] then
		unfinishedUnits[allyTeamID][unitID] = nil
	else
		allyteamCost[allyTeamID] = allyteamCost[allyTeamID] - unitCost[unitDefID]
	end
end

function gadget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
	local allyTeamID = teamAllyteam[unitTeam]
	local oldAllyTeamID = teamAllyteam[oldTeam]
	if not allyTeamID or not oldAllyTeamID then return end

	if spGetUnitIsBeingBuilt(unitID) then
		unfinishedUnits[oldAllyTeamID][unitID] = nil
		unfinishedUnits[allyTeamID][unitID] = unitDefID
	else
		allyteamCost[oldAllyTeamID] = allyteamCost[oldAllyTeamID] - unitCost[unitDefID]
		allyteamCost[allyTeamID] = allyteamCost[allyTeamID] + unitCost[unitDefID]
	end
end

function gadget:UnitTaken(unitID, unitDefID, unitTeam, oldTeam)
	local allyTeamID = teamAllyteam[unitTeam]
	local oldAllyTeamID = teamAllyteam[oldTeam]
	if not allyTeamID or not oldAllyTeamID then return end

	if spGetUnitIsBeingBuilt(unitID) then
		unfinishedUnits[oldAllyTeamID][unitID] = nil
		unfinishedUnits[allyTeamID][unitID] = unitDefID
	else
		allyteamCost[oldAllyTeamID] = allyteamCost[oldAllyTeamID] + unitCost[unitDefID]
		allyteamCost[allyTeamID] = allyteamCost[allyTeamID] - unitCost[unitDefID]
	end
end

function gadget:Initialize()
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID), Spring.GetUnitTeam(unitID))
	end
end

function gadget:GameFrame(gf)
	if gf % 200 == 1 then
		if Script.LuaUI("RankingEvent") then
			local temp = {}
			for allyTeamID, totalCost in pairs(allyteamCost) do
				-- get current resources in storage
				local totalResCost = 0
				local teamList = spGetTeamList(allyTeamID)
				for i = 1, #teamList do
					local availableMetal = spGetTeamResources(teamList[i], "metal")
					local availableEnergy = spGetTeamResources(teamList[i], "energy")
					totalResCost = mathFloor(totalResCost + availableMetal + (availableEnergy / 65))
				end
				-- get unfinished units worth
				local totalConstructionCost = 0
				for unitID, unitDefID in pairs(unfinishedUnits[allyTeamID]) do
					local completeness = select(2, spGetUnitIsBeingBuilt(unitID))
					if not completeness then	-- this shouldnt occur
						unfinishedUnits[allyTeamID][unitID] = nil
					else
						totalConstructionCost = totalConstructionCost + mathFloor(unitCost[unitDefID] * completeness)
					end
				end
				temp[#temp+1] = { allyTeamID = allyTeamID, totalCost = totalCost + totalResCost + totalConstructionCost }
			end
			tableSort(temp, function(m1, m2)
				return m1.totalCost > m2.totalCost
			end)
			local rankingChanged = false
			local ranking = {}
			for i, params in ipairs(temp) do
				ranking[i] = params.allyTeamID
				if not prevRanking[i] or ranking[i] ~= prevRanking[i] then
					rankingChanged = true
				end
			end
			if rankingChanged then
				prevRanking = ranking
				Script.LuaUI.RankingEvent(ranking)
			end
		end
	end
end

