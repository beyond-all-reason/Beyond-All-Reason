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

	The matchflow module's exemplar gadget: liveness events + ceremony hosting;
	the end-condition decision is delegated to the policies/game_over.lua
	pipeline, and scripted mission verdicts (MatchFlow.Victory/Defeat) enter
	through the same pipeline's MissionOverride gate — one exit path.
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
	for udefID, def in ipairs(UnitDefs) do
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
	local GetGameFrame = Spring.GetGameFrame

	local ModuleHandler = VFS.Include("modules/module_handler.lua")
	local Liveness = VFS.Include("modules/matchflow/lib/liveness.lua")
	local Ceremony = VFS.Include("modules/matchflow/lib/ceremony.lua")

	local playerQuitIsDead = true	-- gets turned off for 1v1's
	local oneTeamWasActive = false
	local isFFA = Spring.Utilities.Gametype.IsFFA()

	-- Legacy behavior expressed as configuration, not gadget suicide:
	-- neverend and sandbox (<2 allyteams) disable the ELIMINATION checks, but
	-- the gadget stays alive so scripted mission verdicts still end the game.
	-- (The pre-module gadget removed itself in these cases; it also had no
	-- scripted path to keep alive.)
	local eliminationEnabled = true

	local liveness ---@type MatchLiveness|nil nil when elimination is disabled
	local ceremony ---@type MatchCeremony
	local gameOverPipeline ---@type PolicyDescriptor[]
	local scriptedWinners = nil ---@type integer[]|nil pending MatchFlow verdict

	---The pipeline's evaluation context; rebuilt fields per check, engine
	---reads injected once.
	local gameOverCtx = {
		infos = nil,
		scriptedWinners = nil,
		fixedallies = fixedallies,
		sharedDynamicAllianceVictory = sharedDynamicAllianceVictory,
		AreTeamsAllied = Spring.AreTeamsAllied,
	}

	local function CheckAllPlayers(gf)
		if liveness then
			liveness.CheckAllPlayers(gf)
		end
	end

	function gadget:GameOver()
		gadgetHandler:RemoveGadget(self)
	end

	function gadget:Initialize()
		if Spring.GetModOptions().deathmode == 'neverend' then
			eliminationEnabled = false
		end

		local teamCount = 0
		for _, teamID in ipairs(teamList) do
			if teamID ~= gaiaTeamID then
				teamCount = teamCount + 1
			end
		end
		if #allyteamList - 1 < 2 then  -- sandbox mode
			eliminationEnabled = false
		elseif teamCount == 2 or isFFA then  -- let player quit & rejoin in 1v1
			playerQuitIsDead = false
		end

		ceremony = Ceremony.New({
			spring = {
				SetGlobalLos = Spring.SetGlobalLos,
				GameOver = GameOver,
				GetAllUnits = Spring.GetAllUnits,
				GetUnitDefID = Spring.GetUnitDefID,
				GetUnitAllyTeam = Spring.GetUnitAllyTeam,
				GiveOrderToUnit = Spring.GiveOrderToUnit,
				ValidUnitID = Spring.ValidUnitID,
				GetCOBScriptID = Spring.GetCOBScriptID,
				CallCOBScript = Spring.CallCOBScript,
				UnitScriptGetScriptEnv = Spring.UnitScript.GetScriptEnv,
				UnitScriptCallAsUnit = Spring.UnitScript.CallAsUnit,
			},
			isCommander = isCommander,
			cmdStop = CMD.STOP,
			maxDeathFrame = function()
				return GG.maxDeathFrame
			end,
		})

		gameOverPipeline = ModuleHandler.LoadPolicies("matchflow").game_over

		-- Scripted verdicts: the MatchFlow.Victory/Defeat contract surface.
		GG.MatchFlow = {
			---@param allyTeamID integer
			Victory = function(allyTeamID)
				scriptedWinners = { allyTeamID }
			end,
			---@param losers integer[]
			Defeat = function(losers)
				local losing = {}
				for _, allyTeamID in ipairs(losers) do
					losing[allyTeamID] = true
				end
				local winners = {}
				for _, allyTeamID in ipairs(allyteamList) do
					if not losing[allyTeamID] and allyTeamID ~= gaiaAllyTeamID then
						winners[#winners + 1] = allyTeamID
					end
				end
				scriptedWinners = winners
			end,
		}

		if eliminationEnabled then
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
			CheckAllPlayers(GetGameFrame())
		end
	end

	function gadget:Shutdown()
		GG.MatchFlow = nil
	end

	function gadget:GameFrame(gf)
		if ceremony.IsStarted() then
			ceremony.GameFrame(gf)
		else
			-- The legacy gadget refreshed player state on a cadence but ran the
			-- decision every frame; preserved exactly. With elimination off,
			-- only a pending scripted verdict triggers an evaluation.
			if eliminationEnabled then
				if fixedallies then
					if gf < 30 or gf % 30 == 1 then
						CheckAllPlayers(gf)
					end
				else
					if gf < 30 or gf % 15 == 1 then
						CheckAllPlayers(gf)
					end
				end
			elseif scriptedWinners == nil then
				return
			end

			gameOverCtx.infos = liveness and liveness.Infos() or nil
			gameOverCtx.scriptedWinners = scriptedWinners
			local verdict = ModuleHandler.Evaluate(gameOverPipeline, gameOverCtx)
			scriptedWinners = nil

			if verdict and not verdict.continue then
				local winners = verdict.winners
				if Spring.GetModOptions().scenariooptions then
					Spring.Echo("winners", winners[1])
					SendToUnsynced("scenariogameend", winners[1])
				end
				ceremony.Begin(winners, gf)
			end
		end
	end

	function gadget:TeamChanged(teamID)
		CheckAllPlayers(GetGameFrame())
	end

	function gadget:TeamDied(teamID)
		if liveness then
			liveness.TeamDied(teamID, GetGameFrame())
		end
	end

	function gadget:UnitCreated(unitID, unitDefID, unitTeamID, builderID)
		if liveness then
			liveness.UnitCreated(unitDefID, unitTeamID)
		end
	end
	gadget.UnitGiven = gadget.UnitCreated

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
		if liveness then
			liveness.UnitDestroyed(unitDefID, unitTeam)
		end
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
