function gadget:GetInfo()
	return {
		name = 'Initial Spawn',
		desc = 'Handles initial spawning of units',
		author = 'Niobium, nbusseneau',
		version = 'v2.0',
		date = 'April 2011',
		license = 'GNU GPL, v2 or later',
		layer = 0,
		enabled = true
	}
end

-- Note: (31/03/13) coop_II deals with the extra startpoints etc needed for teamsIDs with more than one playerID.

-- 2023-08-19: FFA start points configuration is now offloaded to a dedicated `game_ffa_start_setup` gadget and has been
-- reworked with a new format without global variables. The `game_initial_spawn` gadget is now consuming the data
-- provided by `game_ffa_start_setup` instead of also handling FFA start points. Backwards compatibility to the previous
-- FFA start points config format is handled by `game_ffa_start_setup`.

-- 2024-04-15: Draft Spawn Order mod by Tom Fyuri
-- Since we have multiple discord suggestions asking for more spawn position options, here we go.
-- More info: https://github.com/beyond-all-reason/Beyond-All-Reason/pull/2845

----------------------------------------------------------------
-- Synced
----------------------------------------------------------------
if gadgetHandler:IsSyncedCode() then
	local spGetPlayerInfo = Spring.GetPlayerInfo
	local spGetTeamInfo = Spring.GetTeamInfo
	local spGetTeamRulesParam = Spring.GetTeamRulesParam
	local spSetTeamRulesParam = Spring.SetTeamRulesParam
	local spGetAllyTeamStartBox = Spring.GetAllyTeamStartBox
	local spCreateUnit = Spring.CreateUnit
	local spGetGroundHeight = Spring.GetGroundHeight

	----------------------------------------------------------------
	-- Config
	----------------------------------------------------------------
	local changeStartUnitRegex = 'changeStartUnit(%d+)$'
	local startUnitParamName = 'startUnit'
	local closeSpawnDist = 350

	----------------------------------------------------------------
	-- Vars
	----------------------------------------------------------------
	local validStartUnits = {}
	local armcomDefID = UnitDefNames.armcom and UnitDefNames.armcom.id
	if armcomDefID then
		validStartUnits[armcomDefID] = true
	end
	local corcomDefID = UnitDefNames.corcom and UnitDefNames.corcom.id
	if corcomDefID then
		validStartUnits[corcomDefID] = true
	end
	local legcomDefID = UnitDefNames.legcom and UnitDefNames.legcom.id
	if legcomDefID then
		validStartUnits[legcomDefID] = true
	end
	local teams = {} -- teams[teamID] = allyID
	local teamsCount

	-- each player gets to choose a faction
	local playerStartingUnits = {} -- playerStartingUnits[unitID] = unitDefID
	GG.playerStartingUnits = playerStartingUnits

	-- each team gets one startpos. if coop mode is on, extra startpoints are placed in GG.coopStartPoints by coop
	local teamStartPoints = {} -- teamStartPoints[teamID] = {x,y,z}
	GG.teamStartPoints = teamStartPoints
	local startPointTable = {}

	---------------------------------------------------------------------------------------------------
	-- the faction limiter attemtps to group strings seperated by comma and turn any faction names it finds in that into a team limiter.
	-- any groups that are not found to have a valid faction do not expand the pool.
	-- if the pool is insufficent for the number of teams, then the list is read looping back from the start
	local factionStrings = include("gamedata/sidedata.lua")
	if Spring.GetModOptions().experimentallegionfaction then
		factionStrings[#factionStrings + 1] = {
			name = "Legion",
			startunit = 'legcom'
		}
	end
	for _,factionData in pairs(factionStrings) do
		factionData.name = string.lower(factionData.name)
	end
	local faction_limiter = Spring.GetModOptions().faction_limiter
	local faction_limiter_valid = false
	local faction_limited_options = {}
	if faction_limiter then
		faction_limiter = string.lower(faction_limiter)
		local teamGroupID = 1
		local teamLists = string.split(faction_limiter, ',')
		for i = 1, #teamLists do
			local team = teamLists[i]
			for _, faction in pairs(factionStrings) do
				if string.find(team, faction.name) then
					if faction_limited_options[teamGroupID] == nil then
						faction_limited_options[teamGroupID] = {}
					end
					faction_limited_options[teamGroupID][UnitDefNames[faction.startunit].id] = true
					faction_limiter_valid = true
				end
			end
			if faction_limited_options[teamGroupID] ~= nil then
				teamGroupID = teamGroupID + 1
			end
		end
	end

	----------------------------------------------------------------
	-- Start Point Guesser
	----------------------------------------------------------------
	include("luarules/gadgets/lib_startpoint_guesser.lua") -- start point guessing routines

	----------------------------------------------------------------
	-- FFA start points (provided by `game_ffa_start_setup`)
	----------------------------------------------------------------
	local isFFA = Spring.Utilities.Gametype.IsFFA()
	local isTeamFFA = isFFA and Spring.Utilities.Gametype.IsTeams()

	----------------------------------------------------------------
	-- draft/skill order mods --
	----------------------------------------------------------------
	local allyTeamSpawnOrder = {} -- [allyTeam] = [teamID,teamID,...] - used for random/skill draft - placement order
	local allyTeamSpawnOrderPlaced = {} -- [allyTeam] = 1,..,#TeamsinAllyTeam - whose order to place right now
	local teamPlayerData = {} -- [teamID] = {id, name, skill} of that team's player
	local allyTeamIsInGame = {} -- [allyTeam] = true/false - fully joined ally teams
	local votedToForceSkipTurn = {} -- [allyTeam][teamID] - if more than 50% vote for it, the current player turn is force-skipped
	local gaiaAllyTeamID = select(6, Spring.GetTeamInfo(Spring.GetGaiaTeamID(), false))
	local draftMode = Spring.GetModOptions().draft_mode

	local function FindPlayerIDFromTeamID(teamID)
		if teamPlayerData and teamPlayerData[teamID] and teamPlayerData[teamID].id then
			return teamPlayerData[teamID].id
		else
			return nil
		end
	end

	local function shuffleArray(array)
		local n = #array
		if n <= 1 then return array end
		local random = math.random
		for i = 1, n do
			local j = random(i, n)
			array[i], array[j] = array[j], array[i]
		end
		return array
	end

	local function GetSkillByTeam(teamID)
		if teamPlayerData and teamPlayerData[teamID] and teamPlayerData[teamID].skill then
			return teamPlayerData[teamID].skill
		else
			return 0
		end
	end

	local function GetSkillByPlayer(playerID)
		if playerID == nil then return 0 end -- uhh
		local customtable = select(11, Spring.GetPlayerInfo(playerID))
		if type(customtable) == 'table' then
			local tsMu = customtable.skill
			local tsSigma = customtable.skilluncertainty
			local ts = tsMu and tonumber(tsMu:match("%d+%.?%d*"))
			if (ts == nil) then return 0 else return ts end
		end
		return 0
	end

	local function compareSkills(teamA, teamB)
		local skillA = GetSkillByTeam(teamA)
		local skillB = GetSkillByTeam(teamB)
		return skillA > skillB  -- Sort in descending order of skill
	end

	local function isAllyTeamSkillZero(allyTeamID)
		local tteams = Spring.GetTeamList(allyTeamID)
		for _, teamID in ipairs(tteams) do
			local _, _, _, isAiTeam = Spring.GetTeamInfo(teamID)
			if not isAiTeam and gaiaAllyTeamID ~= allyTeamID then
				local skill = GetSkillByTeam(teamID)
				if skill ~= 0 then
					return false
				end
			end
		end
		return true
	end

	local function sendTeamOrder(teamOrder, allyTeamID_ready, log)
		if (teamOrder == nil or #teamOrder <= 0) then return end -- do not send empty order ever
		-- we send to allyTeamID Turn1 Turn2 Turn3 {...}
		local orderMsg = ""
		local orderIds = ""
		local alone = true
		for i, teamID in ipairs(teamOrder) do
			local tname = teamPlayerData[teamID].name or "unknown" -- "unknown" should not happen if we create the order after everyone connects, so we are good
			if i == 1 then
				orderMsg = tname
				orderIds = FindPlayerIDFromTeamID(teamID)
			else
				if alone then alone = false end
				orderMsg = orderMsg .. ", " .. tname
				orderIds = orderIds .. " " .. FindPlayerIDFromTeamID(teamID)
			end
		end
		if log and not alone then
			Spring.Log(gadget:GetInfo().name, LOG.INFO, "Order [id:"..allyTeamID_ready.."]: "..orderMsg)
		end
		Spring.SendLuaUIMsg("DraftOrderPlayersOrder " .. allyTeamID_ready .. " " .. orderIds)
	end

	local function calculateVotedPercentage(allyTeamID)
		local totalPlayers = Spring.GetTeamCount(allyTeamID)
		local votedPlayers = 0
		for teamID, _ in pairs(votedToForceSkipTurn[allyTeamID]) do
			if votedToForceSkipTurn[allyTeamID][teamID] then
				votedPlayers = votedPlayers + 1
			end
		end
		return (votedPlayers / totalPlayers) * 100
	end

	local function checkVotesAndAdvanceTurn(allyTeamID)
		if allyTeamSpawnOrderPlaced[allyTeamID] >= #allyTeamSpawnOrder[allyTeamID] then return end
		local votedPercentage = calculateVotedPercentage(allyTeamID)
		if votedPercentage > 50 then
			--Spring.Echo("Over 50% of players on ally team " .. allyTeamID .. " have voted.")
			for teamID, _ in pairs(votedToForceSkipTurn[allyTeamID]) do
				votedToForceSkipTurn[allyTeamID][teamID] = false -- reset vote
			end -- and advance turn
			allyTeamSpawnOrderPlaced[allyTeamID] = allyTeamSpawnOrderPlaced[allyTeamID]+1
			SendDraftMessageToPlayer(allyTeamID, allyTeamSpawnOrderPlaced[allyTeamID])
		end
	end

	local function isTurnToPlace(allyTeamID, teamID)
		-- Returns:
		-- 0 - Can't place yet
		-- 1 - Your turn
		-- 2 - Your turn has passed
		local teamOrder = allyTeamSpawnOrder[allyTeamID]
		if not teamOrder then
			return 2  -- No spawn order defined for this team; you can place whenever then
		end
		local placedIndex = allyTeamSpawnOrderPlaced[allyTeamID]
		if placedIndex <= 0 then
			return 2 -- Cannot figure out whose turn; you can place then
		end
		local teamIndex = nil
		-- Find the index of the team within the spawn order
		for i, id in ipairs(teamOrder) do
			if id == teamID then
				teamIndex = i
				break
			end
		end
		if not teamIndex then return 2 end -- The team is not in the spawn order; you can place whenever then
		if teamIndex == placedIndex then -- Your turn
			return 1
		elseif teamIndex < placedIndex then -- Skipped your turn?
			return 2
		else
			return 0 -- Your turn is yet to be
		end
	end

	local function SendDraftMessageToPlayer(allyTeamID, target_num)
		-- technically do not care if it overflows here, on the clientside there just won't be anyone in the queue left
		Spring.SendLuaUIMsg("DraftOrderPlayerTurn " .. allyTeamID .. " " .. target_num) -- we send allyTeamID orderIndex
	end

	-- Tom: order is generated after the entire ally team is in game, tested in a LAN game
	local function InitDraftOrderData(allyTeamID_ready) -- by this point we have all teamPlayerData we need
		Spring.SendLuaUIMsg("DraftOrderAllyTeamJoined "..allyTeamID_ready)
		if draftMode == "random" then
			local tteams = Spring.GetTeamList()
			for _, teamID in ipairs(tteams) do
				local _, _, _, isAiTeam, _, allyTeamID = Spring.GetTeamInfo(teamID, false)
				if not isAiTeam and allyTeamID_ready == allyTeamID and gaiaAllyTeamID ~= allyTeamID then
					table.insert(allyTeamSpawnOrder[allyTeamID], teamID)
					if not votedToForceSkipTurn[allyTeamID] then
						votedToForceSkipTurn[allyTeamID] = {}
					end
					votedToForceSkipTurn[allyTeamID][teamID] = false
				end
			end
			shuffleArray(allyTeamSpawnOrder[allyTeamID_ready])
		elseif draftMode == "skill" then
			local tteams = Spring.GetTeamList()
			table.sort(tteams, compareSkills) -- Sort teams based on skill
			-- Assign sorted teams to allyTeamSpawnOrder
			for _, teamID in ipairs(tteams) do
				local _, _, _, isAiTeam, _, allyTeamID = Spring.GetTeamInfo(teamID, false)
				if not isAiTeam and allyTeamID_ready == allyTeamID and gaiaAllyTeamID ~= allyTeamID then
					table.insert(allyTeamSpawnOrder[allyTeamID], teamID)
					if not votedToForceSkipTurn[allyTeamID] then
						votedToForceSkipTurn[allyTeamID] = {}
					end
					votedToForceSkipTurn[allyTeamID][teamID] = false
				end
			end
			-- If the entire ally team has zero skill players, random shuffle then
			if isAllyTeamSkillZero(allyTeamID_ready) then
				shuffleArray(allyTeamSpawnOrder[allyTeamID_ready])
			else -- If two players have same skill, do a coin flip
				local function randomlySwap(array, i, j)
					if math.random(2) == 1 then
						array[i], array[j] = array[j], array[i]
					end
				end
				for i = 1, #allyTeamSpawnOrder[allyTeamID_ready] - 1 do
					if GetSkillByTeam(allyTeamSpawnOrder[allyTeamID_ready][i]) <= 0 then break end
					if GetSkillByTeam(allyTeamSpawnOrder[allyTeamID_ready][i]) == GetSkillByTeam(allyTeamSpawnOrder[allyTeamID_ready][i+1]) then
						randomlySwap(allyTeamSpawnOrder[allyTeamID_ready], i, i+1)
					end
				end
			end
		end
		if draftMode == "skill" or draftMode == "random" then
			allyTeamSpawnOrderPlaced[allyTeamID_ready] = 1 -- First team in the order queue must place now
			SendDraftMessageToPlayer(allyTeamID_ready, 1) -- We send the team a message notifying them it's their turn to place
			sendTeamOrder(allyTeamSpawnOrder[allyTeamID_ready], allyTeamID_ready, true)
		end
	end

	----------------------------------------------------------------
	-- Initialize
	----------------------------------------------------------------
	function gadget:Initialize()
		Spring.SetLogSectionFilterLevel(gadget:GetInfo().name, LOG.INFO)

		local gaiaTeamID = Spring.GetGaiaTeamID()
		local teamList = Spring.GetTeamList()
		for i = 1, #teamList do
			local teamID = teamList[i]
			if teamID ~= gaiaTeamID then
				-- set & broadcast (current) start unit
				local _, _, _, _, teamSide, teamAllyID = spGetTeamInfo(teamID, false)
				local comDefID = armcomDefID
				-- we try to give you your faction, if we can't, we find the first available faction, loops around if the list isn't long enough to include current team
				if faction_limiter_valid then
					if teamSide == 'cortex' and faction_limited_options[ teamAllyID % #faction_limited_options + 1][corcomDefID] then
						comDefID = corcomDefID
					elseif teamSide == 'legion' and faction_limited_options[ teamAllyID % #faction_limited_options + 1][legcomDefID] then
						comDefID = legcomDefID
					elseif faction_limited_options[teamAllyID % #faction_limited_options + 1][armcomDefID] ~= true then
						if faction_limited_options[ teamAllyID % #faction_limited_options + 1][corcomDefID] then
							comDefID = corcomDefID
						elseif faction_limited_options[teamAllyID % #faction_limited_options + 1][legcomDefID] then
							comDefID = legcomDefID
						else
							Spring.Echo("gadget/game_initial_spawn - how did we get here?")
						end
					end
				-- otherwise default behaviour
				else
					if teamSide == 'cortex' then
						comDefID = corcomDefID
					elseif teamSide == 'legion' then
						comDefID = legcomDefID
					end
				end
				spSetTeamRulesParam(teamID, startUnitParamName, comDefID, { allied = true, public = false })
				teams[teamID] = teamAllyID
			end
		end

		teamsCount = 0
		for k, v in pairs(teams) do
			teamsCount = teamsCount + 1
		end

		-- mark all players as 'not yet placed' and 'not yet readied'
		local initState
		if Game.startPosType ~= 2 then
			initState = -1 -- if players won't be allowed to place startpoints
		else
			initState = 0 -- players will be allowed to place startpoints

			if draftMode == "random" then -- Random draft
				Spring.SendLuaUIMsg("DraftOrder_Random") -- Discord: https://discord.com/channels/549281623154229250/1163844303735500860
			elseif draftMode == "skill" then -- Skill-based placement order
				Spring.SendLuaUIMsg("DraftOrder_Skill") -- Discord: https://discord.com/channels/549281623154229250/1134886429361713252
			elseif draftMode == "fair" then -- Fair mod
				Spring.SendLuaUIMsg("DraftOrder_Fair") -- Discord: https://discord.com/channels/549281623154229250/1123310748236529715
			end
			if (draftMode == "skill" or draftMode == "random" or draftMode == "fair") then
				local tteams = Spring.GetTeamList()
				for _, teamID in ipairs(tteams) do
					local _, _, _, isAiTeam, _, allyTeamID = Spring.GetTeamInfo(teamID, false)
					if not isAiTeam and gaiaAllyTeamID ~= allyTeamID then
						teamPlayerData[teamID] = nil
						if allyTeamIsInGame[allyTeamID] == nil then
							allyTeamSpawnOrder[allyTeamID] = {} -- won't be used in fair mode
							allyTeamIsInGame[allyTeamID] = false
						end
					end
				end
			end
		end
		local playerList = Spring.GetPlayerList()
		for _, playerID in pairs(playerList) do
			Spring.SetGameRulesParam("player_" .. playerID .. "_readyState", initState)
		end

		-- initializes gameside player readystates
		--local playerList = Spring.GetPlayerList()
		--for _, playerID in pairs(playerList) do
		--	Spring.SetGameRulesParam("player_" .. playerID .. "_ready_status", 0)
		--end
	end

	----------------------------------------------------------------
	-- Factions
	----------------------------------------------------------------
	-- keep track of choosing faction ingame
	function gadget:RecvLuaMsg(msg, playerID)
		local startUnit = false
		if string.sub(msg, 1, string.len("changeStartUnit")) == "changeStartUnit" then
			startUnit = tonumber(msg:match(changeStartUnitRegex))
		end
		local _, _, playerIsSpec, playerTeam, allyTeamID = Spring.GetPlayerInfo(playerID, false)
		if startUnit and ((validStartUnits[startUnit] and faction_limiter_valid == false) or (faction_limited_options[ allyTeamID % #faction_limited_options + 1][startUnit] and faction_limiter_valid == true)) then
			if not playerIsSpec then
				playerStartingUnits[playerID] = startUnit
				spSetTeamRulesParam(playerTeam, startUnitParamName, startUnit, { allied = true, public = false }) -- visible to allies only, set visible to all on GameStart
				return true
			end
		end

		-- keep track of ready status gameside.
		-- sending ready status in GameSetup early prevents players from repositioning
		-- thus, the plan is to keep track of readystats gameside, and only send through GameSetup
		-- when everyone is ready
		if msg == "ready_to_start_game" then
			Spring.SetGameRulesParam("player_" .. playerID .. "_readyState", 1)
		end

		-- keep track of who has joined
		-- so when last person joins, start the auto-ready countdown
		if msg == "joined_game" then
			Spring.SetGameRulesParam("player_" .. playerID .. "_joined", 1)
			local playerList = Spring.GetPlayerList()
			local all_players_joined = true
			for _, PID in pairs(playerList) do
				local _, _, spectator_flag = Spring.GetPlayerInfo(PID)
				if spectator_flag == false then
					if Spring.GetGameRulesParam("player_" .. PID .. "_joined") == nil then
						all_players_joined = false
					end
				end
			end
			if all_players_joined == true then
				Spring.SetGameRulesParam("all_players_joined", 1)
			end
		end

		-- keep track of lock state
		if msg == "locking_in_place" then
			Spring.SetGameRulesParam("player_" .. playerID .. "_lockState", 1)
		end
		if msg == "unlocking_in_place" then
			Spring.SetGameRulesParam("player_" .. playerID .. "_lockState", 0)
		end

		if not playerIsSpec then
			if (draftMode ~= "disabled") then
				if (draftMode == "skill" or draftMode == "random") then
					if allyTeamSpawnOrderPlaced[allyTeamID] and allyTeamSpawnOrderPlaced[allyTeamID] > 0 then
						if msg == "skip_my_turn" then
							if allyTeamIsInGame[allyTeamID] and playerTeam and allyTeamID then
								local turnCheck = isTurnToPlace(allyTeamID, playerTeam)
								if turnCheck == 1 then -- your turn and you skip? sure thing then!
									allyTeamSpawnOrderPlaced[allyTeamID] = allyTeamSpawnOrderPlaced[allyTeamID]+1 -- if it "overflows", that means all teams inside the allyteam can place, which is OK
									SendDraftMessageToPlayer(allyTeamID, allyTeamSpawnOrderPlaced[allyTeamID])
								end
							end
						elseif msg == "vote_skip_turn" and votedToForceSkipTurn[allyTeamID][playerTeam] ~= nil and allyTeamSpawnOrderPlaced[allyTeamID] < #allyTeamSpawnOrder[allyTeamID] then
							votedToForceSkipTurn[allyTeamID][playerTeam] = true
							checkVotesAndAdvanceTurn(allyTeamID)
						end
					end
				end
				if msg == "i_have_joined_fair" then
					local playerName = select(1,Spring.GetPlayerInfo(playerID, false))
					if playerID > -1 and playerName ~= nil then
						teamPlayerData[playerTeam] = {id = playerID, name = playerName, skill = GetSkillByPlayer(playerID)} -- Save data
					end
					-- Check if all allies have joined
					if allyTeamIsInGame[allyTeamID] ~= true then
						local allAlliesJoined = true
						local teamList = Spring.GetTeamList(allyTeamID)
						for _, team in ipairs(teamList) do
							local _, _, _, isAI = Spring.GetTeamInfo(team, false)
							if not isAI and gaiaAllyTeamID ~= allyTeamID and teamPlayerData[team] == nil then
								allAlliesJoined = false
								--Spring.Echo("Player missing in team:".. team)
								break
							end
						end
						if allAlliesJoined then
							allyTeamIsInGame[allyTeamID] = true
							InitDraftOrderData(allyTeamID)
						end
					end
				elseif msg == "send_me_the_info_again" then -- someone luaui /reload'ed, send them the queue and index again
					if allyTeamIsInGame[allyTeamID] then
						Spring.SendLuaUIMsg("DraftOrderAllyTeamJoined "..allyTeamID)
						if draftMode ~= "fair" and allyTeamSpawnOrderPlaced[allyTeamID] then
							SendDraftMessageToPlayer(allyTeamID, allyTeamSpawnOrderPlaced[allyTeamID])
							sendTeamOrder(allyTeamSpawnOrder[allyTeamID], allyTeamID, false)
						end
					end
				end
			end
		end
	end
	
	----------------------------------------------------------------
	-- Startpoints
	----------------------------------------------------------------
	function gadget:AllowStartPosition(playerID, teamID, readyState, x, y, z)
		-- readyState:
		-- 0: player did not place startpoint, is unready
		-- 1: game starting, player is ready
		-- 2: player pressed ready OR game is starting and player is forcibly readied (note: if the player chose a startpoint, reconnected and pressed ready without re-placing, this case will have the wrong x,z)
		-- 3: game forcestarted & player absent

		-- we also add the following
		-- -1: players will not be allowed to place startpoints; automatically readied once ingame
		--  4: player has placed a startpoint but is not yet ready

		--[[
		-- for debugging
		local name,_,_,tID = Spring.GetPlayerInfo(playerID,false)
		Spring.Echo(name,tID,x,z,readyState, (startPointTable[tID]~=nil))
		Spring.MarkerAddPoint(x,y,z,name .. " " .. readyState)
		--]]

		-- if startPosType is not set to choose-in-game, we will handle start positions manually
		if Game.startPosType ~= 2 then
			return true
		end

		if select(4, Spring.GetTeamInfo(teamID)) then -- isAiTeam
			return false
		end

		local _, _, _, teamID, allyTeamID = Spring.GetPlayerInfo(playerID, false)
		if not teamID or not allyTeamID then
			return false
		end --fail

		local myTurn = false
		local _, _, _, isAI = Spring.GetTeamInfo(teamID, false)
		if not isAI then
			if allyTeamIsInGame[allyTeamID] == false then return false end -- Wait for everyone
			if draftMode == "skill" or draftMode == "random" then
				local turnCheck = isTurnToPlace(allyTeamID, teamID) -- Check if it's your turn
				if turnCheck == 0 then
					return false
				elseif turnCheck == 1 then
					myTurn = true
				end
			end
		end -- The rest of the code remains untouched; it's a simple implementation

		-- don't allow player to place startpoint unless its inside the startbox, if we have a startbox
		if allyTeamID == nil then
			return false
		end
		local xmin, zmin, xmax, zmax = spGetAllyTeamStartBox(allyTeamID)
		if xmin >= xmax or zmin >= zmax then
			return true
		else
			local isOutsideStartbox = (xmin + 1 >= x) or (x >= xmax - 1) or (zmin + 1 >= z) or
					(z >= zmax - 1) -- the engine rounds startpoints to integers but does not round the startbox (wtf)
			if isOutsideStartbox then
				return false
			end
		end

		-- don't allow player to place if locked
		local is_player_locked = Spring.GetGameRulesParam("player_" .. playerID .. "_lockState")
		if is_player_locked == 1 then
			return false
		end

		-- communicate readyState to all
		-- Spring.SetGameRulesParam("player_" .. playerID .. "_readyState", readyState)
		local is_player_ready = Spring.GetGameRulesParam("player_" .. playerID .. "_readyState")

		for otherTeamID, startpoint in pairs(startPointTable) do
			local sx, sz = startpoint[1], startpoint[2]
			local tooClose = ((x - sx) ^ 2 + (z - sz) ^ 2 <= closeSpawnDist ^ 2)
			local sameTeam = (teamID == otherTeamID)
			local sameAllyTeam = (allyTeamID == select(6, Spring.GetTeamInfo(otherTeamID, false)))
			if (sx > 0) and tooClose and sameAllyTeam and not sameTeam then
				SendToUnsynced("PositionTooClose", playerID)
				return false
			end
		end

		-- record table of starting points for startpoint assist to use
		if readyState == 2 then
			-- player pressed ready (we have already recorded their startpoint when they placed it) OR game was force started and player is forcibly readied
			if not startPointTable[teamID] then
				startPointTable[teamID] = { -5000, -5000 } -- if the player was forcibly readied without having placed a startpoint, place an invalid one far away (thats what the StartPointGuesser wants)
			end
		else
			-- player placed startpoint OR game is starting and player is ready
			startPointTable[teamID] = { x, z }
			if is_player_ready ~= 1 then
				-- game is not starting (therefore, player cannot yet have pressed ready)
				Spring.SetGameRulesParam("player_" .. playerID .. "_readyState", 4)
			end
		end

		if myTurn then
			allyTeamSpawnOrderPlaced[allyTeamID] = allyTeamSpawnOrderPlaced[allyTeamID]+1
			SendDraftMessageToPlayer(allyTeamID, allyTeamSpawnOrderPlaced[allyTeamID])
		end
		return true
	end

	local function setPermutedSpawns(nSpawns, idsToSpawn)
		-- this function assumes that idsToSpawn is a hash table with nSpawns elements
		-- returns a bijective random map from key values of idsToSpawn to [1,...,nSpawns]

		-- first, construct a random permutation of [1,...,nSpawns] using a Knuth shuffle
		local perm = {}
		for i = 1, nSpawns do
			perm[i] = i
		end
		for i = 1, nSpawns - 1 do
			local j = math.random(i, nSpawns)
			local temp = perm[i]
			perm[i] = perm[j]
			perm[j] = temp
		end

		local permutedSpawns = {}
		local slot = 1
		for id, _ in pairs(idsToSpawn) do
			permutedSpawns[id] = perm[slot]
			slot = slot + 1
		end
		return permutedSpawns
	end

	local startUnitList = {}
	local function spawnStartUnit(teamID, x, z)
		local startUnit = spGetTeamRulesParam(teamID, startUnitParamName)
		local luaAI = Spring.GetTeamLuaAI(teamID)

		local _, _, _, isAI, sideName = Spring.GetTeamInfo(teamID)
		if sideName == "random" then
			if math.random() > 0.5 then
				startUnit = corcomDefID
			else
				startUnit = armcomDefID
			end
		end

		-- spawn starting unit
		local y = spGetGroundHeight(x, z)
		local scenarioSpawnsUnits = false

		if Spring.GetModOptions().scenariooptions then
			local scenariooptions = Json.decode(string.base64Decode(Spring.GetModOptions().scenariooptions))
			if scenariooptions and scenariooptions.unitloadout and next(scenariooptions.unitloadout) then
				Spring.Echo("Scenario: Spawning loadout instead of regular commanders")
				scenarioSpawnsUnits = true
			end
		end


		if not scenarioSpawnsUnits then
			if not (luaAI and (string.find(luaAI, "Scavengers") or luaAI == "RaptorsAI" or luaAI == "ScavReduxAI")) then
				local unitID = spCreateUnit(startUnit, x, y, z, 0, teamID)
				if unitID then
					startUnitList[#startUnitList + 1] = { unitID = unitID, teamID = teamID, x = x, y = y, z = z }
					if not isAI then
						Spring.MoveCtrl.Enable(unitID)
					end
					Spring.SetUnitNoDraw(unitID, true)
					local uhealth, umaxhealth, uparalyze = Spring.GetUnitHealth(unitID)
					local paralyzemult = 3 * 0.025 -- 3 seconds of paralyze
					local paralyzedamage = (umaxhealth - uparalyze) + (umaxhealth * paralyzemult)
					Spring.SetUnitHealth(unitID, { paralyze = paralyzedamage })
				end
			end
		end

		-- share info
		teamStartPoints[teamID] = { x, y, z }
		--spSetTeamRulesParam(teamID, startUnitParamName, startUnit, { public = true }) -- visible to all (and picked up by advpllist)
		spSetTeamRulesParam(teamID, startUnitParamName, startUnit, { allied = true, public = false })

		-- team storage is set up by game_team_resources
	end

	local function spawnUsingFFAStartPoints(teamID, allyTeamID)
		-- get ally team start point
		local startPoint = GG.ffaStartPoints[allyTeamID]
		local x = startPoint.x
		local z = startPoint.z

		-- if we are in TeamFFA but still using automatic spawning (i.e. no start boxes), we want to avoid
		-- spawning all commanders in the exact same position
		if isTeamFFA then
			local r = math.random(50, 120)
			local theta = math.random(100) / 100 * 2 * math.pi
			local cx = x + r * math.cos(theta)
			local cz = z + r * math.sin(theta)
			if not IsSteep(cx, cz) then
				-- IsSteep comes from lib_startpoint_guesser, returns true if pos is too steep for com to walk on
				x = cx
				z = cz
			end
		end

		spawnStartUnit(teamID, x, z)
	end

	local function spawnRegularly(teamID, allyTeamID)
		local x, _, z = Spring.GetTeamStartPosition(teamID)
		local xmin, zmin, xmax, zmax = spGetAllyTeamStartBox(allyTeamID)

		-- if its choose-in-game mode, see if we need to autoplace anyone
		if Game.startPosType == 2 then
			if not startPointTable[teamID] or startPointTable[teamID][1] < 0 then
				-- guess points for the ones classified in startPointTable as not genuine
				x, z = GuessStartSpot(teamID, allyTeamID, xmin, zmin, xmax, zmax, startPointTable)
			else
				-- fallback
				if x <= 0 or z <= 0 then
					x = (xmin + xmax) / 2
					z = (zmin + zmax) / 2
				end
			end
		end

		spawnStartUnit(teamID, x, z)
	end

	----------------------------------------------------------------
	-- Spawning
	----------------------------------------------------------------
	function gadget:GameStart()
		-- if this a FFA match with automatic spawning (i.e. no start boxes) and a list of start points was provided by
		-- `game_ffa_start_setup` for the ally teams in this match
		if isFFA and Game.startPosType == 1 and GG.ffaStartPoints then
			Spring.Log(gadget:GetInfo().name, LOG.INFO, "spawn using FFA start points config")
			for teamID, allyTeamID in pairs(teams) do
				spawnUsingFFAStartPoints(teamID, allyTeamID)
			end
		else
			-- otherwise default to spawning regularly
			if Game.startPosType == 2 then
				if draftMode == "skill" then -- https://discord.com/channels/549281623154229250/1134886429361713252
					Spring.Log(gadget:GetInfo().name, LOG.INFO, "manual spawning based on positions chosen by players in start boxes, skill based draft order") -- similar to next if section but order is based on ts
				elseif draftMode == "random" then -- https://discord.com/channels/549281623154229250/1163844303735500860
					Spring.Log(gadget:GetInfo().name, LOG.INFO, "manual spawning based on positions chosen by players in start boxes, random draft order")
				elseif draftMode == "fair" then -- https://discord.com/channels/549281623154229250/1123310748236529715
					Spring.Log(gadget:GetInfo().name, LOG.INFO, "manual spawning based on positions chosen by players in start boxes, fair mode")
				else
					Spring.Log(gadget:GetInfo().name, LOG.INFO, "manual spawning based on positions chosen by players in start boxes")
				end
			elseif Game.startPosType == 1 then
				Spring.Log(gadget:GetInfo().name, LOG.INFO,
					"automatic spawning using default map start positions, in random order")
			elseif Game.startPosType == 0 then
				Spring.Log(gadget:GetInfo().name, LOG.INFO,
					"automatic spawning using default map start positions, in fixed order")
			end
			for teamID, allyTeamID in pairs(teams) do
				spawnRegularly(teamID, allyTeamID)
			end
		end
	end

	function gadget:GameFrame(n)
		if not scenarioSpawnsUnits then
            if n == 60 then
                for i = 1, #startUnitList do
                    local x = startUnitList[i].x
                    local y = startUnitList[i].y
                    local z = startUnitList[i].z
                    Spring.SpawnCEG("commander-spawn", x, y, z, 0, 0, 0)
                end
            end
            if n == 90 then
                for i = 1, #startUnitList do
                    local unitID = startUnitList[i].unitID
                    Spring.MoveCtrl.Disable(unitID)
                    Spring.SetUnitNoDraw(unitID, false)
                    Spring.SetUnitHealth(unitID, { paralyze = 0 })
                end
            end
		end
		if n > 90 then
			gadgetHandler:RemoveGadget(self)
		end
	end

	------------------------------------------------------------------------------
	------------------------------------------------------------------------------
else -- UNSYNCED
	local function positionTooClose(_, playerID)
		if Script.LuaUI('GadgetMessageProxy') then
			local message = Script.LuaUI.GadgetMessageProxy('ui.initialSpawn.tooClose')
			Spring.SendMessageToPlayer(playerID, message)
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("PositionTooClose", positionTooClose)
	end

	function gadget:GameFrame(n)
		if n == 60 then
			Spring.PlaySoundFile("commanderspawn", 0.6, 'ui')
		end
		if n > 90 then
			gadgetHandler:RemoveGadget(self)
		end
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("PositionTooClose")
	end
end
