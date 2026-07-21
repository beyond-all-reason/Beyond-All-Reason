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

	local GetPlayerInfo = Spring.GetPlayerInfo
	local GetTeamInfo = Spring.GetTeamInfo
	local GameOver = Spring.GameOver
	local AreTeamsAllied = Spring.AreTeamsAllied
	local GetGameFrame = Spring.GetGameFrame

	local Liveness = VFS.Include("modules/matchflow/lib/liveness.lua")

	local playerQuitIsDead = true	-- gets turned off for 1v1's
	local oneTeamWasActive = false
	local isFFA = Spring.Utilities.Gametype.IsFFA()

	local gameoverFrame
	local gameoverWinners
	local gameoverAnimFrame
	local gameoverAnimUnits
	local singleWinnerScratch = {}
	local sharedWinnerScratch = {}

	local globalLosGranted = false

	-- Liveness state machine (allyTeamInfos bookkeeping) lives in
	-- modules/matchflow/lib/liveness.lua, extracted behavior-for-behavior and
	-- spec'd. This gadget keeps the end-condition decision and the ceremony.
	local liveness ---@type MatchLiveness
	local allyTeamInfos ---@type table set from liveness.Infos() at Initialize

	local function CheckAllPlayers(gf)
		liveness.CheckAllPlayers(gf)
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
		if #allyteamList-1 < 2 then  -- sandbox mode
			gadgetHandler:RemoveGadget(self)
			return
		elseif teamCount == 2 or isFFA then  -- let player quit & rejoin in 1v1
			playerQuitIsDead = false
		end

		liveness = Liveness.New({
			spring = {
				GetPlayerList = Spring.GetPlayerList,
				GetTeamList = Spring.GetTeamList,
				GetPlayerInfo = Spring.GetPlayerInfo,
				GetTeamInfo = Spring.GetTeamInfo,
				GetTeamUnitCount = Spring.GetTeamUnitCount,
				GetTeamUnits = Spring.GetTeamUnits,
				GetUnitDefID = Spring.GetUnitDefID,
				GetAIInfo = Spring.GetAIInfo,
				GetTeamLuaAI = Spring.GetTeamLuaAI,
				KillTeam = Spring.KillTeam,
				DestroyUnit = Spring.DestroyUnit,
			},
			config = {
				gaiaTeamID = gaiaTeamID,
				gaiaAllyTeamID = gaiaAllyTeamID,
				isFFA = isFFA,
				playerQuitIsDead = playerQuitIsDead,
				earlyDropGrace = earlyDropGrace,
				killGraceFrames = Game.gameSpeed * (isFFA and 20 or 12),
				ignoredTeams = ignoredTeams,
				unitDecoration = unitDecoration,
			},
			wipeoutAllyTeam = function(allyTeamID)
				GG.wipeoutAllyTeam(allyTeamID)
			end,
		})
		liveness.InitTeams(allyteamList)
		allyTeamInfos = liveness.Infos()

		CheckAllPlayers(GetGameFrame())
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
		for i = #singleWinnerScratch, 1, -1 do
			singleWinnerScratch[i] = nil
		end
		local winnerCount = 0
		for allyTeamID in pairs(allyTeamInfos) do
			if not allyTeamInfos[allyTeamID].dead then
				winnerCount = winnerCount + 1
				singleWinnerScratch[winnerCount] = allyTeamID
			end
		end
		if winnerCount > 1 then
			return false
		end
		return singleWinnerScratch
	end

	-- we have to cross check all the alliances
	local function CheckSharedAllyVictoryEnd()
		for allyTeamID in pairs(sharedWinnerScratch) do
			sharedWinnerScratch[allyTeamID] = nil
		end
		local winnerCountSquared = 0
		local aliveCount = 0
		for allyTeamA in pairs(allyTeamInfos) do
			if not allyTeamInfos[allyTeamA].dead then
				aliveCount = aliveCount + 1
				for allyTeamB in pairs(allyTeamInfos) do
					if not allyTeamInfos[allyTeamB].dead and AreAllyTeamsDoubleAllied(allyTeamA, allyTeamB) then
						-- store both check directions
						-- since we're gonna check if we're allied against ourself, only secondAllyTeamID needs to be stored
						sharedWinnerScratch[allyTeamB] = true
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
		for winner in pairs(sharedWinnerScratch) do
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
					CheckAllPlayers(gf)
				end
				winners = CheckSingleAllyVictoryEnd()
			else
				if gf < 30 or gf % 15 == 1 then
					CheckAllPlayers(gf)
				end
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
					local winnerSet = {}
					for u = 1, #winners do
						winnerSet[winners[u]] = true
					end
					local units = Spring.GetAllUnits()
					for i = 1, #units do
						local unitID = units[i]
						if isCommander[Spring.GetUnitDefID(unitID)] and winnerSet[Spring.GetUnitAllyTeam(unitID)] then
							Spring.GiveOrderToUnit(unitID, CMD.STOP, 0, 0)	-- give stop cmd so commanders can animate in place
							gameoverAnimUnits[unitID] = true
						end
					end
				end
			end
		end
	end

	function gadget:TeamChanged(teamID)
		CheckAllPlayers(GetGameFrame())
	end

	function gadget:TeamDied(teamID)
		liveness.TeamDied(teamID, GetGameFrame())
	end

	function gadget:UnitCreated(unitID, unitDefID, unitTeamID, builderID)
		liveness.UnitCreated(unitDefID, unitTeamID)
	end
	gadget.UnitGiven = gadget.UnitCreated

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
		liveness.UnitDestroyed(unitDefID, unitTeam)
	end
	gadget.UnitTaken = gadget.UnitDestroyed

	function gadget:RecvLuaMsg(msg, playerID)

		-- detect when no players are ingame (thus only specs remain) and shutdown the game
		if GetGameFrame() == 0 and string.byte(msg, 1) == 112 and string.byte(msg, 2) == 99 then -- 'p'=112, 'c'=99
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
		if not cheated and gf % 30 == 0 then
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
