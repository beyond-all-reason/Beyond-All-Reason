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

-- 2024-04-15: Since we have multiple discord suggestions asking for more spawn position possibilities, here we go. Note this is the most fastest-to-code version, not the most elegant one.
-- draftMode modoption: skill draft, random draft (are almost identical to 2 "choose in game", just with a delay, eliminating 'fast pc' power gaming)
-- how does it work right now:
-- draft: before the game starts we create a random order of teams that should place: players must place start positions in the order that was determined.
-- skill: instead of random order it's skill based order, with the highest skill placing first.
-- caveats: gameframe is always zero before the gamestarts, this means there is no delay or timeouts on gadget side. so this makes our work harder...
-- we send clients playerID of the players that must place. on the clientside we will reply after 5 seconds "oh yeah we did" regardless if they placed or not. this will allow the gadget to call for the next team to place.
-- this only modifies the possibility of placing before your turn has come up or passed, nothing else has been changed.

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

	local allyTeamSpawnOrder = {} -- [allyTeam] = [teamID,teamID,...] - only used by draft/skill spawn options
	local allyTeamSpawnOrderPlaced = {} -- [allyTeam] = 1,..,#TeamsinAllyTeam - track whos order to place it is
	local gaiaAllyTeamID = select(6, Spring.GetTeamInfo(Spring.GetGaiaTeamID(), false)) -- remember so we don't calculate gaia ally team
	local draftMode = Spring.GetModOptions().draft_mode

	local function FindPlayerIDFromTeamID(teamID) -- need revisit if we allow multiple players on same team btw
		local playerList = Spring.GetPlayerList()
		
		for i = 1, #playerList do
			local playerID = playerList[i]
			local _, _, _, _, _, teamIDOfPlayer = Spring.GetPlayerInfo(playerID)
			
			if teamIDOfPlayer == teamID then
				return playerID
			end
		end
		
		return nil -- Return nil if no player with the specified teamID is found
	end

	-- Shuffle the table
	local function shuffleArray(array)
		-- maybe if array size is 1 just return array as is?
		local n, random, j = #array, math.random
		for i = 1, n do
			local j = random(i, n)
			array[i], array[j] = array[j], array[i]
		end
		return array
	end

	local function GetSkill(playerID)
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
		-- Implement a custom comparison function based on team skill
		local skillA = GetSkill(FindPlayerIDFromTeamID(teamA))
		local skillB = GetSkill(FindPlayerIDFromTeamID(teamB))
		return skillA > skillB  -- Sort in descending order of skill
	end

	local function isAllyTeamSkillZero(allyTeamID)
		local teams = Spring.GetTeamList(allyTeamID)
		for _, teamID in ipairs(teams) do
			local _, _, _, isAiTeam = Spring.GetTeamInfo(teamID)
			if not isAiTeam then  -- Check if the team is human player, if not - don't care
				local players = Spring.GetPlayerList(teamID)
				for _, playerID in ipairs(players) do
					local skill = GetSkill(playerID)
					if skill ~= 0 then
						return false  -- If any player has non-zero skill, return false
					end
				end
			else return true end -- AI is not player, return true
		end
		return true  -- If all players have skill level zero, return true
	end

	local function printTeamNamesAndIDs(teamOrder) -- TODO this should be lua msg probably...
		for _, teamID in ipairs(teamOrder) do
			local playerID = FindPlayerIDFromTeamID(teamID) -- we assume only ONE player can be on a team, which is OK for right now I guess?
			if not playerID then
				Spring.Echo("Name: Unknown, Team ID: " .. teamID) -- if this one happens, we've touched AI or Gaia on accident then!
			else
				local tname = Spring.GetPlayerInfo(playerID, false)
				Spring.Echo("Name: " .. tname .. ", Team ID: " .. teamID)
			end
		end
	end

	local function isTurnToPlace(allyTeamID, teamID) -- return 0 - cant place, -- 1 - your turn, -- 2 - your turn has passed
		local teamOrder = allyTeamSpawnOrder[allyTeamID]
		if not teamOrder then
			return 2  -- No spawn order defined for this ally team, you can place whenever then
		end
	
		local placedIndex = allyTeamSpawnOrderPlaced[allyTeamID]
		if (placedIndex <= 0) then return 2 end -- cannot figure out who's turn, you can place then
		local teamIndex = nil
	
		-- Find the index of the team within the spawn order
		for i, id in ipairs(teamOrder) do
			if id == teamID then
				teamIndex = i
				break
			end
		end
	
		if not teamIndex then
			return 2 -- The team is not in the spawn order, you can place whenever then
		end
	
		if teamIndex == placedIndex then -- YOUR turn
			return 1
		elseif teamIndex < placedIndex then -- skipped your turn?
			return 2
		else
			return 0 -- your turn is yet to be
		end
	end

	local function SendDraftMessageToPlayer(allyTeamID, target_num)
		-- if we can't find playerID of that team, then something has gone very bad... if player never connects we are going to wait for them forever... :(
		if target_num <= #allyTeamSpawnOrder[allyTeamID] then -- if we overflow then all players have placed
			local playerID_draft = FindPlayerIDFromTeamID(allyTeamSpawnOrder[allyTeamID][target_num])
			if (playerID_draft) then
				Spring.SendLuaUIMsg("DraftOrderPlayerTurn " .. playerID_draft)
			end
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
				Spring.SendLuaUIMsg("DraftOrder_Random") -- https://discord.com/channels/549281623154229250/1163844303735500860
				--Spring.Log(gadget:GetInfo().name, LOG.INFO, "manual spawning based on positions chosen by players in start boxes, random draft order")
				local teams = Spring.GetTeamList()  -- Get a list of all teams in the game
				for _, teamID in ipairs(teams) do
					local _,_,_,isAiTeam,_,allyTeamID = Spring.GetTeamInfo(teamID,false)
					if not isAiTeam and gaiaAllyTeamID ~= allyTeamID then  -- Check if the team is human player, if not - don't care
						if not allyTeamSpawnOrder[allyTeamID] then
							allyTeamSpawnOrder[allyTeamID] = {}  -- Initialize order table for the ally team if it doesn't exist
						end
						table.insert(allyTeamSpawnOrder[allyTeamID], teamID)  -- Add the teamID to the order table for the ally team
					end
				end
				-- Now, shuffle the order for each ally team
				for _, teamOrder in pairs(allyTeamSpawnOrder) do
					shuffleArray(teamOrder)
				end
			elseif draftMode == "skill" then -- Skill-based placement order -- maybe if ALL player skills are zero, FORCE a random draft order?
				Spring.SendLuaUIMsg("DraftOrder_Skill") -- https://discord.com/channels/549281623154229250/1134886429361713252
				--Spring.Log(gadget:GetInfo().name, LOG.INFO, "manual spawning based on positions chosen by players in start boxes, skill based draft order") -- similar to next if section but order is based on ts
				local teams = Spring.GetTeamList()
				-- Sort teams based on skill
				table.sort(teams, compareSkills)
		
				-- Assign sorted teams to allyTeamSpawnOrder
				for _, teamID in ipairs(teams) do
					local _,_,_,isAiTeam,_,allyTeamID = Spring.GetTeamInfo(teamID,false)
					if not isAiTeam and gaiaAllyTeamID ~= allyTeamID then  -- Check if the team is human player, if not - don't care
						if not allyTeamSpawnOrder[allyTeamID] then
							allyTeamSpawnOrder[allyTeamID] = {}  -- Initialize order table for the ally team if it doesn't exist
						end
						table.insert(allyTeamSpawnOrder[allyTeamID], teamID)  -- Add the teamID to the order table for the ally team
					end
				end

				-- If the entire ally team has zero skill players, random shuffle then
				for allyTeamID, _ in pairs(allyTeamSpawnOrder) do
					if isAllyTeamSkillZero(allyTeamID) then
						shuffleArray(allyTeamSpawnOrder[allyTeamID]) -- oof
					end
				end
			end
			if draftMode == "skill" or draftMode == "random" then
				-- Send first teams who should place
				for allyTeamID, _ in pairs(allyTeamSpawnOrder) do
					allyTeamSpawnOrderPlaced[allyTeamID] = 1 -- first team in the order queue must place now
					SendDraftMessageToPlayer(allyTeamID, 1)
					-- ^ the way it works, we just send the team 'oh hey its your turn now', then we wait until they place or send the message back 'i skip my turn'
					-- then we OrderPlaced + 1 and send the next team, until the array is empty
				end
				-- Debug. Print the draft order for everybody to see:
				Spring.Echo("Spawn Orders:")
				for allyTeamID, _ in pairs(allyTeamSpawnOrder) do
					Spring.Echo("AllyTeam: "..allyTeamID)
					printTeamNamesAndIDs(allyTeamSpawnOrder[allyTeamID])
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

		if msg == "skip_my_turn" and (draftMode == "skill" or draftMode == "random") then
			local _, _, _, teamID, allyTeamID = Spring.GetPlayerInfo(playerID, false)
			if teamID and allyTeamID then
				local turnCheck = isTurnToPlace(allyTeamID, teamID)
				if turnCheck == 1 then -- your turn and you skip? sure thing then!
					allyTeamSpawnOrderPlaced[allyTeamID] = allyTeamSpawnOrderPlaced[allyTeamID]+1 -- if it "overflows", that means all teams inside the allyteam can place, which is OK
					SendDraftMessageToPlayer(allyTeamID, allyTeamSpawnOrderPlaced[allyTeamID])
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
		if draftMode == "skill" or draftMode == "random" then
			local _, _, _, isAI = Spring.GetTeamInfo(teamID, false)
			if not isAI then -- is it your turn yet?
				-- is it YOUR turn yet?
				local turnCheck = isTurnToPlace(allyTeamID, teamID)
				if turnCheck == 0 then -- NOT your turn, you must wait before other teams place before you!
					return false
				elseif turnCheck == 1 then -- if its 2, your turn has passed or we could not calculate, either way you are good to go to place
					myTurn = true
				end
			end
		end -- the rest of the code untouched, very simple implementation, we only care about delaying a player selecting a start pos out of turn, nothing else

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
			-- nice job!
			allyTeamSpawnOrderPlaced[allyTeamID] = allyTeamSpawnOrderPlaced[allyTeamID]+1 -- if it "overflows", that means all teams inside the allyteam can place, which is OK
			SendDraftMessageToPlayer(allyTeamID, allyTeamSpawnOrderPlaced[allyTeamID])
			-- debug: Spring.Echo("Player has placed on his turn, neat.")
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
