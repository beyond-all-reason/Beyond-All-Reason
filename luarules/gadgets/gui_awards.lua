function gadget:GetInfo()
	return {
		name = "Awards",
		desc = "Awards Awards",
		author = "Bluestone",
		date = "2013-07-06",
		license = "GPLv2",
		layer = -1,
		enabled = true -- loaded by default?
	}
end

--local localtestDebug = false        -- when true: ends game after 30 secs

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

	-- for debugging/testing
	--[[
	local effSampleRate = 15
	function gadget:GameFrame(n)
		if n%(30*effSampleRate)~=0 or n==0 then return end

		if localtestDebug and n==900 then
			Spring.GameOver({1,0})
		end
	end
	]]

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
		local ecoKillAward, ecoKillAwardSec, ecoKillAwardThi, ecoKillScore, ecoKillScoreSec, ecoKillScoreThi = -1, -1, -1, 0, 0, 0
		local fightKillAward, fightKillAwardSec, fightKillAwardThi, fightKillScore, fightKillScoreSec, fightKillScoreThi = -1, -1, -1, 0, 0, 0
		local effKillAward, effKillAwardSec, effKillAwardThi, effKillScore, effKillScoreSec, effKillScoreThi = -1, -1, -1, 0, 0, 0
		local ecoAward, ecoScore = -1, 0
		local dmgRecAward, dmgRecScore = -1, 0
		local sleepAward, sleepScore = -1, 0
		local traitorAward, traitorAwardSec, traitorAwardThi, traitorScore, traitorScoreSec, traitorScoreThi = -1, -1, -1, 0, 0, 0

		for teamID, _ in pairs(teamInfo) do
			--deal with sleep times
			local curTime = Spring.GetGameSeconds()
			if (curTime - teamInfo[teamID].lastKill > teamInfo[teamID].sleepTime) then
				teamInfo[teamID].sleepTime = curTime - teamInfo[teamID].lastKill
			end
			--eco killing award
			if ecoKillScore < teamInfo[teamID].ecoDmg then
				ecoKillScoreThi = ecoKillScoreSec
				ecoKillAwardThi = ecoKillAwardSec
				ecoKillScoreSec = ecoKillScore
				ecoKillAwardSec = ecoKillAward
				ecoKillScore = teamInfo[teamID].ecoDmg
				ecoKillAward = teamID
			elseif ecoKillScoreSec < teamInfo[teamID].ecoDmg then
				ecoKillScoreThi = ecoKillScoreSec
				ecoKillAwardThi = ecoKillAwardSec
				ecoKillScoreSec = teamInfo[teamID].ecoDmg
				ecoKillAwardSec = teamID
			elseif ecoKillScoreThi < teamInfo[teamID].ecoDmg then
				ecoKillScoreThi = teamInfo[teamID].ecoDmg
				ecoKillAwardThi = teamID
			end
			--fight killing award
			if fightKillScore < teamInfo[teamID].fightDmg then
				fightKillScoreThi = fightKillScoreSec
				fightKillAwardThi = fightKillAwardSec
				fightKillScoreSec = fightKillScore
				fightKillAwardSec = fightKillAward
				fightKillScore = teamInfo[teamID].fightDmg
				fightKillAward = teamID
			elseif fightKillScoreSec < teamInfo[teamID].fightDmg then
				fightKillScoreThi = fightKillScoreSec
				fightKillAwardThi = fightKillAwardSec
				fightKillScoreSec = teamInfo[teamID].fightDmg
				fightKillAwardSec = teamID
			elseif fightKillScoreThi < teamInfo[teamID].fightDmg then
				fightKillScoreThi = teamInfo[teamID].fightDmg
				fightKillAwardThi = teamID
			end
			--efficiency ratio award
			if effKillScore < teamInfo[teamID].effScore then
				effKillScoreThi = effKillScoreSec
				effKillAwardThi = effKillAwardSec
				effKillScoreSec = effKillScore
				effKillAwardSec = effKillAward
				effKillScore = teamInfo[teamID].effScore
				effKillAward = teamID
			elseif effKillScoreSec < teamInfo[teamID].effScore then
				effKillScoreThi = effKillScoreSec
				effKillAwardThi = effKillAwardSec
				effKillScoreSec = teamInfo[teamID].effScore
				effKillAwardSec = teamID
			elseif effKillScoreThi < teamInfo[teamID].effScore then
				effKillScoreThi = teamInfo[teamID].effScore
				effKillAwardThi = teamID
			end

			--eco prod award
			if ecoScore < teamInfo[teamID].ecoProd then
				ecoScore = teamInfo[teamID].ecoProd
				ecoAward = teamID
			end
			--most damage rec award
			if dmgRecScore < teamInfo[teamID].dmgRec then
				dmgRecScore = teamInfo[teamID].dmgRec
				dmgRecAward = teamID
			end
			--longest sleeper award
			if sleepScore < teamInfo[teamID].sleepTime and teamInfo[teamID].sleepTime > 12 * 60 then
				sleepScore = teamInfo[teamID].sleepTime
				sleepAward = teamID
			end
			--traitor award
			if traitorScore < teamInfo[teamID].teamDmg then
				traitorScoreThi = traitorScoreSec
				traitorAwardThi = traitorAwardSec
				traitorScoreSec = traitorScore
				traitorAwardSec = traitorAward
				traitorScore = teamInfo[teamID].teamDmg
				traitorAward = teamID
			elseif traitorScoreSec < teamInfo[teamID].teamDmg then
				traitorScoreThi = traitorScoreSec
				traitorAwardThi = traitorAwardSec
				traitorScoreSec = teamInfo[teamID].teamDmg
				traitorAwardSec = teamID
			elseif traitorScoreThi < teamInfo[teamID].teamDmg then
				traitorScoreThi = teamInfo[teamID].teamDmg
				traitorAwardThi = teamID
			end
		end

		--is the cow awarded?
		local cowAward = -1
		if ecoKillAward ~= -1 and (ecoKillAward == fightKillAward) and (fightKillAward == effKillAward) and ecoKillAward ~= -1 and nTeams > 3 then
			--check if some team got all the awards + if more than 3 teams in the game
			if winningAllyTeams and winningAllyTeams[1] then
				local _, _, _, _, _, cowAllyTeamID = Spring.GetTeamInfo(ecoKillAward, false)
				for _, allyTeamID in pairs(winningAllyTeams) do
					if cowAllyTeamID == allyTeamID then
						--check if this team won the game
						cowAward = ecoKillAward
						break
					end
				end
			end
		end

		--tell unsynced
		SendToUnsynced("ReceiveAwards", ecoKillAward, ecoKillAwardSec, ecoKillAwardThi, ecoKillScore, ecoKillScoreSec, ecoKillScoreThi,
			fightKillAward, fightKillAwardSec, fightKillAwardThi, fightKillScore, fightKillScoreSec, fightKillScoreThi,
			effKillAward, effKillAwardSec, effKillAwardThi, effKillScore, effKillScoreSec, effKillScoreThi,
			ecoAward, ecoScore,
			dmgRecAward, dmgRecScore,
			sleepAward, sleepScore,
			cowAward,
			traitorAward, traitorAwardSec, traitorAwardThi, traitorScore, traitorScoreSec, traitorScoreThi)
	end

	-------------------------------------------------------------------------------------
else

	local function ProcessAwards(_, ecoKillAward, ecoKillAwardSec, ecoKillAwardThi, ecoKillScore, ecoKillScoreSec, ecoKillScoreThi,
						   fightKillAward, fightKillAwardSec, fightKillAwardThi, fightKillScore, fightKillScoreSec, fightKillScoreThi,
						   effKillAward, effKillAwardSec, effKillAwardThi, effKillScore, effKillScoreSec, effKillScoreThi,
						   ecoAward, ecoScore,
						   dmgRecAward, dmgRecScore,
						   sleepAward, sleepScore,
						   cowAward,
						   traitorAward, traitorAwardSec, traitorAwardThi, traitorScore, traitorScoreSec, traitorScoreThi)

		-- record who won which awards in chat message (for demo parsing by replays.springrts.com)
		-- make all values positive, as unsigned ints are easier to parse
		local ecoKillLine = '\161' .. tostring(1 + ecoKillAward) .. ':' .. tostring(ecoKillScore) .. '\161' .. tostring(1 + ecoKillAwardSec) .. ':' .. tostring(ecoKillScoreSec) .. '\161' .. tostring(1 + ecoKillAwardThi) .. ':' .. tostring(ecoKillScoreThi)
		local fightKillLine = '\162' .. tostring(1 + fightKillAward) .. ':' .. tostring(fightKillScore) .. '\162' .. tostring(1 + fightKillAwardSec) .. ':' .. tostring(fightKillScoreSec) .. '\162' .. tostring(1 + fightKillAwardThi) .. ':' .. tostring(fightKillScoreThi)
		local effKillLine = '\163' .. tostring(1 + effKillAward) .. ':' .. tostring(effKillScore) .. '\163' .. tostring(1 + effKillAwardSec) .. ':' .. tostring(effKillScoreSec) .. '\163' .. tostring(1 + effKillAwardThi) .. ':' .. tostring(effKillScoreThi)
		local otherLine = '\164' .. tostring(1 + cowAward) .. '\165' .. tostring(1 + ecoAward) .. ':' .. tostring(ecoScore) .. '\166' .. tostring(1 + dmgRecAward) .. ':' .. tostring(dmgRecScore) .. '\167' .. tostring(1 + sleepAward) .. ':' .. tostring(sleepScore)
		local awardsMsg = ecoKillLine .. fightKillLine .. effKillLine .. otherLine
		Spring.SendLuaRulesMsg(awardsMsg)

		-- send to awards widget
		if Script.LuaUI("GadgetReceiveAwards") then
			Script.LuaUI.GadgetReceiveAwards(ecoKillAward, ecoKillAwardSec, ecoKillAwardThi, ecoKillScore, ecoKillScoreSec, ecoKillScoreThi,
				fightKillAward, fightKillAwardSec, fightKillAwardThi, fightKillScore, fightKillScoreSec, fightKillScoreThi,
				effKillAward, effKillAwardSec, effKillAwardThi, effKillScore, effKillScoreSec, effKillScoreThi,
				ecoAward, ecoScore,
				dmgRecAward, dmgRecScore,
				sleepAward, sleepScore,
				cowAward,
				traitorAward, traitorAwardSec, traitorAwardThi, traitorScore, traitorScoreSec, traitorScoreThi)
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("ReceiveAwards", ProcessAwards)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("ReceiveAwards")
	end

end
