local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Awards",
		desc = "Awards Awards",
		author = "Bluestone",
		date = "2013-07-06",
		license = "GNU GPL, v2 or later",
		layer = -1,
		enabled = true
	}
end

local topPlacementsCount = 3 -- Only report the top N places for each award

if gadgetHandler:IsSyncedCode() then
	local spAreTeamsAllied = Spring.AreTeamsAllied
	local gaiaTeamID = Spring.GetGaiaTeamID()

	local teamInfo = {}
	local coopInfo = {}
	local present = {}

	local isEcon = {
		--land t1
		[UnitDefNames.armsolar.id] = true,
		[UnitDefNames.corsolar.id] = true,
		[UnitDefNames.armadvsol.id] = true,
		[UnitDefNames.coradvsol.id] = true,
		[UnitDefNames.armwin.id] = true,
		[UnitDefNames.corwin.id] = true,
		[UnitDefNames.armmakr.id] = true,
		[UnitDefNames.cormakr.id] = true,
		--sea t1
		[UnitDefNames.armtide.id] = true,
		[UnitDefNames.cortide.id] = true,
		[UnitDefNames.armfmkr.id] = true,
		[UnitDefNames.corfmkr.id] = true,
		--land t2
		[UnitDefNames.armmmkr.id] = true,
		[UnitDefNames.cormmkr.id] = true,
		[UnitDefNames.corfus.id] = true,
		[UnitDefNames.armfus.id] = true,
		[UnitDefNames.armafus.id] = true,
		[UnitDefNames.corafus.id] = true,
		--sea t2
		[UnitDefNames.armuwfus.id] = true,
		[UnitDefNames.coruwfus.id] = true,
		[UnitDefNames.armuwmmm.id] = true,
		[UnitDefNames.coruwmmm.id] = true,
	}
	for udid, ud in pairs(UnitDefs) do
		for id, v in pairs(isEcon) do
			if string.find(ud.name, UnitDefs[id].name) then
				isEcon[udid] = v
			end
		end
	end

	local unitNumWeapons = {}
	local unitCombinedCost = {}
	for unitDefID, unitDef in pairs(UnitDefs) do
		local weapons = unitDef.weapons
		if #weapons > 0 then
			unitNumWeapons[unitDefID] = #weapons
		end
		unitCombinedCost[unitDefID] = unitDef.energyCost + (60 * unitDef.metalCost)
	end

	-----------------------------------
	-- set up book keeping
	-----------------------------------

	function gadget:GameStart()
		-- make table of teams eligible for awards
		local allyTeamIDs = Spring.GetAllyTeamList()
		for i = 1, #allyTeamIDs do
			local teamIDs = Spring.GetTeamList(allyTeamIDs[i])
			for j = 1, #teamIDs do
				local isLuaAI = (Spring.GetTeamLuaAI(teamIDs[j]) ~= nil)
				local isAiTeam = select(4, Spring.GetTeamInfo(teamIDs[j]))
				if not (isLuaAI or isAiTeam or teamIDs[j] == gaiaTeamID) then
					local playerIDs = Spring.GetPlayerList(teamIDs[j])
					local numPlayers = 0
					for _, playerID in pairs(playerIDs) do
						if not select(3, Spring.GetPlayerInfo(playerID, false)) then
							numPlayers = numPlayers + 1
						end
					end
					if numPlayers > 0 then
						present[teamIDs[j]] = true
						teamInfo[teamIDs[j]] = { allDmg = 0, ecoDmg = 0, fightDmg = 0, otherDmg = 0, dmgDealt = 0, ecoUsed = 0, effScore = 0, ecoProd = 0, lastKill = 0, dmgRec = 0, sleepTime = 0, present = true, teamDmg = 0, }
						coopInfo[teamIDs[j]] = { players = numPlayers, }
					else
						present[teamIDs[j]] = false
					end
				else
					present[teamIDs[j]] = false
				end
			end
		end
	end

	-----------------------------------
	-- track kill damages (measure by cost of killed unit)
	-----------------------------------

	function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
		-- add destroyed unitID cost to stats for attackerTeamID
		if not attackerTeamID then
			return
		end
		if attackerTeamID == gaiaTeamID then
			return
		end
		if not present[attackerTeamID] then
			return
		end
		if not unitDefID or not teamID then
			return
		end
		if spAreTeamsAllied(teamID, attackerTeamID) then
			if teamID ~= attackerTeamID then
				--keep track of teamkilling
				teamInfo[attackerTeamID].teamDmg = teamInfo[attackerTeamID].teamDmg + unitCombinedCost[unitDefID]
			end
			return
		end

		--keep track of who didn't kill for longest (sleeptimes)
		local curTime = Spring.GetGameSeconds()
		if curTime - teamInfo[attackerTeamID].lastKill > teamInfo[attackerTeamID].sleepTime then
			teamInfo[attackerTeamID].sleepTime = curTime - teamInfo[attackerTeamID].lastKill
		end
		teamInfo[attackerTeamID].lastKill = curTime

		local cost = unitCombinedCost[unitDefID]

		--keep track of killing
		teamInfo[attackerTeamID].allDmg = teamInfo[attackerTeamID].allDmg + cost
		if unitNumWeapons[unitDefID] then
			teamInfo[attackerTeamID].fightDmg = teamInfo[attackerTeamID].fightDmg + cost
		elseif isEcon[unitDefID] then
			teamInfo[attackerTeamID].ecoDmg = teamInfo[attackerTeamID].ecoDmg + cost
		else
			teamInfo[attackerTeamID].otherDmg = teamInfo[attackerTeamID].otherDmg + cost --currently not using this but recording it for interest
		end
	end

	-----------------------------------
	-- work out who wins the awards
	-----------------------------------

	local function calculateEfficiency(teamID)
		--calculate total damage dealt and unitsDeadCost
		local totalDmg = 1 -- minor hack, avoid div0
		local totalEco = 1
		local nTeams = 0
		for tID, _ in pairs(teamInfo) do
			local cur_max = Spring.GetTeamStatsHistory(tID)
			local stats = Spring.GetTeamStatsHistory(tID, cur_max, cur_max)
			totalDmg = totalDmg + teamInfo[tID].allDmg
			totalEco = totalEco + stats[1].energyUsed + 60 * stats[1].metalUsed -- don't count excessed & reclaimed res
			nTeams = nTeams + 1
		end

		-- calculate efficiency score
		local cur_max = Spring.GetTeamStatsHistory(teamID)
		local stats = Spring.GetTeamStatsHistory(teamID, cur_max, cur_max)
		local teamEco = stats[1].energyProduced + 60 * stats[1].metalProduced -- do count excessed & reclaimed res
		local pEco = teamEco / totalEco -- [0,1]
		local pDmg = teamInfo[teamID].allDmg / totalDmg -- [0,infty), due to m/e excessed, but typically [0,1]
		local effScore = nTeams * (pDmg - pEco)

		return effScore
	end

	function gadget:GameOver(winningAllyTeams)
		--get stuff from engine stats (not all of which is currently used)
		for teamID, _ in pairs(teamInfo) do
			local cur_max = Spring.GetTeamStatsHistory(teamID)
			local stats = Spring.GetTeamStatsHistory(teamID, cur_max, cur_max)
			teamInfo[teamID].ecoUsed = teamInfo[teamID].ecoUsed + stats[1].energyUsed + 60 * stats[1].metalUsed -- might already be non-zero due to accounting in UnitTaken
			teamInfo[teamID].ecoProd = stats[1].energyProduced + 60 * stats[1].metalProduced
			teamInfo[teamID].dmgDealt = stats[1].damageDealt
			teamInfo[teamID].dmgRec = stats[1].damageReceived
		end

		--take account of coop, calculate total damage and nTeams
		local nDmg = 1
		local nTeams = 0
		for teamID, _ in pairs(teamInfo) do
			teamInfo[teamID].allDmg = teamInfo[teamID].allDmg / coopInfo[teamID].players
			teamInfo[teamID].ecoDmg = teamInfo[teamID].ecoDmg / coopInfo[teamID].players
			teamInfo[teamID].fightDmg = teamInfo[teamID].fightDmg / coopInfo[teamID].players
			teamInfo[teamID].otherDmg = teamInfo[teamID].otherDmg / coopInfo[teamID].players
			teamInfo[teamID].dmgRec = teamInfo[teamID].dmgRec / coopInfo[teamID].players

			nDmg = nDmg + teamInfo[teamID].allDmg
			nTeams = nTeams + 1
		end

		-- calculate efficiencies
		for teamID, _ in pairs(teamInfo) do
			local eff = calculateEfficiency(teamID)
			if nDmg > 7500 * nTeams then
				teamInfo[teamID].effScore = eff
			else
				teamInfo[teamID].effScore = -1
			end
		end

		--award awards
		local awards = {
			ecoKill = {},
			fightKill = {},
			efficiency = {},
			eco = {},
			sleep = {},
			damageReceived = {},
			goldenCow = {},
			traitor = {},
		}

		local dummyEntry = { teamID = -1, score = 0 }

		for teamID, _ in pairs(teamInfo) do
			--deal with sleep times
			local curTime = Spring.GetGameSeconds()
			if (curTime - teamInfo[teamID].lastKill > teamInfo[teamID].sleepTime) then
				teamInfo[teamID].sleepTime = curTime - teamInfo[teamID].lastKill
			end

			if teamInfo[teamID].ecoDmg > 0 then
				table.insert(awards.ecoKill, { teamID = teamID, score = teamInfo[teamID].ecoDmg })
			end
			if teamInfo[teamID].fightDmg > 0 then
				table.insert(awards.fightKill, { teamID = teamID, score = teamInfo[teamID].fightDmg })
			end
			if teamInfo[teamID].effScore > 0 then
				table.insert(awards.efficiency, { teamID = teamID, score = teamInfo[teamID].effScore })
			end
			if teamInfo[teamID].ecoProd > 0 then
				table.insert(awards.eco, { teamID = teamID, score = teamInfo[teamID].ecoProd })
			end
			if teamInfo[teamID].dmgRec > 0 then
				table.insert(awards.damageReceived, { teamID = teamID, score = teamInfo[teamID].dmgRec })
			end
			if teamInfo[teamID].teamDmg > 0 then
				table.insert(awards.traitor, { teamID = teamID, score = teamInfo[teamID].teamDmg })
			end
			if (teamInfo[teamID].sleepTime > 12 * 60) then
				table.insert(awards.sleep, { teamID = teamID, score = teamInfo[teamID].sleepTime })
			end
		end

		local awardSortFunction = function (award1, award2)
			return award1.score > award2.score
		end

		for _, entries in pairs(awards) do
			table.sort(entries, awardSortFunction)

			for index = #entries, topPlacementsCount + 1, -1 do
					table.remove(entries, index)
			end

			for index = 1, topPlacementsCount do
				if entries[index] == nil then
					table.insert(entries, index, dummyEntry)
				end
			end
		end

		--is the cow awarded?
		local ecoKillAwardTeam = awards.ecoKill[1].teamID
		local fightKillAwardTeam = awards.fightKill[1].teamID
		local efficiencyAwardTeam = awards.efficiency[1].teamID

		--If one player won all the awards, they also win the Golden Cow award, but this is only meaningful in large games
		if ecoKillAwardTeam ~= -1 and (ecoKillAwardTeam == fightKillAwardTeam) and (ecoKillAwardTeam == efficiencyAwardTeam) and nTeams > 3 then
			if winningAllyTeams then
				table.insert(awards.goldenCow, { teamID = ecoKillAwardTeam, score = 1 })
				table.sort(awards.goldenCow, awardSortFunction)
			end
		end

		_G.awards = awards

		SendToUnsynced("ReceiveAwards")
	end

	-------------------------------------------------------------------------------------
else

	local function ProcessAwards(_)
		local awards = SYNCED.awards

		-- record who won which awards in chat message (for demo parsing by replays.springrts.com)
		-- make all values positive, as unsigned ints are easier to parse
		local ecoKillLine = '\161' .. tostring(1 + awards.ecoKill[1].teamID) .. ':' .. tostring(awards.ecoKill[1].score) .. '\161' .. tostring(1 + awards.ecoKill[2].teamID) .. ':' .. tostring(awards.ecoKill[2].score) .. '\161' .. tostring(1 + awards.ecoKill[3].teamID) .. ':' .. tostring(awards.ecoKill[3].score)
		local fightKillLine = '\162' .. tostring(1 + awards.fightKill[1].teamID) .. ':' .. tostring(awards.fightKill[1].score) .. '\162' .. tostring(1 + awards.fightKill[2].teamID) .. ':' .. tostring(awards.fightKill[2].score) .. '\162' .. tostring(1 + awards.fightKill[3].teamID) .. ':' .. tostring(awards.fightKill[3].score)
		local efficientKillLine = '\163' .. tostring(1 + awards.efficiency[1].teamID) .. ':' .. tostring(awards.efficiency[1].score) .. '\163' .. tostring(1 + awards.efficiency[2].teamID) .. ':' .. tostring(awards.efficiency[2].score) .. '\163' .. tostring(1 + awards.efficiency[3].teamID) .. ':' .. tostring(awards.efficiency[3].score)
		local otherLine = '\164' .. tostring(1 + awards.goldenCow[1].teamID) .. '\165' .. tostring(1 + awards.eco[1].teamID) .. ':' .. tostring(awards.eco[1].score) .. '\166' .. tostring(1 + awards.damageReceived[1].teamID) .. ':' .. tostring(awards.damageReceived[1].score) .. '\167' .. tostring(1 + awards.sleep[1].teamID) .. ':' .. tostring(awards.sleep[1].score)
		local awardsMsg = ecoKillLine .. fightKillLine .. efficientKillLine .. otherLine

		Spring.SendLuaRulesMsg(awardsMsg)

		-- send to awards widget
		if Script.LuaUI("GadgetReceiveAwards") then
			Script.LuaUI.GadgetReceiveAwards(awards)
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("ReceiveAwards", ProcessAwards)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("ReceiveAwards")
	end

end
