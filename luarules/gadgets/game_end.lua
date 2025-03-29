local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Game End",
		desc = "Handles team/allyteam deaths and declares gameover",
		author = "Andrea Piras",
		date = "June, 2013",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

--[[
	A dead AllyTeam blows up all units it still contains

	AllyTeam is dead when:
	- no longer has any units
	- has no alive teams
]]
if gadgetHandler:IsSyncedCode() then

	local sharedDynamicAllianceVictory = Spring.GetModOptions().shareddynamicalliancevictory
	local fixedallies = Spring.GetModOptions().fixedallies

	local gaiaTeamID = Spring.GetGaiaTeamID()
	local gaiaAllyTeamID = select(6, Spring.GetTeamInfo(gaiaTeamID, false))

	local earlyDropGrace = Game.gameSpeed * 60 * 1 -- in frames

	-- Exclude Scavengers / Raptors AI
	local ignoredTeams = {
		[gaiaTeamID] = true,
	}
	local allyteamList = Spring.GetAllyTeamList()
	local teamList = Spring.GetTeamList()
	for i = 1, #teamList do
		local luaAI = Spring.GetTeamLuaAI(teamList[i])
		if luaAI and (luaAI:find("Raptors") or luaAI:find("Scavengers")) then
			ignoredTeams[teamList[i]] = true

			-- ignore all other teams in this allyteam as well
			local allyTeamID = select(6, Spring.GetTeamInfo(teamList[i], false))
			local teammates = Spring.GetTeamList(allyTeamID)
			for j = 1, #teammates do
				ignoredTeams[teammates[j]] = true
			end
		end
	end

	local isCommander = {}
	local unitDecoration = {}
	for udefID,def in ipairs(UnitDefs) do
		if def.customParams.iscommander then
			isCommander[udefID] = true
		end
		if def.customParams.decoration then
			unitDecoration[udefID] = true
		end
	end

	local KillTeam = Spring.KillTeam
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
	local teamToAllyTeam = { [gaiaTeamID] = gaiaAllyTeamID }
	local playerIDtoAIs = {}
	local playerList = GetPlayerList()
	local killTeamQueue = {}
	local isFFA = Spring.Utilities.Gametype.IsFFA()

	local gameoverFrame
	local gameoverWinners
	local gameoverAnimFrame
	local gameoverAnimUnits

	local globalLosGranted = false

	local allyTeamInfos = {}
	--[[
	allyTeamInfos structure: (excluding gaia)
	 allyTeamInfos = {
		[allyTeamID] = {
			teams = {
				[teamID]= {
					players = {
						[playerID] = isControlling
					},
					unitCount,
					dead,
					isAI,
					isControlled,
				},
			},
			unitCount,
			unitDecorationCount,
			dead,
		},
	}
	]]--

	local function UpdateAllyTeamIsDead(allyTeamID)
		if GetGameFrame() == 0 then return end

		local wipeout = true
		local allyTeamInfo = allyTeamInfos[allyTeamID]
		for teamID, team in pairs(allyTeamInfo.teams) do
			wipeout = wipeout and (team.dead or (playerQuitIsDead and not team.isControlled or not team.hasLeader))
		end
		if wipeout and not allyTeamInfos[allyTeamID].dead then
			if isFFA and Spring.GetGameFrame() < earlyDropGrace then
				for teamID, team in pairs(allyTeamInfos[allyTeamID].teams) do
					local teamUnits = Spring.GetTeamUnits(teamID)
					for i=1, #teamUnits do
						Spring.DestroyUnit(teamUnits[i], false, true)	-- reclaim, dont want to leave FFA comwreck for idling starts
					end
				end
			else
				GG.wipeoutAllyTeam(allyTeamID)
			end
			allyTeamInfos[allyTeamID].dead = true
		end
	end

	local function CheckPlayer(playerID)
		local _, active, spectator, teamID, allyTeamID = GetPlayerInfo(playerID, false)
		local team = allyTeamInfos[allyTeamID].teams[teamID]

		local gf = GetGameFrame()
		if not spectator and active then
			team.players[playerID] = gf
		end
		team.hasLeader = select(2, GetTeamInfo(teamID, false)) >= 0

		local allResigned = true
		if not team.dead then
			if team.isAI then
				allResigned = false
			else
				local players = GetPlayerList(teamID)
				for _, playerID in pairs(players) do
					local _, active, spec = GetPlayerInfo(playerID, false)
					allResigned = allResigned and spec
				end
			end
		end
		if not team.dead and allResigned then
			killTeamQueue[teamID] = gf
		else
			if not team.hasLeader and not team.dead then
				if not killTeamQueue[teamID] then
					killTeamQueue[teamID] = gf + (Game.gameSpeed * (isFFA and 20 or 12))	-- add a grace period before killing the team
				end
			elseif killTeamQueue[teamID] then
				killTeamQueue[teamID] = nil
			end
		end
		if killTeamQueue[teamID] and gf >= killTeamQueue[teamID] then
			KillTeam(teamID)
			killTeamQueue[teamID] = nil
		end

		-- if team isn't AI controlled, then we need to check if we have attached players
		if not team.isAI then
			team.isControlled = false
			for _, isControlling in pairs(team.players) do
				if isControlling and isControlling > (gf - 60) then -- this entire crap is needed because GetPlayerInfo returns active = false for the next 30 gameframes after savegame load, and results in immediate end of loaded games if > 1v1 game
					team.isControlled = true
					break
				end
			end
		end

		allyTeamInfos[allyTeamID].teams[teamID] = team

		-- if player is an AI controller, then mark all hosted AIs as uncontrolled
		local AIHostList = playerIDtoAIs[playerID] or {}
		for AITeam, AIAllyTeam in pairs(AIHostList) do
			allyTeamInfos[AIAllyTeam].teams[AITeam].isControlled = active
		end

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
		for _, teamID in ipairs(teamList) do
			if teamID ~= gaiaTeamID then
				teamCount = teamCount + 1
			end
		end
		if teamCount < 2 then  -- sandbox mode
			gadgetHandler:RemoveGadget(self)
			return
		elseif teamCount == 2 or isFFA then  -- let player quit & rejoin in 1v1
			playerQuitIsDead = false
		end

		-- at start, fill in the table of all alive allyteams
		for _, allyTeamID in ipairs(allyteamList) do
			if allyTeamID ~= gaiaAllyTeamID then
				local allyteamTeams = Spring.GetTeamList(allyTeamID)
				local allyTeamInfo = {
					unitCount = 0,
					unitDecorationCount = 0,
					teams = {},
					dead = (#allyteamTeams == 0),
				}
				for _, teamID in ipairs(allyteamTeams) do
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
					local units = Spring.GetTeamUnits(teamID)
					for u = 1, #units do
						if unitDecoration[Spring.GetUnitDefID(units[u])] then
							allyTeamInfo.unitDecorationCount = allyTeamInfo.unitDecorationCount + 1
						end
					end
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
		if gameoverFrame then
			if not globalLosGranted then
				for _, allyTeamId in ipairs(gameoverWinners) do
					Spring.SetGlobalLos(allyTeamId, true)
				end

				globalLosGranted = true
			end

			if gf == gameoverFrame then
				GameOver(gameoverWinners)
			end

			if gf == gameoverAnimFrame then
				for unitID, _ in pairs(gameoverAnimUnits) do
					if Spring.ValidUnitID(unitID) then
						if Spring.GetCOBScriptID(unitID, 'GameOverAnim') then
							Spring.CallCOBScript(unitID, 'GameOverAnim', 0, true)
						else
							local scriptEnv = Spring.UnitScript.GetScriptEnv(unitID)
							if scriptEnv and scriptEnv['GameOverAnim'] then
								Spring.UnitScript.CallAsUnit(unitID, scriptEnv['GameOverAnim'], true)
							end
						end
					end
				end
			end
		else
			local winners
			if fixedallies then
				if gf < 30 or gf % 30 == 1 then
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

				-- delay gameover to let everything blow up gradually first
				local delay = GG.maxDeathFrame or 250
				gameoverFrame = gf + delay + 70
				gameoverWinners = winners

				-- make all winner commanders dance!
				gameoverAnimFrame = gf + 55		-- delay a bit because walking commanders need to stop walking + a delay look nice
				gameoverAnimUnits = {}
				if type(winners) == 'table' then
					local units = Spring.GetAllUnits()
					for i, unitID in ipairs(units) do
						if isCommander[Spring.GetUnitDefID(unitID)] then
							for u, allyTeamID in pairs(winners) do
								if Spring.GetUnitAllyTeam(unitID) == allyTeamID then
									Spring.GiveOrderToUnit(unitID, CMD.STOP, 0, 0)	-- give stop cmd so commanders can animate in place
									gameoverAnimUnits[unitID] = true
								end
							end
						end
					end
				end
			end
		end
	end

	function gadget:TeamChanged(teamID)
		CheckAllPlayers()
	end

	function gadget:TeamDied(teamID)
		local allyTeamID = teamToAllyTeam[teamID]
		allyTeamInfos[allyTeamID].teams[teamID].dead = true
		UpdateAllyTeamIsDead(allyTeamID)
		CheckAllPlayers()
	end

	function gadget:UnitCreated(unitID, unitDefID, unitTeamID, builderID)
		if not ignoredTeams[unitTeamID] then
			local allyTeamID = teamToAllyTeam[unitTeamID]
			local allyTeamInfo = allyTeamInfos[allyTeamID]
			allyTeamInfo.teams[unitTeamID].unitCount = allyTeamInfo.teams[unitTeamID].unitCount + 1
			allyTeamInfo.unitCount = allyTeamInfo.unitCount + 1
			if unitDecoration[unitDefID] then
				allyTeamInfo.unitDecorationCount = allyTeamInfo.unitDecorationCount + 1
			end
			allyTeamInfos[allyTeamID] = allyTeamInfo
		end
	end
	gadget.UnitGiven = gadget.UnitCreated

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
		if not ignoredTeams[unitTeam] then
			local allyTeamID = teamToAllyTeam[unitTeam]
			local allyTeamInfo = allyTeamInfos[allyTeamID]
			local teamUnitCount = allyTeamInfo.teams[unitTeam].unitCount - 1
			local allyTeamUnitCount = allyTeamInfo.unitCount - 1
			allyTeamInfo.teams[unitTeam].unitCount = teamUnitCount
			allyTeamInfo.unitCount = allyTeamUnitCount
			if unitDecoration[unitDefID] then
				allyTeamInfo.unitDecorationCount = allyTeamInfo.unitDecorationCount - 1
			end
			allyTeamInfos[allyTeamID] = allyTeamInfo
			if allyTeamUnitCount <= allyTeamInfo.unitDecorationCount then
				for teamID in pairs(allyTeamInfo.teams) do
					KillTeam(teamID)
					killTeamQueue[teamID] = nil
				end
			end
		end
	end
	gadget.UnitTaken = gadget.UnitDestroyed

	function gadget:RecvLuaMsg(msg, playerID)

		-- detect when no players are ingame (thus only specs remain) and shutdown the game
		if Spring.GetGameFrame() == 0 and string.sub(msg, 1, 2) == 'pc' then
			local activeTeams = 0
			local leaderPlayerID, isDead, isAiTeam, active, spec
			for _, teamID in ipairs(teamList) do
				if teamID ~= gaiaTeamID then
					leaderPlayerID, isDead, isAiTeam = GetTeamInfo(teamID, false)
					if isDead == 0 and not isAiTeam then
						_, active, spec = GetPlayerInfo(leaderPlayerID, false)
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

	local sec = 0
	local cheated = false
	local IsCheatingEnabled = Spring.IsCheatingEnabled

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
			local message = Json.encode(stats)
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
