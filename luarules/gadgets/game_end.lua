function gadget:GetInfo()
	return {
		name = "Game End",
		desc = "Handles team/allyteam deaths and declares gameover",
		author = "Andrea Piras",
		date = "June, 2013",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true  --  loaded by default?
	}
end

if gadgetHandler:IsSyncedCode() then
	-- In this gadget, an allyteam is declared dead when it no longer has any units
	-- Allyteam explosion when no coms are left (killing all remaining units of that allyteam) is implemented in teamcomends.lua

	local sharedDynamicAllianceVictory = Spring.GetModOptions().shareddynamicalliancevictory
	local fixedallies = Spring.GetModOptions().fixedallies

	local KillTeam = Spring.KillTeam
	local GetAllyTeamList = Spring.GetAllyTeamList
	local GetTeamList = Spring.GetTeamList
	local GetPlayerInfo = Spring.GetPlayerInfo
	local GetPlayerList = Spring.GetPlayerList
	local GetTeamInfo = Spring.GetTeamInfo
	local GetTeamUnitCount = Spring.GetTeamUnitCount
	local GetAIInfo = Spring.GetAIInfo
	local GetTeamLuaAI = Spring.GetTeamLuaAI
	local GameOver = Spring.GameOver
	local AreTeamsAllied = Spring.AreTeamsAllied
	local GetGameFrame = Spring.GetGameFrame

	local playerQuitIsDead = true	-- gets turned off for 1v1's
	local oneTeamWasActive = false
	local teamToAllyTeam = {}
	local playerIDtoAIs = {}
	local gaiaTeamID = Spring.GetGaiaTeamID()
	local gaiaAllyTeamID = select(6, Spring.GetTeamInfo(gaiaTeamID))
	local playerList = GetPlayerList()

	local allyTeamInfos = {}
	--allyTeamInfos structure: (excluding gaia)
	-- allyTeamInfos = {
	--	[allyTeamID] = {
	--		teams = {
	--			[teamID]= {
	--				players = {
	--					[playerID] = isControlling
	--				},
	--				unitCount,
	--				dead,
	--				isAI,
	--				isControlled,
	--			},
	--		},
	--		unitCount,
	--		dead,
	--	},
	--}


	local function UpdateAllyTeamIsDead(allyTeamID)
		local allyTeamInfo = allyTeamInfos[allyTeamID]
		local dead = true
		for teamID, teamInfo in pairs(allyTeamInfo.teams) do
			if not playerQuitIsDead then
				dead = dead and (teamInfo.dead or not teamInfo.hasLeader)
			else
				dead = dead and (teamInfo.dead or not teamInfo.isControlled)
			end
		end
		allyTeamInfos[allyTeamID].dead = dead
	end


	local function CheckPlayer(playerID)
		local _, active, spectator, teamID, allyTeamID = GetPlayerInfo(playerID, false)
		local teamInfo = allyTeamInfos[allyTeamID].teams[teamID]

		local gf = GetGameFrame()
		if not spectator and active then
			teamInfo.players[playerID] = gf
		end
		teamInfo.hasLeader = select(2, GetTeamInfo(teamID,false)) >= 0

		if not teamInfo.hasLeader and not teamInfo.dead then
			KillTeam(teamID)
		end

		-- if team isn't AI controlled, then we need to check if we have attached players
		if not teamInfo.isAI then
			teamInfo.isControlled = false
			for _, isControlling in pairs(teamInfo.players) do
				if isControlling and isControlling > (gf - 60) then -- this entire crap is needed because GetPlayerInfo returns active = false for the next 30 gameframes after savegame load, and results in immediate end of loaded games if > 1v1 game
					teamInfo.isControlled = true
					break
				end
			end
		end

		-- if player is an AI controller, then mark all hosted AIs as uncontrolled
		local AIHostList = playerIDtoAIs[playerID] or {}
		for AITeam, AIAllyTeam in pairs(AIHostList) do
			allyTeamInfos[AIAllyTeam].teams[AITeam].isControlled = active
		end
		allyTeamInfos[allyTeamID].teams[teamID] = teamInfo

		UpdateAllyTeamIsDead(allyTeamID)
	end


	local function CheckAllPlayers()
		playerList = GetPlayerList()
		for _, playerID in ipairs(playerList) do
			CheckPlayer(playerID)
		end
	end


	function gadget:GameOver()
		gadgetHandler:RemoveGadget(self)
	end


	function gadget:Initialize()
		if Spring.GetModOptions().deathmode == 'neverend' then
			gadgetHandler:RemoveGadget(self)
			return
		end

		local teamCount = 0
		for _, teamID in ipairs(GetTeamList()) do
			if teamID ~= gaiaTeamID then
				teamCount = teamCount + 1
			end
		end
		if teamCount < 2 then  -- sandbox mode
			gadgetHandler:RemoveGadget(self)
			return
		elseif teamCount == 2 then  -- let player quit & rejoin in 1v1
			playerQuitIsDead = false
		end

		-- at start, fill in the table of all alive allyteams
		local gaiaAllyTeamID = select(6, Spring.GetTeamInfo(gaiaTeamID))
		for _, allyTeamID in ipairs(GetAllyTeamList()) do
			if allyTeamID ~= gaiaAllyTeamID then
				local allyTeamInfo = {
					unitCount = 0,
					teams = {},
				}
				for _, teamID in ipairs(GetTeamList(allyTeamID)) do
					teamToAllyTeam[teamID] = allyTeamID
					local teamInfo = {
						players = {},
						hasLeader = select(2, GetTeamInfo(teamID, false)) >= 0,
					}
					-- engine AI
					teamInfo.isAI = select(4, GetTeamInfo(teamID, false))
					if teamInfo.isAI then
						-- store who hosts that engine AI
						local AIHostPlayerID = select(3, GetAIInfo(teamID))
						playerIDtoAIs[AIHostPlayerID] = playerIDtoAIs[AIHostPlayerID] or {}
						playerIDtoAIs[AIHostPlayerID][teamID] = allyTeamID
					end
					-- lua AI
					local luaAi = GetTeamLuaAI(teamID)
					if luaAi and luaAi ~= '' then
						teamInfo.isAI = true
						teamInfo.isControlled = true
					end

					teamInfo.unitCount = GetTeamUnitCount(teamID)
					allyTeamInfo.unitCount = allyTeamInfo.unitCount + teamInfo.unitCount
					allyTeamInfo.teams[teamID] = teamInfo
				end
				allyTeamInfos[allyTeamID] = allyTeamInfo
			end
		end
		CheckAllPlayers()
	end


	local function AreAllyTeamsDoubleAllied(firstAllyTeamID, secondAllyTeamID)
		-- we need to check for both directions of alliance
		for teamA in pairs(allyTeamInfos[firstAllyTeamID].teams) do
			for teamB in pairs(allyTeamInfos[secondAllyTeamID].teams) do
				if not AreTeamsAllied(teamA, teamB) or not AreTeamsAllied(teamB, teamA) then
					return false
				end
			end
		end
		return true
	end


	-- find the last remaining allyteam
	local function CheckSingleAllyVictoryEnd()
		local winnerCount = 0
		local candidateWinners = {}
		for allyTeamID in pairs(allyTeamInfos) do
			if not allyTeamInfos[allyTeamID].dead then
				winnerCount = winnerCount + 1
				candidateWinners[winnerCount] = allyTeamID
			end
		end
		if winnerCount > 1 then
			return false
		end
		return candidateWinners
	end


	-- we have to cross check all the alliances
	local function CheckSharedAllyVictoryEnd()
		local candidateWinners = {}
		local winnerCountSquared = 0
		local aliveCount = 0
		for allyTeamA in pairs(allyTeamInfos) do
			if not allyTeamInfos[allyTeamA].dead then
				aliveCount = aliveCount + 1
				for allyTeamB in pairs(allyTeamInfos) do
					if not allyTeamInfos[allyTeamB].dead and AreAllyTeamsDoubleAllied(allyTeamA, allyTeamB) then
						-- store both check directions
						-- since we're gonna check if we're allied against ourself, only secondAllyTeamID needs to be stored
						candidateWinners[allyTeamB] = true
						winnerCountSquared = winnerCountSquared + 1
					end
				end
			end
		end

		if aliveCount * aliveCount ~= winnerCountSquared then
			return false
		end

		-- all the allyteams alive are bidirectionally allied against eachother, they are all winners
		--local winnersCorrectFormat = {}
		local winnersCorrectFormatCount = 0
		for winner in pairs(candidateWinners) do
			winnersCorrectFormatCount = winnersCorrectFormatCount + 1
			--winnersCorrectFormat[winnersCorrectFormatCount] = winner
		end
		return winnersCorrectFormatCount
	end


	function gadget:GameFrame(gf)
		local winners
		if fixedallies then
			if gf < 30 then
				CheckAllPlayers()
			end
			winners = CheckSingleAllyVictoryEnd()
		else
			CheckAllPlayers()
			winners = sharedDynamicAllianceVictory and CheckSharedAllyVictoryEnd() or CheckSingleAllyVictoryEnd()
		end

		if winners then
			if Spring.GetModOptions().scenariooptions then
				Spring.Echo("winners", winners[1])
				SendToUnsynced("scenariogameend", winners[1])
			end
			GameOver(winners)
		end
	end


	function gadget:PlayerChanged(playerID) -- not all events that we want to test call gadget:PlayerChanged (e.g. allying)
		CheckAllPlayers()
	end

	function gadget:TeamDied(teamID)
		local allyTeamID = teamToAllyTeam[teamID]
		local allyTeamInfo = allyTeamInfos[allyTeamID]
		allyTeamInfo.teams[teamID].dead = true
		allyTeamInfos[allyTeamID] = allyTeamInfo
		UpdateAllyTeamIsDead(allyTeamID)
		CheckAllPlayers()
	end


	function gadget:UnitCreated(unitID, unitDefID, unitTeamID)
		if unitTeamID == gaiaTeamID then
			return
		end
		local allyTeamID = teamToAllyTeam[unitTeamID]
		local allyTeamInfo = allyTeamInfos[allyTeamID]
		allyTeamInfo.teams[unitTeamID].unitCount = allyTeamInfo.teams[unitTeamID].unitCount + 1
		allyTeamInfo.unitCount = allyTeamInfo.unitCount + 1
		allyTeamInfos[allyTeamID] = allyTeamInfo
	end
	gadget.UnitGiven = gadget.UnitCreated
	gadget.UnitCaptured = gadget.UnitCreated


	function gadget:UnitDestroyed(unitID, unitDefID, unitTeamID)
		if unitTeamID == gaiaTeamID then
			return
		end
		local allyTeamID = teamToAllyTeam[unitTeamID]
		local allyTeamInfo = allyTeamInfos[allyTeamID]
		local teamUnitCount = allyTeamInfo.teams[unitTeamID].unitCount - 1
		local allyTeamUnitCount = allyTeamInfo.unitCount - 1
		allyTeamInfo.teams[unitTeamID].unitCount = teamUnitCount
		allyTeamInfo.unitCount = allyTeamUnitCount
		allyTeamInfos[allyTeamID] = allyTeamInfo

		if allyTeamUnitCount == 0 then
			for teamID in pairs(allyTeamInfo.teams) do
				KillTeam(teamID)
			end
		end
	end
	gadget.UnitTaken = gadget.UnitDestroyed


	function gadget:RecvLuaMsg(msg, playerID)

		-- detect when no players are ingame (thus only specs remain) and shutdown the game
		if Spring.GetGameFrame() == 0 and string.sub(msg, 1, 2) == 'pc' then
			local activeTeams = 0
			local leaderPlayerID, isDead, isAiTeam, isLuaAI, active, spec
			for _, teamID in ipairs(GetTeamList()) do
				if teamID ~= gaiaTeamID then
					leaderPlayerID, isDead, isAiTeam = Spring.GetTeamInfo(teamID)
					if isDead == 0 and not isAiTeam then
						_, active, spec = Spring.GetPlayerInfo(leaderPlayerID, false)
						if active and not spec then
							activeTeams = activeTeams + 1
						end
					end
				end
			end
			if activeTeams > 0 then
				oneTeamWasActive = true
			end
			if oneTeamWasActive and activeTeams == 0 then
				GameOver({})
			end
		end
	end


else	-- Unsynced


	local IsCheatingEnabled = Spring.IsCheatingEnabled
	local sec = 0
	local cheated = false

	function gadget:Update(dt)
		if Spring.GetGameFrame() == 0 then
			sec = sec + Spring.GetLastUpdateSeconds()
			if sec > 3 then
				sec = 0
				Spring.SendLuaRulesMsg('pc')
			end
		end
	end

	function gadget:GameFrame(gf)
		if not cheated then
			cheated = IsCheatingEnabled()
		end
	end

	local function ScenarioGameEnd(_, winners)
		if Spring.IsReplay() then
			return
		end
		local myTeamID = Spring.GetMyAllyTeamID()
		local cur_max = Spring.GetTeamStatsHistory(myTeamID)
		local stats = Spring.GetTeamStatsHistory(myTeamID, cur_max, cur_max)
		stats = stats[1]
		stats.cheated = cheated
		stats.winners = winners
		stats.won = (myTeamID == winners)
		stats.endtime = Spring.GetGameFrame() / 30
		stats.scenariooptions = Spring.GetModOptions().scenariooptions -- pass it back so we know difficulty

		if Spring.GetMenuName and string.find(string.lower(Spring.GetMenuName()), 'chobby') ~= nil then
			local message = Spring.Utilities.json.encode(stats)
			Spring.SendLuaMenuMsg("ScenarioGameEnd " .. message)
		end
	end

	function gadget:Initialize()
		if Spring.GetModOptions().scenariooptions then
			gadgetHandler:AddSyncAction("scenariogameend", ScenarioGameEnd)
		end
	end

	function gadget:Shutdown()
		if Spring.GetModOptions().scenariooptions then
			gadgetHandler:RemoveSyncAction("scenariogameend")
		end
	end
end
