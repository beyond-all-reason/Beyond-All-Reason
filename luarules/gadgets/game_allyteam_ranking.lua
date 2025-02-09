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

local unitCost = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	unitCost[unitDefID] = math.floor(unitDef.metalCost + (unitDef.energyCost / 65))
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if unitTeam ~= GaiaTeamID then
		local allyTeamID = teamAllyteam[unitTeam]
		if spGetUnitIsBeingBuilt(unitID) then
			unfinishedUnits[allyTeamID][unitID] = unitDefID
		else
			allyteamCost[allyTeamID] = allyteamCost[allyTeamID] + unitCost[unitDefID]
		end
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if unitTeam ~= GaiaTeamID then
		local allyTeamID = teamAllyteam[unitTeam]
		if unfinishedUnits[allyTeamID][unitID] then
			allyteamCost[allyTeamID] = allyteamCost[allyTeamID] + unitCost[unitDefID]
			unfinishedUnits[allyTeamID][unitID] = nil
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	if unitTeam ~= GaiaTeamID then
		local allyTeamID = teamAllyteam[unitTeam]
		allyteamCost[allyTeamID] = allyteamCost[allyTeamID] - unitCost[unitDefID]
		unfinishedUnits[allyTeamID][unitID] = nil
	end
end

function gadget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
	if unitTeam ~= GaiaTeamID then
		local allyTeamID = teamAllyteam[unitTeam]
		allyteamCost[allyTeamID] = allyteamCost[allyTeamID] + unitCost[unitDefID]
		if spGetUnitIsBeingBuilt(unitID) then
			unfinishedUnits[allyTeamID][unitID] = allyTeamID
		end
	end
end

function gadget:UnitTaken(unitID, unitDefID, unitTeam, oldTeam)
	if unitTeam ~= GaiaTeamID then
		local allyTeamID = teamAllyteam[unitTeam]
		allyteamCost[allyTeamID] = allyteamCost[allyTeamID] - unitCost[unitDefID]
		unfinishedUnits[allyTeamID][unitID] = nil
	end
end

function gadget:Initialize()
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID), Spring.GetUnitTeam(unitID))
	end
end

function gadget:GameFrame(gf)
	if gf % 150 == 1 then
		if Script.LuaUI("rankingEvent") then
			local temp = {}
			for allyTeamID, totalCost in pairs(allyteamCost) do
				-- get current resources in storage
				local totalResCost = 0
				local teamList = spGetTeamList(allyTeamID)
				for _, teamID in ipairs(teamList) do
					local availableMetal = spGetTeamResources(teamID, "metal")
					local availableEnergy = spGetTeamResources(teamID, "energy")
					totalResCost = math.floor(totalResCost + availableMetal + (availableEnergy / 65))
				end
				-- get unfinished units worth
				local totalConstructionCost = 0
				for unitID, unitDefID in pairs(unfinishedUnits[allyTeamID]) do
					local beingBuilt, buildProgress = spGetUnitIsBeingBuilt(unitID)
					if not beingBuilt then
						unfinishedUnits[allyTeamID][unitID] = nil
					elseif unitCost[unitDefID] then
						totalConstructionCost = totalConstructionCost + math.floor(unitCost[unitDefID] * buildProgress)
					end
				end
				temp[#temp+1] = { allyTeamID = allyTeamID, totalCost = totalCost + totalResCost + totalConstructionCost }
			end
			table.sort(temp, function(m1, m2)
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
				Script.LuaUI.rankingEvent(ranking)
			end
		end
	end
end

