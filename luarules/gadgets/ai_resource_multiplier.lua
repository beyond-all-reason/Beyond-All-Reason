function gadget:GetInfo()
	return {
		name = "AI Resource Multiplier",	-- reclaim excluded + given units excluded + filters units with insignificant production + emp'd units still included
		desc = "",
		author = "Floris",
		date = "September 2018",
		license = "GPL",
		layer = 1,
		enabled = true
	}
end

local timedResBonusMultiplier = 0.00020 
local timedResBonusMultiplierMax = 2


if (not gadgetHandler:IsSyncedCode()) then
	return -- No Unsynced
end

local aiResourceMultiplier = tonumber(Spring.GetModOptions().ai_incomemultiplier) or 1

if timedResBonusMultiplier == 0 and aiResourceMultiplier == 1 then
	return
end

local aiTeams = {}
local aiCount = 0
for _,teamID in ipairs(Spring.GetTeamList()) do
	if select(4,Spring.GetTeamInfo(teamID,false)) then	-- is AI?
		aiCount = aiCount + 1
		aiTeams[teamID] = { energy = 0, metal = 0, winds = 0, mexes = {} }
		--aiCountEResMultiplier = aiCount*0.2 + 0.8
		--aiCountMResMultiplier = aiCount*0.1 + 0.9
	end
end
if aiCount == 0 then
	return
end

local ecoUnitsDefs = {}
local energyUnitDefs = {}
local windUnitDefs = {}
local metalUnitDefs = {}
local mexUnitDefs = {}
local aiGiftedUnits = {}
local newMexes = {}

local spGetUnitResources = Spring.GetUnitResources

function gadget:UnitGiven(uID, uDefID, uTeam)
	if aiTeams[uTeam] and ecoUnitsDefs[uDefID] then
		aiGiftedUnits[uID] = true
	end
end

function gadget:UnitFinished(uID, uDefID, uTeam, builderID)
	if aiTeams[uTeam] and ecoUnitsDefs[uDefID] and not aiGiftedUnits[uID] then
		if windUnitDefs[uDefID] then
			aiTeams[uTeam].winds = aiTeams[uTeam].winds + 1
		end
		if mexUnitDefs[uDefID] then
			newMexes[uID] = {Spring.GetGameFrame() + 30, uTeam} 	-- unfortunately mex produces nothing yet so we have to scedule it
		end
		if energyUnitDefs[uDefID] then
			aiTeams[uTeam].energy = aiTeams[uTeam].energy + energyUnitDefs[uDefID]
		end
		if metalUnitDefs[uDefID] then
			aiTeams[uTeam].metal = aiTeams[uTeam].metal + metalUnitDefs[uDefID]
		end
	end
end

function gadget:UnitDestroyed(uID, uDefID, uTeam)
	if aiTeams[uTeam] and ecoUnitsDefs[uDefID] then
		if aiGiftedUnits[uID] then
			aiGiftedUnits[uID] = nil
		else
			if newMexes[uID] then
				newMexes[uID] = nil
			end
			if windUnitDefs[uDefID] then
				aiTeams[uTeam].winds = aiTeams[uTeam].winds - 1
			end
			if mexUnitDefs[uDefID] and aiTeams[uTeam].mexes[uID] then
				aiTeams[uTeam].metal = aiTeams[uTeam].metal - aiTeams[uTeam].mexes[uID]
				aiTeams[uTeam].mexes[uID] = nil
			end
			if energyUnitDefs[uDefID] then
				aiTeams[uTeam].energy = aiTeams[uTeam].energy - energyUnitDefs[uDefID]
			end
			if metalUnitDefs[uDefID] then
				aiTeams[uTeam].metal = aiTeams[uTeam].metal - metalUnitDefs[uDefID]
			end
		end
	end
end

function gadget:Initialize()
	for uDefID,def in ipairs(UnitDefs) do
		if def.energyMake >= 10 then	-- filter insignificant production to save some performance
			energyUnitDefs[uDefID] = def.energyMake
			ecoUnitsDefs[uDefID] = true
		end
		if def.energyUpkeep < 0 then
			energyUnitDefs[uDefID] = -def.energyUpkeep
			ecoUnitsDefs[uDefID] = true
		end
		if def.windGenerator > 0 then
			windUnitDefs[uDefID] = true
			ecoUnitsDefs[uDefID] = true
		end
		if def.metalMake >= 0.1 then	-- filter insignificant production to save some performance
			metalUnitDefs[uDefID] = def.metalMake
			ecoUnitsDefs[uDefID] = true
		end
		if def.extractsMetal > 0 then
			mexUnitDefs[uDefID] = def.extractsMetal
			ecoUnitsDefs[uDefID] = true
		end
		if ecoUnitsDefs[uDefID] then
			for teamID,_ in pairs(aiTeams) do
				aiTeams[teamID][uDefID] = 0
			end
		end
	end
	if Spring.GetGameFrame() > 0 then	-- in case of a luarules reload
		for teamID,_ in pairs(aiTeams) do
			local teamUnits = Spring.GetTeamUnitsSorted(teamID)
			for uDefID, units in pairs(teamUnits) do
				if type(units) == 'table' then
					for _, unitID in pairs(units) do
						if select(5,Spring.GetUnitHealth(unitID)) >= 1 then
							gadget:UnitFinished(unitID, uDefID, teamID)
						end
					end
				end
			end
		end
	end
end


function gadget:GameFrame(n)

	if n % 30 == 1 then

		-- a just finished mex doesnt produce metal yet so we sceduled it
		for uID,params in pairs(newMexes) do
			if n > params[1] then
				aiTeams[params[2]].mexes[uID] = select(1,spGetUnitResources(uID))
				aiTeams[params[2]].metal = aiTeams[params[2]].metal + aiTeams[params[2]].mexes[uID]
				newMexes[uID] = nil
			end
		end

		local timedResBonus = (n / 30) * timedResBonusMultiplier
		if timedResBonus > timedResBonusMultiplierMax then
			timedResBonus = timedResBonusMultiplierMax
		end

		local currentWind = string.format('%.1f', select(4,Spring.GetWind()))
		for TeamID, aiRes in pairs(aiTeams) do
			local totalEnergy = aiRes.energy + (aiRes.winds * currentWind)
			local totalMetal = aiRes.metal

			--Spring.Echo(totalEnergy..'   +   '..((totalEnergy * (aiResourceMultiplier + timedResBonus)) - totalEnergy))
			--Spring.Echo(totalMetal..'   +   '..((totalMetal * (aiResourceMultiplier + timedResBonus)) - totalMetal))
			Spring.AddTeamResource(TeamID,"e", (totalEnergy * (aiResourceMultiplier + timedResBonus)) - totalEnergy)
			Spring.AddTeamResource(TeamID,"m", (totalMetal * (aiResourceMultiplier + timedResBonus)) - totalMetal)
		end
	end
end
