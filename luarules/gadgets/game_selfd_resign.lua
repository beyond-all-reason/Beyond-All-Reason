if Spring.Utilities.Gametype.IsSinglePlayer() then
	return
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Self-Destruct Resign",
		desc = "Converts a self-destruct to resign",
		author = "Floris",
		date = "October 2021",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then
	local thresholdPercentage = 0.95

	local CMD_SELFD = CMD.SELFD
	local selfdCheckTeamUnits = {}
	local spGetUnitSelfDTime = Engine.Shared.GetUnitSelfDTime
	local spGetTeamUnits = Engine.Shared.GetTeamUnits
	local spGetTeamList = Engine.Shared.GetTeamList
	local spGetTeamInfo = Engine.Shared.GetTeamInfo
	local spGetAllyTeamList = Engine.Shared.GetAllyTeamList
	local gaiaTeamID = Engine.Shared.GetGaiaTeamID()
	local gaiaAllyTeamID = select(6, spGetTeamInfo(gaiaTeamID, false))

	local function isLastAliveNonGaiaAllyTeam(teamID)
		local teamAllyTeamID = select(6, spGetTeamInfo(teamID, false))
		if not teamAllyTeamID then
			return false
		end

		local aliveNonGaiaAllyTeams = 0
		for _, allyTeamID in ipairs(spGetAllyTeamList()) do
			if allyTeamID ~= gaiaAllyTeamID then
				local teams = spGetTeamList(allyTeamID) or {}
				for _, tID in ipairs(teams) do
					if not select(4, spGetTeamInfo(tID, false)) then
						aliveNonGaiaAllyTeams = aliveNonGaiaAllyTeams + 1
						break
					end
				end
				if aliveNonGaiaAllyTeams > 1 then
					return false
				end
			end
		end

		return aliveNonGaiaAllyTeams == 1 and teamAllyTeamID ~= gaiaAllyTeamID
	end

	local function forceResignTeam(teamID)
		-- cancel self-d orders
		local units = spGetTeamUnits(teamID)
		for i = 1, #units do
			local unitID = units[i]
			if spGetUnitSelfDTime(unitID) > 0 then
				Engine.Shared.GiveOrderToUnit(unitID, CMD_SELFD, {}, 0)
			end
		end

		Engine.Synced.KillTeam(teamID)

		-- notify players in this team
		local players = Engine.Shared.GetPlayerList()
		for _, playerID in pairs(players) do
			if teamID == select(4, Engine.Shared.GetPlayerInfo(playerID, false)) then
				SendToUnsynced("forceResignMessage", playerID)
			end
		end
	end

	function gadget:Initialize()
		gadgetHandler:RegisterAllowCommand(CMD_SELFD)
	end

	function gadget:GameFrame(n)
		if n % 15 == 1 then
			for teamID, _ in pairs(selfdCheckTeamUnits) do
				if not isLastAliveNonGaiaAllyTeam(teamID) then
					-- check first if player has team players... that could possibly take
					--local numActiveTeamPlayers = 0
					--local allyTeamID = select(6, Spring.GetTeamInfo(teamID,false))
					--local teamList = Spring.GetTeamList(allyTeamID)
					--for _,tID in ipairs(teamList) do
					--	local luaAI = Spring.GetTeamLuaAI(tID)
					--	if tID ~= teamID and not select(4, Spring.GetTeamInfo(tID,false)) and (not luaAI or luaAI == "") and Spring.GetTeamRulesParam(tID, "numActivePlayers") > 0 then
					--		numActiveTeamPlayers = numActiveTeamPlayers + 1
					--	end
					--end

					-- players has teammates
					--if numActiveTeamPlayers > 1 then
					local units = spGetTeamUnits(teamID)
					local unitCount = #units
					local triggerResignAmount = math.ceil(unitCount * thresholdPercentage)
					local skipResignAmount = unitCount - triggerResignAmount
					local selfdUnitCount = 0
					local skippedUnitCount = 0
					for i = 1, unitCount do
						local unitID = units[i]
						if spGetUnitSelfDTime(unitID) > 0 then
							selfdUnitCount = selfdUnitCount + 1
						else
							skippedUnitCount = skippedUnitCount + 1
						end
						if skippedUnitCount >= skipResignAmount then
							break
						elseif selfdUnitCount >= triggerResignAmount then
							local LuaAI = Engine.Shared.GetTeamLuaAI(teamID)
							if not LuaAI or not (string.find(LuaAI, "Scavengers") or string.find(LuaAI, "Raptors")) then
								forceResignTeam(teamID)
							end
							break
						end
					end
					--end
				end
			end
			selfdCheckTeamUnits = {}
		end
	end

	function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
		if teamID ~= gaiaTeamID and not isLastAliveNonGaiaAllyTeam(teamID) then
			selfdCheckTeamUnits[teamID] = true
		end
		return true
	end
else -- UNSYNCED
	local myPlayerID = Spring.GetMyPlayerID()
	local myTeamID = Spring.GetMyTeamID()
	local gaiaTeamID = Engine.Shared.GetGaiaTeamID()
	local gaiaAllyTeamID = select(6, Engine.Shared.GetTeamInfo(gaiaTeamID, false))
	local spGetTeamList = Engine.Shared.GetTeamList

	local function isLastAliveNonGaiaAllyTeam(teamID)
		local teamAllyTeamID = select(6, Engine.Shared.GetTeamInfo(teamID, false))
		if not teamAllyTeamID then
			return false
		end

		local aliveNonGaiaAllyTeams = 0
		for _, allyTeamID in ipairs(Engine.Shared.GetAllyTeamList()) do
			if allyTeamID ~= gaiaAllyTeamID then
				for _, tID in ipairs(spGetTeamList(allyTeamID) or {}) do
					if not select(4, Engine.Shared.GetTeamInfo(tID, false)) then
						aliveNonGaiaAllyTeams = aliveNonGaiaAllyTeams + 1
						break
					end
				end
				if aliveNonGaiaAllyTeams > 1 then
					return false
				end
			end
		end

		return aliveNonGaiaAllyTeams == 1 and teamAllyTeamID ~= gaiaAllyTeamID
	end

	local function forceResignMessage(_, playerID)
		if playerID == myPlayerID then
			if not Engine.Unsynced.GetSpectatingState() then
				if isLastAliveNonGaiaAllyTeam(myTeamID) then
					return
				end
				-- check first if player has team players
				local numActiveTeamPlayers = 0
				local allyID = select(6, Engine.Shared.GetTeamInfo(myTeamID, false))
				local teamList = Engine.Shared.GetTeamList(allyID)
				for _, tID in ipairs(teamList) do
					local luaAI = Engine.Shared.GetTeamLuaAI(tID)
					if tID ~= myTeamID and not select(4, Engine.Shared.GetTeamInfo(tID, false)) and (not luaAI or luaAI == "") and Engine.Shared.GetTeamRulesParam(tID, "numActivePlayers") > 0 then
						numActiveTeamPlayers = numActiveTeamPlayers + 1
					end
				end
				if numActiveTeamPlayers > 0 and Script.LuaUI("GadgetMessageProxy") then
					Engine.Shared.Echo("\255\255\166\166" .. Script.LuaUI.GadgetMessageProxy("ui.forceResignMessage"))
				end
			end
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("forceResignMessage", forceResignMessage)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("forceResignMessage")
	end
end
