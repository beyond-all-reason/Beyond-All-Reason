--- Match liveness tracking, extracted behavior-for-behavior from
--- luarules/gadgets/game_end.lua: the allyTeamInfos bookkeeping (controlled /
--- resigned state, leader grace periods, AI-host tracking, decoration-unit
--- counting, the savegame 60-frame active hack). State maintenance only — the
--- end-condition DECISION stays with the caller, reading Infos().
---
--- Every hack is preserved on purpose; the original comments travel with the
--- code. Dependencies are injected so the machine specs under busted; the
--- gadget supplies Spring and GG.wipeoutAllyTeam.

local Liveness = {}

---@class LivenessSpringDeps engine reads/effects the machine needs
---@field GetPlayerList fun(teamID?: integer): integer[]
---@field GetTeamList fun(allyTeamID?: integer): integer[]
---@field GetPlayerInfo fun(playerID: integer, getPlayerOpts: boolean): string?, boolean?, boolean?, integer?, integer?
---@field GetTeamInfo fun(teamID: integer, getTeamKeys: boolean): integer?, integer?, integer?, boolean?, string?, integer?
---@field GetTeamUnitCount fun(teamID: integer): integer?
---@field GetTeamUnits fun(teamID: integer): integer[]?
---@field GetUnitDefID fun(unitID: integer): integer?
---@field GetAIInfo fun(teamID: integer): integer?, string?, integer?
---@field GetTeamLuaAI fun(teamID: integer): string?
---@field KillTeam fun(teamID: integer)
---@field DestroyUnit fun(unitID: integer, selfd: boolean, reclaimed: boolean)

---@class LivenessConfig
---@field gaiaTeamID integer
---@field gaiaAllyTeamID integer
---@field isFFA boolean
---@field playerQuitIsDead boolean false for 1v1/FFA (quit & rejoin allowed)
---@field earlyDropGrace integer frames; FFA early-drop reclaim window
---@field killGraceFrames integer frames of leaderless grace before KillTeam
---@field ignoredTeams table<integer, boolean> teams excluded from unit counting (gaia, Raptors/Scavengers)
---@field unitDecoration table<integer, boolean> unitDefID -> is decoration

---@class LivenessDeps
---@field spring LivenessSpringDeps
---@field config LivenessConfig
---@field wipeoutAllyTeam fun(allyTeamID: integer) GG.wipeoutAllyTeam in production

---@class MatchLiveness
---@field InitTeams fun(allyteamList: integer[])
---@field CheckAllPlayers fun(gf: integer)
---@field TeamDied fun(teamID: integer, gf: integer)
---@field UnitCreated fun(unitDefID: integer, unitTeamID: integer)
---@field UnitDestroyed fun(unitDefID: integer, unitTeam: integer)
---@field Infos fun(): table read-only-by-convention allyTeamInfos view

---@param deps LivenessDeps
---@return MatchLiveness
function Liveness.New(deps)
	local spring = deps.spring
	local config = deps.config
	local wipeoutAllyTeam = deps.wipeoutAllyTeam

	local EMPTY_TABLE = {}

	local playerQuitIsDead = config.playerQuitIsDead
	local teamToAllyTeam = { [config.gaiaTeamID] = config.gaiaAllyTeamID }
	local playerIDtoAIs = {}
	local playerInfoCache = {}
	local teamEvalFrame = {}
	local allyTeamEvalFrame = {}
	local playerList = spring.GetPlayerList()
	local killTeamQueue = {}
	local isFFA = config.isFFA

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

	local function UpdateAllyTeamIsDead(allyTeamID, gf)
		if gf == 0 then return end

		local wipeout = true
		local allyTeamInfo = allyTeamInfos[allyTeamID]
		for teamID, team in pairs(allyTeamInfo.teams) do
			wipeout = wipeout and (team.dead or (playerQuitIsDead and not team.isControlled or not team.hasLeader))
		end
		if wipeout and not allyTeamInfos[allyTeamID].dead then
			if isFFA and gf < config.earlyDropGrace then
				for teamID, team in pairs(allyTeamInfos[allyTeamID].teams) do
					local teamUnits = spring.GetTeamUnits(teamID) or EMPTY_TABLE
					for i = 1, #teamUnits do
						spring.DestroyUnit(teamUnits[i], false, true)	-- reclaim, dont want to leave FFA comwreck for idling starts
					end
				end
			else
				wipeoutAllyTeam(allyTeamID)
			end
			allyTeamInfos[allyTeamID].dead = true
		end
	end

	local function CheckPlayer(playerID, gf)
		local cachedPlayerInfo = playerInfoCache[playerID]
		local active = cachedPlayerInfo and cachedPlayerInfo.active
		local spectator = cachedPlayerInfo and cachedPlayerInfo.spectator
		local teamID = cachedPlayerInfo and cachedPlayerInfo.teamID
		local allyTeamID = cachedPlayerInfo and cachedPlayerInfo.allyTeamID
		if teamID == nil then
			_, active, spectator, teamID, allyTeamID = spring.GetPlayerInfo(playerID, false)
		end
		local team = allyTeamInfos[allyTeamID].teams[teamID]

		if not spectator and active then
			team.players[playerID] = gf
		end
		if teamEvalFrame[teamID] ~= gf then
			teamEvalFrame[teamID] = gf

			team.hasLeader = select(2, spring.GetTeamInfo(teamID, false)) >= 0

			local allResigned = true
			if not team.dead then
				if team.isAI then
					allResigned = false
				else
					for trackedPlayerID in pairs(team.players) do
						local trackedInfo = playerInfoCache[trackedPlayerID]
						local spec = trackedInfo and trackedInfo.spectator
						if spec == nil then
							_, _, spec = spring.GetPlayerInfo(trackedPlayerID, false)
						end
						allResigned = allResigned and (spec == true)
						if not allResigned then
							break
						end
					end
				end
			end
			if not team.dead and allResigned then
				killTeamQueue[teamID] = gf
			else
				if not team.hasLeader and not team.dead then
					if not killTeamQueue[teamID] then
						killTeamQueue[teamID] = gf + config.killGraceFrames	-- add a grace period before killing the team
					end
				elseif killTeamQueue[teamID] then
					killTeamQueue[teamID] = nil
				end
			end
			if killTeamQueue[teamID] and gf >= killTeamQueue[teamID] then
				spring.KillTeam(teamID)
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
		end

		-- if player is an AI controller, then mark all hosted AIs as uncontrolled
		for AITeam, AIAllyTeam in pairs(playerIDtoAIs[playerID] or EMPTY_TABLE) do
			allyTeamInfos[AIAllyTeam].teams[AITeam].isControlled = active
		end

		if allyTeamEvalFrame[allyTeamID] ~= gf then
			allyTeamEvalFrame[allyTeamID] = gf
			UpdateAllyTeamIsDead(allyTeamID, gf)
		end
	end

	local liveness = {}

	liveness.CheckAllPlayers = function(gf)
		playerList = spring.GetPlayerList()
		for i = 1, #playerList do
			local playerID = playerList[i]
			local _, active, spectator, teamID, allyTeamID = spring.GetPlayerInfo(playerID, false)
			local info = playerInfoCache[playerID] or {}
			info.active = active
			info.spectator = spectator
			info.teamID = teamID
			info.allyTeamID = allyTeamID
			playerInfoCache[playerID] = info
		end
		for i = 1, #playerList do
			CheckPlayer(playerList[i], gf)
		end
	end

	-- at start, fill in the table of all alive allyteams
	liveness.InitTeams = function(allyteamList)
		for _, allyTeamID in ipairs(allyteamList) do
			if allyTeamID ~= config.gaiaAllyTeamID then
				local allyteamTeams = spring.GetTeamList(allyTeamID)
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
						hasLeader = select(2, spring.GetTeamInfo(teamID, false)) >= 0,
					}
					local teamPlayers = spring.GetPlayerList(teamID) or EMPTY_TABLE
					for p = 1, #teamPlayers do
						teamInfo.players[teamPlayers[p]] = false
					end
					-- engine AI
					teamInfo.isAI = select(4, spring.GetTeamInfo(teamID, false))
					if teamInfo.isAI then
						-- store who hosts that engine AI
						local AIHostPlayerID = select(3, spring.GetAIInfo(teamID))
						playerIDtoAIs[AIHostPlayerID] = playerIDtoAIs[AIHostPlayerID] or {}
						playerIDtoAIs[AIHostPlayerID][teamID] = allyTeamID
					end
					-- lua AI
					local luaAi = spring.GetTeamLuaAI(teamID)
					if luaAi and luaAi ~= '' then
						teamInfo.isAI = true
						teamInfo.isControlled = true
					end

					teamInfo.unitCount = spring.GetTeamUnitCount(teamID)
					allyTeamInfo.unitCount = allyTeamInfo.unitCount + teamInfo.unitCount
					local units = spring.GetTeamUnits(teamID) or EMPTY_TABLE
					for u = 1, #units do
						if config.unitDecoration[spring.GetUnitDefID(units[u])] then
							allyTeamInfo.unitDecorationCount = allyTeamInfo.unitDecorationCount + 1
						end
					end
					allyTeamInfo.teams[teamID] = teamInfo
				end
				allyTeamInfos[allyTeamID] = allyTeamInfo
			end
		end
	end

	liveness.TeamDied = function(teamID, gf)
		local allyTeamID = teamToAllyTeam[teamID]
		allyTeamInfos[allyTeamID].teams[teamID].dead = true
		UpdateAllyTeamIsDead(allyTeamID, gf)
		liveness.CheckAllPlayers(gf)
	end

	liveness.UnitCreated = function(unitDefID, unitTeamID)
		if not config.ignoredTeams[unitTeamID] then
			local allyTeamID = teamToAllyTeam[unitTeamID]
			local allyTeamInfo = allyTeamInfos[allyTeamID]
			allyTeamInfo.teams[unitTeamID].unitCount = allyTeamInfo.teams[unitTeamID].unitCount + 1
			allyTeamInfo.unitCount = allyTeamInfo.unitCount + 1
			if config.unitDecoration[unitDefID] then
				allyTeamInfo.unitDecorationCount = allyTeamInfo.unitDecorationCount + 1
			end
		end
	end

	liveness.UnitDestroyed = function(unitDefID, unitTeam)
		if not config.ignoredTeams[unitTeam] then
			local allyTeamID = teamToAllyTeam[unitTeam]
			local allyTeamInfo = allyTeamInfos[allyTeamID]
			local teamUnitCount = allyTeamInfo.teams[unitTeam].unitCount - 1
			local allyTeamUnitCount = allyTeamInfo.unitCount - 1
			allyTeamInfo.teams[unitTeam].unitCount = teamUnitCount
			allyTeamInfo.unitCount = allyTeamUnitCount
			if config.unitDecoration[unitDefID] then
				allyTeamInfo.unitDecorationCount = allyTeamInfo.unitDecorationCount - 1
			end
			if allyTeamUnitCount <= allyTeamInfo.unitDecorationCount then
				for teamID in pairs(allyTeamInfo.teams) do
					spring.KillTeam(teamID)
					killTeamQueue[teamID] = nil
				end
			end
		end
	end

	liveness.Infos = function()
		return allyTeamInfos
	end

	return liveness
end

return Liveness
